import SwiftUI

// MARK: - Chat View

/// Modern flagship chat view for Korah AI tutor
struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var showImagePicker = false
    @State private var showImageSourceSheet = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showClearAlert = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list or empty state
                if viewModel.isEmpty {
                    emptyState
                } else {
                    messagesList
                }
                
                // Typing indicator
                if viewModel.isLoading && !viewModel.isStreaming {
                    TypingIndicatorView()
                        .padding(.bottom, Spacing.sm)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Suggestion chips
                if !viewModel.suggestions.isEmpty && !viewModel.isLoading {
                    SuggestionChipsView(suggestions: viewModel.suggestions) { suggestion in
                        viewModel.sendSuggestion(suggestion)
                    }
                    .padding(.vertical, Spacing.xs)
                }
                
                // Composer
                ComposerView(
                    text: $viewModel.inputText,
                    selectedImage: $viewModel.selectedImage,
                    isLoading: viewModel.isLoading,
                    onSend: { viewModel.sendMessage() },
                    onAttachment: { showImageSourceSheet = true },
                    onStopStreaming: { viewModel.stopStreaming() },
                    isStreaming: viewModel.isStreaming
                )
            }
            .kBackground()
            .navigationTitle("Korah")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.clearChat()
                        } label: {
                            Label("New Chat", systemImage: "square.and.pencil")
                        }
                        
                        Button(role: .destructive) {
                            showClearAlert = true
                        } label: {
                            Label("Clear Chat", systemImage: "trash")
                        }
                        .disabled(viewModel.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.headline)
                            .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    }
                }
            }
            .alert("Clear Chat?", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    viewModel.clearChat()
                }
            } message: {
                Text("This will delete all messages in this conversation.")
            }
            .confirmationDialog("Add Image", isPresented: $showImageSourceSheet) {
                Button("Take Photo") {
                    imageSource = .camera
                    showImagePicker = true
                }
                Button("Choose from Library") {
                    imageSource = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(
                    selectedImage: $viewModel.selectedImage,
                    sourceType: imageSource
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Spacer(minLength: 80)
                
                // Hero icon
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                    .symbolEffect(.pulse)
                
                // Title
                VStack(spacing: Spacing.sm) {
                    Text("Hi! I'm Korah")
                        .font(.kTitle)
                        .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    
                    Text("Your friendly AI study buddy")
                        .font(.kBody)
                        .foregroundStyle(Color.adaptive(light: .Light.textSecondary, dark: .Dark.textSecondary))
                }
                .multilineTextAlignment(.center)
                
                // Starter suggestions
                VStack(spacing: Spacing.sm) {
                    Text("Try asking me...")
                        .font(.kSubheadline)
                        .foregroundStyle(Color.adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary))
                    
                    VStack(spacing: Spacing.xs) {
                        ForEach(ChatSuggestion.starters) { suggestion in
                            StarterSuggestionButton(suggestion: suggestion) {
                                viewModel.sendSuggestion(suggestion)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Messages List
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            onCopy: { viewModel.copyMessage(message) },
                            onRetry: { viewModel.retryLastMessage() }
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.lastMessageID) { _, newID in
                if let id = newID, viewModel.isAtBottom {
                    withAnimation(KAnimation.smooth) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Starter Suggestion Button

private struct StarterSuggestionButton: View {
    let suggestion: ChatSuggestion
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            HStack(spacing: Spacing.sm) {
                if let icon = suggestion.icon {
                    Image(systemName: icon)
                        .font(.kBody)
                        .foregroundStyle(Color.adaptive(light: .Light.accent, dark: .Dark.accent))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.adaptive(light: .Light.accent.opacity(0.1), dark: .Dark.accent.opacity(0.15)))
                        )
                }
                
                Text(suggestion.text)
                    .font(.kBody)
                    .foregroundStyle(Color.adaptive(light: .Light.textPrimary, dark: .Dark.textPrimary))
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.kCaption)
                    .foregroundStyle(Color.adaptive(light: .Light.textTertiary, dark: .Dark.textTertiary))
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(Color.adaptive(light: .Light.surface, dark: .Dark.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .stroke(Color.adaptive(light: .Light.border, dark: .Dark.border), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Image Picker View

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    @Environment(\.dismiss) private var dismiss
    
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
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
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

// MARK: - Preview

#Preview {
    ChatView()
}

#Preview("With Messages") {
    ChatView()
}
