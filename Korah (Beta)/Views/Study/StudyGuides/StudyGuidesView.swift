import SwiftUI
import Foundation
import UIKit

struct KorahFormatted: Decodable {
    let kind: String?
    let title: String?
    let summary: String?
    let steps: [String]?
    let hints: [String]?
    let questions: [String]?
    let footer: String?
}

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

fileprivate struct OAChatMessage: Encodable { let role: String; let content: String }
fileprivate struct OAChatRequest: Encodable {
    let model: String
    let temperature: Double
    let max_tokens: Int
    let messages: [OAChatMessage]
}

fileprivate struct OAChatAPIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String?
            let content: String?
        }
        let index: Int?
        let message: Message
        let finish_reason: String?
    }
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]
}

struct GeneratedStudyGuide: Decodable {
    struct Meta: Decodable {
        let title: String               
        let setTitle: String
        let audience: String?           
        let difficulty: String?         
        let sourceCount: Int?           
        let generatedAt: String?        
    }
    struct Term: Decodable {
        let term: String
        let definition: String
    }
    struct QA: Decodable, Identifiable {
        let id: String
        let question: String
        let answer: String
    }

    let meta: Meta
    let keyTakeaways: [String]          
    let terms: [Term]                   
    let summary: String                 
    let practiceQuestions: [QA]         
}

fileprivate func studyGuideToMarkdown(_ g: GeneratedStudyGuide) -> String {
    var md: [String] = []

    md.append("## \(g.meta.title)")
    md.append("")
    md.append("_From set:_ **\(g.meta.setTitle)**")
    if let aud = g.meta.audience, !aud.isEmpty { md.append("_Audience:_ \(aud)") }
    if let diff = g.meta.difficulty, !diff.isEmpty { md.append("_Difficulty:_ \(diff)") }
    if let sc = g.meta.sourceCount { md.append("_Cards used:_ \(sc)") }
    if let ts = g.meta.generatedAt { md.append("_Generated:_ \(ts)") }
    md.append("")

    if !g.keyTakeaways.isEmpty {
        md.append("## Key Takeaways")
        g.keyTakeaways.forEach { md.append("- \($0)") }
        md.append("")
    }

    if !g.terms.isEmpty {
        md.append("## Terms")
        g.terms.forEach { md.append("- \($0.term): \($0.definition)") }
        md.append("")
    }

    if !g.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        md.append("## Summary")
        md.append(g.summary)
        md.append("")
    }

    if !g.practiceQuestions.isEmpty {
        md.append("## Practice Questions")
        for (i, q) in g.practiceQuestions.enumerated() {
            md.append("\(i+1). \(q.question)")
        }
        md.append("")
        md.append("## Answers")
        for (i, q) in g.practiceQuestions.enumerated() {
            md.append("\(i+1). \(q.answer)")
        }
        md.append("")
    }

    return md.joined(separator: "\n")
}

struct StudyGuidesView: View {
    let openGeneratorOnAppear: Bool

    init(openGeneratorOnAppear: Bool = false) {
        self.openGeneratorOnAppear = openGeneratorOnAppear
    }

    @State private var inputText: String = ""
    @State private var guideTitle: String = ""
    @State private var generatedMarkdown: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    @State private var savedGuides: [StudyGuide] = []
    private let saveKey = "StudyGuides"

    @State private var flashcardSets: [FlashcardSet] = []
    @State private var selectedSetIndex: Int = 0
    @State private var navigateToGenerator: Bool = false
    @State private var showManualCreate: Bool = false

    private func loadGuides() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([StudyGuide].self, from: data) {
            savedGuides = decoded
        }
    }
    private func persistGuides() {
        if let encoded = try? JSONEncoder().encode(savedGuides) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func deleteGuides(at offsets: IndexSet) {
        let sorted = savedGuides.sorted(by: { $0.createdAt > $1.createdAt })
        var mutable = sorted
        mutable.remove(atOffsets: offsets)
        savedGuides = mutable
        persistGuides()
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

    private func generateStudyGuideFromSelectedSet() {
        errorMessage = nil
        isLoading = true
        generatedMarkdown = ""

        guard !flashcardSets.isEmpty else {
            self.errorMessage = "No flashcard sets found."
            self.isLoading = false
            return
        }
        let set = flashcardSets[selectedSetIndex]
        let pairs: [[String: String]] = set.cards.map { ["term": $0.front, "definition": $0.back] }

        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            self.errorMessage = "Invalid URL"
            self.isLoading = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemJSONSchema = """
You are Korah, a friendly study coach. Create study guides from flashcard sets using **PURE JSON** (no code fences, no markdown) that matches this schema exactly:

{
  "kind": "study-guide",
  "title": string,              
  "summary": string,            
  "steps": [string],            
  "hints": [string],            
  "questions": [string],        
  "footer": string              
}

Rules:
- Use ONLY the provided flashcard term/definition pairs as content.
- Create an engaging title for the study guide
- Write a clear 2-3 sentence summary of what this study guide covers
- List 4-8 key learning objectives in "steps" (what students should know/understand)
- Include 3-6 most important terms with brief definitions in "hints" 
- Create 4-8 practice questions in "questions" that test understanding
- Add an encouraging footer message
- Keep language friendly and educational
- Return valid JSON only. No trailing commas. No extra text.
"""

        let userPayload: [String: Any] = [
            "setTitle": set.title,
            "pairs": pairs as Any
        ]

        let userContentData = try? JSONSerialization.data(withJSONObject: userPayload, options: [.sortedKeys])
        let userContentString = String(data: userContentData ?? Data(), encoding: .utf8) ?? "{}"

        let messages = [
            OAChatMessage(role: "system", content: systemJSONSchema),
            OAChatMessage(role: "user", content: userContentString)
        ]

        let chatBody = OAChatRequest(
            model: "gpt-4o-mini",          
            temperature: 0.2,
            max_tokens: 1600,
            messages: messages
        )
        request.httpBody = try? JSONEncoder().encode(chatBody)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Network error: \(error.localizedDescription)" }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { self.errorMessage = "No data from server" }
                return
            }

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let msg: String
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = dict["error"] as? [String: Any],
                   let m = err["message"] as? String {
                    msg = m
                } else {
                    msg = "HTTP Error \(http.statusCode). Check your API key."
                }
                DispatchQueue.main.async { self.errorMessage = msg }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(OAChatAPIResponse.self, from: data)
                let raw = decoded.choices.first?.message.content ?? ""
                guard let jsonString = extractJSONObject(from: raw),
                      let jsonData = jsonString.data(using: .utf8) else {
                    DispatchQueue.main.async { self.errorMessage = "AI did not return valid JSON." }
                    return
                }
                if let _ = try? JSONDecoder().decode(KorahFormatted.self, from: jsonData) {
                    let title = "Study Guide: \(set.title)"
                    let guide = StudyGuide(title: title, content: jsonString)
                    DispatchQueue.main.async {
                        self.savedGuides.append(guide)
                        self.persistGuides()
                    }
                } else {
                    let guideJSON = try JSONDecoder().decode(GeneratedStudyGuide.self, from: jsonData)
                    let title = guideJSON.meta.title.isEmpty ? "Study Guide: \(set.title)" : guideJSON.meta.title
                    let guide = StudyGuide(title: title, content: jsonString)
                    DispatchQueue.main.async {
                        self.savedGuides.append(guide)
                        self.persistGuides()
                    }
                }
            } catch {
                let responseString = String(data: data, encoding: .utf8) ?? "(unreadable)"
                print("Decode error: \(error)\nRaw: \(responseString)")
                DispatchQueue.main.async { self.errorMessage = "Error in parsing JSON. Please try again" }
            }
        }.resume()
    }

    private func generatePracticeTestFromSelectedSet() {
        errorMessage = nil
        isLoading = true
        generatedMarkdown = ""

        guard !flashcardSets.isEmpty else {
            self.errorMessage = "No flashcard sets found."
            self.isLoading = false
            return
        }
        let set = flashcardSets[selectedSetIndex]

        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            self.errorMessage = "Invalid URL"
            self.isLoading = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Implementation for generating practice test should be added here
    }

    private func generateStudyGuideFromPastedText() {
        errorMessage = nil
        isLoading = true

        let source = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { isLoading = false; return }

        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            self.errorMessage = "Invalid URL"
            self.isLoading = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemJSONSchema =
        """
        You are Korah, a friendly study coach. Create study guides from text using **PURE JSON** (no code fences, no markdown) that matches this schema exactly:

        {
          "kind": "study-guide",
          "title": string,              
          "summary": string,            
          "steps": [string],            
          "hints": [string],            
          "questions": [string],        
          "footer": string              
        }

        Rules:
        - Use ONLY the provided source text as content.
        - Create an engaging title for the study guide
        - Write a clear 2-3 sentence summary of what this study guide covers
        - List 4-8 key learning objectives in "steps" (what students should know/understand)
        - Include 3-6 most important terms with brief definitions in "hints" 
        - Create 4-8 practice questions in "questions" that test understanding
        - Add an encouraging footer message
        - Keep language friendly and educational
        - Return valid JSON only. No trailing commas. No extra text.
        """

        let title = guideTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let userPayload: [String: Any] = [
            "setTitle": title.isEmpty ? "Pasted Source" : title,
            "source": source
        ]

        let userContentData = try? JSONSerialization.data(withJSONObject: userPayload, options: [.sortedKeys])
        let userContentString = String(data: userContentData ?? Data(), encoding: .utf8) ?? "{}"

        let messages = [
            OAChatMessage(role: "system", content: systemJSONSchema),
            OAChatMessage(role: "user", content: userContentString)
        ]

        let chatBody = OAChatRequest(
            model: "gpt-4o-mini",
            temperature: 0.2,
            max_tokens: 1600,
            messages: messages
        )
        request.httpBody = try? JSONEncoder().encode(chatBody)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Network error: \(error.localizedDescription)" }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { self.errorMessage = "No data from server" }
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let msg: String
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = dict["error"] as? [String: Any],
                   let m = err["message"] as? String {
                    msg = m
                } else {
                    msg = "HTTP Error \(http.statusCode). Check your API key."
                }
                DispatchQueue.main.async { self.errorMessage = msg }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(OAChatAPIResponse.self, from: data)
                let raw = decoded.choices.first?.message.content ?? ""
                guard let jsonString = extractJSONObject(from: raw),
                      let jsonData = jsonString.data(using: .utf8) else {
                    DispatchQueue.main.async { self.errorMessage = "AI did not return valid JSON." }
                    return
                }
                if let _ = try? JSONDecoder().decode(KorahFormatted.self, from: jsonData) {
                    let title = self.guideTitle.isEmpty ? "Study Guide" : self.guideTitle
                    let guide = StudyGuide(title: title, content: jsonString)
                    DispatchQueue.main.async {
                        self.savedGuides.append(guide)
                        self.persistGuides()
                        self.inputText = ""
                        self.guideTitle = ""
                    }
                } else {
                    let guideJSON = try JSONDecoder().decode(GeneratedStudyGuide.self, from: jsonData)
                    let title = guideJSON.meta.title.isEmpty ? (self.guideTitle.isEmpty ? "Study Guide" : self.guideTitle) : guideJSON.meta.title
                    let guide = StudyGuide(title: title, content: jsonString)
                    DispatchQueue.main.async {
                        self.savedGuides.append(guide)
                        self.persistGuides()
                        self.inputText = ""
                        self.guideTitle = ""
                    }
                }
            } catch {
                let responseString = String(data: data, encoding: .utf8) ?? "(unreadable)"
                print("Decode error: \(error)\nRaw: \(responseString)")
                DispatchQueue.main.async { self.errorMessage = "Failed to parse study guide JSON. See console." }
            }
        }.resume()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.korahGradientBackground().ignoresSafeArea()
                List {
                    Section(header: Text("Create from Flashcards")) {
                        if flashcardSets.isEmpty {
                            Text("No flashcard sets found.").foregroundColor(.secondary)
                        } else {
                            Picker("Flashcard Set", selection: $selectedSetIndex) {
                                ForEach(flashcardSets.indices, id: \.self) { idx in
                                    Text(flashcardSets[idx].title).tag(idx)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())

                            Button(action: generateStudyGuideFromSelectedSet) {
                                Label("Generate Study Guide", systemImage: "book.closed")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .disabled(isLoading || flashcardSets.isEmpty)

                            Button(action: generatePracticeTestFromSelectedSet) {
                                Label("Generate Practice Test", systemImage: "doc.text.magnifyingglass")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                            .disabled(isLoading || flashcardSets.isEmpty)

                            Button { showManualCreate = true } label: {
                                Label("Create Manually", systemImage: "plus.square.on.square")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                            .disabled(isLoading)
                        }
                    }
                    .listRowBackground(Color.clear)

                    Section(header: Text("Create from Pasted Text")) {
                        TextField("Guide Title (optional)", text: $guideTitle)
                            .textInputAutocapitalization(.words)
                        TextEditor(text: $inputText)
                            .frame(minHeight: 140)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        Button {
                            generateStudyGuideFromPastedText()
                        } label: {
                            Label("Generate from Text", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .listRowBackground(Color.clear)

                    Section(header: Text("Saved Study Guides")) {
                        let guides: [StudyGuide] = savedGuides.sorted(by: { (lhs: StudyGuide, rhs: StudyGuide) in lhs.createdAt > rhs.createdAt })
                        if guides.isEmpty {
                            Text("No study guides yet.").foregroundColor(.secondary)
                        } else {
                            ForEach(guides) { guide in
                                NavigationLink(destination: StudyGuideDetailView(guide: guide)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(guide.title.isEmpty ? "Untitled Guide" : guide.title)
                                            .foregroundColor(.white)
                                        Text(guide.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .onDelete(perform: deleteGuides)
                        }
                    }
                    .listRowBackground(Color.clear)

                    if let errorMessage = errorMessage {
                        Section { Text(errorMessage).foregroundColor(.red) }
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .navigationTitle("Study Guides")

                if isLoading {
                    ProgressView("Generating...")
                        .progressViewStyle(.circular)
                        .tint(.purple)
                }
            }
        }
        .accentColor(.purple)
        .preferredColorScheme(.dark)
        .onAppear {
            loadGuides()
            loadFlashcardSets()
            if openGeneratorOnAppear {
                if !flashcardSets.isEmpty { selectedSetIndex = 0 }
            }
        }
        .sheet(isPresented: $showManualCreate, onDismiss: { loadFlashcardSets() }) {
            NavigationStack { ManualFlashcardSetCreateView() }
                .accentColor(.purple)
        }
    }
}

struct StudyGuideCard: View {
    let studyGuide: GeneratedStudyGuide
    let timestamp: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(studyGuide.meta.title)
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("From set: **\(studyGuide.meta.setTitle)**")
                    .foregroundColor(.white)
                    .font(.subheadline)
                if let generated = studyGuide.meta.generatedAt {
                    Text("Generated: \(generated)")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                }
            }
            
            if !studyGuide.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(studyGuide.summary)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !studyGuide.keyTakeaways.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key Takeaways")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    ForEach(Array(studyGuide.keyTakeaways.enumerated()), id: \.offset) { (idx: Int, takeaway: String) in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx+1).").bold().foregroundColor(.white)
                            Text(takeaway).foregroundColor(.white)
                        }
                    }
                }
            }
            
            if !studyGuide.terms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Terms")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    ForEach(studyGuide.terms, id: \.term) { term in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "book.closed")
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(term.term)
                                    .foregroundColor(.white)
                                    .bold()
                                Text(term.definition)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            
            if !studyGuide.practiceQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Practice Questions")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    ForEach(studyGuide.practiceQuestions) { question in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(question.question)
                                    .foregroundColor(.white)
                                Text(question.answer)
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            
            Text(timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}

struct ChatViewStyleCard: View {
    let formatted: KorahFormatted
    let timestamp: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = formatted.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            if let summary = formatted.summary, !summary.isEmpty {
                Text(summary)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let steps = formatted.steps, !steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Steps")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    ForEach(Array(steps.enumerated()), id: \.offset) { (idx: Int, s: String) in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx+1).").bold().foregroundColor(.white)
                            Text(s).foregroundColor(.white)
                        }
                    }
                }
            }
            if let hints = formatted.hints, !hints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hints")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    ForEach(hints, id: \.self) { h in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.white)
                            Text(h)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            if let qs = formatted.questions, !qs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Try these questions")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    ForEach(qs, id: \.self) { q in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.white)
                            Text(q)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            if let footer = formatted.footer, !footer.isEmpty {
                Divider().background(.white.opacity(0.2))
                Text(footer)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}

struct StudyGuideDetailView: View {
    let guide: StudyGuide
    
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false

    private var chatViewFormatted: KorahFormatted? {
        guard let jsonString = extractJSONObject(from: guide.content),
              let jsonData = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(KorahFormatted.self, from: jsonData) else {
            return nil
        }
        return decoded
    }
    
    private var decodedStudyGuide: GeneratedStudyGuide? {
        guard chatViewFormatted == nil,
              let jsonString = extractJSONObject(from: guide.content),
              let jsonData = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(GeneratedStudyGuide.self, from: jsonData) else {
            return nil
        }
        return decoded
    }

    private func deleteCurrentGuide() {
        var guides: [StudyGuide] = []
        if let data = UserDefaults.standard.data(forKey: "StudyGuides"),
           let decoded = try? JSONDecoder().decode([StudyGuide].self, from: data) {
            guides = decoded
        }
        guides.removeAll { $0.id == guide.id }
        if let encoded = try? JSONEncoder().encode(guides) {
            UserDefaults.standard.set(encoded, forKey: "StudyGuides")
        }
        dismiss()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let chatFormatted = chatViewFormatted {
                    ChatViewStyleCard(formatted: chatFormatted, timestamp: guide.createdAt)
                } else if let studyGuide = decodedStudyGuide {
                    StudyGuideCard(studyGuide: studyGuide, timestamp: guide.createdAt)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(guide.title.isEmpty ? "Untitled Guide" : guide.title)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        Divider().background(Color.white.opacity(0.1))
                        Text(guide.content)
                            .foregroundColor(.white)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .background(Color.clear)
        .korahGradientBackground()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Study Guide")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) { showDeleteAlert = true } label: { Image(systemName: "trash") }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Study Guide?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteCurrentGuide() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove this study guide from your library.")
        }
    }
}


struct StudyGuideGeneratorView: View {
    @State private var inputText: String = ""
    @State private var guideTitle: String = ""
    @State private var generatedMarkdown: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var savedGuides: [StudyGuide] = []
    private let saveKey = "StudyGuides"


    func generateStudyGuide() {
        // API key now centralized in OpenAIConfig
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Title")) {
                    TextField("Study Guide Title", text: $guideTitle)
                        .textInputAutocapitalization(.words)
                }
                Section(header: Text("Source Text")) {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 160)
                }
                if let errorMessage = errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red) }
                }
                Section {
                    Button(action: generateStudyGuide) {
                        Label("Generate", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !generatedMarkdown.isEmpty {
                    Section(header: Text("Preview")) {
                        ScrollView { Text(generatedMarkdown).textSelection(.enabled) }
                            .frame(minHeight: 200)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Guide Generator")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading { ProgressView().tint(.purple) }
                }
            }
        }
        .accentColor(.purple)
        .preferredColorScheme(.dark)
    }
}

