import SwiftUI

struct AIPracticeTestPromptGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var prompt: String = ""
    @State private var testTitle: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert = false
    @State private var numberOfQuestions: Int = 10
    
    var body: some View {
        ZStack {
            Color.clear.korahGradientBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.green)
                                .font(.title2)
                                .shadow(color: .green.opacity(0.3), radius: 5)
                            Text("AI Practice Test Generator")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text("Describe a topic and AI will create a multiple-choice test for you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Title")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        TextField("e.g., World History Quiz", text: $testTitle)
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
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Number of Questions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Picker("Questions", selection: $numberOfQuestions) {
                            Text("5 questions").tag(5)
                            Text("10 questions").tag(10)
                            Text("15 questions").tag(15)
                            Text("20 questions").tag(20)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What topic should the test cover?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        TextEditor(text: $prompt)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 180)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Examples:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ExamplePromptButton(text: "American Revolution key battles and dates", onTap: {
                                prompt = "American Revolution key battles and dates"
                            })
                            
                            ExamplePromptButton(text: "Basic algebra equations and problem solving", onTap: {
                                prompt = "Basic algebra equations and problem solving"
                            })
                            
                            ExamplePromptButton(text: "Parts of the cell and their functions", onTap: {
                                prompt = "Parts of the cell and their functions"
                            })
                        }
                        .padding(.horizontal)
                    }
                    
                    if let errorMessage = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
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
                        .background(canGenerate ? Color.green : Color.gray.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .disabled(!canGenerate || isGenerating)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
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
                Button(role: .cancel) { dismiss() } label: {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItem(placement: .principal) {
                Text("AI Generator")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .alert("Success!", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Practice test with \(numberOfQuestions) questions created and saved to your library!")
        }
    }
    
    private var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !testTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func generatePracticeTest() {
        errorMessage = nil
        isGenerating = true
        
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = testTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            errorMessage = "Invalid URL"
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
You are Korah, a test generator. Generate a multiple-choice test based on the provided topic using **PURE JSON** (no code fences) matching this schema:

{
  "questions": [
    {
      "prompt": string,
      "options": [string, string, string, string],
      "correctIndex": number (0-3)
    }
  ]
}

Rules:
- Generate exactly \(numberOfQuestions) multiple-choice questions based on the topic
- Each question must have exactly 4 options
- correctIndex must be 0, 1, 2, or 3
- Make questions educational and test understanding
- Create plausible distractors (wrong answers)
- Vary difficulty from easy to challenging
- Return valid JSON only. No trailing commas. No extra text.
"""
        
        let userPayload: [String: Any] = [
            "title": trimmedTitle,
            "topic": trimmedPrompt,
            "numQuestions": numberOfQuestions
        ]
        
        let userContentData = try? JSONSerialization.data(withJSONObject: userPayload, options: [.sortedKeys])
        let userContentString = String(data: userContentData ?? Data(), encoding: .utf8) ?? "{}"
        
        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userContentString]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.7,
            "max_tokens": 3000,
            "messages": messages
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { isGenerating = false }
            
            if let error = error {
                DispatchQueue.main.async { errorMessage = "Network error: \(error.localizedDescription)" }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { errorMessage = "No data from server" }
                return
            }
            
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                DispatchQueue.main.async { errorMessage = "HTTP Error \(http.statusCode). Check your API key." }
                return
            }
            
            do {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // Extract JSON from content
                    let jsonString: String
                    if let startIndex = content.firstIndex(of: "{"),
                       let endIndex = content.lastIndex(of: "}") {
                        jsonString = String(content[startIndex...endIndex])
                    } else {
                        jsonString = content
                    }
                    
                    if let jsonData = jsonString.data(using: .utf8),
                       let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let questionArray = result["questions"] as? [[String: Any]] {
                        
                        var questions: [PracticeTestQuestion] = []
                        for item in questionArray {
                            if let prompt = item["prompt"] as? String,
                               let options = item["options"] as? [String],
                               let correctIndex = item["correctIndex"] as? Int,
                               options.count == 4,
                               correctIndex >= 0 && correctIndex < 4 {
                                let q = PracticeTestQuestion(prompt: prompt, options: options, correctIndex: correctIndex)
                                questions.append(q)
                            }
                        }
                        
                        guard !questions.isEmpty else {
                            DispatchQueue.main.async { errorMessage = "No valid questions generated" }
                            return
                        }
                        
                        // Save to UserDefaults
                        var existing: [PracticeTest] = []
                        if let existingData = UserDefaults.standard.data(forKey: "PracticeTests"),
                           let decoded = try? JSONDecoder().decode([PracticeTest].self, from: existingData) {
                            existing = decoded
                        }
                        
                        let newTest = PracticeTest(title: trimmedTitle, questions: questions)
                        existing.append(newTest)
                        
                        if let encoded = try? JSONEncoder().encode(existing) {
                            UserDefaults.standard.set(encoded, forKey: "PracticeTests")
                            DispatchQueue.main.async {
                                showSuccessAlert = true
                            }
                        } else {
                            DispatchQueue.main.async { errorMessage = "Failed to save practice test" }
                        }
                        return
                    }
                }
                DispatchQueue.main.async { errorMessage = "Failed to parse AI response" }
            } catch {
                DispatchQueue.main.async { errorMessage = "Parse error: \(error.localizedDescription)" }
            }
        }.resume()
    }
}

#Preview {
    NavigationStack {
        AIPracticeTestPromptGeneratorView()
    }
}
