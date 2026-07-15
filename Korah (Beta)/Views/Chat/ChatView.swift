import SwiftUI

// MARK: - Chat View

/// Modern flagship chat view for Korah AI tutor
struct ChatView: View {
    /// Invoked by the header's back chevron — returns to the SAT home tab.
    var onBack: (() -> Void)? = nil

    @State private var viewModel = ChatViewModel()
    @State private var showImagePicker = false
    @State private var showImageSourceSheet = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showClearAlert = false
    @State private var showCameraMode = false
    @State private var cameraIsReady = false

    var body: some View {
        NavigationStack {
            ZStack {
                chatContent
                    .opacity(showCameraMode ? 0 : 1)

                if showCameraMode {
                    cameraMode
                        .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            // Custom Liquid Glass header with the Camera / Chat toggle
            header

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
                
                // Contextual suggestion chips (only during an active chat)
                if !viewModel.isEmpty && !viewModel.suggestions.isEmpty && !viewModel.isLoading {
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
            .kBackground(withStars: true)
            .overlay {
                if showClearAlert {
                    DeleteChatConfirmView(
                        onCancel: {
                            withAnimation(KAnimation.quick) { showClearAlert = false }
                        },
                        onDelete: {
                            viewModel.clearChat()
                            withAnimation(KAnimation.quick) { showClearAlert = false }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
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

    // MARK: - Camera Mode

    private var cameraMode: some View {
        ZStack(alignment: .top) {
            CustomCameraView(
                onPhotoCaptured: { image in
                    // Drop the capture into the composer so the user can add a
                    // question before sending — don't fire the message off yet.
                    viewModel.selectedImage = image
                    withAnimation(KAnimation.quick) { showCameraMode = false }
                },
                onDismiss: {
                    withAnimation(KAnimation.quick) { showCameraMode = false }
                },
                onCameraReady: { ready in
                    cameraIsReady = ready
                }
            )
            .ignoresSafeArea()

            header

            // Center crosshair once the preview is live
            if cameraIsReady {
                Image("crosshare")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Header

    /// Shared Liquid Glass header, used in both chat and camera modes. Carries
    /// the Camera / Chat toggle; new-chat and delete actions hide in camera mode.
    private var header: some View {
        ChatHeaderBar(
            onBack: onBack,
            showCameraMode: showCameraMode,
            onSelectCamera: {
                hideKeyboard()
                withAnimation(KAnimation.quick) { showCameraMode = true }
                Haptics.selection()
            },
            onSelectChat: {
                withAnimation(KAnimation.quick) { showCameraMode = false }
                Haptics.selection()
            },
            onNewChat: { viewModel.clearChat() },
            onDelete: { withAnimation(KAnimation.quick) { showClearAlert = true } },
            deleteDisabled: viewModel.isEmpty
        )
    }

    // MARK: - Empty State
    
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Spacer(minLength: 48)

                // Hero brand mark
                Image("newlogo12")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .shadow(color: SATAccent.violet.solid.opacity(0.35), radius: 18, y: 8)

                // Title
                VStack(spacing: Spacing.xs) {
                    Text("Ask Me Anything")
                        .font(.kTitle)
                        .foregroundStyle(Color.kTextPrimary)

                    Text("Any domain, strategy, problem, or equation. I got you.")
                        .font(.kSubheadline)
                        .foregroundStyle(Color.kTextSecondary)
                }
                .multilineTextAlignment(.center)

                // Category-colored starter cards
                VStack(spacing: Spacing.sm) {
                    ForEach(SATStarter.all) { starter in
                        SATStarterCard(starter: starter) {
                            viewModel.sendSuggestion(ChatSuggestion(starter.prompt))
                        }
                    }
                }
                .padding(.top, Spacing.xs)

                Spacer(minLength: Spacing.lg)
            }
            .padding(.horizontal, Spacing.lg)
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

// MARK: - Chat Header Bar

/// Floating Liquid Glass toolbar: back-to-home chevron, centered Camera / Chat
/// toggle, and new-chat / delete actions (the latter hidden in camera mode).
private struct ChatHeaderBar: View {
    var onBack: (() -> Void)?
    let showCameraMode: Bool
    let onSelectCamera: () -> Void
    let onSelectChat: () -> Void
    let onNewChat: () -> Void
    let onDelete: () -> Void
    let deleteDisabled: Bool

    var body: some View {
        ZStack {
            // Centered Camera / Chat switcher
            modeToggle

            // Side actions
            HStack(spacing: Spacing.xxs) {
                if let onBack {
                    iconButton("chevron.left", tint: Color.kTextPrimary, action: onBack)
                        .accessibilityLabel("Back to home")
                }

                Spacer()

                if !showCameraMode {
                    iconButton("square.and.pencil", tint: Color.kTextPrimary, action: onNewChat)
                        .accessibilityLabel("New chat")

                    iconButton(
                        "trash",
                        tint: deleteDisabled ? Color.kTextTertiary : SATAccent.red.solid,
                        action: onDelete
                    )
                    .disabled(deleteDisabled)
                    .accessibilityLabel("Delete chat")
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .satGlassBar()
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xxs)
    }

    private var modeToggle: some View {
        HStack(spacing: 2) {
            toggleChip(title: "Camera", icon: "camera.fill", active: showCameraMode, action: onSelectCamera)
            toggleChip(title: "Chat", icon: "message.fill", active: !showCameraMode, action: onSelectChat)
        }
        .padding(3)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(Color.kBorder, lineWidth: 1))
    }

    private func toggleChip(title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.kCaption.weight(.semibold))
            }
            .foregroundStyle(active ? .white : Color.kTextSecondary)
            .padding(.vertical, 6)
            .padding(.horizontal, Spacing.sm)
            .background(
                Capsule().fill(active ? AnyShapeStyle(SATAccent.violet.solid) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ name: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: name)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - SAT Starter Card

/// Welcome-screen prompt tile. Each carries its own category color — a solid
/// tinted icon chip and a matching border — echoing the web home page tiles.
private struct SATStarterCard: View {
    let starter: SATStarter
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: starter.icon)
                    .font(.kHeadline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous).fill(Color.white.opacity(0.2)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(starter.title)
                        .font(.kBodyBold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Text(starter.subtitle)
                        .font(.kCaption)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: Spacing.xs)

                Image(systemName: "chevron.right")
                    .font(.kCaption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(starter.accent.solid)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Delete Chat Confirmation

/// Custom "are you sure?" sheet styled like the web delete modal — a glass card
/// with a red destructive action, instead of the default system alert.
private struct DeleteChatConfirmView: View {
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: Spacing.md) {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundStyle(SATAccent.red.solid)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(SATAccent.red.tint))

                VStack(spacing: Spacing.xxs) {
                    Text("Delete this chat?")
                        .font(.kTitle3)
                        .foregroundStyle(Color.kTextPrimary)

                    Text("This will permanently clear every message in this conversation. This can't be undone.")
                        .font(.kSubheadline)
                        .foregroundStyle(Color.kTextSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: Spacing.sm) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.kBodyBold)
                            .foregroundStyle(Color.kTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous).fill(Color.kSurfaceElevated))
                            .overlay(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous).stroke(Color.kBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Text("Delete")
                            .font(.kBodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous).fill(SATAccent.red.solid))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, Spacing.xxs)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .fill(Color.kSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(SATAccent.red.border, lineWidth: 1)
            )
            .kShadowStrong()
            .padding(.horizontal, Spacing.xl)
        }
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
