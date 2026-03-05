import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @Environment(AuthManager.self) private var authManager
    @FocusState private var focusedField: Field?
    @State private var appeared = false

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                LoginLogoSection()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(KAnimation.smooth, value: appeared)

                LoginFormSection(
                    email: $email,
                    password: $password,
                    focusedField: $focusedField
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .animation(KAnimation.smooth.delay(0.1), value: appeared)

                if let error = authManager.errorMessage {
                    AuthErrorBanner(message: error)
                        .transition(.opacity.combined(with: .offset(y: -8)))
                }

                Button(action: handleLogin) {
                    if authManager.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Sign In")
                    }
                }
                .buttonStyle(.kPrimary)
                .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                .opacity(appeared ? 1 : 0)
                .animation(KAnimation.smooth.delay(0.2), value: appeared)

                AuthOrDivider()
                    .opacity(appeared ? 1 : 0)
                    .animation(KAnimation.smooth.delay(0.25), value: appeared)

                Button(action: handleGoogleSignIn) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: ComponentSize.Icon.medium))
                        Text("Continue with Google")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.kGlass)
                .disabled(authManager.isLoading)
                .opacity(appeared ? 1 : 0)
                .animation(KAnimation.smooth.delay(0.3), value: appeared)

                LoginFooterLink()
                    .opacity(appeared ? 1 : 0)
                    .animation(KAnimation.smooth.delay(0.35), value: appeared)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.section)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { appeared = true }
    }

    private func handleLogin() {
        Haptics.light()
        Task {
            do {
                try await authManager.login(email: email, password: password)
            } catch {}
        }
    }

    private func handleGoogleSignIn() {
        Haptics.light()
        Task {
            do {
                try await authManager.initiateGoogleSignIn()
            } catch {}
        }
    }
}

// MARK: - Private Sub-Views

private struct LoginLogoSection: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Image("korahimg")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .kShadowGlow()

            VStack(spacing: Spacing.xs) {
                Text("Welcome Back")
                    .kTitleStyle()
                Text("Sign in to continue your studies")
                    .kSecondaryStyle()
            }
            .multilineTextAlignment(.center)
        }
    }
}

private struct LoginFormSection: View {
    @Binding var email: String
    @Binding var password: String
    var focusedField: FocusState<LoginView.Field?>.Binding

    /// Left-edge offset matching the icon column + gap so the divider
    /// aligns with the text content rather than the icon.
    private let dividerLeading: CGFloat =
        Spacing.md + ComponentSize.Icon.large + Spacing.sm

    var body: some View {
        VStack(spacing: 0) {
            AuthFieldRow(label: "Email", systemImage: "envelope") {
                TextField("name@example.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .focused(focusedField, equals: .email)
                    .autocorrectionDisabled()
            }

            Rectangle()
                .fill(Color.kSeparator)
                .frame(height: 0.5)
                .padding(.leading, dividerLeading)

            AuthFieldRow(label: "Password", systemImage: "lock") {
                SecureField("••••••••", text: $password)
                    .focused(focusedField, equals: .password)
            }
        }
        .kGlassEffect(cornerRadius: CornerRadius.card)
        .kShadowSubtle()
    }
}

private struct LoginFooterLink: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text("Don't have an account?")
                .kSecondaryStyle()

            NavigationLink("Sign up") {
                SignupView()
            }
            .buttonStyle(.kGhost)
        }
        .padding(.bottom, Spacing.md)
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environment(AuthManager.shared)
    }
}
