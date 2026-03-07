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
        ZStack {
            // Background
            TwinklingStarsBackground(starCount: 100)
                .ignoresSafeArea()
            
            ScrollView {
                VStack {
                    Spacer(minLength: 40)
                    
                    // Main Bento Card
                    VStack(spacing: 28) {
                        // Top Icon (Korah Mascot)
                        Image("korahimg")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .kShadowGlow()
                        
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
                            HStack(spacing: 12) {
                                BentoInputField(
                                    text: $firstName,
                                    placeholder: "First Name",
                                    isSecure: false,
                                    focused: $focusedField,
                                    field: .firstName
                                )
                                
                                BentoInputField(
                                    text: $lastName,
                                    placeholder: "Last Name",
                                    isSecure: false,
                                    focused: $focusedField,
                                    field: .lastName
                                )
                            }
                            
                            BentoInputField(
                                text: $email,
                                placeholder: "Email",
                                isSecure: false,
                                focused: $focusedField,
                                field: .email
                            )
                            
                            BentoInputField(
                                text: $password,
                                placeholder: "Password",
                                isSecure: true,
                                focused: $focusedField,
                                field: .password,
                                showHelpIcon: true
                            )
                            
                            BentoInputField(
                                text: $confirmPassword,
                                placeholder: "Confirm Password",
                                isSecure: true,
                                focused: $focusedField,
                                field: .confirmPassword
                            )
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
                        if #available(iOS 18.0, *) {
                            RoundedRectangle(cornerRadius: 48, style: .continuous)
                                .fill(.clear)
                                .glassEffect(
                                    .regular.tint(.white.opacity(0.05)),
                                    in: .rect(cornerRadius: 48)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 48, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                                .background(.ultraThinMaterial.opacity(0.4))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 40)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
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
