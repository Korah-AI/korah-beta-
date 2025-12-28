import SwiftUI

struct ManualStudyGuideCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var errorMessage: String? = nil
    
    @State private var flashcardSets: [FlashcardSet] = []
    @State private var selectedSetIndex: Int = 0
    @State private var isGenerating: Bool = false
    @State private var showSetSelectionSection: Bool = false
    
    var body: some View {
        ZStack {
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Study Guide")
                        .font(.title3).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    
                    if !flashcardSets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Generate from Flashcards")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: { showSetSelectionSection.toggle() }) {
                                    Image(systemName: showSetSelectionSection ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.purple)
                                }
                            }
                            
                            if showSetSelectionSection {
                                Picker("Flashcard Set", selection: $selectedSetIndex) {
                                    ForEach(flashcardSets.indices, id: \.self) { idx in
                                        Text(flashcardSets[idx].title).tag(idx)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Button(action: generateGuideFromFlashcards) {
                                    Label("Generate Study Guide", systemImage: "sparkles")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.purple)
                                .disabled(isGenerating || !networkMonitor.isConnected)
                            }
                        }
                        .padding(12)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("e.g., Biology Basics", text: $title)
                            .textInputAutocapitalization(.words)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $content)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 240)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb")
                                    .foregroundColor(.yellow)
                                Text("Use clear, organized sections")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb")
                                    .foregroundColor(.yellow)
                                Text("Include key terms and definitions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb")
                                    .foregroundColor(.yellow)
                                Text("Add bullet points for easier reading")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(8)
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
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.top)
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
                        Text("Generating study guide...")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("This may take a few moments")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                }
            }
            
            // Offline indicator
            if !networkMonitor.isConnected {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.white)
                        Text(networkMonitor.offlineMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.bottom, 20)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .cancel) { dismiss() } label: { Image(systemName: "xmark") }
            }
            ToolbarItem(placement: .principal) {
                Text("Create Study Guide").font(.headline).foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: save) { Image(systemName: "checkmark") }
                    .disabled(!canSave)
                    .foregroundColor(canSave ? .purple : .gray)
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
        } else {
            flashcardSets = []
        }
    }
    
    private func generateGuideFromFlashcards() {
        guard !flashcardSets.isEmpty else { return }
        guard networkMonitor.isConnected else {
            errorMessage = networkMonitor.offlineMessage
            return
        }
        
        isGenerating = true
        errorMessage = nil
        
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
        
        let systemPrompt = """
You are Korah, a study assistant. Generate a study guide from flashcards in plain text format (no JSON, no markdown code fences).

Instructions:
- Create a well-organized guide with clear sections
- Use the flashcard terms and definitions as source material
- Include key takeaways, important definitions, and study tips
- Format with headers, bullet points, and clear organization
- Make it engaging and educational
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
                   let generatedContent = message["content"] as? String {
                    DispatchQueue.main.async {
                        content = generatedContent.trimmingCharacters(in: .whitespacesAndNewlines)
                        title = "Study Guide: \(set.title)"
                    }
                    return
                }
                DispatchQueue.main.async { errorMessage = "I had trouble understanding the response. Please try again." }
            } catch {
                DispatchQueue.main.async { errorMessage = "I had trouble processing that. Please try again." }
            }
        }.resume()
    }
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func save() {
        errorMessage = nil
        
        let guideTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let guideContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !guideTitle.isEmpty, !guideContent.isEmpty else {
            errorMessage = "Please enter both title and content."
            return
        }
        
        var existing: [StudyGuide] = []
        if let data = UserDefaults.standard.data(forKey: "StudyGuides"),
           let decoded = try? JSONDecoder().decode([StudyGuide].self, from: data) {
            existing = decoded
        }
        
        let newGuide = StudyGuide(title: guideTitle, content: guideContent)
        existing.append(newGuide)
        
        if let encoded = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(encoded, forKey: "StudyGuides")
        }
        
        dismiss()
    }
}

#Preview {
    NavigationStack { ManualStudyGuideCreateView() }
}
