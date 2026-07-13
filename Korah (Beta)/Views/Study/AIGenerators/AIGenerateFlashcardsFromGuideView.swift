import SwiftUI

struct AIGenerateFlashcardsFromGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedGuideIndex: Int = 0
    private var studyGuides: [StudyGuide] { FirestoreStudyService.shared.studyGuides }
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
                            .foregroundColor(.purple)
                            .font(.title2)
                            .shadow(color: .purple.opacity(0.3), radius: 5)
                        Text("Generate Flashcards")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    
                    Text("From Study Guide")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                    
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
                        .background(studyGuides.isEmpty || isGenerating ? Color.gray.opacity(0.5) : Color.purple)
                        .cornerRadius(12)
                    }
                    .disabled(studyGuides.isEmpty || isGenerating)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            
            // Loading overlay
            if isGenerating {
                ModernLoadingOverlay(
                    message: "Generating Flashcards",
                    subtitle: "Creating from your study guide",
                    accentColor: .purple
                )
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
        .preferredColorScheme(.dark)
    }
    
    private func generateFlashcards() {
        guard !studyGuides.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        successMessage = nil
        
        let guide = studyGuides[selectedGuideIndex]
        
        guard let url = URL(string: APIConfig.chatCompletionsURL) else {
            errorMessage = "Invalid URL"
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        
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
            "model": APIConfig.chatModel,
            "temperature": 0.3,
            "max_tokens": 1500,
            "messages": messages
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isGenerating = false }
            
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "I'm having trouble connecting. Please check your internet connection and try again." }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { self.errorMessage = "I didn't get a response. Please try again in a moment." }
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
                DispatchQueue.main.async { self.errorMessage = message }
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
                    
                    let newCards = cardList.map { Flashcard(front: $0["term"] ?? "", back: $0["definition"] ?? "") }
                    let newSet = FlashcardSet(title: "Flashcards from \(guide.title)", cards: newCards)
                    try? FirestoreStudyService.shared.addFlashcardSet(newSet)
                    
                    DispatchQueue.main.async {
                        self.successMessage = "Flashcards generated successfully!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.dismiss()
                        }
                    }
                    return
                }
            }
            DispatchQueue.main.async { self.errorMessage = "I had trouble understanding the response. Please try again." }
        }.resume()
    }
}

#Preview {
    NavigationStack { AIGenerateFlashcardsFromGuideView() }
}
