import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @Environment(AuthManager.self) private var authManager
    @FocusState private var focusedField: Field?
    @State private var appeared = false
    @State private var rotation: Double = 0

    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Background
            TwinklingStarsBackground(starCount: 100)
                .ignoresSafeArea()
            
            ScrollView {
                VStack {
                    Spacer(minLength: 50)
                    
                    // Main Bento Card
                    VStack(spacing: 12) {
                        // Top Icon (Korah Mascot)
                        Image("korahimg")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .kShadowGlow()
                        
                        // Title
                        Text("Korah")
                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 4) {
                            Text("Study Smarter, Not Harder")
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.bottom, 10)
                        }
                        .font(.system(size: 18))
                        
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
                            .buttonStyle(BentoGlowingButtonStyle())
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

// MARK: - Animated Button Style

struct BentoGlowingButtonStyle: ButtonStyle {
    @State private var rotation: Double = 0
    @State private var dashPhase: CGFloat = 0
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                    ZStack {
                        // Rainbow rotating gradient stroke with dash
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        .red, .orange, .yellow, .green, .mint, .teal, .blue, .indigo, .purple, .pink, .red
                                    ],
                                    center: .center,
                                    angle: .degrees(rotation)
                                ),
                                style: StrokeStyle(
                                    lineWidth: 3,
                                    lineCap: .round,
                                    lineJoin: .round,
                                    dash: [40, 400],
                                    dashPhase: dashPhase
                                )
                            )
                            .blur(radius: 0.5)

                        // Subtle angular glow accent with reduced opacity
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                AngularGradient(
                                    colors: [.clear, .white.opacity(0.25), .clear],
                                    center: .center,
                                    angle: .degrees(rotation)
                                ),
                                lineWidth: 2
                            )
                            .blur(radius: 2)
                    }
                }
        
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeIn(duration: 0.1), value: configuration.isPressed)
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    dashPhase = -440 // moves the dash around the perimeter continuously
                }
            }
    }
}
