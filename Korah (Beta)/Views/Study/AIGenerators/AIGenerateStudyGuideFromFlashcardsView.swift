import SwiftUI

fileprivate func extractJSONObject(from text: String) -> String? {
    if let data = text.data(using: .utf8),
       (try? JSONSerialization.jsonObject(with: data)) != nil {
        return text
    }
    guard let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}") else { return nil }
    let sub = text[s...e]
    if let data = String(sub).data(using: .utf8),
       (try? JSONSerialization.jsonObject(with: data)) != nil {
        return String(sub)
    }
    return nil
}

struct AIGenerateStudyGuideFromFlashcardsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSetIndex: Int = 0
    private var flashcardSets: [FlashcardSet] { FirestoreStudyService.shared.flashcardSets }
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        ZStack {
            Color.clear.korahGradientBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                            .font(.title2)
                            .shadow(color: .blue.opacity(0.3), radius: 5)
                        Text("Generate Study Guide")
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
                    
                    Button(action: generateStudyGuide) {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                Text("Generating...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Study Guide")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(flashcardSets.isEmpty || isGenerating ? Color.gray.opacity(0.5) : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(flashcardSets.isEmpty || isGenerating)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            
            // Loading overlay
            if isGenerating {
                ModernLoadingOverlay(
                    message: "Generating Study Guide",
                    subtitle: "Powered by AI • Creating from your flashcards",
                    accentColor: .blue
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .cancel) { dismiss() } label: { Image(systemName: "xmark") }
            }
            ToolbarItem(placement: .principal) {
                Text("Generate Study Guide").font(.headline).foregroundColor(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
    
    private func generateStudyGuide() {
        guard !flashcardSets.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        successMessage = nil
        
        let set = flashcardSets[selectedSetIndex]
        let pairs: [[String: String]] = set.cards.map { ["term": $0.front, "definition": $0.back] }
        
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
You are Korah, a study assistant. Generate a study guide from flashcards using this JSON schema ONLY (no markdown code fences, no extra text):

{
  "kind": "study-guide",
  "title": string,
  "summary": string,
  "steps": [string],
  "hints": [string],
  "questions": [string],
  "footer": string
}

Instructions:
- Create a well-organized guide with clear sections
- Use ONLY the flashcard terms and definitions as content
- Return valid JSON only. No extra text or markdown code fences.
"""
        
        let userPayload: [String: Any] = [
            "setTitle": set.title,
            "pairs": pairs as Any
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
                    
                    guard let jsonString = extractJSONObject(from: content),
                          let jsonData = jsonString.data(using: .utf8),
                          (try? JSONSerialization.jsonObject(with: jsonData)) != nil else {
                        DispatchQueue.main.async { errorMessage = "I had trouble understanding the response. Please try again." }
                        return
                    }
                    
                    let newGuide = StudyGuide(
                        title: "Study Guide: \(set.title)",
                        content: jsonString
                    )
                    try? FirestoreStudyService.shared.addStudyGuide(newGuide)
                    
                    DispatchQueue.main.async {
                        successMessage = "Study guide generated successfully!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                    return
                }
                DispatchQueue.main.async { errorMessage = "I had trouble understanding the response. Please try again." }
            } catch {
                DispatchQueue.main.async { errorMessage = "I had trouble processing that. Please try again." }
            }
        }.resume()
    }
}

#Preview {
    NavigationStack { AIGenerateStudyGuideFromFlashcardsView() }
}
