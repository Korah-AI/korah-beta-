import SwiftUI
import Foundation

struct AIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}

struct AIPracticeTestGeneratorView: View {
    @State private var flashcardSets: [FlashcardSet] = []
    @State private var selectedSetIndex: Int = 0
    @State private var numberOfQuestions: Int = 1
    @State private var customTitle: String = ""
    @State private var isGenerating: Bool = false
    @State private var progressText: String = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let openAIURL = URL(string: OpenAIConfig.chatCompletionsURL)!
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.korahGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.green)
                                .font(.title2)
                                .shadow(color: .green.opacity(0.3), radius: 5)
                            Text("Generate Practice Test")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        
                        Text("From Flashcards")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Flashcard Set")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if flashcardSets.isEmpty {
                                Text("No flashcard sets available")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                Picker("Flashcard Set", selection: $selectedSetIndex) {
                                    ForEach(flashcardSets.indices, id: \.self) { idx in
                                        Text(flashcardSets[idx].title).tag(idx)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .onChange(of: selectedSetIndex) { _ in
                                    updateNumberOfQuestionsLimit()
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        if !flashcardSets.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Number of Questions")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    Text("\(numberOfQuestions) questions")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Stepper("", value: $numberOfQuestions, in: 1...max(1, flashcardSets[selectedSetIndex].cards.count))
                                }
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Test Title (Optional)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                TextField("e.g., Biology Quiz", text: $customTitle)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                            }
                        }
                        
                        if !progressText.isEmpty {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.purple)
                                Text(progressText)
                                    .font(.callout)
                                    .foregroundColor(.purple)
                            }
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
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
                            .padding(.horizontal)
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
                            .padding(.horizontal)
                        }
                        
                        Button(action: generatePracticeTest) {
                            HStack(spacing: 8) {
                                if isGenerating {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                    Text("Generating...")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Generate Practice Test")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(flashcardSets.isEmpty || isGenerating ? Color.gray.opacity(0.5) : Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(flashcardSets.isEmpty || isGenerating)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
                
                // Loading overlay
                if isGenerating {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text("Generating practice test...")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("This may take a few seconds")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .cancel) {
                        // Navigation handled by parent
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Generate Practice Test")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
            .korahGradientBackground()
            .preferredColorScheme(.dark)
            .onAppear(perform: loadFlashcardSets)
        }
    }
    
    private func updateNumberOfQuestionsLimit() {
        let maxCount = flashcardSets[selectedSetIndex].cards.count
        if numberOfQuestions > maxCount {
            numberOfQuestions = maxCount
        }
        if numberOfQuestions < 1 {
            numberOfQuestions = 1
        }
    }
    
    private func loadFlashcardSets() {
        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let sets = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
            self.flashcardSets = sets
            if !sets.isEmpty {
                selectedSetIndex = 0
                updateNumberOfQuestionsLimit()
            }
        }
    }
    
    private func generatePracticeTest() {
        guard !flashcardSets.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        successMessage = nil
        progressText = "Preparing prompt..."
        
        let selectedSet = flashcardSets[selectedSetIndex]
        updateNumberOfQuestionsLimit()
        
        let flashcardsArray: [[String: String]] = selectedSet.cards.map {
            ["front": $0.front, "back": $0.back]
        }
        
        let promptJSONSchema = """
        You will receive an array of flashcards with "front" and "back" strings. Generate a multiple choice practice test in JSON format ONLY, no explanations, no extra text. The JSON MUST strictly follow this schema:
        {
          "title": String,
          "questions": [
            {
              "prompt": String,
              "options": [String,String,String,String],
              "correctIndex": Int (0-based index)
            }
          ]
        }
        Create \(numberOfQuestions) questions derived from the flashcards.
        Use the "front" as prompt. The correct answer is always the "back".
        The other options should be plausible wrong answers from other cards' backs.
        Provide the JSON ONLY.
        Here is the flashcards array:
        \(flashcardsArray)
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "temperature": 0.2,
            "max_tokens": 1200,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that outputs strictly JSON."],
                ["role": "user", "content": promptJSONSchema]
            ]
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            self.isGenerating = false
            self.errorMessage = "Failed to create request body."
            return
        }
        
        var request = URLRequest(url: openAIURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        request.httpBody = bodyData
        
        progressText = "Sending request to OpenAI..."
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isGenerating = false
                if let error = error {
                    self.errorMessage = "I'm having trouble connecting. Please check your internet connection and try again."
                    return
                }
                guard let data = data else {
                    self.errorMessage = "I didn't get a response. Please try again in a moment."
                    return
                }
                
                guard let openAIResponse = try? JSONDecoder().decode(AIChatResponse.self, from: data),
                      let content = openAIResponse.choices.first?.message.content ?? "" as String? else {
                    self.errorMessage = "I had trouble understanding the response. Please try again."
                    return
                }
                
                var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
                jsonString = stripCodeFences(from: jsonString)
                
                if let jsonData = jsonString.data(using: .utf8),
                   let parsedTest = try? JSONDecoder().decode(PracticeTest.self, from: jsonData) {
                    self.savePracticeTest(parsedTest)
                } else {
                    self.progressText = "Decoding OpenAI response failed. Generating locally..."
                    let fallbackTest = self.generatePracticeTestLocally(from: selectedSet, count: self.numberOfQuestions, title: self.customTitle.isEmpty ? nil : self.customTitle)
                    self.savePracticeTest(fallbackTest)
                }
            }
        }
        task.resume()
    }
    
    private func savePracticeTest(_ test: PracticeTest) {
        var existingTests: [PracticeTest] = []
        if let data = UserDefaults.standard.data(forKey: "PracticeTests"),
           let decoded = try? JSONDecoder().decode([PracticeTest].self, from: data) {
            existingTests = decoded
        }
        existingTests.append(test)
        if let encoded = try? JSONEncoder().encode(existingTests) {
            UserDefaults.standard.set(encoded, forKey: "PracticeTests")
            self.successMessage = "Practice test \"\(test.title)\" saved successfully."
            self.progressText = ""
            self.errorMessage = nil
        } else {
            self.errorMessage = "Failed to save practice test."
        }
    }
    
    private func stripCodeFences(from string: String) -> String {
        var str = string
        if str.hasPrefix("```json") {
            str = String(str.dropFirst(7))
        } else if str.hasPrefix("```") {
            str = String(str.dropFirst(3))
        }
        if str.hasSuffix("```") {
            str = String(str.dropLast(3))
        }
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generatePracticeTestLocally(from set: FlashcardSet, count: Int, title: String?) -> PracticeTest {
        let cards = set.cards.shuffled()
        let questionsCount = min(count, cards.count)
        
        let allBacks = set.cards.map { $0.back }
        
        var questions: [PracticeTestQuestion] = []
        for i in 0..<questionsCount {
            let correctCard = cards[i]
            var options = [correctCard.back]
            
            var wrongAnswers = allBacks.filter { $0 != correctCard.back }
            wrongAnswers.shuffle()
            options.append(contentsOf: wrongAnswers.prefix(3))
            options.shuffle()
            
            let correctIndex = options.firstIndex(of: correctCard.back) ?? 0
            
            let question = PracticeTestQuestion(
                prompt: correctCard.front,
                options: options,
                correctIndex: correctIndex
            )
            questions.append(question)
        }
        
        let testTitle = title?.isEmpty == false ? title! : "Practice Test from \(set.title)"
        return PracticeTest(title: testTitle, questions: questions)
    }
}

struct AIPracticeTestGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        AIPracticeTestGeneratorView()
            .preferredColorScheme(.dark)
            .accentColor(.purple)
    }
}
