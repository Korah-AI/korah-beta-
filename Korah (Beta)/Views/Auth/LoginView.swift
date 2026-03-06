import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @Environment(AuthManager.self) private var authManager
    @FocusState private var focusedField: Field?
    @State private var appeared = false

    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Background
            TwinklingStarsBackground(starCount: 100)
                .ignoresSafeArea()
            
            ScrollView {
                VStack {
                    Spacer(minLength: 80)
                    
                    // Main Bento Card
                    VStack(spacing: 32) {
                        // Top Icon (Korah Mascot)
                        Image("korahimg")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .kShadowGlow()
                        
                        // Title
                        Text("Korah")
                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        // Form Fields
                        VStack(spacing: 20) {
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
                        }
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            Button(action: handleLogin) {
                                Group {
                                    if authManager.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Sign in")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color.black.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 30))
                                .foregroundStyle(.white)
                                .font(.system(size: 18, weight: .medium))
                            }
                            .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                            
                            Button(action: handleGoogleSignIn) {
                                HStack(spacing: 12) {
                                    Image("Google-Logo-PNG-Image")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    Text("Sign in with Google")
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
                            Text("Don't have an account?")
                                .foregroundStyle(.white.opacity(0.6))
                            
                            NavigationLink(destination: SignupView()) {
                                Text("Sign up, it's free!")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 48)
                    .background {
                        if #available(iOS 18.0, *) {
                            RoundedRectangle(cornerRadius: 56, style: .continuous)
                                .fill(.clear)
                                .glassEffect(
                                    .regular.tint(.white.opacity(0.05)),
                                    in: .rect(cornerRadius: 56)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 56, style: .continuous)
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 56, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                                .background(.ultraThinMaterial.opacity(0.4))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 56, style: .continuous)
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 40)
                    
                    Spacer(minLength: 80)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                appeared = true
            }
        }
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

// MARK: - Bento Components

private struct BentoInputField: View {
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    var focused: FocusState<LoginView.Field?>.Binding
    let field: LoginView.Field
    var showHelpIcon: Bool = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                if isSecure {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.3)))
                } else {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.3)))
                        .textInputAutocapitalization(.never)
                        .keyboardType(placeholder.contains("Email") ? .emailAddress : .default)
                        .autocorrectionDisabled()
                }
            }
            .focused(focused, equals: field)
            .padding(.horizontal, 24)
            .frame(height: 64)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .foregroundStyle(.white)
            .font(.system(size: 17))
            
            if showHelpIcon {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.trailing, 16)
                    .font(.system(size: 18))
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environment(AuthManager.shared)
    }
}
