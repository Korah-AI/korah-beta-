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
    
    @State private var flashcardSets: [FlashcardSet] = []
    @State private var selectedSetIndex: Int = 0
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Generate Study Guide from Flashcards")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    
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
                    
                    Button(action: generateStudyGuide) {
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
                                Text("Generate Study Guide")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(flashcardSets.isEmpty || isGenerating ? Color.gray : Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .disabled(flashcardSets.isEmpty || isGenerating)
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
                Text("Generate Study Guide").font(.headline).foregroundColor(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.clear)
        .korahGradientBackground()
        .preferredColorScheme(.dark)
        .onAppear { loadFlashcardSets() }
    }
    
    private func loadFlashcardSets() {
        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let decoded = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
            flashcardSets = decoded
            selectedSetIndex = min(selectedSetIndex, max(0, flashcardSets.count - 1))
        }
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
        
        }
        
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
                DispatchQueue.main.async { errorMessage = "Network error: \(error.localizedDescription)" }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { errorMessage = "No data from server" }
                return
            }
            
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                DispatchQueue.main.async { errorMessage = "HTTP Error \(http.statusCode)" }
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
                        DispatchQueue.main.async { errorMessage = "AI response was not valid JSON" }
                        return
                    }
                    
                    var existing: [StudyGuide] = []
                    if let existingData = UserDefaults.standard.data(forKey: "StudyGuides"),
                       let decoded = try? JSONDecoder().decode([StudyGuide].self, from: existingData) {
                        existing = decoded
                    }
                    
                    let newGuide = StudyGuide(
                        title: "Study Guide: \(set.title)",
                        content: jsonString
                    )
                    existing.append(newGuide)
                    
                    if let encoded = try? JSONEncoder().encode(existing) {
                        UserDefaults.standard.set(encoded, forKey: "StudyGuides")
                    }
                    
                    DispatchQueue.main.async {
                        successMessage = "Study guide generated successfully!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                    return
                }
                DispatchQueue.main.async { errorMessage = "Failed to parse response" }
            } catch {
                DispatchQueue.main.async { errorMessage = "Parse error: \(error.localizedDescription)" }
            }
        }.resume()
    }
}

#Preview {
    NavigationStack { AIGenerateStudyGuideFromFlashcardsView() }
}
