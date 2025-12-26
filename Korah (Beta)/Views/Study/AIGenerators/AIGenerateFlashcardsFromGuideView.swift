import SwiftUI

struct AIGenerateFlashcardsFromGuideView: View {
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
                    Text("Generate Flashcards from Study Guide")
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
                    
                    Button(action: generateFlashcards) {
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
                                Text("Generate Flashcards")
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
                Text("Generate Flashcards").font(.headline).foregroundColor(.white)
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
    
    private func generateFlashcards() {
        guard !studyGuides.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        successMessage = nil
        
        let guide = studyGuides[selectedGuideIndex]
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            errorMessage = "Invalid URL"
            isGenerating = false
            return
        }
        
        if OpenAIConfig.bearerToken.isEmpty {
            errorMessage = "Missing or invalid API key."
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(OpenAIConfig.bearerToken, forHTTPHeaderField: "Authorization")
        
        let systemPrompt = """
You are Korah, a study assistant. Generate flashcards from the provided study guide content using PURE JSON (no code fences, no markdown) that matches this schema exactly:

{
  "cards": [
    {"term": string, "definition": string},
    ...
  ]
}

Rules:
- Extract key concepts from the study guide as terms
- Create clear, concise definitions for each term
- Generate 8-15 flashcard pairs
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
            "max_tokens": 1500,
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
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                if let jsonData = content.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let cardList = parsed["cards"] as? [[String: String]] {
                    
                    var existing: [FlashcardSet] = []
                    if let existingData = UserDefaults.standard.data(forKey: "FlashcardSets"),
                       let decoded = try? JSONDecoder().decode([FlashcardSet].self, from: existingData) {
                        existing = decoded
                    }
                    
                    let newCards = cardList.map { Flashcard(front: $0["term"] ?? "", back: $0["definition"] ?? "") }
                    let newSet = FlashcardSet(title: "Flashcards from \(guide.title)", cards: newCards)
                    existing.append(newSet)
                    
                    if let encoded = try? JSONEncoder().encode(existing) {
                        UserDefaults.standard.set(encoded, forKey: "FlashcardSets")
                    }
                    
                    DispatchQueue.main.async {
                        self.successMessage = "Flashcards generated successfully!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.dismiss()
                        }
                    }
                    return
                }
            }
            DispatchQueue.main.async { self.errorMessage = "Failed to parse response" }
        }.resume()
    }
}

#Preview {
    NavigationStack { AIGenerateFlashcardsFromGuideView() }
}
