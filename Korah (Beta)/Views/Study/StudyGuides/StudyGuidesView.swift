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

// Using shared utility from StudyUtilities.extractJSONObject

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

    @Environment(FirestoreStudyService.self) private var studyService
    @State private var inputText: String = ""
    @State private var guideTitle: String = ""
    @State private var generatedMarkdown: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var networkMonitor = NetworkMonitor.shared

    @State private var selectedSetIndex: Int = 0
    @State private var navigateToGenerator: Bool = false
    @State private var showManualCreate: Bool = false

    private var savedGuides: [StudyGuide] { studyService.studyGuides }
    private var flashcardSets: [FlashcardSet] { studyService.flashcardSets }

    private func deleteGuide(_ guide: StudyGuide) {
        Task { try? await studyService.deleteStudyGuide(id: guide.id) }
    }

    private func generateStudyGuideFromSelectedSet() {
        guard networkMonitor.isConnected else {
            errorMessage = networkMonitor.offlineMessage
            return
        }
        
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

        guard let url = URL(string: APIConfig.chatCompletionsURL) else {
            self.errorMessage = "Invalid URL"
            self.isLoading = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()

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
            model: APIConfig.chatModel,          
            temperature: 0.2,
            max_tokens: 1600,
            messages: messages
        )
        request.httpBody = try? JSONEncoder().encode(chatBody)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                DispatchQueue.main.async { self.errorMessage = StudyUtilities.errorMessage(for: error) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { self.errorMessage = "No data from server" }
                return
            }

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                DispatchQueue.main.async { 
                    self.errorMessage = StudyUtilities.errorMessage(for: http.statusCode, responseData: data)
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(OAChatAPIResponse.self, from: data)
                let raw = decoded.choices.first?.message.content ?? ""
                guard let jsonString = StudyUtilities.extractJSONObject(from: raw),
                      let jsonData = jsonString.data(using: .utf8) else {
                    DispatchQueue.main.async { self.errorMessage = "AI did not return valid JSON." }
                    return
                }
                if let _ = try? JSONDecoder().decode(KorahFormatted.self, from: jsonData) {
                    let title = "Study Guide: \(set.title)"
                    let guide = StudyGuide(title: title, content: jsonString)
                    DispatchQueue.main.async {
                        try? self.studyService.addStudyGuide(guide)
                    }
                } else {
                    let guideJSON = try JSONDecoder().decode(GeneratedStudyGuide.self, from: jsonData)
                    let title = guideJSON.meta.title.isEmpty ? "Study Guide: \(set.title)" : guideJSON.meta.title
                    let guide = StudyGuide(title: title, content: jsonString)
                    DispatchQueue.main.async {
                        try? self.studyService.addStudyGuide(guide)
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

        guard let url = URL(string: APIConfig.chatCompletionsURL) else {
            self.errorMessage = "Invalid URL"
            self.isLoading = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()

        // Implementation for generating practice test should be added here
    }

    private func generateStudyGuideFromPastedText() {
        guard networkMonitor.isConnected else {
            errorMessage = networkMonitor.offlineMessage
            return
        }
        
        errorMessage = nil
        isLoading = true

        let source = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { isLoading = false; return }

        guard let url = URL(string: APIConfig.chatCompletionsURL) else {
            self.errorMessage = "Invalid URL"
            self.isLoading = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()

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
            model: APIConfig.chatModel,
            temperature: 0.2,
            max_tokens: 1600,
            messages: messages
        )
        request.httpBody = try? JSONEncoder().encode(chatBody)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                DispatchQueue.main.async { self.errorMessage = StudyUtilities.errorMessage(for: error) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { self.errorMessage = "No data from server" }
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                DispatchQueue.main.async { 
                    self.errorMessage = StudyUtilities.errorMessage(for: http.statusCode, responseData: data)
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(OAChatAPIResponse.self, from: data)
                let raw = decoded.choices.first?.message.content ?? ""
                guard let jsonString = StudyUtilities.extractJSONObject(from: raw),
                      let jsonData = jsonString.data(using: .utf8) else {
                    DispatchQueue.main.async { self.errorMessage = "AI did not return valid JSON." }
                    return
                }
                if let _ = try? JSONDecoder().decode(KorahFormatted.self, from: jsonData) {
                    let title = self.guideTitle.isEmpty ? "Study Guide" : self.guideTitle
                    let guide = StudyGuide(title: title, content: jsonString)
                    DispatchQueue.main.async {
                        try? self.studyService.addStudyGuide(guide)
                        self.inputText = ""
                        self.guideTitle = ""
                    }
                } else {
                    let guideJSON = try JSONDecoder().decode(GeneratedStudyGuide.self, from: jsonData)
                    let title = guideJSON.meta.title.isEmpty ? (self.guideTitle.isEmpty ? "Study Guide" : self.guideTitle) : guideJSON.meta.title
                    let guide = StudyGuide(title: title, content: jsonString)
                    DispatchQueue.main.async {
                        try? self.studyService.addStudyGuide(guide)
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
            ScrollView {
                VStack(spacing: 20) {
                    flashcardsSection
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 20)
                    
                    pastedTextSection
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 20)
                    
                    savedGuidesSection
                    
                    errorSection
                }
                .padding(.vertical, 16)
            }
        .background(Color.clear)
        .refreshable { }
            .korahGradientBackground()
            .overlay {
                loadingOverlay
                offlineIndicator
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Study Guides")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .accentColor(.purple)
        .preferredColorScheme(.dark)
        .onAppear {
            if openGeneratorOnAppear {
                if !flashcardSets.isEmpty { selectedSetIndex = 0 }
            }
        }
        .sheet(isPresented: $showManualCreate) {
            NavigationStack { ManualFlashcardSetCreateView() }
                .accentColor(.purple)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var flashcardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
                        Text("Create from Flashcards")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        if flashcardSets.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "rectangle.stack")
                                    .font(.system(size: 50))
                                    .foregroundColor(.purple.opacity(0.5))
                                
                                Text("No flashcard sets found")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Create a flashcard set first to generate study guides from it")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 16) {
                                // Flashcard Set Picker Card
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "rectangle.stack")
                                            .font(.system(size: 24))
                                            .foregroundColor(.purple)
                                            .frame(width: 50, height: 50)
                                            .background(Color.purple.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Select Flashcard Set")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Text("Choose a set to generate from")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    Picker("Flashcard Set", selection: $selectedSetIndex) {
                                        ForEach(flashcardSets.indices, id: \.self) { idx in
                                            Text(flashcardSets[idx].title).tag(idx)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.purple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(10)
                                }
                                .padding(20)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
                                )
                                
                                // Generation Options
                                StudyGuideGenerationCard(
                                    icon: "book.closed",
                                    title: "Generate Study Guide",
                                    description: "Create a comprehensive study guide from flashcards",
                                    buttonText: "Generate",
                                    color: .blue,
                                    action: generateStudyGuideFromSelectedSet,
                                    isDisabled: isLoading || !networkMonitor.isConnected
                                )
                                
                                StudyGuideGenerationCard(
                                    icon: "doc.text.magnifyingglass",
                                    title: "Generate Practice Test",
                                    description: "Create a practice test based on your flashcards",
                                    buttonText: "Generate",
                                    color: .green,
                                    action: generatePracticeTestFromSelectedSet,
                                    isDisabled: isLoading
                                )
                                
                                StudyGuideGenerationCard(
                                    icon: "pencil.line",
                                    title: "Create Manually",
                                    description: "Build a study guide from scratch",
                                    buttonText: "Create",
                                    color: .purple,
                                    action: { showManualCreate = true },
                                    isDisabled: isLoading
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                    }
    }
    
    @ViewBuilder
    private var pastedTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
                        Text("Create from Pasted Text")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                        .frame(width: 50, height: 50)
                                        .background(Color.blue.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Paste Your Content")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Add text to generate a study guide")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                
                                TextField("Guide Title (optional)", text: $guideTitle)
                                    .textInputAutocapitalization(.words)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(10)
                                
                                TextEditor(text: $inputText)
                                    .frame(minHeight: 140)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .padding(12)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .padding(20)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                            )
                            
                            Button(action: generateStudyGuideFromPastedText) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.headline)
                                    Text("Generate from Text")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    (isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !networkMonitor.isConnected) 
                                    ? Color.blue.opacity(0.5) 
                                    : Color.blue
                                )
                                .cornerRadius(12)
                            }
                            .disabled(isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !networkMonitor.isConnected)
                        }
                        .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var savedGuidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
                        Text("Saved Study Guides")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        let guides: [StudyGuide] = savedGuides.sorted(by: { $0.createdAt > $1.createdAt })
                        
                        if guides.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue.opacity(0.5))
                                
                                Text("No study guides yet")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Generate your first study guide to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        } else {
                            ForEach(guides) { guide in
                                NavigationLink(destination: StudyGuideDetailView(guide: guide)) {
                                    StudyGuideItemCard(
                                        title: guide.title.isEmpty ? "Untitled Guide" : guide.title,
                                        subtitle: guide.createdAt.formattedCreatedAt()
                                    )
                                }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteGuide(guide)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
        }
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = errorMessage {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.red.opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if isLoading {
            ModernLoadingOverlay(
                message: "Generating Study Guide",
                subtitle: "Powered by AI • This may take a few moments",
                accentColor: .blue
            )
        }
    }
    
    @ViewBuilder
    private var offlineIndicator: some View {
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
            
            Text(timestamp.formattedTime())
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
        guard let jsonString = StudyUtilities.extractJSONObject(from: guide.content),
              let jsonData = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(KorahFormatted.self, from: jsonData) else {
            return nil
        }
        return decoded
    }
    
    private var decodedStudyGuide: GeneratedStudyGuide? {
        guard chatViewFormatted == nil,
              let jsonString = StudyUtilities.extractJSONObject(from: guide.content),
              let jsonData = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(GeneratedStudyGuide.self, from: jsonData) else {
            return nil
        }
        return decoded
    }

    private func deleteCurrentGuide() {
        Task { try? await FirestoreStudyService.shared.deleteStudyGuide(id: guide.id) }
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
        // API key now centralized in APIConfig
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

// MARK: - Helper Views

private struct StudyGuideGenerationCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
    let color: Color
    let action: () -> Void
    let isDisabled: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(20)
            
            Button(action: action) {
                Text(buttonText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isDisabled ? color.opacity(0.5) : color)
                    .cornerRadius(12)
            }
            .disabled(isDisabled)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1.5)
        )
    }
}

private struct StudyGuideItemCard: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 32))
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue.opacity(0.7))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

