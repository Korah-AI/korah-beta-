import SwiftUI

// MARK: - Message Bubble View

/// Modern message bubble with support for formatted responses
struct MessageBubbleView: View {
    let message: ChatMessage
    var onCopy: (() -> Void)?
    var onRetry: (() -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: Spacing.xs) {
                // Image attachment
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(.rect(cornerRadius: CornerRadius.md))
                }
                
                // Message content
                if message.isUser {
                    userBubble
                } else {
                    assistantBubble
                }
                
                // Action buttons for assistant messages
                if message.isAssistant && !message.isStreaming {
                    messageActions
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, Spacing.md)
    }
    
    // MARK: - User Bubble
    
    private var userBubble: some View {
        Text(message.content)
            .font(.kBody)
            .foregroundStyle(.white)
            .kLineSpacing()
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                BubbleShape(isUser: true)
                    .fill(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
            )
            .kShadowAccent()
    }
    
    // MARK: - Assistant Bubble
    
    @ViewBuilder
    private var assistantBubble: some View {
        if let formatted = message.content.decodeKorahResponse() {
            FormattedResponseView(response: formatted, isStreaming: message.isStreaming)
        } else {
            plainTextBubble
        }
    }
    
    private var plainTextBubble: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if message.isStreaming {
                HStack(spacing: Spacing.xs) {
                    Text(message.content)
                        .font(.kBody)
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                        .kLineSpacing()
                    
                    StreamingCursor()
                }
            } else {
                Text(message.content)
                    .font(.kBody)
                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    .kLineSpacing()
                    .textSelection(.enabled)
            }
        }
        .padding(Spacing.md)
        .background(
            BubbleShape(isUser: false)
                .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
        )
        .overlay(
            BubbleShape(isUser: false)
                .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
        )
        .kShadowSubtle()
    }
    
    // MARK: - Message Actions
    
    private var messageActions: some View {
        HStack(spacing: Spacing.md) {
            Button {
                onCopy?()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.kCaption)
                    .foregroundStyle(Color.adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary))
            }
            
            if case .error = message.state {
                Button {
                    onRetry?()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.kCaption)
                        .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                }
            }
        }
        .padding(.top, Spacing.xxs)
    }
}

// MARK: - Formatted Response View

struct FormattedResponseView: View {
    let response: KorahResponse
    let isStreaming: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack(spacing: Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                
                Text("Korah")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                
                if isStreaming {
                    StreamingCursor()
                }
            }
            
            // Title
            if let title = response.title, !title.isEmpty {
                Text(title)
                    .font(.kTitle3)
                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
            }
            
            // Summary
            if let summary = response.summary, !summary.isEmpty {
                Text(summary)
                    .font(.kBody)
                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    .kLineSpacing()
            }
            
            // Steps
            if let steps = response.steps, !steps.isEmpty {
                StepsView(steps: steps)
            }
            
            // Hints
            if let hints = response.hints, !hints.isEmpty {
                HintsView(hints: hints)
            }
            
            // Questions
            if let questions = response.questions, !questions.isEmpty {
                QuestionsView(questions: questions)
            }
            
            // Footer
            if let footer = response.footer, !footer.isEmpty {
                Divider()
                    .background(Color.adaptive(light: .Light.separator, dark: .Dark.separator))
                
                Text(footer)
                    .font(.kCaption)
                    .foregroundStyle(Color.adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.bubble, style: .continuous)
                .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.bubble, style: .continuous)
                .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
        )
        .kShadowSubtle()
    }
}

// MARK: - Steps View

private struct StepsView: View {
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(steps.enumerated(), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    // Step number badge
                    Text("\(index + 1)")
                        .font(.kCaption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.adaptive(light: .Light.accent, dark: .Dark.accent).opacity(0.8))
                        )
                    
                    Text(step)
                        .font(.kBody)
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                        .kLineSpacing()
                }
            }
        }
    }
}

// MARK: - Hints View

private struct HintsView: View {
    let hints: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("💡 Hints")
                .font(.kSubheadline)
                .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
            
            ForEach(hints, id: \.self) { hint in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Image(systemName: "lightbulb.fill")
                        .font(.kCaption)
                        .foregroundStyle(Color.adaptive(light: .Light.warning, dark: .Dark.warning))
                    
                    Text(hint)
                        .font(.kBody)
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                }
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                .fill(Color.adaptive(light: .Light.warning.opacity(0.1), dark: .Dark.warning.opacity(0.1)))
        )
    }
}

// MARK: - Questions View

private struct QuestionsView: View {
    let questions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("🤔 Try these")
                .font(.kSubheadline)
                .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
            
            ForEach(questions, id: \.self) { question in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Image(systemName: "questionmark.circle")
                        .font(.kCaption)
                        .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                    
                    Text(question)
                        .font(.kBody)
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                }
            }
        }
    }
}

// MARK: - Streaming Cursor

struct StreamingCursor: View {
    @State private var isVisible = true
    
    var body: some View {
        Rectangle()
            .fill(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
            .frame(width: 2, height: 16)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = CornerRadius.bubble
        let tailSize: CGFloat = 6
        
        var path = Path()
        
        if isUser {
            // User bubble (tail on right)
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                             control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - tailSize))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY - tailSize),
                             control: CGPoint(x: rect.maxX, y: rect.maxY - tailSize))
            path.addLine(to: CGPoint(x: rect.maxX - radius + tailSize, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY - tailSize))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - tailSize - radius),
                             control: CGPoint(x: rect.minX, y: rect.maxY - tailSize))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                             control: CGPoint(x: rect.minX, y: rect.minY))
        } else {
            // Simple rounded rect for assistant
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
        }
        
        return path
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            MessageBubbleView(
                message: ChatMessage(
                    role: .user,
                    content: "How do I solve quadratic equations?"
                )
            )
            
            MessageBubbleView(
                message: ChatMessage(
                    role: .assistant,
                    content: """
                    {"kind":"tutor","title":"Solving Quadratic Equations","summary":"Let me guide you through the process!","steps":["Identify the coefficients a, b, and c","Use the quadratic formula","Simplify your answer"],"hints":["Remember: a is never zero","Check your work by substituting back"],"questions":["What are your coefficients?"]}
                    """
                )
            )
        }
        .padding()
    }
    .kBackground()
}
