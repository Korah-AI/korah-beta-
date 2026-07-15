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
                
                // Message content — skip the text bubble entirely for an
                // image-only user message so no empty bubble shows.
                if message.isUser {
                    if !message.content.isEmpty {
                        userBubble
                    }
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
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.kAccent)
            )
            .kShadowAccent()
    }
    
    // MARK: - Assistant Bubble
    //
    // Plain Markdown + KaTeX (matching the web app), rendered inside a glass
    // card headed by the Korah brand mark and a violet "SAT Tutor" tag.

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            assistantHeader

            if message.content.isEmpty && message.isStreaming {
                HStack(spacing: Spacing.xs) {
                    Text("Thinking")
                        .font(.kSubheadline)
                        .foregroundStyle(Color.kTextSecondary)
                    StreamingCursor()
                }
            } else {
                HStack(alignment: .bottom, spacing: Spacing.xxs) {
                    LatexMarkdownView(content: message.content, isStreaming: message.isStreaming)
                    if message.isStreaming { StreamingCursor() }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            BubbleShape(isUser: false)
                .fill(Color.kSurface)
        )
        .overlay(
            BubbleShape(isUser: false)
                .stroke(SATAccent.violet.border, lineWidth: 1)
        )
        .kShadowSubtle()
    }

    private var assistantHeader: some View {
        HStack(spacing: Spacing.xs) {
            Image("newlogo2")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)

            Text("Korah")
                .font(.kSubheadline.weight(.semibold))
                .foregroundStyle(Color.kTextPrimary)
        }
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
                    Use the quadratic formula:

                    $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$

                    **Faster on the SAT:** graph it in Desmos and read the $x$-intercepts directly.
                    """
                )
            )
        }
        .padding()
    }
    .kBackground()
}
