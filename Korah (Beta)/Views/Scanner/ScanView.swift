import SwiftUI
import UIKit
import AVFoundation
import Foundation


struct ScanMessage: Identifiable {
    let id = UUID()
    let role: String 
    let content: String
    let timestamp: Date
    let image: UIImage? 
}

struct ScanOpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String?
        }
        let message: Message
        let finishReason: String?
        let index: Int?
        private enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
            case index
        }
    }
    struct Usage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        private enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]
    let usage: Usage?
}


struct ScanKorahFormatted: Decodable {
    let kind: String?           
    let title: String?          
    let summary: String?        
    let steps: [String]?        
    let hints: [String]?        
    let questions: [String]?    
    let footer: String?         
}

extension String {
    func decodeScanKorahFormatted() -> ScanKorahFormatted? {
        if let data = self.data(using: .utf8),
           let obj = try? JSONDecoder().decode(ScanKorahFormatted.self, from: data) {
            return obj
        }
        guard let start = self.firstIndex(of: "{"),
              let end = self.lastIndex(of: "}") else { return nil }
        let jsonSubstring = self[start...end]
        guard let data2 = String(jsonSubstring).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ScanKorahFormatted.self, from: data2)
    }
    
}


struct ScanTypingIndicator: View {
    @State private var animationAmount: Double = 1.0
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Korah is thinking")
                .foregroundColor(.white.opacity(0.7))
                .font(.subheadline)
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .scaleEffect(animationAmount)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: animationAmount
                        )
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .frame(maxWidth: 260, alignment: .leading)
        .id("typing-indicator")
        .onAppear {
            animationAmount = 0.5
        }
    }
}


struct ScanView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("SavedFirstName") private var savedFirstName: String = ""
    @State private var navigateToHome = false
    
    @State private var selectedFlashcardSetID: UUID? = nil
    @State private var navigateToGuideID: UUID? = nil

    @State private var messages: [ScanMessage] = []
    @State private var userInput: String = ""
    @State private var isLoading = false
    @State private var showTypingIndicator = false
    @State private var showClearChatAlert = false
    @State private var showImagePicker = false
    @State private var showImageSourceAlert = false
    @State private var selectedImage: UIImage?
    @State private var imageSourceType: UIImagePickerController.SourceType = .camera
    
    @State private var starterSuggestions: [String] = [
        "Help me solve this math problem",
        "Explain this concept step by step",
        "Check my homework answer",
        "Break down this question for me"
    ]
    
    var onQuickTip: (String) -> Void = { _ in }
    
    private var hasAssistantResponse: Bool {
        messages.last?.role == "assistant"
    }
    
    private var contextSuggestions: [String] {
        if let lastAssistantContent = messages.last(where: { $0.role == "assistant" })?.content,
           let formatted = lastAssistantContent.decodeScanKorahFormatted(),
           let qs = formatted.questions, !qs.isEmpty {
            return normalizeSuggestions(Array(qs.prefix(3)))
        }
        let lastAssistant = messages.last { $0.role == "assistant" }?.content ?? ""
        let lastUser = messages.last { $0.role == "user" }?.content ?? ""
        var results: [String] = []
        if !lastAssistant.isEmpty {
            results.append("Can you go deeper on that?")
            results.append("Give me a quick practice problem")
            results.append("Summarize the key idea in 2 sentences")
        }
        if !lastUser.isEmpty {
            results.append("What should I try next?")
            results.append("Check my understanding with a question")
        }
        var seen = Set<String>()
        let unique = results.filter { seen.insert($0).inserted }
        return normalizeSuggestions(Array(unique.prefix(3)))
    }
    
    private func normalizeSuggestions(_ items: [String]) -> [String] {
        return items.map { s in
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            if lower.hasPrefix("do you want") || lower.hasPrefix("would you like") || lower.hasPrefix("do you need") || lower.hasPrefix("need help") || lower.hasPrefix("can i") || lower.hasPrefix("should we") {
                if lower.contains("help") {
                    return "I need help" + (trimmed.drop(while: { $0 != " " }).isEmpty ? "" : " with " + trimmed.components(separatedBy: "help").last!.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!?")))
                } else if lower.contains("learn") {
                    return "I want to learn " + trimmed.components(separatedBy: "learn").last!.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
                } else if lower.contains("practice") {
                    return "Give me a practice exercise on " + trimmed.components(separatedBy: "practice").last!.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
                } else {
                    return "I want to try that"
                }
            }
            return trimmed
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(isActive: $navigateToHome) {
                HomePageView()
            } label: {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(isActive: Binding(get: { selectedFlashcardSetID != nil }, set: { if !$0 { selectedFlashcardSetID = nil } })) {
                if let id = selectedFlashcardSetID {
                    FlashcardsView(selectedSetID: id)
                } else {
                    EmptyView()
                }
            } label: {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(isActive: Binding(get: { navigateToGuideID != nil }, set: { if !$0 { navigateToGuideID = nil } })) {
                if let id = navigateToGuideID,
                   let data = UserDefaults.standard.data(forKey: "StudyGuides"),
                   let guides = try? JSONDecoder().decode([StudyGuide].self, from: data),
                   let guide = guides.first(where: { $0.id == id }) {
                    StudyGuideDetailView(guide: guide)
                } else {
                    EmptyView()
                }
            } label: {
                EmptyView()
            }
            .hidden()
            
            HStack {
                Button(action: { hideKeyboard(); navigateToHome = true }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                }
                Text("Scan")
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    showClearChatAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(messages.isEmpty)
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal)
            
            if messages.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Text("Scan any image!")
                        .font(.largeTitle).bold()
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.95))
                        .padding(.horizontal)
                    SuggestionChips(suggestions: starterSuggestions) { suggestion in
                        sendSuggestion(suggestion)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickTipButton(title: "Explain Deeper") {
                        if hasAssistantResponse && !isLoading && !showTypingIndicator {
                            followUp("Explain deeper")
                        }
                    }
                    QuickTipButton(title: "Give Example") {
                        if hasAssistantResponse && !isLoading && !showTypingIndicator {
                            followUp("Give a concrete example")
                        }
                    }
                    QuickTipButton(title: "Flashcard Set") {
                        if hasAssistantResponse && !isLoading && !showTypingIndicator {
                            requestFlashcardSetFromConversation()
                        }
                    }
                    QuickTipButton(title: "Study Guide") {
                        if hasAssistantResponse && !isLoading && !showTypingIndicator {
                            requestStudyGuideFromConversation()
                        }
                    }
                }
                .padding(.horizontal)
                .opacity((!hasAssistantResponse || isLoading || showTypingIndicator) ? 0.5 : 1)
                .disabled(!hasAssistantResponse || isLoading || showTypingIndicator)
            }
            .padding(.vertical, 6)
            .accessibilityLabel("Quick action tips")
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ScanChatBubble(message: message)
                                .id(message.id)
                                .padding(.horizontal, 16)
                        }
                        
                        if showTypingIndicator {
                            ScanTypingIndicator()
                                .padding(.horizontal)
                        }
                        
                        if !messages.isEmpty, !showTypingIndicator, !contextSuggestions.isEmpty {
                            SuggestionChips(suggestions: contextSuggestions) { suggestion in
                                sendSuggestion(suggestion)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .onTapGesture { hideKeyboard() }
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
                .onChange(of: showTypingIndicator) { _ in
                    if showTypingIndicator {
                        withAnimation { proxy.scrollTo("typing-indicator", anchor: .bottom) }
                    }
                }
            }
            .padding(.horizontal, 12)

            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .cornerRadius(8)
                    Spacer()
                    Button(action: { selectedImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            HStack(spacing: 8) {
                Button(action: {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        imageSourceType = .camera
                    }
                    showImageSourceAlert = true
                }) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                TextField("Type your message…", text: $userInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background((userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil) ? Color.gray : Color.accentColor)
                        .clipShape(Capsule())
                }
                .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil)
            }
            .padding(.all, 12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .alert("Delete Chat", isPresented: $showClearChatAlert) {
            Button("Delete", role: .destructive) {
                withAnimation { messages.removeAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete chat?")
        }
        .confirmationDialog("Choose Image Source", isPresented: $showImageSourceAlert) {
            Button("Camera") {
                imageSourceType = .camera
                showImagePicker = true
            }
            Button("Photo Library") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: imageSourceType)
                .onDisappear {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        imageSourceType = .camera
                    }
                }
        }
        .onChange(of: selectedImage) { newImage in
            if let img = newImage {
                if userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    userInput = ""
                }
                sendMessage()
            }
        }
        .korahGradientBackground()
        .accentColor(.purple)
        .preferredColorScheme(.dark)
        .onAppear {
            requestCameraAccessIfNeeded { granted in
                if granted {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        imageSourceType = .camera
                    } else {
                        imageSourceType = .photoLibrary
                    }
                    if !showImagePicker {
                        showImagePicker = true
                    }
                } else {
                    imageSourceType = .photoLibrary
                    if !showImagePicker {
                        showImagePicker = true
                    }
                }
            }
        }
    }
    
    struct SuggestionChips: View {
        let suggestions: [String]
        let onTap: (String) -> Void
        var body: some View {
            let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button(action: { onTap(s) }) {
                        Text(s)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func sendSuggestion(_ text: String) {
        userInput = text
        sendMessage()
    }
    

    struct ScanChatBubble: View {
        let message: ScanMessage

        var body: some View {
            HStack(alignment: .bottom) {
                Spacer().frame(width: 0)
                if message.role == "assistant" {
                    if let formatted = message.content.decodeScanKorahFormatted() {
                        ScanAnswerView(formatted: formatted, timestamp: message.timestamp)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ScrollView {
                            Text(scanFormattedResponse(message.content))
                                .font(.body)
                                .foregroundColor(.white)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .monospaced(false)
                                .padding(16)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .none, alignment: .topLeading)
                    }
                } else {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        if let image = message.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200)
                                .cornerRadius(8)
                        }
                        if !message.content.isEmpty {
                            Text(message.content)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 48, 360), alignment: .trailing)
                }
            }
        }
    }


    struct ScanAnswerView: View {
        let formatted: ScanKorahFormatted
        let timestamp: Date

        private func badge(_ index: Int) -> some View {
            Text("\(index)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(.white)
                    Text("Answer")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }

                if let title = formatted.title, !title.isEmpty {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let summary = formatted.summary, !summary.isEmpty {
                    Text(summary)
                        .foregroundStyle(.white)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let steps = formatted.steps, !steps.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 12) {
                                badge(idx + 1)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 6) {
                                    let parts = step.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                                    if let first = parts.first, !first.isEmpty {
                                        Text(String(first))
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                    if parts.count > 1 {
                                        Text(String(parts[1]))
                                            .foregroundStyle(.white)
                                            .lineSpacing(4)
                                    }
                                }
                            }
                        }
                    }
                }

                if let hints = formatted.hints, !hints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        ForEach(hints, id: \.self) { h in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb")
                                    .foregroundStyle(.white)
                                Text(h)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }

                if let qs = formatted.questions, !qs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try these questions")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        ForEach(qs, id: \.self) { q in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(.white)
                                Text(q)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }

                Text(timestamp, style: .time)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(18)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }


    func sendMessage() {
        let input = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty || selectedImage != nil else { return }

        messages.append(ScanMessage(role: "user", content: input, timestamp: Date(), image: selectedImage))
        userInput = ""
        let imageToSend = selectedImage
        selectedImage = nil
        isLoading = true
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        showTypingIndicator = true
        fetchChatResponse(image: imageToSend)
    }
    
    private func followUp(_ instruction: String) {
        guard hasAssistantResponse && !isLoading && !showTypingIndicator else { return }
        userInput = instruction
        sendMessage()
    }
    
    private func generateFlashcardSetFromLastAnswer() {
        guard hasAssistantResponse && !isLoading && !showTypingIndicator else { return }
        guard let lastAssistantContent = messages.last(where: { $0.role == "assistant" })?.content else { return }
        
        guard let formatted = lastAssistantContent.decodeScanKorahFormatted() else { return }
        
        let pairs = extractPairsFrom(formatted: formatted)
        guard !pairs.isEmpty else { return }
        
        let title = formatted.title ?? "Flashcard Set"
        
        let flashcards = pairs.map { Flashcard(front: $0.0, back: $0.1) }
        let newSet = FlashcardSet(title: title, cards: flashcards)
        
        var savedSets: [FlashcardSet] = []
        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let decoded = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
            savedSets = decoded
        }
        savedSets.append(newSet)
        if let encoded = try? JSONEncoder().encode(savedSets) {
            UserDefaults.standard.set(encoded, forKey: "FlashcardSets")
        }
        
        selectedFlashcardSetID = newSet.id
    }
    
    private func generateStudyGuideFromLastAnswer() {
        guard hasAssistantResponse && !isLoading && !showTypingIndicator else { return }
        guard let lastAssistantContent = messages.last(where: { $0.role == "assistant" })?.content else { return }
        
        guard let formatted = lastAssistantContent.decodeScanKorahFormatted() else { return }
        
        let guide = StudyGuide(title: formatted.title ?? "Study Guide", content: lastAssistantContent)
        
        var savedGuides: [StudyGuide] = []
        if let data = UserDefaults.standard.data(forKey: "StudyGuides"),
           let decoded = try? JSONDecoder().decode([StudyGuide].self, from: data) {
            savedGuides = decoded
        }
        savedGuides.append(guide)
        if let encoded = try? JSONEncoder().encode(savedGuides) {
            UserDefaults.standard.set(encoded, forKey: "StudyGuides")
        }
        
        navigateToGuideID = guide.id
    }

    
    private func requestFlashcardSetFromConversation() {
        guard hasAssistantResponse && !isLoading && !showTypingIndicator else { return }
        isLoading = true
        showTypingIndicator = true

        let url = URL(string: OpenAIConfig.chatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        }

        let systemInstruction = "You are Korah. Always respond with PURE JSON matching the existing schema."
        var apiMessages: [[String: Any]] = [["role": "system", "content": systemInstruction]]

        for message in messages {
            if let img = message.image, let base64 = img.jpegData(compressionQuality: 0.8)?.base64EncodedString() {
                var content: [[String: Any]] = []
                if !message.content.isEmpty { content.append(["type": "text", "text": message.content]) }
                content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]])
                apiMessages.append(["role": message.role, "content": content])
            } else {
                apiMessages.append(["role": message.role, "content": message.content])
            }
        }

        let instruction = "Create a flashcard set from our conversation in the same JSON schema. Put concise terms in hints and matching definitions in steps."
        apiMessages.append(["role": "user", "content": instruction])

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": apiMessages,
            "temperature": 0.3,
            "max_tokens": 1000,
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "Network error: \(error.localizedDescription)", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "No data received from server", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "HTTP Error \(http.statusCode): Check your API key", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(ScanOpenAIResponse.self, from: data)
                if let content = decoded.choices.first?.message.content, !content.isEmpty {
                    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let formatted = trimmed.decodeScanKorahFormatted() {
                        let pairs = self.extractPairsFrom(formatted: formatted)
                        if pairs.isEmpty {
                            DispatchQueue.main.async {
                                self.messages.append(ScanMessage(role: "assistant", content: "I couldn't extract flashcards from the response.", timestamp: Date(), image: nil))
                                self.showTypingIndicator = false
                            }
                            return
                        }

                        let title = formatted.title ?? "Flashcard Set"
                        let flashcards = pairs.map { Flashcard(front: $0.0, back: $0.1) }
                        let newSet = FlashcardSet(title: title, cards: flashcards)

                        var savedSets: [FlashcardSet] = []
                        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
                           let decoded = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
                            savedSets = decoded
                        }
                        savedSets.append(newSet)
                        if let encoded = try? JSONEncoder().encode(savedSets) {
                            UserDefaults.standard.set(encoded, forKey: "FlashcardSets")
                        }

                        DispatchQueue.main.async {
                            self.selectedFlashcardSetID = newSet.id
                            self.showTypingIndicator = false
                            self.messages.append(ScanMessage(role: "assistant", content: "Flashcard set created! Go find it with your other flashcard sets!", timestamp: Date(), image: nil))
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.messages.append(ScanMessage(role: "assistant", content: "Error (The AI did not return valid JSON for flashcards.)", timestamp: Date(), image: nil))
                            self.showTypingIndicator = false
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.messages.append(ScanMessage(role: "assistant", content: "Error: (Received empty response from AI)", timestamp: Date(), image: nil))
                        self.showTypingIndicator = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "Error parsing AI response.", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
            }
        }.resume()
    }
    
    private func requestStudyGuideFromConversation() {
        guard hasAssistantResponse && !isLoading && !showTypingIndicator else { return }
        isLoading = true
        showTypingIndicator = true
        
        let url = URL(string: OpenAIConfig.chatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        }
        
        let systemInstruction = """
        You are Korah. Always respond with PURE JSON matching the StudyGuide schema:
        {
          "kind": "study_guide",
          "title": string,
          "summary": string,
          "steps": [string],
          "hints": [string],
          "questions": [string],
          "footer": string
        }
        """
        
        var apiMessages: [[String: Any]] = [["role": "system", "content": systemInstruction]]
        
        for message in messages {
            if let img = message.image, let base64 = img.jpegData(compressionQuality: 0.8)?.base64EncodedString() {
                var content: [[String: Any]] = []
                if !message.content.isEmpty { content.append(["type": "text", "text": message.content]) }
                content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]])
                apiMessages.append(["role": message.role, "content": content])
            } else {
                apiMessages.append(["role": message.role, "content": message.content])
            }
        }
        
        let userInstruction = "Generate a study guide from our conversation using the StudyGuide JSON schema, be concise and clear."
        apiMessages.append(["role": "user", "content": userInstruction])
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": apiMessages,
            "temperature": 0.3,
            "max_tokens": 1000,
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "Network error: \(error.localizedDescription)", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "No data received from server", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }
            
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "HTTP Error \(http.statusCode): Check your API key", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(ScanOpenAIResponse.self, from: data)
                if let content = decoded.choices.first?.message.content, !content.isEmpty {
                    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let formatted = trimmed.decodeScanKorahFormatted() {
                        let guide = StudyGuide(title: formatted.title ?? "Study Guide", content: trimmed)
                        
                        var savedGuides: [StudyGuide] = []
                        if let existingData = UserDefaults.standard.data(forKey: "StudyGuides"),
                           let decodedGuides = try? JSONDecoder().decode([StudyGuide].self, from: existingData) {
                            savedGuides = decodedGuides
                        }
                        savedGuides.append(guide)
                        if let encoded = try? JSONEncoder().encode(savedGuides) {
                            UserDefaults.standard.set(encoded, forKey: "StudyGuides")
                        }
                        
                        DispatchQueue.main.async {
                            self.navigateToGuideID = guide.id
                            self.showTypingIndicator = false
                            self.messages.append(ScanMessage(role: "assistant", content: "Study guide created! You can find it in your study guides.", timestamp: Date(), image: nil))
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.messages.append(ScanMessage(role: "assistant", content: "The AI did not return valid JSON for the study guide.", timestamp: Date(), image: nil))
                            self.showTypingIndicator = false
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.messages.append(ScanMessage(role: "assistant", content: "Received empty response from AI", timestamp: Date(), image: nil))
                        self.showTypingIndicator = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "Error parsing AI response.", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
            }
        }.resume()
    }

    
    private func extractPairsFrom(formatted: ScanKorahFormatted) -> [(String, String)] {
        if let hints = formatted.hints, !hints.isEmpty, let steps = formatted.steps, !steps.isEmpty {
            let count = min(hints.count, steps.count)
            return (0..<count).map { (hints[$0], steps[$0]) }
        }
        
        if let steps = formatted.steps, !steps.isEmpty {
            if let hints = formatted.hints, !hints.isEmpty {
                let count = min(steps.count, hints.count)
                return (0..<count).map { (steps[$0], hints[$0]) }
            }
            return steps.map { ($0, "") }
        }
        
        if let summary = formatted.summary, !summary.isEmpty {
            let sentences = summary.components(separatedBy: ". ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            var pairs: [(String, String)] = []
            for i in stride(from: 0, to: sentences.count, by: 2) {
                let term = sentences[i]
                let def = (i + 1) < sentences.count ? sentences[i + 1] : ""
                pairs.append((term, def))
            }
            return pairs
        }
        
        return []
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private func scanFormattedResponse(_ text: String) -> String {
    var s = text
    s = s.replacingOccurrences(of: " * ", with: " × ")
    s = s.replacingOccurrences(of: "*", with: "×")
    s = s.replacingOccurrences(of: " -- ", with: " — ")
    s = s.replacingOccurrences(of: "\n- ", with: "\n• ")
    return s
}


extension ScanView {
    func fetchChatResponse(image: UIImage? = nil) {
        let url = URL(string: OpenAIConfig.chatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let apiKey = OpenAIConfig.apiKey
        
        let systemInstruction =
        """
        You are Korah, a friendly tutor for kids. Never give final answers to homework outright; guide step-by-step.
        Always respond with PURE JSON (no backticks, no code fences), matching this schema:

        {
          "kind": "tutor",
          "title": string,              
          "summary": string,            
          "steps": [string],            
          "hints": [string],            
          "questions": [string],        

        Rules:
        - Keep it kid-friendly, concise, and actionable.
        - Do NOT include any non-JSON text.
        - If the user asks for direct answers, redirect with hints in JSON.
        """

        var apiMessages: [[String: Any]] = [["role": "system", "content": systemInstruction]]
        
        for message in messages {
            if let img = message.image, let base64 = img.jpegData(compressionQuality: 0.8)?.base64EncodedString() {
                var content: [[String: Any]] = []
                if !message.content.isEmpty {
                    content.append(["type": "text", "text": message.content])
                }
                content.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                ])
                apiMessages.append(["role": message.role, "content": content])
            } else {
                apiMessages.append(["role": message.role, "content": message.content])
            }
        }

        let modelToUse = "gpt-4o"
        
        var body: [String: Any] = [
            "model": modelToUse,
            "messages": apiMessages,
            "temperature": 0.3,
            "max_tokens": 1000,
        ]
        body["response_format"] = ["type": "json_object"]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                print("Request error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "Network error: \(error.localizedDescription)", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "No data received from server", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorDict["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    DispatchQueue.main.async {
                        self.messages.append(ScanMessage(role: "assistant", content: "API Error: \(message)", timestamp: Date(), image: nil))
                        self.showTypingIndicator = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.messages.append(ScanMessage(role: "assistant", content: "HTTP Error \(httpResponse.statusCode): Check your API key", timestamp: Date(), image: nil))
                        self.showTypingIndicator = false
                    }
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(ScanOpenAIResponse.self, from: data)
                if let content = decoded.choices.first?.message.content, !content.isEmpty {
                    DispatchQueue.main.async {
                        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.decodeScanKorahFormatted() != nil {
                            self.messages.append(ScanMessage(role: "assistant",
                                                             content: trimmed,
                                                             timestamp: Date(),
                                                             image: nil))
                        } else {
                            let safeSummary = trimmed.replacingOccurrences(of: "\n", with: " ")
                            let fallback: [String: Any] = [
                                "kind": "tutor",
                                "title": "Here’s some guidance",
                                "summary": safeSummary,
                                "steps": [],
                                "hints": [],
                                "questions": ["What part would you like to try next?"],
                                "footer": "If you need a structured plan, ask me to list steps."
                            ]
                            if let jsonData = try? JSONSerialization.data(withJSONObject: fallback),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                self.messages.append(ScanMessage(role: "assistant",
                                                                 content: jsonString,
                                                                 timestamp: Date(),
                                                                 image: nil))
                            } else {
                                self.messages.append(ScanMessage(role: "assistant",
                                                                 content: trimmed,
                                                                 timestamp: Date(),
                                                                 image: nil))
                            }
                        }
                        self.showTypingIndicator = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.messages.append(ScanMessage(role: "assistant", content: "Received empty response from AI", timestamp: Date(), image: nil))
                        self.showTypingIndicator = false
                    }
                }
            } catch {
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to read response"
                print("Decoding error: \(error)")
                print("Raw response: \(responseString)")
                DispatchQueue.main.async {
                    let safeSummary = responseString.replacingOccurrences(of: "\n", with: " ")
                    let fallback: [String: Any] = [
                        "kind": "tutor",
                        "title": "I had trouble reading that",
                        "summary": safeSummary,
                        "steps": [],
                        "hints": ["Try asking again in a shorter message.", "If you included an image, add a brief description too."],
                        "questions": ["What is the main goal of your question?"],
                        "footer": "I’ll keep responses in pure JSON."
                    ]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: fallback),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        self.messages.append(ScanMessage(role: "assistant", content: jsonString, timestamp: Date(), image: nil))
                    } else {
                        self.messages.append(ScanMessage(role: "assistant", content: "I had trouble parsing the response.", timestamp: Date(), image: nil))
                    }
                    self.showTypingIndicator = false
                }
            }
        }.resume()
    }
    
    private func requestCameraAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}


struct QuickTipButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.8), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}


struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    var sourceType: UIImagePickerController.SourceType
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
