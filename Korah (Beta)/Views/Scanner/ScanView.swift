import SwiftUI
import LaTeXSwiftUI
import UIKit
import AVFoundation
import Foundation
import MarkdownUI


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

// Streaming response structure for SSE
struct ScanStreamingResponse: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let role: String?
            let content: String?
        }
        let delta: Delta
        let finishReason: String?
        private enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }
    let choices: [Choice]
}


struct ScanKorahFormatted: Decodable {
    let kind: String?           
    let title: String?          
    let summary: String?        
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
    
    @State private var showCameraMode = false

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
        guard let lastAssistant = messages.last(where: { $0.role == "assistant" }),
              !lastAssistant.content.isEmpty else {
            return []
        }
        
        // Try to extract dynamic follow-up questions from the LLM response
        if let formatted = lastAssistant.content.decodeScanKorahFormatted(),
           let questions = formatted.questions,
           !questions.isEmpty {
            return Array(questions.prefix(3))
        }
        
        // Fallback to generic suggestions if no questions in response
        return [
            "Can you explain that differently?",
            "Give me an example",
            "What should I try next?"
        ]
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
                   let guide = FirestoreStudyService.shared.studyGuides.first(where: { $0.id == id }) {
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
        VStack(spacing: Spacing.sm) {
            // Top bar with back button and actions
            HStack {
                Button(action: { hideKeyboard(); navigateToHome = true }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                }
                
                Spacer()
                
                if !showCameraMode {
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
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xl)
            
            // Mode Toggle
            HStack(spacing: Spacing.sm) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCameraMode = true
                        hideKeyboard()
                    }
                    Haptics.selection()
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                        Text("Camera")
                            .font(.kSubheadline)
                    }
                    .foregroundStyle(showCameraMode ? .white : Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(showCameraMode ? Color.adaptive(light: .Light.accent, dark: .Dark.accent) : Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                    .stroke(showCameraMode ? Color.clear : Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: showCameraMode ? Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCameraMode = false
                    }
                    Haptics.selection()
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 14))
                        Text("Chat")
                            .font(.kSubheadline)
                    }
                    .foregroundStyle(!showCameraMode ? .white : Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(!showCameraMode ? Color.adaptive(light: .Light.accent, dark: .Dark.accent) : Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                    .stroke(!showCameraMode ? Color.clear : Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: !showCameraMode ? Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
    }
    
    private var modeToggle: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCameraMode = true
                    hideKeyboard()
                }
                Haptics.selection()
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                    Text("Camera")
                        .font(.kSubheadline)
                }
                .foregroundStyle(showCameraMode ? .white : Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(showCameraMode ? Color.adaptive(light: .Light.accent, dark: .Dark.accent) : Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .stroke(showCameraMode ? Color.clear : Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                        )
                )
                .shadow(color: showCameraMode ? Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCameraMode = false
                }
                Haptics.selection()
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 14))
                    Text("Chat")
                        .font(.kSubheadline)
                }
                .foregroundStyle(!showCameraMode ? .white : Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(!showCameraMode ? Color.adaptive(light: .Light.accent, dark: .Dark.accent) : Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .stroke(!showCameraMode ? Color.clear : Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                        )
                )
                .shadow(color: !showCameraMode ? Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            // Title
            VStack(spacing: Spacing.xs) {
                Text("Ask Anything")
                    .font(.kLargeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                Text("with AI Search")
                    .font(.kLargeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
            }
            .padding(.horizontal)
            
            // Search Field
            HStack(spacing: Spacing.sm) {
                TextField("Ask anything...", text: $userInput, axis: .vertical)
                    .font(.kBody)
                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    .lineLimit(1...4)
                    .onSubmit {
                        if !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Haptics.light()
                            sendMessage()
                        }
                    }
                
                if !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: {
                        Haptics.light()
                        sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 1)
                    )
            )
            .padding(.horizontal, Spacing.lg)
            
            // Suggestion Cards Grid
            EmptyStateSuggestionGrid(onTap: sendSuggestion)
                .padding(.horizontal, Spacing.md)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    struct EmptyStateSuggestionCard: View {
        let emoji: String
        let title: String
        let subtitle: String
        let onTap: () -> Void
        
        var body: some View {
            Button(action: {
                Haptics.selection()
                onTap()
            }) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Text(emoji)
                            .font(.system(size: 16))
                        Text(title)
                            .font(.kSubheadline)
                            .bold()
                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    }
                    Text(subtitle)
                        .font(.kCaption)
                        .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                                .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
                        )
                )
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
    
    struct EmptyStateSuggestionGrid: View {
        let onTap: (String) -> Void
        
        private let suggestions: [(emoji: String, title: String, subtitle: String)] = [
            ("📚", "Learn more", "Teach me the quadratic formula?"),
            ("🦣", "Highlight", "What role did the Columbian Exchange play in the narrative?"),
            ("💪", "Brief me on", "What is Gestalt's Principle on perception?"),
            ("🏛️", "Help me write", "What agreement came out of the Berlin conference?")
        ]
        
        var body: some View {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                ForEach(suggestions, id: \.title) { suggestion in
                    EmptyStateSuggestionCard(
                        emoji: suggestion.emoji,
                        title: suggestion.title,
                        subtitle: suggestion.subtitle
                    ) {
                        onTap(suggestion.subtitle)
                    }
                }
            }
        }
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
                            isStreaming: isStreaming && message.id == messages.last?.id,
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
                showImageSourceAlert = true
            },
            onSend: {
                Haptics.light()
                sendMessage()
            }
        )
    }
    
    var body: some View {
        ZStack {
            // Chat Mode
            if !showCameraMode {
                VStack(spacing: 0) {
                    navigationLinks
                    headerBar
                    
                    if messages.isEmpty {
                        emptyStateView
                    } else {
                        quickTipsBar
                        messagesListView
                    }
                    
                    if isVoiceModeActive {
                        voiceModeIndicator
                    }
                    
                    if !messages.isEmpty {
                        imagePreviewView
                        ttsControlsView
                        composerBar
                    }
                }
                .kBackground(withStars: true)
                .transition(.opacity)
            }
            
            // Camera Mode
            if showCameraMode {
                ZStack(alignment: .top) {
                    CustomCameraView(
                        onPhotoCaptured: { image in
                            selectedImage = image
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCameraMode = false
                            }
                        },
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCameraMode = false
                            }
                        }
                    )
                    .ignoresSafeArea()
                    
                    modeToggle
                        .padding(.top, Spacing.xl + 44)
                        .padding(.horizontal, Spacing.md)
                }
                .transition(.opacity)
            }
        }
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
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCameraMode = true
                }
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
            // Default to camera mode when view appears
            showCameraMode = true
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
        let isStreaming: Bool
        @State private var isSpeaking = false
        @State private var thinkingOpacity: Double = 0.4
        let onCopy: (String) -> Void
        let onListen: (String, UUID) -> Void
        let onRetry: () -> Void

        var body: some View {
            VStack(alignment: message.role == "assistant" ? .leading : .trailing, spacing: Spacing.xs) {
                HStack(alignment: .bottom) {
                    Spacer().frame(width: 0)
                    if message.role == "assistant" {
                        if message.content.isEmpty {
                            // Show loading state when content is empty
                            Text("Korah is thinking...")
                                .font(.kBody)
                                .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                                .opacity(thinkingOpacity)
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
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                        thinkingOpacity = 1.0
                                    }
                                }
                        } else if let formatted = message.content.decodeScanKorahFormatted() {
                            ScanAnswerView(formatted: formatted, timestamp: message.timestamp)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            KorahLatexView(content: message.content, isStreaming: isStreaming)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
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
                                    .fixedSize(horizontal: false, vertical: true)
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
                                    .fixedSize(horizontal: false, vertical: true)
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

        let instruction = "Create a flashcard set from our conversation in the same JSON schema. Put concise terms in hints and matching definitions."
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

                        try? FirestoreStudyService.shared.addFlashcardSet(newSet)

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
                        
                        try? FirestoreStudyService.shared.addStudyGuide(guide)
                        
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
        if let hints = formatted.hints, !hints.isEmpty {
            return hints.map { ($0, "") }
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
            
            if let hints = formatted.hints, !hints.isEmpty {
                text += "Tips:\n"
                for hint in hints {
                    text += "• \(hint)\n"
                }
                text += "\n"
            }
            
            if let questions = formatted.questions, !questions.isEmpty {
                text += "Questions:\n"
                for question in questions {
                    text += "• \(question)\n"
                }
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
            try? FirestoreConversationService.shared.saveConversation(existing)
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
            try? FirestoreConversationService.shared.saveConversation(updatedConversation)
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
        
        Rules:
        - Be a tutor that is friendly and makes learning fun, using emojis and being educational
        - Explain concepts clearly and provide helpful hints
        - If the user asks for direct answers, redirect with guiding questions and hints
        - Use natural, conversational language
        - Break down complex topics into understandable pieces
        - Be encouraging and patient
        
        Formatting:
        - Use **bold** for key terms and important concepts
        - Use *italics* for emphasis
        - Use bullet points with - or * for lists
        - Use ## for section headers when organizing longer explanations
        - Use ### for sub-headers within sections
        - For math equations, use LaTeX syntax. CRITICAL RULE: always place LaTeX on its own separate line with a blank line before and after it. NEVER write LaTeX inline within a sentence of regular text — doing so breaks rendering.
          * Display math (for standalone equations): always on its own line, e.g.: $$\\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$$
          * Inline math
          * When describing math concepts in prose, spell them out in plain text rather than mixing LaTeX into the sentence
        - Keep it visually organized and easy to scan
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

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": apiMessages,
            "temperature": 0.9,
            "max_tokens": 1000,
            "stream": true
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // Create placeholder assistant message
        let messageId = UUID()
        let placeholderMessage = (ScanMessage(id: messageId, role: "assistant", content: "", timestamp: Date(), image: nil))
        messages.append(placeholderMessage)
        let messageIndex = messages.count - 1
        streamingMessageIndex = messageIndex
        isStreaming = true
        showTypingIndicator = false
        
        streamTask = Task {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    await handleStreamError("Invalid response", at: messageIndex)
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    await handleStreamError("Server error: \(httpResponse.statusCode)", at: messageIndex)
                    return
                }
                
                var accumulatedContent = ""
                
                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    
                    // SSE format: "data: {json}" or "data: [DONE]"
                    guard line.hasPrefix("data: ") else { continue }
                    let dataString = String(line.dropFirst(6))
                    
                    if dataString == "[DONE]" {
                        break
                    }
                    
                    // Parse the streaming chunk
                    guard let data = dataString.data(using: .utf8),
                          let chunk = try? JSONDecoder().decode(ScanStreamingResponse.self, from: data),
                          let delta = chunk.choices.first?.delta.content else {
                        continue
                    }
                    
                    accumulatedContent += delta
                    
                    // Update UI with accumulated content
                    await MainActor.run {
                        if messageIndex < messages.count {
                            messages[messageIndex].content = accumulatedContent
                        }
                    }
                }
                
                // After streaming completes, validate and format the JSON
                let trimmed = accumulatedContent.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard !trimmed.isEmpty else {
                    await MainActor.run {
                        if messageIndex < messages.count {
                            messages[messageIndex].content = "I didn't understand that. Could you try asking in a different way?"
                        }
                        finishStreaming()
                    }
                    return
                }
                
                // Final update with complete content
                await MainActor.run {
                    if messageIndex < messages.count {
                        messages[messageIndex].content = trimmed
                    }
                    finishStreaming()
                    saveCurrentConversation()
                }
                
            } catch {
                if !Task.isCancelled {
                    await handleStreamError(error.localizedDescription, at: messageIndex)
                }
            }
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

