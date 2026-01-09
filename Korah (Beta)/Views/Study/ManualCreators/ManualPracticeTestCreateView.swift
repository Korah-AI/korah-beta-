import SwiftUI

struct ManualPracticeTestCreateView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var errorMessage: String? = nil
    
    @State private var studyGuides: [StudyGuide] = []
    @State private var selectedGuideIndex: Int = 0
    @State private var isGenerating: Bool = false
    @State private var showGuideSelectionSection: Bool = false
    
    struct EditableQuestion: Identifiable, Hashable {
        let id = UUID()
        var prompt: String
        var option1: String
        var option2: String
        var option3: String
        var option4: String
        var correctOption: Int = 0 
    }
    @State private var questions: [EditableQuestion] = [
        EditableQuestion(prompt: "", option1: "", option2: "", option3: "", option4: "")
    ]
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Practice Test")
                        .font(.title3).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    
                    if !studyGuides.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Generate from Study Guide")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: { showGuideSelectionSection.toggle() }) {
                                    Image(systemName: showGuideSelectionSection ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.korahPurple)
                                }
                            }
                            
                            if showGuideSelectionSection {
                                Picker("Study Guide", selection: $selectedGuideIndex) {
                                    ForEach(studyGuides.indices, id: \.self) { idx in
                                        Text(studyGuides[idx].title.isEmpty ? "Untitled Guide" : studyGuides[idx].title).tag(idx)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Button(action: generateTestFromGuide) {
                                    Label("Generate Practice Test", systemImage: "sparkles")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.korahPurple)
                                .disabled(isGenerating)
                            }
                        }
                        .padding(12)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Title")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("e.g., Biology Chapter 3 Quiz", text: $title)
                            .textInputAutocapitalization(.words)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Questions")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        ForEach($questions) { $question in
                            QuestionRowView(question: $question)
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer(minLength: 80)
                }
                .padding(.horizontal)
                .padding(.top)
            }
            
            Button(action: addQuestion) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.korahPurple))
                    .shadow(color: Color.korahPurple.opacity(0.5), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .cancel) { dismiss() } label: { Image(systemName: "xmark") }
            }
            ToolbarItem(placement: .principal) {
                Text("Create Practice Test").font(.headline).foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: save) { Image(systemName: "checkmark") }
                    .disabled(!canSave)
                    .foregroundColor(canSave ? .korahPurple : .gray)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.clear)
        .korahGradientBackground()
        .preferredColorScheme(.dark)
        .onAppear { loadStudyGuides() }
    }
    
    private func loadStudyGuides() {
        if let data = UserDefaults.standard.data(forKey: "StudyGuides"),
           let decoded = try? JSONDecoder().decode([StudyGuide].self, from: data) {
            studyGuides = decoded
            selectedGuideIndex = min(selectedGuideIndex, max(0, studyGuides.count - 1))
        } else {
            studyGuides = []
        }
    }
    
    private func generateTestFromGuide() {
        guard !studyGuides.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        
        let guide = studyGuides[selectedGuideIndex]
        
        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            errorMessage = "Invalid URL"
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        
        let systemPrompt = """
You are Korah, a study assistant. Generate practice test questions from a study guide in JSON format (no code fences, no markdown) that matches this schema exactly:

{
  "questions": [
    {
      "prompt": string,
      "option1": string,
      "option2": string,
      "option3": string,
      "option4": string,
      "correctOption": int (0-3 index)
    },
    ...
  ]
}

Rules:
- Extract key concepts from the study guide
- Create multiple choice questions that test understanding
- Generate 5-10 questions
- Ensure correct answer corresponds to correctOption index (0=opt1, 1=opt2, 2=opt3, 3=opt4)
- Make wrong answers plausible but clearly distinguishable
- Return valid JSON only. No extra text.
"""
        
        let userPayload: [String: Any] = [
            "guideTitle": guide.title,
            "content": guide.content
        ]
        
        let userContentData = try? JSONSerialization.data(withJSONObject: userPayload, options: [.sortedKeys])
        let userContentString = String(data: userContentData ?? Data(), encoding: .utf8) ?? "{}"
        
        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userContentString]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.3,
            "max_tokens": 2000,
            "messages": messages
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { isGenerating = false }
            
            if let error = error {
                DispatchQueue.main.async { errorMessage = "I'm having trouble connecting. Please check your internet connection and try again." }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { errorMessage = "I didn't get a response. Please try again in a moment." }
                return
            }
            
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                var message = "Oops! Something went wrong. "
                if http.statusCode == 401 {
                    message += "There's an authentication issue. Please contact support."
                } else if http.statusCode == 429 {
                    message += "Too many requests right now. Please wait a moment and try again."
                } else if http.statusCode >= 500 {
                    message += "The service is having trouble. Please try again in a few minutes."
                } else {
                    message += "Please try again."
                }
                DispatchQueue.main.async { errorMessage = message }
                return
            }
            
            do {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    if let jsonData = content.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let questionList = parsed["questions"] as? [[String: Any]] {
                        let newQuestions = questionList.compactMap { dict -> EditableQuestion? in
                            let prompt = dict["prompt"] as? String ?? ""
                            let opt1 = dict["option1"] as? String ?? ""
                            let opt2 = dict["option2"] as? String ?? ""
                            let opt3 = dict["option3"] as? String ?? ""
                            let opt4 = dict["option4"] as? String ?? ""
                            let correctIdx = dict["correctOption"] as? Int ?? 0
                            
                            guard !prompt.isEmpty, !opt1.isEmpty, !opt2.isEmpty, !opt3.isEmpty, !opt4.isEmpty else {
                                return nil
                            }
                            
                            return EditableQuestion(prompt: prompt, option1: opt1, option2: opt2, option3: opt3, option4: opt4, correctOption: correctIdx)
                        }
                        
                        DispatchQueue.main.async {
                            if !newQuestions.isEmpty {
                                questions = newQuestions
                                title = "Practice Test from \(guide.title)"
                            } else {
                                errorMessage = "I couldn't generate questions from that. Please try again."
                            }
                        }
                        return
                    }
                }
                DispatchQueue.main.async { errorMessage = "I had trouble understanding the response. Please try again." }
            } catch {
                DispatchQueue.main.async { errorMessage = "I had trouble processing that. Please try again." }
            }
        }.resume()
    }
    
    private var canSave: Bool {
        let testTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let validQuestions = questions.filter { q in
            !q.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !q.option1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !q.option2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !q.option3.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !q.option4.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !testTitle.isEmpty && !validQuestions.isEmpty
    }
    
    private func addQuestion() {
        questions.append(
            EditableQuestion(prompt: "", option1: "", option2: "", option3: "", option4: "")
        )
    }
    
    private func save() {
        errorMessage = nil
        
        let testTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !testTitle.isEmpty else {
            errorMessage = "Please enter a test title."
            return
        }
        
        let validQuestions = questions.compactMap { q -> PracticeTestQuestion? in
            let prompt = q.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let opt1 = q.option1.trimmingCharacters(in: .whitespacesAndNewlines)
            let opt2 = q.option2.trimmingCharacters(in: .whitespacesAndNewlines)
            let opt3 = q.option3.trimmingCharacters(in: .whitespacesAndNewlines)
            let opt4 = q.option4.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !prompt.isEmpty, !opt1.isEmpty, !opt2.isEmpty, !opt3.isEmpty, !opt4.isEmpty else {
                return nil
            }
            
            return PracticeTestQuestion(
                prompt: prompt,
                options: [opt1, opt2, opt3, opt4],
                correctIndex: q.correctOption
            )
        }
        
        guard !validQuestions.isEmpty else {
            errorMessage = "Add at least one complete question with all options filled."
            return
        }
        
        var existing: [PracticeTest] = []
        if let data = UserDefaults.standard.data(forKey: "PracticeTests"),
           let decoded = try? JSONDecoder().decode([PracticeTest].self, from: data) {
            existing = decoded
        }
        
        let newTest = PracticeTest(title: testTitle, questions: validQuestions)
        existing.append(newTest)
        
        if let encoded = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(encoded, forKey: "PracticeTests")
        }
        
        dismiss()
    }
}

struct QuestionRowView: View {
    @Binding var question: ManualPracticeTestCreateView.EditableQuestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Question")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Question text", text: $question.prompt, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1...3)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        OptionIndicator(index: 0, isCorrect: question.correctOption == 0) {
                            question.correctOption = 0
                        }
                        TextField("Option A", text: $question.option1)
                            .textInputAutocapitalization(.sentences)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 8) {
                        OptionIndicator(index: 1, isCorrect: question.correctOption == 1) {
                            question.correctOption = 1
                        }
                        TextField("Option B", text: $question.option2)
                            .textInputAutocapitalization(.sentences)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 8) {
                        OptionIndicator(index: 2, isCorrect: question.correctOption == 2) {
                            question.correctOption = 2
                        }
                        TextField("Option C", text: $question.option3)
                            .textInputAutocapitalization(.sentences)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 8) {
                        OptionIndicator(index: 3, isCorrect: question.correctOption == 3) {
                            question.correctOption = 3
                        }
                        TextField("Option D", text: $question.option4)
                            .textInputAutocapitalization(.sentences)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct OptionIndicator: View {
    let index: Int
    let isCorrect: Bool
    let action: () -> Void
    
    var labels = ["A", "B", "C", "D"]
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isCorrect ? .green : .secondary)
                Text(labels[index])
                    .font(.caption2.bold())
                    .foregroundColor(.white)
            }
            .frame(width: 40)
        }
    }
}

#Preview {
    NavigationStack { ManualPracticeTestCreateView() }
}
