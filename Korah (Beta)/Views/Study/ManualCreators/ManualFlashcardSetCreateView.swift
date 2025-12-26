import SwiftUI

struct ManualFlashcardSetCreateView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var subject: String = ""
    @State private var title: String = ""
    @State private var descriptionText: String = ""

    struct EditableCard: Identifiable, Hashable {
        let id = UUID()
        var term: String
        var definition: String
    }
    @State private var cards: [EditableCard] = [EditableCard(term: "", definition: ""), EditableCard(term: "", definition: "")]

    @State private var errorMessage: String? = nil
    
    @State private var studyGuides: [StudyGuide] = []
    @State private var selectedGuideIndex: Int = 0
    @State private var isGenerating: Bool = false
    @State private var showGuideSelectionSection: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !studyGuides.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                    .font(.title3)
                                Text("Generate from Study Guide")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: { showGuideSelectionSection.toggle() }) {
                                    Image(systemName: showGuideSelectionSection ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.yellow)
                                }
                            }
                            
                            if showGuideSelectionSection {
                                VStack(spacing: 10) {
                                    Picker("Study Guide", selection: $selectedGuideIndex) {
                                        ForEach(studyGuides.indices, id: \.self) { idx in
                                            Text(studyGuides[idx].title.isEmpty ? "Untitled Guide" : studyGuides[idx].title).tag(idx)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    
                                    Button(action: generateFlashcardsFromGuide) {
                                        if isGenerating {
                                            HStack {
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                                    .tint(.white)
                                                Text("Generating...")
                                            }
                                            .frame(maxWidth: .infinity)
                                        } else {
                                            HStack {
                                                Image(systemName: "wand.and.stars")
                                                Text("Generate Flashcards")
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.yellow)
                                    .disabled(isGenerating)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.yellow.opacity(0.12))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Set Information")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 12) {
                            InputFieldView(placeholder: "Subject, chapter, unit", text: $subject)
                            InputFieldView(placeholder: "Title", text: $title)
                            InputFieldView(placeholder: "Description (optional)", text: $descriptionText, minHeight: 80)
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("Flashcards")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(cards.count)")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(6)
                        }
                        
                        VStack(spacing: 10) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, _ in
                                FlashcardInputCard(card: $cards[index])
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)

                    if let errorMessage = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .font(.callout)
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.2), lineWidth: 1))
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }

            Button(action: addCard) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.purple))
                    .shadow(color: Color.purple.opacity(0.5), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .cancel) { dismiss() } label: { Image(systemName: "xmark") }
            }
            ToolbarItem(placement: .principal) {
                Text("Create flashcard set").font(.headline).foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: save) { Image(systemName: "checkmark") }
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
        } else {
            studyGuides = []
        }
    }
    
    private func generateFlashcardsFromGuide() {
        guard !studyGuides.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        
        let guide = studyGuides[selectedGuideIndex]
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            errorMessage = "Invalid URL"
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(OpenAIConfig.bearerToken, forHTTPHeaderField: "Authorization")
        
        if OpenAIConfig.bearerToken.isEmpty {
            errorMessage = "Missing or invalid API key."
            isGenerating = false
            return
        }
        
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
- Generate 5-15 flashcard pairs
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
                    
                    if let jsonData = content.data(using: .utf8),
                       let result = try? JSONDecoder().decode([String: [[String: String]]].self, from: jsonData),
                       let cardList = result["cards"] {
                        let newCards = cardList.map { Flashcard(front: $0["term"] ?? "", back: $0["definition"] ?? "") }
                        DispatchQueue.main.async {
                            cards = newCards.map { EditableCard(term: $0.front, definition: $0.back) }
                            title = "Flashcards from \(guide.title)"
                        }
                        return
                    }
                }
                DispatchQueue.main.async { errorMessage = "Failed to parse response" }
            } catch {
                DispatchQueue.main.async { errorMessage = "Parse error: \(error.localizedDescription)" }
            }
        }.resume()
    }

    private func addCard() {
        cards.append(EditableCard(term: "", definition: ""))
    }

    private func save() {
        errorMessage = nil
        let setTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? title : (subject.isEmpty ? "Untitled Set" : subject)
        let nonEmpty = cards.compactMap { c -> (String, String)? in
            let t = c.term.trimmingCharacters(in: .whitespacesAndNewlines)
            let d = c.definition.trimmingCharacters(in: .whitespacesAndNewlines)
            return (t.isEmpty && d.isEmpty) ? nil : (t, d)
        }
        guard !nonEmpty.isEmpty else {
            errorMessage = "Add at least one term and definition."
            return
        }

        var existing: [FlashcardSet] = []
        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let decoded = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
            existing = decoded
        }

        let newCards: [Flashcard] = nonEmpty.map { pair in
            Flashcard(front: pair.0, back: pair.1)
        }

        let newSet = FlashcardSet(title: setTitle, cards: newCards)

        existing.append(newSet)
        if let encoded = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(encoded, forKey: "FlashcardSets")
        }
        dismiss()
    }
}


struct InputFieldView: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 50
    
    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .textInputAutocapitalization(.words)
            .lineLimit(1...5)
            .padding(12)
            .frame(minHeight: minHeight)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            .foregroundColor(.white)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct FlashcardInputCard: View {
    @Binding var card: ManualFlashcardSetCreateView.EditableCard
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(card.term.isEmpty ? "(empty)" : card.term)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.purple)
                    .font(.subheadline)
            }
            
            if isExpanded {
                Divider().background(Color.white.opacity(0.1))
                
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Term")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("Enter term", text: $card.term, axis: .vertical)
                            .textInputAutocapitalization(.sentences)
                            .lineLimit(1...3)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Definition")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("Enter definition", text: $card.definition, axis: .vertical)
                            .textInputAutocapitalization(.sentences)
                            .lineLimit(2...5)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.2), lineWidth: 1))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}

#Preview {
    NavigationStack { ManualFlashcardSetCreateView() }
}
