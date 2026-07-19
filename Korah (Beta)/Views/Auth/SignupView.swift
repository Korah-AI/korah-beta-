import SwiftUI

struct SignupView: View {
    @State private var firstName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var appeared = false

    enum Field { case firstName, email, password, confirmPassword }

    private var hasMinLength: Bool { password.count >= 8 }
    private var hasUppercase: Bool { password.contains(where: \.isUppercase) }
    private var hasLowercase: Bool { password.contains(where: \.isLowercase) }
    private var hasNumber: Bool { password.contains(where: \.isNumber) }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && password == confirmPassword }

    // Email validation only applies when the user has entered something.
    private var isEmailFormatValid: Bool {
        guard !email.isEmpty else { return true }
        let parts = email.split(separator: "@", maxSplits: 1)
        return parts.count == 2 && parts[1].contains(".")
    }

    private var isPasswordValid: Bool {
        hasMinLength && hasUppercase && hasLowercase && hasNumber && passwordsMatch
    }

    private var isFormValid: Bool {
        !firstName.isEmpty && !email.isEmpty && isEmailFormatValid && isPasswordValid
    }

    var body: some View {
        ZStack {
            // Background
            TwinklingStarsBackground(starCount: 100)
                .ignoresSafeArea()
            
            // Main Bento Card
                    VStack(spacing: 28) {
                        // Top Icon (Korah Mascot)
                        AuthLogo(size: 100)

                        // Title
                        VStack(spacing: 8) {
                            Text("Create Account")
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Join Korah and study smarter")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            BentoInputField(
                                text: $firstName,
                                placeholder: "Display Name",
                                isSecure: false,
                                focused: $focusedField,
                                field: .firstName
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                BentoInputField(
                                    text: $email,
                                    placeholder: "Email",
                                    isSecure: false,
                                    focused: $focusedField,
                                    field: .email
                                )
                                if !email.isEmpty {
                                    AuthValidationHint(message: "Valid email address", isValid: isEmailFormatValid)
                                        .padding(.horizontal, 4)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                BentoInputField(
                                    text: $password,
                                    placeholder: "Password",
                                    isSecure: true,
                                    focused: $focusedField,
                                    field: .password
                                )
                                if !password.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        AuthValidationHint(message: "At least 8 characters", isValid: hasMinLength)
                                        AuthValidationHint(message: "One uppercase letter", isValid: hasUppercase)
                                        AuthValidationHint(message: "One lowercase letter", isValid: hasLowercase)
                                        AuthValidationHint(message: "One number", isValid: hasNumber)
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                BentoInputField(
                                    text: $confirmPassword,
                                    placeholder: "Confirm Password",
                                    isSecure: true,
                                    focused: $focusedField,
                                    field: .confirmPassword
                                )
                                if !confirmPassword.isEmpty {
                                    AuthValidationHint(message: "Passwords match", isValid: passwordsMatch)
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: handleSignup) {
                                Group {
                                    if authManager.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Create Account")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color.black.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 30))
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .medium))
                            }
                            .buttonStyle(BentoGlowingButtonStyle())
                            .disabled(!isFormValid || authManager.isLoading)
                            
                            Button(action: handleGoogleSignIn) {
                                HStack(spacing: 12) {
                                    Image("Google-Logo-PNG-Image")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    Text("Sign up with Google")
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 30))
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .medium))
                            }
                            .disabled(authManager.isLoading)

                            Button(action: handleAppleSignIn) {
                                HStack(spacing: 12) {
                                    Image(systemName: "apple.logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    Text("Sign up with Apple")
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 30))
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .medium))
                            }
                            .disabled(authManager.isLoading)
                        }
                        
                        if let error = authManager.errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.kError)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Footer
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Button("Sign in") { dismiss() }
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 40)
                    .background {
                        RoundedRectangle(cornerRadius: 48, style: .continuous)
                            .fill(Color.kSurface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 48, style: .continuous)
                                    .stroke(Color.kBorder, lineWidth: 1)
                            }
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 40)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private func handleSignup() {
        Haptics.light()
        Task {
            do {
                try await authManager.signUp(
                    firstName: firstName,
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

    private func handleAppleSignIn() {
        Haptics.light()
        Task {
            do {
                try await authManager.initiateAppleSignIn()
            } catch {}
        }
    }
}

// MARK: - Bento Components

private struct BentoInputField: View {
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    var focused: FocusState<SignupView.Field?>.Binding
    let field: SignupView.Field
    var showHelpIcon: Bool = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                if isSecure {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.3)))
                } else {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.3)))
                        .textInputAutocapitalization(placeholder.contains("Name") ? .words : .never)
                        .keyboardType(placeholder.contains("Email") ? .emailAddress : .default)
                        .autocorrectionDisabled()
                }
            }
            .focused(focused, equals: field)
            .padding(.horizontal, 20)
            .frame(height: 60)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(.white)
            .font(.system(size: 16))
            
            if showHelpIcon {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.trailing, 14)
                    .font(.system(size: 16))
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignupView()
            .environment(AuthManager.shared)
    }
}
