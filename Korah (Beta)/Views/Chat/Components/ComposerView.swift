import SwiftUI

// MARK: - Composer View

/// Modern message composer with attachment support
struct ComposerView: View {
    @Binding var text: String
    @Binding var selectedImage: UIImage?
    var isLoading: Bool = false
    var onSend: () -> Void
    var onAttachment: () -> Void
    var onStopStreaming: (() -> Void)?
    var isStreaming: Bool = false
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            // Image preview
            if let image = selectedImage {
                imagePreview(image)
            }
            
            // Composer bar
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                // Attachment button
                attachmentButton
                
                // Text field
                textField
                
                // Send/Stop button
                actionButton
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .satGlassBar(cornerRadius: CornerRadius.xxl)
            .kShadowMedium()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }
    
    // MARK: - Image Preview
    
    private func imagePreview(_ image: UIImage) -> some View {
        HStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .clipShape(.rect(cornerRadius: CornerRadius.sm))
            
            Spacer()
            
            Button {
                withAnimation(KAnimation.quick) {
                    selectedImage = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary))
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
        )
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Attachment Button
    
    private var attachmentButton: some View {
        Button(action: onAttachment) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .contentShape(Circle())
        }
        .disabled(isLoading || isStreaming)
        .opacity(isLoading || isStreaming ? 0.5 : 1)
        .accessibilityLabel("Attach image")
    }
    
    // MARK: - Text Field
    
    private var textField: some View {
        TextField("Ask an SAT question…", text: $text, axis: .vertical)
            .font(.kBody)
            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
            .lineLimit(1...6)
            .focused($isFocused)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .disabled(isStreaming)
            .accessibilityLabel("Message input")
    }
    
    // MARK: - Action Button
    
    @ViewBuilder
    private var actionButton: some View {
        if isStreaming {
            stopButton
        } else {
            sendButton
        }
    }
    
    private var sendButton: some View {
        Button(action: {
            Haptics.light()
            onSend()
        }) {
            Image(systemName: "arrow.up")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .background(
                    Circle()
                        .fill(canSend ? Color.adaptive(light: .Light.accent, dark: .Dark.accent) : Color.adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary).opacity(0.5))
                )
                .kShadowAccent()
        }
        .disabled(!canSend || isLoading)
        .scaleEffect(canSend ? 1 : 0.9)
        .animation(KAnimation.quick, value: canSend)
        .accessibilityLabel("Send message")
    }
    
    private var stopButton: some View {
        Button {
            Haptics.medium()
            onStopStreaming?()
        } label: {
            Image(systemName: "stop.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .background(
                    Circle()
                        .fill(Color.adaptive(light: .Light.error, dark: .Dark.error))
                )
        }
        .accessibilityLabel("Stop generating")
    }
    
    // MARK: - Computed
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil
    }
}

// MARK: - Typing Indicator View

/// Polished typing/streaming indicator
struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Korah icon
            Image(systemName: "sparkles")
                .font(.kSubheadline)
                .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
            
            Text("Korah is thinking")
                .font(.kSubheadline)
                .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
            
            // Animated dots
            HStack(spacing: Spacing.xxs) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                        .frame(width: 6, height: 6)
                        .scaleEffect(animationPhase == index ? 1.3 : 0.8)
                        .opacity(animationPhase == index ? 1 : 0.4)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
        )
        .overlay(
            Capsule()
                .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
        )
        .kShadowSubtle()
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(KAnimation.quick) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Suggestion Chips View

/// Horizontal scrolling suggestion chips
struct SuggestionChipsView: View {
    let suggestions: [ChatSuggestion]
    let onSelect: (ChatSuggestion) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    SuggestionChip(
                        suggestion: suggestion,
                        accent: SATAccent.palette[index % SATAccent.palette.count]
                    ) {
                        onSelect(suggestion)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }
}

// MARK: - Suggestion Chip

private struct SuggestionChip: View {
    let suggestion: ChatSuggestion
    let accent: SATAccent
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            HStack(spacing: Spacing.xxs) {
                if let icon = suggestion.icon {
                    Image(systemName: icon)
                        .font(.kCaption)
                        .foregroundStyle(accent.solid)
                }

                Text(suggestion.text)
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextPrimary)
                    .lineLimit(2)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(accent.tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(accent.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        
        TypingIndicatorView()
        
        SuggestionChipsView(
            suggestions: ChatSuggestion.starters,
            onSelect: { _ in }
        )
        
        ComposerView(
            text: .constant(""),
            selectedImage: .constant(nil),
            onSend: {},
            onAttachment: {}
        )
    }
    .kBackground()
}
