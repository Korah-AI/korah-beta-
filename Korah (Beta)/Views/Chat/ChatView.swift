import SwiftUI
import UIKit
import Speech
import AVFoundation

struct Message: Identifiable {
    let id = UUID()
    let role: String 
    let content: String
    let timestamp: Date
}

struct OpenAIResponse: Decodable {
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

struct ChatKorahFormatted: Decodable {
    let kind: String?
    let title: String?
    let summary: String?
    let steps: [String]?
    let hints: [String]?
    let questions: [String]?
    let footer: String?
}

extension String {
    // extracts json from assistant messages for ui rendering
    func decodeKorahFormatted() -> ChatKorahFormatted? {
        if let data = self.data(using: .utf8),
           let obj = try? JSONDecoder().decode(ChatKorahFormatted.self, from: data) {
            return obj
        }
        guard let start = self.firstIndex(of: "{"),
              let end = self.lastIndex(of: "}") else { return nil }
        let jsonSubstring = self[start...end]
        guard let data2 = String(jsonSubstring).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ChatKorahFormatted.self, from: data2)
    }
}

struct TypingIndicator: View {
    @State private var animationAmount: Double = 1.0
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Korah is typing")
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

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var navigateToHome = false

    @State private var messages: [Message] = []
    @State private var userInput: String = ""
    @State private var isLoading = false
    @State private var showTypingIndicator = false
    @State private var showClearChatAlert = false
    @State private var showConversationHistory = false
    @State private var showNewChatAlert = false
    @State private var currentConversation: Conversation?

    @State private var starterSuggestions: [String] = [
        "What can you help me learn?",
        "Give me a math warm-up",
        "Explain photosynthesis simply",
        "Practice spelling with me"
    ]
    
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
    
    @State private var showTTSControls = false
    @State private var isTTSLoading = false
    @State private var ttsAudioPlayer: AVAudioPlayer?
    @State private var ttsAudioPlayerDelegate: TTSAudioPlayerDelegate?
    @State private var currentTTSText: String = ""
    @State private var audioDuration: TimeInterval = 0
    @State private var audioCurrentTime: TimeInterval = 0
    @State private var audioTimer: Timer?
    
    // generates follow-up suggestion chips from ai response
    private var contextSuggestions: [String] {
        if let lastAssistantContent = messages.last(where: { $0.role == "assistant" })?.content,
           let formatted = lastAssistantContent.decodeKorahFormatted(),
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

    private func sendSuggestion(_ text: String) {
        userInput = text
        sendMessage()
    }
    
    // converts assistant-style prompts to first-person user prompts
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
            
            HStack {
                Button(action: { hideKeyboard(); navigateToHome = true }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                }
                Text("Chat")
                    .font(.headline)
                Spacer()
                Button {
                    if !messages.isEmpty {
                        showNewChatAlert = true
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                Button {
                    showConversationHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
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
                    Text("Ready when you are!")
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

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(
                                message: message,
                                onCopy: { content in copyToClipboard(content) },
                                onListen: { content, id in speakText(content, messageId: id) },
                                onRetry: { retryLastMessage() }
                            )
                            .id(message.id)
                            .padding(.horizontal)
                        }
                        
                        if showTypingIndicator {
                            TypingIndicator()
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
            .padding(.horizontal)
            
            if isVoiceModeActive {
                HStack(spacing: 8) {
                    Image(systemName: isListening ? "waveform" : isThinking ? "brain" : isSpeaking ? "speaker.wave.2.fill" : "mic.fill")
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor.iterative, isActive: isListening || isThinking || isSpeaking)
                    
                    Text(isListening ? "Listening..." : isThinking ? "Thinking..." : isSpeaking ? "Speaking..." : "Voice mode active")
                        .foregroundColor(.white)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button(action: stopVoiceMode) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: isListening ? [Color.blue.opacity(0.3), Color.blue.opacity(0.5)] :
                                isThinking ? [Color.orange.opacity(0.3), Color.orange.opacity(0.5)] :
                                isSpeaking ? [Color.green.opacity(0.3), Color.green.opacity(0.5)] :
                                [Color.purple.opacity(0.3), Color.purple.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            if showTTSControls || isTTSLoading {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        if isTTSLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Generating audio...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                        } else {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.white)
                                .symbolEffect(.variableColor.iterative, isActive: ttsAudioPlayer?.isPlaying == true)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ttsAudioPlayer?.isPlaying == true ? "Playing" : "Paused")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text("\(formatTime(audioCurrentTime)) / \(formatTime(audioDuration))")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                ttsAudioPlayer?.currentTime = 0
                                audioCurrentTime = 0
                                ttsAudioPlayer?.play()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                if ttsAudioPlayer?.isPlaying == true {
                                    ttsAudioPlayer?.pause()
                                } else {
                                    ttsAudioPlayer?.play()
                                }
                            }) {
                                Image(systemName: ttsAudioPlayer?.isPlaying == true ? "pause.fill" : "play.fill")
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: stopTTS) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            
            HStack(spacing: 8) {
                Button(action: toggleVoiceMode) {
                    Image(systemName: isVoiceModeActive ? "waveform" : "mic.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(isVoiceModeActive ? Color.blue : Color.purple)
                        .clipShape(Circle())
                        .symbolEffect(.pulse, isActive: isVoiceModeActive)
                }
                
                TextField("Type your message…", text: $userInput, axis: .vertical)
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                    .foregroundColor(.white)
                    .lineLimit(1...4)
                    .disabled(isVoiceModeActive)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.purple)
                        .clipShape(Circle())
                }
                .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVoiceModeActive)
            }
            .padding(.all, 12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(25)
            .padding(.horizontal)
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
                type: .chat,
                onSelectConversation: { conversation in
                    loadConversation(conversation)
                },
                onDismiss: {
                    showConversationHistory = false
                }
            )
        }
        .korahGradientBackground()
        .accentColor(.purple)
        .preferredColorScheme(.dark)
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


    struct ChatBubble: View {
        let message: Message
        @State private var isSpeaking = false
        let onCopy: (String) -> Void
        let onListen: (String, UUID) -> Void
        let onRetry: () -> Void

        var body: some View {
            VStack(alignment: message.role == "assistant" ? .leading : .trailing, spacing: 4) {
                HStack(alignment: .bottom) {
                    Spacer().frame(width: 0)
                    if message.role == "assistant" {
                        if let formatted = message.content.decodeKorahFormatted() {
                            AssistantCard(formatted: formatted, timestamp: message.timestamp)
                                .frame(maxWidth: 320, alignment: .leading)
                        } else {
                            Text(message.content)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .frame(maxWidth: 260, alignment: .leading)
                        }
                    } else {
                        Spacer()
                        Text(message.content)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .frame(maxWidth: 260, alignment: .trailing)
                    }
                }
                
                if message.role == "assistant" {
                    HStack(spacing: 16) {
                        Button(action: { onCopy(message.content) }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundColor(.purple)
                        }
                        
                        Button(action: { onListen(message.content, message.id) }) {
                            Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.system(size: 14))
                                .foregroundColor(.purple)
                                .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                        }
                        
                        Button(action: onRetry) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }


    struct AssistantCard: View {
        let formatted: ChatKorahFormatted
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
                        ForEach(Array(steps.enumerated()), id: \.offset) { idx, s in
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
                        ForEach(Array(qs.prefix(3)), id: \.self) { q in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "questionmark.circle")
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


    func sendMessage() {
        let input = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        messages.append(Message(role: "user", content: input, timestamp: Date()))
        userInput = ""
        isLoading = true
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        showTypingIndicator = true
        saveCurrentConversation()
        fetchChatResponse()
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
        if let formatted = content.decodeKorahFormatted() {
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
            Message(role: msg.role, content: msg.content, timestamp: msg.timestamp)
        }
    }
    
    private func saveCurrentConversation() {
        guard !messages.isEmpty else { return }
        
        let conversationMessages = messages.map { msg in
            ConversationMessage(id: msg.id, role: msg.role, content: msg.content, timestamp: msg.timestamp)
        }
        
        if var existing = currentConversation {
            existing.messages = conversationMessages
            existing.updatedAt = Date()
            currentConversation = existing
            ConversationManager.shared.autoSaveConversation(existing)
        } else {
            let title = ConversationManager.shared.generateTitle(from: messages.first?.content ?? "")
            let newConversation = Conversation(
                title: title,
                type: .chat,
                messages: conversationMessages
            )
            currentConversation = newConversation
            ConversationManager.shared.autoSaveConversation(newConversation)
        }
    }
    
    
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
                    self.messages.append(Message(role: "user", content: text, timestamp: Date()))
                    self.saveCurrentConversation()
                    self.sendVoiceMessageToAI(text: text)
                }
                
                try? FileManager.default.removeItem(at: fileURL)
            }
        }.resume()
    }
    
    // sends voice transcript to openai for text chat response
    func sendVoiceMessageToAI(text: String) {
        isThinking = true
        showTypingIndicator = true
        
        let url = URL(string: OpenAIConfig.chatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
                    
                    let newMessage = Message(role: "assistant", content: content, timestamp: Date())
                    self.messages.append(newMessage)
                    self.saveCurrentConversation()
                    
                    self.speakText(content, messageId: newMessage.id)
                } else {
                    self.messages.append(Message(role: "assistant", content: "I couldn't process that. Can you try again?", timestamp: Date()))
                }
            }
        }.resume()
    }
    
    // converts ai response to speech using openai tts
    func speakText(_ text: String, messageId: UUID) {
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
        ttsAudioPlayerDelegate = nil
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
    
    // plays tts audio and auto-restarts listening when done
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


    func fetchChatResponse() {
        let url = URL(string: OpenAIConfig.chatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
          "questions": [string]         
        }

        Rules:
        - Keep it kid-friendly, concise, and actionable.
        - Do NOT include any non-JSON text.
        - If the user asks for direct answers, redirect with hints in JSON.
        - Always include exactly 3 thoughtful follow-up prompts in the `questions` array.
        - IMPORTANT: Phrase each item in `questions` as a first-person user intent, not as a question from the assistant. Examples:
          - "I need help with math"
          - "Give me a practice problem about fractions"
          - "Explain that again with a simpler example"
          - "Quiz me on the key ideas"
        - Avoid leading with phrases like "Do you want...", "Would you like...", or "Do you need..." in `questions`.
        - REMINDER: Students can ask you to create flashcards, study guides, or practice tests about what they're learning. Let them know they can do this if appropriate.
        """

        let apiMessages: [[String: Any]] =
            [["role": "system", "content": systemInstruction]] +
            messages.map { ["role": $0.role, "content": $0.content] }

        var body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": apiMessages,
            "temperature": 0.3
        ]


        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                print("Request error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.messages.append(Message(role: "assistant", content: "Hmm, I'm having trouble connecting. Please check your internet connection and try again.", timestamp: Date()))
                    self.showTypingIndicator = false
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.messages.append(Message(role: "assistant", content: "I didn't get a response. Please try again in a moment.", timestamp: Date()))
                    self.showTypingIndicator = false
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                var friendlyMessage = "Oops! Something went wrong. "
                
                if httpResponse.statusCode == 401 {
                    friendlyMessage += "There's an issue with the app's authentication. Please contact support."
                } else if httpResponse.statusCode == 429 {
                    friendlyMessage += "I'm getting too many requests right now. Please wait a moment and try again."
                } else if httpResponse.statusCode >= 500 {
                    friendlyMessage += "The service is having trouble right now. Please try again in a few minutes."
                } else {
                    friendlyMessage += "Please try again."
                }
                
                DispatchQueue.main.async {
                    self.messages.append(Message(role: "assistant", content: friendlyMessage, timestamp: Date()))
                    self.showTypingIndicator = false
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                if let content = decoded.choices.first?.message.content, !content.isEmpty {
                    DispatchQueue.main.async {
                        self.messages.append(Message(role: "assistant",
                                                     content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                                                     timestamp: Date()))
                        self.showTypingIndicator = false
                        self.saveCurrentConversation()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.messages.append(Message(role: "assistant", content: "I didn't understand that. Could you try asking in a different way?", timestamp: Date()))
                        self.showTypingIndicator = false
                    }
                }
            } catch {
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to read response"
                print("Decoding error: \(error)")
                print("Raw response: \(responseString)")
                DispatchQueue.main.async {
                    self.messages.append(Message(role: "assistant", content: "I'm having trouble understanding the response. Please try asking your question again.", timestamp: Date()))
                    self.showTypingIndicator = false
                }
            }
        }.resume()
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

