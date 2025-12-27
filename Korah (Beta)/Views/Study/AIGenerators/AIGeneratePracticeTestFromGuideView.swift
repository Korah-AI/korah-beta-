import SwiftUI

struct AIGeneratePracticeTestFromGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var studyGuides: [StudyGuide] = []
    @State private var selectedGuideIndex: Int = 0
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Generate Practice Test from Study Guide")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Study Guide")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if studyGuides.isEmpty {
                            Text("No study guides available")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            Picker("Study Guide", selection: $selectedGuideIndex) {
                                ForEach(studyGuides.indices, id: \.self) { idx in
                                    Text(studyGuides[idx].title.isEmpty ? "Untitled Guide" : studyGuides[idx].title).tag(idx)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    
                    if let error = errorMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.callout)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        .padding()
                    }
                    
                    if let success = successMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text(success)
                                .font(.callout)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                        .padding()
                    }
                    
                    Button(action: generatePracticeTest) {
                        if isGenerating {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                Text("Generating...")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        } else {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Generate Practice Test")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(studyGuides.isEmpty || isGenerating ? Color.gray : Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .disabled(studyGuides.isEmpty || isGenerating)
                    .padding()
                    
                    Spacer()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .cancel) { dismiss() } label: { Image(systemName: "xmark") }
            }
            ToolbarItem(placement: .principal) {
                Text("Generate Practice Test").font(.headline).foregroundColor(.white)
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
        }
    }
    
    private func generatePracticeTest() {
        guard !studyGuides.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        successMessage = nil
        
        let guide = studyGuides[selectedGuideIndex]
        
        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            errorMessage = "Invalid URL"
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
            DispatchQueue.main.async { self.isGenerating = false }
            
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Network error: \(error.localizedDescription)" }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { self.errorMessage = "No data from server" }
                return
            }
            
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                DispatchQueue.main.async { self.errorMessage = "HTTP Error \(http.statusCode)" }
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
                        
                        let questions = questionList.compactMap { dict -> PracticeTestQuestion? in
                            let prompt = dict["prompt"] as? String ?? ""
                            let opt1 = dict["option1"] as? String ?? ""
                            let opt2 = dict["option2"] as? String ?? ""
                            let opt3 = dict["option3"] as? String ?? ""
                            let opt4 = dict["option4"] as? String ?? ""
                            let correctIdx = dict["correctOption"] as? Int ?? 0
                            
                            guard !prompt.isEmpty, !opt1.isEmpty, !opt2.isEmpty, !opt3.isEmpty, !opt4.isEmpty else {
                                return nil
                            }
                            
                            return PracticeTestQuestion(
                                prompt: prompt,
                                options: [opt1, opt2, opt3, opt4],
                                correctIndex: correctIdx
                            )
                        }
                        
                        guard !questions.isEmpty else {
                            DispatchQueue.main.async { self.errorMessage = "No valid questions generated" }
                            return
                        }
                        
                        var existing: [PracticeTest] = []
                        if let existingData = UserDefaults.standard.data(forKey: "PracticeTests"),
                           let decoded = try? JSONDecoder().decode([PracticeTest].self, from: existingData) {
                            existing = decoded
                        }
                        
                        let newTest = PracticeTest(
                            title: "Practice Test from \(guide.title)",
                            questions: questions
                        )
                        existing.append(newTest)
                        
                        if let encoded = try? JSONEncoder().encode(existing) {
                            UserDefaults.standard.set(encoded, forKey: "PracticeTests")
                        }
                        
                        DispatchQueue.main.async {
                            self.successMessage = "Practice test generated successfully!"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                self.dismiss()
                            }
                        }
                        return
                    }
                }
                DispatchQueue.main.async { self.errorMessage = "Failed to parse response" }
            } catch {
                DispatchQueue.main.async { self.errorMessage = "Parse error: \(error.localizedDescription)" }
            }
        }.resume()
    }
}

#Preview {
    NavigationStack { AIGeneratePracticeTestFromGuideView() }
}
