import SwiftUI
import UIKit
import AVFoundation
import Foundation


struct ScanMessage: Identifiable {
    let id: UUID
    let role: String 
    var content: String
    let timestamp: Date
    let image: UIImage?
    
    init(id: UUID = UUID(), role: String, content: String, timestamp: Date, image: UIImage?) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.image = image
    }
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
    @State private var scales: [CGFloat] = [1.0, 1.0, 1.0]
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("Korah is thinking")
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary).opacity(0.9))
                .font(.kSubheadline)
            
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                        .frame(width: 8, height: 8)
                        .scaleEffect(scales[index])
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: scales[index]
                        )
                }
            }
        }
        .padding(Spacing.md)
        .background(
            Capsule()
                .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                .overlay(
                    Capsule()
                        .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(maxWidth: 280, alignment: .leading)
        .id("typing-indicator")
        .onAppear {
            scales = [0.5, 0.5, 0.5]
        }
    }
}


struct ScanView: View {
    @Environment(\.dismiss) private var dismiss

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
    @State private var showConversationHistory = false
    @State private var showNewChatAlert = false
    @State private var currentConversation: Conversation?
    
    // Streaming state
    @State private var isStreaming = false
    @State private var streamingMessageIndex: Int?
    @State private var streamTask: Task<Void, Never>?
    private let updateThrottle: TimeInterval = 0.05
    @State private var lastUpdateTime: Date = Date()
    
    @State private var showTTSControls = false
    @State private var isTTSLoading = false
    @State private var ttsAudioPlayer: AVAudioPlayer?
    @State private var ttsAudioPlayerDelegate: TTSAudioPlayerDelegate?
    @State private var currentTTSText: String = ""
    @State private var audioDuration: TimeInterval = 0
    @State private var audioCurrentTime: TimeInterval = 0
    @State private var audioTimer: Timer?
    
    // Voice mode state
    @State private var isVoiceModeActive = false
    @State private var isListening = false
    @State private var isThinking = false
    @State private var isSpeaking = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioPlayerDelegate: AudioPlayerDelegate?
    @State private var recordingURL: URL?
    @State private var silenceTimer: Timer?
    @State private var audioLevelTimer: Timer?
    private let silenceThreshold: Float = -40.0
    private let silenceDuration: TimeInterval = 1.5
    
    @State private var starterSuggestions: [String] = [
        "Help me solve this math problem",
        "Explain this concept step by step",
        "Check my homework answer",
        "What can you help me learn?"
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

    // MARK: - Extracted Views
    
    private var navigationLinks: some View {
        Group {
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
        }
    }
    
    private var headerBar: some View {
        HStack {
            Button(action: { hideKeyboard(); navigateToHome = true }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
            }
            Text("Scan")
                .font(.kHeadline)
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
            Spacer()
            Button {
                if !messages.isEmpty {
                    showNewChatAlert = true
                }
            } label: {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
            }
            Button {
                showConversationHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
            }
            Button(role: .destructive) {
                showClearChatAlert = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color.adaptive(light: .Light.error, dark: .Dark.error).opacity(0.9))
            }
            .disabled(messages.isEmpty)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text("Scan An Image,")
                .font(.kLargeTitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary).opacity(0.95))
                .padding(.horizontal)
            Text("or Just Ask A Question!")
                .font(.kTitle2)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                .padding(.horizontal)
            SuggestionChips(suggestions: starterSuggestions) { suggestion in
                sendSuggestion(suggestion)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
    
    private var quickTipsBar: some View {
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
    }
    
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        ScanChatBubble(
                            message: message,
                            onCopy: { content in copyToClipboard(content) },
                            onListen: { content, id in speakText(content, messageId: id) },
                            onRetry: { retryLastMessage() }
                        )
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
    }
    
    private var voiceModeIndicator: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: isListening ? "waveform" : isThinking ? "brain" : isSpeaking ? "speaker.wave.2.fill" : "mic.fill")
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                .font(.system(size: 18, weight: .semibold))
                .symbolEffect(.variableColor.iterative, isActive: isListening || isThinking || isSpeaking)
            
            Text(isListening ? "Listening..." : isThinking ? "Thinking..." : isSpeaking ? "Speaking..." : "Voice mode active")
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                .font(.kSubheadline)
            
            Spacer()
            
            Button(action: stopVoiceMode) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                    .font(.system(size: 20))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .fill(voiceModeColor.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
    }
    
    private var voiceModeColor: Color {
        if isListening { return Color.adaptive(light: .Light.info, dark: .Dark.info) }
        if isThinking { return Color.adaptive(light: .Light.warning, dark: .Dark.warning) }
        if isSpeaking { return Color.adaptive(light: .Light.success, dark: .Dark.success) }
        return Color.adaptive(light: .Light.accent, dark: .Dark.accent)
    }
    
    @ViewBuilder
    private var imagePreviewView: some View {
        if let image = selectedImage {
            HStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .clipShape(.rect(cornerRadius: CornerRadius.sm))
                Spacer()
                Button(action: { selectedImage = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                        .font(.title2)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var ttsControlsView: some View {
        if showTTSControls || isTTSLoading {
            ScanTTSControls(
                isTTSLoading: isTTSLoading,
                isPlaying: ttsAudioPlayer?.isPlaying == true,
                currentTime: audioCurrentTime,
                duration: audioDuration,
                onRestart: {
                    ttsAudioPlayer?.currentTime = 0
                    audioCurrentTime = 0
                    ttsAudioPlayer?.play()
                },
                onPlayPause: {
                    if ttsAudioPlayer?.isPlaying == true {
                        ttsAudioPlayer?.pause()
                    } else {
                        ttsAudioPlayer?.play()
                    }
                },
                onStop: stopTTS,
                formatTime: formatTime
            )
        }
    }
    
    private var composerBar: some View {
        ScanComposerBar(
            userInput: $userInput,
            isVoiceModeActive: isVoiceModeActive,
            selectedImage: selectedImage,
            onToggleVoiceMode: toggleVoiceMode,
            onAttachment: {
                Haptics.selection()
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    imageSourceType = .camera
                }
                showImageSourceAlert = true
            },
            onSend: {
                Haptics.light()
                sendMessage()
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            navigationLinks
            headerBar
            
            if messages.isEmpty {
                emptyStateView
            }
            
            quickTipsBar
            messagesListView
            
            if isVoiceModeActive {
                voiceModeIndicator
            }
            
            imagePreviewView
            ttsControlsView
            composerBar
        }
        .kBackground()
        .alert("Delete Chat", isPresented: $showClearChatAlert) {
            Button("Delete", role: .destructive) {
                withAnimation { 
                    messages.removeAll()
                    currentConversation = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete chat?")
        }
        .alert("Start New Chat", isPresented: $showNewChatAlert) {
            Button("New Chat") {
                withAnimation {
                    messages.removeAll()
                    currentConversation = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Current conversation will be saved. Start a new chat?")
        }
        .sheet(isPresented: $showConversationHistory) {
            ConversationHistoryView(
                type: .scan,
                onSelectConversation: { conversation in
                    loadConversation(conversation)
                },
                onDismiss: {
                    showConversationHistory = false
                }
            )
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
        .tint(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
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
            let columns = [GridItem(.adaptive(minimum: 140), spacing: Spacing.sm)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
                ForEach(suggestions, id: \.self) { s in
                    Button(action: {
                        Haptics.selection()
                        onTap(s)
                    }) {
                        Text(s)
                            .font(.kSubheadline)
                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Spacing.sm)
                            .padding(.horizontal, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                                    .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                                            .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                                    )
                            )
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }
    
    private func sendSuggestion(_ text: String) {
        userInput = text
        sendMessage()
    }
    

    struct ScanChatBubble: View {
        let message: ScanMessage
        @State private var isSpeaking = false
        let onCopy: (String) -> Void
        let onListen: (String, UUID) -> Void
        let onRetry: () -> Void

        var body: some View {
            VStack(alignment: message.role == "assistant" ? .leading : .trailing, spacing: Spacing.xs) {
                HStack(alignment: .bottom) {
                    Spacer().frame(width: 0)
                    if message.role == "assistant" {
                        if let formatted = message.content.decodeScanKorahFormatted() {
                            ScanAnswerView(formatted: formatted, timestamp: message.timestamp)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ScrollView {
                                Text(scanFormattedResponse(message.content))
                                    .font(.kBody)
                                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .monospaced(false)
                                    .padding(Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.bubble, style: .continuous)
                                            .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: CornerRadius.bubble, style: .continuous)
                                                    .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .none, alignment: .topLeading)
                        }
                    } else {
                        Spacer()
                        VStack(alignment: .trailing, spacing: Spacing.sm) {
                            if let image = message.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 200)
                                    .clipShape(.rect(cornerRadius: CornerRadius.sm))
                            }
                            if !message.content.isEmpty {
                                Text(message.content)
                                    .font(.kBody)
                                    .foregroundStyle(.white)
                                    .padding(Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.bubble, style: .continuous)
                                            .fill(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: CornerRadius.bubble, style: .continuous)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                            )
                                    )
                                    .shadow(color: Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.3), radius: 12, x: 0, y: 4)
                            }
                        }
                        .frame(maxWidth: 320, alignment: .trailing)
                    }
                }
                
                if message.role == "assistant" {
                    HStack(spacing: Spacing.md) {
                        Button(action: {
                            Haptics.selection()
                            onCopy(message.content)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                        }
                        
                        Button(action: {
                            Haptics.selection()
                            onListen(message.content, message.id)
                        }) {
                            Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                                .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                        }
                        
                        Button(action: {
                            Haptics.selection()
                            onRetry()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                        }
                    }
                    .padding(.leading, Spacing.xs)
                }
            }
        }
    }


    struct ScanAnswerView: View {
        let formatted: ScanKorahFormatted
        let timestamp: Date

        private func badge(_ index: Int) -> some View {
            Text("\(index)")
                .font(.kSubheadline)
                .bold()
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                .frame(width: 26, height: 26)
                .background(Color.adaptive(light: .Light.accent.opacity(0.15), dark: .Dark.accent.opacity(0.2)))
                .clipShape(.circle)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                    Text("Answer")
                        .font(.kHeadline)
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    Spacer()
                }

                if let title = formatted.title, !title.isEmpty {
                    Text(title)
                        .font(.kTitle3)
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let summary = formatted.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.kBody)
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let steps = formatted.steps, !steps.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                badge(idx + 1)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 6) {
                                    let parts = step.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                                    if let first = parts.first, !first.isEmpty {
                                        Text(String(first))
                                            .font(.kHeadline)
                                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                                    }
                                    if parts.count > 1 {
                                        Text(String(parts[1]))
                                            .font(.kBody)
                                            .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                                            .lineSpacing(4)
                                    }
                                }
                            }
                        }
                    }
                }

                if let hints = formatted.hints, !hints.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Tips")
                            .font(.kSubheadline)
                            .bold()
                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                        ForEach(hints, id: \.self) { h in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: "lightbulb")
                                    .foregroundStyle(Color.adaptive(light: .Light.warning, dark: .Dark.warning))
                                Text(h)
                                    .font(.kBody)
                                    .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                            }
                        }
                    }
                }

                if let qs = formatted.questions, !qs.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Try these questions")
                            .font(.kSubheadline)
                            .bold()
                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                        ForEach(qs, id: \.self) { q in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                                Text(q)
                                    .font(.kBody)
                                    .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                            }
                        }
                    }
                }

                Text(timestamp, style: .time)
                    .font(.kCaption)
                    .foregroundStyle(Color.adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary))
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.bubble, style: .continuous)
                    .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.bubble, style: .continuous)
                            .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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
        saveCurrentConversation()
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
        request.addDeviceIDHeader()

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
                    self.messages.append(ScanMessage(role: "assistant", content: "Hmm, I'm having trouble connecting. Please check your internet connection and try again.", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "I didn't get a response. Please try again in a moment.", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let friendlyMessage = APIErrorHandler.handleError(statusCode: http.statusCode, data: data)
                
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: friendlyMessage, timestamp: Date(), image: nil))
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
                            self.saveCurrentConversation()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.messages.append(ScanMessage(role: "assistant", content: "I had trouble creating flashcards from that. Could you try again or rephrase your request?", timestamp: Date(), image: nil))
                            self.showTypingIndicator = false
                            self.saveCurrentConversation()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.messages.append(ScanMessage(role: "assistant", content: "I didn't understand that. Could you try asking in a different way?", timestamp: Date(), image: nil))
                        self.showTypingIndicator = false
                        self.saveCurrentConversation()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "I'm having trouble understanding the response. Please try asking your question again.", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                    self.saveCurrentConversation()
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
        request.addDeviceIDHeader()
        
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
                    self.messages.append(ScanMessage(role: "assistant", content: "Hmm, I'm having trouble connecting. Please check your internet connection and try again.", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "I didn't get a response. Please try again in a moment.", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                }
                return
            }
            
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let friendlyMessage = APIErrorHandler.handleError(statusCode: http.statusCode, data: data)
                
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: friendlyMessage, timestamp: Date(), image: nil))
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
                            self.saveCurrentConversation()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.messages.append(ScanMessage(role: "assistant", content: "I had trouble creating a study guide from that. Could you try again or rephrase your request?", timestamp: Date(), image: nil))
                            self.showTypingIndicator = false
                            self.saveCurrentConversation()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.messages.append(ScanMessage(role: "assistant", content: "I didn't understand that. Could you try asking in a different way?", timestamp: Date(), image: nil))
                        self.showTypingIndicator = false
                        self.saveCurrentConversation()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.messages.append(ScanMessage(role: "assistant", content: "I'm having trouble understanding the response. Please try asking your question again.", timestamp: Date(), image: nil))
                    self.showTypingIndicator = false
                    self.saveCurrentConversation()
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
    
    private func copyToClipboard(_ text: String) {
        let readableText = extractReadableText(from: text)
        UIPasteboard.general.string = readableText
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func extractReadableText(from content: String) -> String {
        // Try to decode as formatted JSON response
        if let formatted = content.decodeScanKorahFormatted() {
            var text = ""
            
            if let title = formatted.title, !title.isEmpty {
                text += title + "\n\n"
            }
            
            if let summary = formatted.summary, !summary.isEmpty {
                text += summary + "\n\n"
            }
            
            if let steps = formatted.steps, !steps.isEmpty {
                text += "Steps:\n"
                for (index, step) in steps.enumerated() {
                    text += "\(index + 1). \(step)\n"
                }
                text += "\n"
            }
            
            if let hints = formatted.hints, !hints.isEmpty {
                text += "Hints:\n"
                for hint in hints {
                    text += "• \(hint)\n"
                }
                text += "\n"
            }
            
            if let footer = formatted.footer, !footer.isEmpty {
                text += footer
            }
            
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Return original content if not JSON formatted
        return content
    }
    
    private func speakText(_ text: String, messageId: UUID) {
        currentTTSText = text
        
        // Check if audio is already cached
        if let cachedAudioURL = getCachedAudioURL(for: messageId),
           FileManager.default.fileExists(atPath: cachedAudioURL.path),
           let audioData = try? Data(contentsOf: cachedAudioURL) {
            // Play cached audio
            showTTSControls = true
            playTTSAudio(data: audioData)
            return
        }
        
        // Generate new audio
        isTTSLoading = true
        showTTSControls = true
        
        let readableText = extractReadableText(from: text)
        
        let url = URL(string: OpenAIConfig.speechURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        
        let body: [String: Any] = [
            "model": "tts-1",
            "input": readableText,
            "voice": "nova",
            "speed": 1.0
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isTTSLoading = false
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.showTTSControls = false
                }
                return
            }
            
            // Cache the audio data
            self.cacheAudioData(data, for: messageId)
            
            DispatchQueue.main.async {
                self.playTTSAudio(data: data)
            }
        }.resume()
    }
    
    private func playTTSAudio(data: Data) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            ttsAudioPlayer = try AVAudioPlayer(data: data)
            ttsAudioPlayer?.prepareToPlay()
            
            audioDuration = ttsAudioPlayer?.duration ?? 0
            audioCurrentTime = 0
            
            let delegate = TTSAudioPlayerDelegate {
                self.stopTTS()
            }
            ttsAudioPlayerDelegate = delegate
            ttsAudioPlayer?.delegate = delegate
            
            ttsAudioPlayer?.play()
            startAudioTimer()
        } catch {
            print("Audio playback error: \(error)")
            showTTSControls = false
        }
    }
    
    private func stopTTS() {
        audioTimer?.invalidate()
        audioTimer = nil
        ttsAudioPlayer?.stop()
        ttsAudioPlayer = nil
        showTTSControls = false
        isTTSLoading = false
        audioCurrentTime = 0
        audioDuration = 0
    }
    
    private func startAudioTimer() {
        audioTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = self.ttsAudioPlayer {
                self.audioCurrentTime = player.currentTime
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Audio Caching
    
    private func getCachedAudioURL(for messageId: UUID) -> URL? {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        return cacheDirectory?.appendingPathComponent("tts_\(messageId.uuidString).m4a")
    }
    
    private func cacheAudioData(_ data: Data, for messageId: UUID) {
        guard let cacheURL = getCachedAudioURL(for: messageId) else { return }
        try? data.write(to: cacheURL)
    }
    
    private func retryLastMessage() {
        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else { return }
        if let lastAssistantIndex = messages.lastIndex(where: { $0.role == "assistant" }) {
            messages.remove(at: lastAssistantIndex)
        }
        userInput = lastUserMessage.content
        sendMessage()
    }
    
    // MARK: - Conversation Management
    
    private func loadConversation(_ conversation: Conversation) {
        currentConversation = conversation
        messages = conversation.messages.map { msg in
            let image: UIImage? = msg.imageFileName.flatMap { fileName in
                ConversationManager.shared.loadImage(fileName: fileName, forConversation: conversation.id)
            }
            return ScanMessage(role: msg.role, content: msg.content, timestamp: msg.timestamp, image: image)
        }
    }
    
    private func saveCurrentConversation() {
        guard !messages.isEmpty else { return }
        
        if var existing = currentConversation {
            // Update existing conversation
            let conversationMessages = messages.map { msg -> ConversationMessage in
                var imageFileName: String?
                if let image = msg.image {
                    imageFileName = ConversationManager.shared.saveImage(image, forConversation: existing.id, messageId: msg.id)
                }
                return ConversationMessage(id: msg.id, role: msg.role, content: msg.content, timestamp: msg.timestamp, imageFileName: imageFileName)
            }
            
            existing.messages = conversationMessages
            existing.updatedAt = Date()
            currentConversation = existing
            ConversationManager.shared.autoSaveConversation(existing)
        } else {
            // Create new conversation
            let title = ConversationManager.shared.generateTitle(from: messages.first?.content ?? "Scan")
            let newConversation = Conversation(
                title: title,
                type: .scan,
                messages: []  // Start with empty, will update below
            )
            currentConversation = newConversation
            
            // Now save images with the conversation's id
            let conversationMessages = messages.map { msg -> ConversationMessage in
                var imageFileName: String?
                if let image = msg.image {
                    imageFileName = ConversationManager.shared.saveImage(image, forConversation: newConversation.id, messageId: msg.id)
                }
                return ConversationMessage(id: msg.id, role: msg.role, content: msg.content, timestamp: msg.timestamp, imageFileName: imageFileName)
            }
            
            var updatedConversation = newConversation
            updatedConversation.messages = conversationMessages
            currentConversation = updatedConversation
            ConversationManager.shared.autoSaveConversation(updatedConversation)
        }
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
        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            showTypingIndicator = false
            isLoading = false
            messages.append(ScanMessage(role: "assistant", content: "Invalid API URL.", timestamp: Date(), image: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        
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
        - REMINDER: Students can ask you to create flashcards, study guides, or practice tests about what they're learning. Let them know they can do this if appropriate.
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

        // Non-streaming request
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": apiMessages,
            "temperature": 0.3,
            "max_tokens": 1000,
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // Create placeholder assistant message for simulated streaming
        let messageId = UUID()
        let placeholderMessage = ScanMessage(id: messageId, role: "assistant", content: "", timestamp: Date(), image: nil)
        messages.append(placeholderMessage)
        let messageIndex = messages.count - 1
        streamingMessageIndex = messageIndex
        isStreaming = true
        showTypingIndicator = false
        
        streamTask = Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    await handleStreamError("Invalid response", at: messageIndex)
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    await handleHTTPStreamError(statusCode: httpResponse.statusCode, at: messageIndex, responseData: data)
                    return
                }
                
                // Decode the full response
                let decoded = try JSONDecoder().decode(ScanOpenAIResponse.self, from: data)
                guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
                    await MainActor.run {
                        if messageIndex < messages.count {
                            messages[messageIndex].content = "I didn't understand that. Could you try asking in a different way?"
                        }
                        finishStreaming()
                    }
                    return
                }
                
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalContent: String
                
                if trimmed.decodeScanKorahFormatted() != nil {
                    finalContent = trimmed
                } else {
                    let safeSummary = trimmed.replacingOccurrences(of: "\n", with: " ")
                    let fallback: [String: Any] = [
                        "kind": "tutor",
                        "title": "Here's some guidance",
                        "summary": safeSummary,
                        "steps": [] as [String],
                        "hints": [] as [String],
                        "questions": ["What part would you like to try next?"],
                        "footer": "If you need a structured plan, ask me to list steps."
                    ]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: fallback),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        finalContent = jsonString
                    } else {
                        finalContent = trimmed
                    }
                }
                
                // Stream the raw JSON text, then it auto-formats when complete
                await simulateStreaming(text: finalContent, at: messageIndex)
                
            } catch {
                if !Task.isCancelled {
                    await handleStreamError(error.localizedDescription, at: messageIndex)
                }
            }
        }
    }
    
    /// Simulates streaming for formatted JSON responses by revealing title → summary → steps → hints → questions
    private func simulateFormattedStreaming(formatted: ScanKorahFormatted, fullJson: String, at index: Int) async {
        // Collect all text segments in order
        var segments: [(field: String, text: String)] = []
        
        if let title = formatted.title, !title.isEmpty {
            segments.append(("title", title))
        }
        if let summary = formatted.summary, !summary.isEmpty {
            segments.append(("summary", summary))
        }
        if let steps = formatted.steps {
            for (i, step) in steps.enumerated() {
                segments.append(("step_\(i)", step))
            }
        }
        if let hints = formatted.hints {
            for (i, hint) in hints.enumerated() {
                segments.append(("hint_\(i)", hint))
            }
        }
        if let questions = formatted.questions {
            for (i, question) in questions.enumerated() {
                segments.append(("question_\(i)", question))
            }
        }
        
        // Calculate total characters and consistent streaming speed
        let totalChars = segments.reduce(0) { $0 + $1.text.count }
        guard totalChars > 0 else {
            await MainActor.run {
                if index < messages.count {
                    messages[index].content = fullJson
                }
                finishStreaming()
                saveCurrentConversation()
            }
            return
        }
        
        let targetDuration: Double = min(3.0, max(1.0, Double(totalChars) * 0.012))
        let updateInterval: UInt64 = 30_000_000 // 30ms
        let totalUpdates = Int(targetDuration / 0.030)
        let charsPerUpdate = max(1, totalChars / totalUpdates)
        
        // Track streaming progress
        var streamedTitle: String = ""
        var streamedSummary: String = ""
        var streamedSteps: [String] = []
        var streamedHints: [String] = []
        var streamedQuestions: [String] = []
        
        var globalCharIndex = 0
        
        for segment in segments {
            if Task.isCancelled { break }
            
            let chars = Array(segment.text)
            var localIndex = 0
            
            while localIndex < chars.count {
                if Task.isCancelled { break }
                
                let charsToAdd = min(charsPerUpdate, chars.count - localIndex)
                localIndex += charsToAdd
                globalCharIndex += charsToAdd
                
                let partialText = String(chars.prefix(localIndex))
                
                // Update the appropriate field
                switch segment.field {
                case "title":
                    streamedTitle = partialText
                case "summary":
                    streamedSummary = partialText
                case let field where field.hasPrefix("step_"):
                    let stepIndex = Int(field.replacingOccurrences(of: "step_", with: "")) ?? 0
                    while streamedSteps.count <= stepIndex { streamedSteps.append("") }
                    streamedSteps[stepIndex] = partialText
                case let field where field.hasPrefix("hint_"):
                    let hintIndex = Int(field.replacingOccurrences(of: "hint_", with: "")) ?? 0
                    while streamedHints.count <= hintIndex { streamedHints.append("") }
                    streamedHints[hintIndex] = partialText
                case let field where field.hasPrefix("question_"):
                    let qIndex = Int(field.replacingOccurrences(of: "question_", with: "")) ?? 0
                    while streamedQuestions.count <= qIndex { streamedQuestions.append("") }
                    streamedQuestions[qIndex] = partialText
                default:
                    break
                }
                
                // Build partial JSON
                let partialJson = buildPartialJson(
                    kind: formatted.kind,
                    title: streamedTitle.isEmpty ? nil : streamedTitle,
                    summary: streamedSummary.isEmpty ? nil : streamedSummary,
                    steps: streamedSteps.isEmpty ? nil : streamedSteps,
                    hints: streamedHints.isEmpty ? nil : streamedHints,
                    questions: streamedQuestions.isEmpty ? nil : streamedQuestions,
                    footer: nil
                )
                
                await MainActor.run {
                    if index < messages.count {
                        messages[index].content = partialJson
                    }
                }
                
                if localIndex < chars.count {
                    try? await Task.sleep(nanoseconds: updateInterval)
                }
            }
        }
        
        // Final update with complete JSON
        await MainActor.run {
            if index < messages.count {
                messages[index].content = fullJson
            }
            finishStreaming()
            saveCurrentConversation()
        }
    }
    
    /// Builds a partial JSON string for streaming display
    private func buildPartialJson(
        kind: String?,
        title: String?,
        summary: String?,
        steps: [String]?,
        hints: [String]?,
        questions: [String]?,
        footer: String?
    ) -> String {
        var dict: [String: Any] = [:]
        if let kind = kind { dict["kind"] = kind }
        if let title = title { dict["title"] = title }
        if let summary = summary { dict["summary"] = summary }
        if let steps = steps, !steps.isEmpty { dict["steps"] = steps }
        if let hints = hints, !hints.isEmpty { dict["hints"] = hints }
        if let questions = questions, !questions.isEmpty { dict["questions"] = questions }
        if let footer = footer { dict["footer"] = footer }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
    
    /// Fallback: simulates streaming for plain text
    private func simulateStreaming(text: String, at index: Int) async {
        let characters = Array(text)
        let totalChars = characters.count
        var currentIndex = 0
        
        let targetDuration: Double = min(2.5, Double(totalChars) * 0.015)
        let updateInterval: UInt64 = 25_000_000
        let charsPerUpdate = max(1, totalChars / Int(targetDuration / 0.025))
        
        while currentIndex < totalChars {
            if Task.isCancelled { break }
            
            let endIndex = min(currentIndex + charsPerUpdate, totalChars)
            let partialText = String(characters[0..<endIndex])
            
            await MainActor.run {
                if index < messages.count {
                    messages[index].content = partialText
                }
            }
            
            currentIndex = endIndex
            
            if currentIndex < totalChars {
                try? await Task.sleep(nanoseconds: updateInterval)
            }
        }
        
        await MainActor.run {
            if index < messages.count {
                messages[index].content = text
            }
            finishStreaming()
            saveCurrentConversation()
        }
    }
    
    private func finishStreaming() {
        isLoading = false
        isStreaming = false
        showTypingIndicator = false
        streamingMessageIndex = nil
    }
    
    private func handleStreamError(_ message: String, at index: Int) async {
        await MainActor.run {
            if index < messages.count {
                messages[index].content = "Hmm, I'm having trouble connecting. Please check your internet connection and try again."
            }
            finishStreaming()
        }
    }
    
    private func handleHTTPStreamError(statusCode: Int, at index: Int, responseData: Data?) async {
        let friendlyMessage: String
        switch statusCode {
        case 401:
            friendlyMessage = "Oops! There's an issue with the app's authentication. Please contact support."
        case 429:
            friendlyMessage = "Oops! I'm getting too many requests right now. Please wait a moment and try again."
        case 500...599:
            friendlyMessage = "Oops! The service is having trouble right now. Please try again in a few minutes."
        default:
            friendlyMessage = "Oops! Something went wrong. Please try again."
        }
        
        await MainActor.run {
            if index < messages.count {
                messages[index].content = friendlyMessage
            }
            finishStreaming()
        }
    }
    
    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        isLoading = false
        showTypingIndicator = false
        streamingMessageIndex = nil
        Haptics.medium()
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
    
    // MARK: - Voice Mode Functions
    
    func toggleVoiceMode() {
        if isVoiceModeActive {
            stopVoiceMode()
        } else {
            startVoiceMode()
        }
    }
    
    func startVoiceMode() {
        isVoiceModeActive = true
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        startListening()
    }
    
    func stopVoiceMode() {
        isVoiceModeActive = false
        stopListening()
        audioPlayer?.stop()
        isSpeaking = false
        isThinking = false
    }
    
    func startListening() {
        guard isVoiceModeActive && !isListening else { return }
        
        do {
            try startRecording()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func startRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default, options: [])
        try audioSession.setActive(true)
        
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("voice_\(Date().timeIntervalSince1970).m4a")
        
        guard let url = recordingURL else { return }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()
        
        isListening = true
        startSilenceDetection()
    }
    
    func startSilenceDetection() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.audioRecorder?.updateMeters()
            let level = self.audioRecorder?.averagePower(forChannel: 0) ?? -160.0
            
            if level > self.silenceThreshold {
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil
            } else {
                if self.silenceTimer == nil {
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceDuration, repeats: false) { _ in
                        DispatchQueue.main.async {
                            self.stopListening()
                        }
                    }
                }
            }
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        silenceTimer?.invalidate()
        audioLevelTimer?.invalidate()
        audioRecorder?.stop()
        isListening = false
        
        if let url = recordingURL {
            transcribeAudio(fileURL: url)
        }
    }
    
    func transcribeAudio(fileURL: URL) {
        let url = URL(string: OpenAIConfig.transcriptionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        if let audioData = try? Data(contentsOf: fileURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String, !text.isEmpty {
                    self.messages.append(ScanMessage(role: "user", content: text, timestamp: Date(), image: nil))
                    self.saveCurrentConversation()
                    self.sendVoiceMessageToAI(text: text)
                }
                
                try? FileManager.default.removeItem(at: fileURL)
            }
        }.resume()
    }
    
    func sendVoiceMessageToAI(text: String) {
        isThinking = true
        showTypingIndicator = true
        
        let url = URL(string: OpenAIConfig.chatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        
        let systemInstruction = """
        You are Korah, a friendly AI tutor for younger students (ages 8-14). Keep responses concise and conversational for voice interaction. You are meant to interactively teach students how to learn and study things they find challenging.
        
        IMPORTANT RULES:
        - Never give direct answers to homework or test questions
        - Instead, ask guiding questions and give hints to help them figure it out themselves
        - Use age-appropriate language and simple examples
        - Keep responses to 2-3 sentences maximum for easy listening
        - Be encouraging and patient
        - If they're stuck, break the problem into smaller steps
        
        Example approach:
        Student: "What's 12 times 8?"
        You: "Great question! Let's break it down. Can you tell me what 12 times 10 would be? Then we can work backwards from there."
        """
        
        let apiMessages: [[String: Any]] =
            [["role": "system", "content": systemInstruction]] +
            messages.map { ["role": $0.role, "content": $0.content] }
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": apiMessages,
            "temperature": 0.7
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isThinking = false
                self.showTypingIndicator = false
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    let newMessage = ScanMessage(role: "assistant", content: content, timestamp: Date(), image: nil)
                    self.messages.append(newMessage)
                    self.saveCurrentConversation()
                    
                    self.speakTextForVoiceMode(content, messageId: newMessage.id)
                } else {
                    self.messages.append(ScanMessage(role: "assistant", content: "I couldn't process that. Can you try again?", timestamp: Date(), image: nil))
                }
            }
        }.resume()
    }
    
    func speakTextForVoiceMode(_ text: String, messageId: UUID) {
        isSpeaking = true
        
        let url = URL(string: OpenAIConfig.speechURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        
        let body: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": "nova",
            "speed": 1.0
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    self.isSpeaking = false
                    if self.isVoiceModeActive {
                        self.startListening()
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                self.playAudio(data: data)
            }
        }.resume()
    }
    
    func playAudio(data: Data) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            
            let delegate = AudioPlayerDelegate {
                self.isSpeaking = false
                if self.isVoiceModeActive {
                    self.startListening()
                }
            }
            audioPlayerDelegate = delegate
            audioPlayer?.delegate = delegate
            
            audioPlayer?.play()
        } catch {
            print("Audio playback error: \(error)")
            isSpeaking = false
            if isVoiceModeActive {
                startListening()
            }
        }
    }
}


// MARK: - TTS Controls

struct ScanTTSControls: View {
    let isTTSLoading: Bool
    let isPlaying: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onRestart: () -> Void
    let onPlayPause: () -> Void
    let onStop: () -> Void
    let formatTime: (TimeInterval) -> String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                if isTTSLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.adaptive(light: .Light.accent, dark: .Dark.accent)))
                        .scaleEffect(0.8)
                    Text("Generating audio...")
                        .font(.kSubheadline)
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    Spacer()
                } else {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                        .font(.system(size: 18))
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isPlaying ? "Playing" : "Paused")
                            .font(.kSubheadline)
                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                        Text("\(formatTime(currentTime)) / \(formatTime(duration))")
                            .font(.kCaption)
                            .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                    }
                    
                    Spacer()
                    
                    Button(action: onRestart) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                            .font(.system(size: 16))
                    }
                    
                    Button(action: onPlayPause) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                            .font(.system(size: 16))
                    }
                    
                    Button(action: onStop) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                            .font(.system(size: 20))
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .fill(Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
            .padding(.horizontal)
            .padding(.bottom, Spacing.sm)
        }
    }
}

// MARK: - Composer Bar

struct ScanComposerBar: View {
    @Binding var userInput: String
    let isVoiceModeActive: Bool
    let selectedImage: UIImage?
    let onToggleVoiceMode: () -> Void
    let onAttachment: () -> Void
    let onSend: () -> Void
    
    private var canSend: Bool {
        !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil
    }
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            voiceButton
            attachmentButton
            textField
            sendButton
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.pill, style: .continuous)
                .fill(Color.adaptive(light: .Light.background, dark: .Dark.background))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.pill, style: .continuous)
                        .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        .padding(.horizontal)
    }
    
    private var voiceButton: some View {
        Button {
            onToggleVoiceMode()
        } label: {
            Image(systemName: isVoiceModeActive ? "waveform" : "mic.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                .frame(width: ComponentSize.buttonHeight, height: ComponentSize.buttonHeight)
                .background(
                    Circle()
                        .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                        .overlay(
                            Circle()
                                .stroke(
                                    isVoiceModeActive ? Color.adaptive(light: .Light.info, dark: .Dark.info) : Color.adaptive(light: .Light.accent, dark: .Dark.accent),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: (isVoiceModeActive ? Color.adaptive(light: .Light.info, dark: .Dark.info) : Color.adaptive(light: .Light.accent, dark: .Dark.accent)).opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .scaleEffect(isVoiceModeActive ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isVoiceModeActive)
        .symbolEffect(.pulse, isActive: isVoiceModeActive)
    }
    
    private var attachmentButton: some View {
        Button {
            onAttachment()
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                .frame(width: ComponentSize.buttonHeight, height: ComponentSize.buttonHeight)
                .background(
                    Circle()
                        .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.adaptive(light: .Light.accent, dark: .Dark.accent),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.2), radius: 8, x: 0, y: 4)
                )
        }
        .disabled(isVoiceModeActive)
        .opacity(isVoiceModeActive ? 0.5 : 1.0)
    }
    
    private var textField: some View {
        TextField("Type your message…", text: $userInput, axis: .vertical)
            .font(.kBody)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.pill, style: .continuous)
                    .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.pill, style: .continuous)
                            .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                    )
            )
            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
            .lineLimit(1...4)
            .disabled(isVoiceModeActive)
    }
    
    private var sendButton: some View {
        Button {
            onSend()
        } label: {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: ComponentSize.buttonHeight, height: ComponentSize.buttonHeight)
                .background(
                    Circle()
                        .fill(canSend ? Color.adaptive(light: .Light.accent, dark: .Dark.accent) : Color.adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary))
                        .shadow(
                            color: canSend ? Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.4) : .clear,
                            radius: 12,
                            x: 0,
                            y: 4
                        )
                )
        }
        .disabled(!canSend || isVoiceModeActive)
    }
}

// MARK: - Quick Tip Button

struct QuickTipButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            Text(title)
                .font(.kSubheadline)
                .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                        .overlay(
                            Capsule()
                                .stroke(Color.adaptive(light: .Light.accent, dark: .Dark.accent), lineWidth: 1.5)
                        )
                )
                .shadow(color: Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.2), radius: 6, x: 0, y: 3)
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

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

class TTSAudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
