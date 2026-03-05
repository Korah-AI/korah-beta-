import SwiftUI

struct SignupView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var appeared = false

    enum Field { case firstName, lastName, email, password, confirmPassword }

    private var isPasswordValid: Bool {
        password.count >= 8 && password == confirmPassword
    }

    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty
            && isPasswordValid && email.contains("@")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                SignupHeadingSection()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(KAnimation.smooth, value: appeared)

                SignupPersonalSection(
                    firstName: $firstName,
                    lastName: $lastName,
                    email: $email,
                    focusedField: $focusedField
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .animation(KAnimation.smooth.delay(0.1), value: appeared)

                SignupCredentialsSection(
                    password: $password,
                    confirmPassword: $confirmPassword,
                    focusedField: $focusedField
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .animation(KAnimation.smooth.delay(0.15), value: appeared)

                if let error = authManager.errorMessage {
                    AuthErrorBanner(message: error)
                        .transition(.opacity.combined(with: .offset(y: -8)))
                }

                Button(action: handleSignup) {
                    if authManager.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create Account")
                    }
                }
                .buttonStyle(.kPrimary)
                .disabled(!isFormValid || authManager.isLoading)
                .opacity(appeared ? 1 : 0)
                .animation(KAnimation.smooth.delay(0.2), value: appeared)

                AuthOrDivider()
                    .opacity(appeared ? 1 : 0)
                    .animation(KAnimation.smooth.delay(0.25), value: appeared)

                Button(action: handleGoogleSignIn) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: ComponentSize.Icon.medium))
                        Text("Sign up with Google")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.kGlass)
                .disabled(authManager.isLoading)
                .opacity(appeared ? 1 : 0)
                .animation(KAnimation.smooth.delay(0.3), value: appeared)

                SignupFooterLink(dismiss: dismiss)
                    .opacity(appeared ? 1 : 0)
                    .animation(KAnimation.smooth.delay(0.35), value: appeared)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appeared = true }
    }

    private func handleSignup() {
        Haptics.light()
        Task {
            do {
                try await authManager.signUp(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    password: password
                )
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

private struct SignupHeadingSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Create Account")
                .kTitleStyle()
            Text("Join Korah and start studying smarter")
                .kSecondaryStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SignupPersonalSection: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var email: String
    var focusedField: FocusState<SignupView.Field?>.Binding

    private let dividerLeading: CGFloat =
        Spacing.md + ComponentSize.Icon.large + Spacing.sm

    var body: some View {
        VStack(spacing: 0) {
            AuthFieldRow(label: "First Name", systemImage: "person") {
                TextField("John", text: $firstName)
                    .focused(focusedField, equals: .firstName)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
            }

            separator

            AuthFieldRow(label: "Last Name", systemImage: "person") {
                TextField("Doe", text: $lastName)
                    .focused(focusedField, equals: .lastName)
                    .textContentType(.familyName)
                    .autocorrectionDisabled()
            }

            separator

            AuthFieldRow(label: "Email", systemImage: "envelope") {
                TextField("name@example.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .focused(focusedField, equals: .email)
                    .autocorrectionDisabled()
            }
        }
        .kGlassEffect(cornerRadius: CornerRadius.card)
        .kShadowSubtle()
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.kSeparator)
            .frame(height: 0.5)
            .padding(.leading, dividerLeading)
    }
}

private struct SignupCredentialsSection: View {
    @Binding var password: String
    @Binding var confirmPassword: String
    var focusedField: FocusState<SignupView.Field?>.Binding

    private let dividerLeading: CGFloat =
        Spacing.md + ComponentSize.Icon.large + Spacing.sm

    var body: some View {
        VStack(spacing: 0) {
            AuthFieldRow(label: "Password", systemImage: "lock") {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    SecureField("••••••••", text: $password)
                        .focused(focusedField, equals: .password)

                    if !password.isEmpty {
                        AuthValidationHint(
                            message: password.count >= 8
                                ? "At least 8 characters"
                                : "At least 8 characters required",
                            isValid: password.count >= 8
                        )
                    }
                }
                .animation(KAnimation.quick, value: password.isEmpty)
            }

            Rectangle()
                .fill(Color.kSeparator)
                .frame(height: 0.5)
                .padding(.leading, dividerLeading)

            AuthFieldRow(label: "Confirm Password", systemImage: "lock.fill") {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    SecureField("••••••••", text: $confirmPassword)
                        .focused(focusedField, equals: .confirmPassword)

                    if !confirmPassword.isEmpty {
                        AuthValidationHint(
                            message: password == confirmPassword
                                ? "Passwords match"
                                : "Passwords do not match",
                            isValid: password == confirmPassword
                        )
                    }
                }
                .animation(KAnimation.quick, value: confirmPassword.isEmpty)
            }
        }
        .kGlassEffect(cornerRadius: CornerRadius.card)
        .kShadowSubtle()
    }
}

private struct SignupFooterLink: View {
    let dismiss: DismissAction

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text("Already have an account?")
                .kSecondaryStyle()

            Button("Sign in") { dismiss() }
                .buttonStyle(.kGhost)
        }
        .padding(.bottom, Spacing.md)
    }
}

#Preview {
    NavigationStack {
        SignupView()
            .environment(AuthManager.shared)
    }
}
