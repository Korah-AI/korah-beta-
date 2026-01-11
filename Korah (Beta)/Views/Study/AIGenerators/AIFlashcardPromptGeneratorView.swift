import SwiftUI

struct AIFlashcardPromptGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var prompt: String = ""
    @State private var setTitle: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var generatedCards: [Flashcard] = []
    @State private var showSuccessAlert = false
    
    var body: some View {
        ZStack {
            Color.clear.korahGradientBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                                .font(.title2)
                                .shadow(color: .purple.opacity(0.3), radius: 5)
                            Text("AI Flashcard Generator")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text("Describe what you want to study and AI will generate flashcards for you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Set Title")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        TextField("e.g., Spanish Vocabulary", text: $setTitle)
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
                        Text("What do you want to learn?")
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
                            
                            ExamplePromptButton(text: "Basic Spanish greetings and common phrases", onTap: {
                                prompt = "Basic Spanish greetings and common phrases"
                            })
                            
                            ExamplePromptButton(text: "Key concepts from photosynthesis", onTap: {
                                prompt = "Key concepts from photosynthesis"
                            })
                            
                            ExamplePromptButton(text: "Important dates from World War II", onTap: {
                                prompt = "Important dates from World War II"
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
                    
                    Button(action: generateFlashcards) {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                Text("Generating...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Flashcards")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canGenerate ? Color.purple : Color.gray.opacity(0.5))
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
                ModernLoadingOverlay(
                    message: "Generating Flashcards",
                    subtitle: "Powered by AI • Creating your study materials",
                    accentColor: .purple
                )
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
            Text("Generated \(generatedCards.count) flashcards and saved to your library!")
        }
    }
    
    private var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !setTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func generateFlashcards() {
        errorMessage = nil
        isGenerating = true
        
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = setTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
You are Korah, a study assistant. Generate flashcards based on the user's prompt using PURE JSON (no code fences, no markdown) that matches this schema exactly:

{
  "cards": [
    {"term": string, "definition": string},
    ...
  ]
}

Rules:
- Generate 8-15 flashcard pairs based on the topic
- Create clear, concise terms and definitions
- Make them educational and useful for studying
- Return valid JSON only. No extra text.
"""
        
        let userPayload: [String: Any] = [
            "title": trimmedTitle,
            "prompt": trimmedPrompt
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
            "max_tokens": 2000,
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
                let friendlyMessage = APIErrorHandler.handleError(statusCode: http.statusCode, data: data)
                DispatchQueue.main.async { errorMessage = friendlyMessage }
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
                       let result = try? JSONDecoder().decode([String: [[String: String]]].self, from: jsonData),
                       let cardList = result["cards"] {
                        
                        let newCards = cardList.compactMap { dict -> Flashcard? in
                            guard let term = dict["term"], let definition = dict["definition"],
                                  !term.isEmpty, !definition.isEmpty else { return nil }
                            return Flashcard(front: term, back: definition)
                        }
                        
                        guard !newCards.isEmpty else {
                            DispatchQueue.main.async { errorMessage = "No valid flashcards generated" }
                            return
                        }
                        
                        // Save to UserDefaults
                        var existing: [FlashcardSet] = []
                        if let existingData = UserDefaults.standard.data(forKey: "FlashcardSets"),
                           let decoded = try? JSONDecoder().decode([FlashcardSet].self, from: existingData) {
                            existing = decoded
                        }
                        
                        let newSet = FlashcardSet(title: trimmedTitle, cards: newCards)
                        existing.append(newSet)
                        
                        if let encoded = try? JSONEncoder().encode(existing) {
                            UserDefaults.standard.set(encoded, forKey: "FlashcardSets")
                            DispatchQueue.main.async {
                                generatedCards = newCards
                                showSuccessAlert = true
                            }
                        } else {
                            DispatchQueue.main.async { errorMessage = "Failed to save flashcards" }
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

struct ExamplePromptButton: View {
    let text: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow.opacity(0.8))
                Text(text)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .font(.caption)
                    .foregroundColor(.purple.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

#Preview {
    NavigationStack {
        AIFlashcardPromptGeneratorView()
    }
}
