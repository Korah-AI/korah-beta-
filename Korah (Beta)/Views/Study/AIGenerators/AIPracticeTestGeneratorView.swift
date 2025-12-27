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
        NavigationView {
            Form {
                Section(header: Text("Select Flashcard Set")) {
                    if flashcardSets.isEmpty {
                        Text("No flashcard sets found.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Flashcard Set", selection: $selectedSetIndex) {
                            ForEach(flashcardSets.indices, id: \.self) { idx in
                                Text(flashcardSets[idx].title).tag(idx)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedSetIndex) { _ in
                            updateNumberOfQuestionsLimit()
                        }
                    }
                }
                
                if !flashcardSets.isEmpty {
                    Section(header: Text("Number of Questions")) {
                        Stepper(value: $numberOfQuestions, in: 1...max(1, flashcardSets[selectedSetIndex].cards.count)) {
                            Text("\(numberOfQuestions)")
                        }
                    }
                    
                    Section(header: Text("Practice Test Title (optional)")) {
                        TextField("Title", text: $customTitle)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.words)
                    }
                    
                    Section {
                        Button {
                            generatePracticeTest()
                        } label: {
                            HStack {
                                Spacer()
                                if isGenerating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color.purple))
                                } else {
                                    Text("Generate Practice Test")
                                        .bold()
                                }
                                Spacer()
                            }
                        }
                        .disabled(isGenerating || flashcardSets.isEmpty)
                    }
                    
                    if successMessage != nil {
                        Section {
                            Button {
                                generatePracticeTest()
                            } label: {
                                HStack { Spacer(); Text(isGenerating ? "Generating…" : "Generate Again").bold(); Spacer() }
                            }
                            .disabled(isGenerating || flashcardSets.isEmpty)
                        }
                    }
                    
                    if !progressText.isEmpty {
                        Section {
                            Text(progressText)
                                .foregroundColor(.purple)
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if let successMessage = successMessage {
                        Section {
                            Text(successMessage)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onAppear(perform: loadFlashcardSets)
            .korahGradientBackground()
        }
        .navigationTitle("Practice Test Generator")
        .preferredColorScheme(.dark)
        .accentColor(.purple)
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
        request.httpBody = bodyData
        
        progressText = "Sending request to OpenAI..."
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isGenerating = false
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    self.errorMessage = "No data received from OpenAI."
                    return
                }
                
                guard let openAIResponse = try? JSONDecoder().decode(AIChatResponse.self, from: data),
                      let content = openAIResponse.choices.first?.message.content ?? "" as String? else {
                    self.errorMessage = "Failed to parse OpenAI response."
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
