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
            
            // Main Bento Card
                    VStack(spacing: 12) {
                        // Top Icon (Korah Mascot)
                        AuthLogo(size: 150)

                        // Title
                        Text("Korah AI")
                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        HStack(spacing: 4) {
                            Text("The Most Goated SAT Prep.")
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

                            Button(action: handleAppleSignIn) {
                                HStack(spacing: 12) {
                                    Image(systemName: "apple.logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    Text("Sign in with Apple")
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
                        RoundedRectangle(cornerRadius: 56, style: .continuous)
                            .fill(Color.kSurface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 56, style: .continuous)
                                    .stroke(Color.kBorder, lineWidth: 1)
                            }
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 40)
        }
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

/// Two glowing pulses of light that chase around the button's border, each
/// constantly shifting color — rather than a solid rainbow ring. The base edge
/// stays faint; only the two travelling spots light up. Driven by
/// `TimelineView(.animation)` — derived purely from the clock — so it never
/// stalls, including the instant the button is tapped or becomes disabled. (The
/// old approach used a `withAnimation(.repeatForever)` started in `.onAppear`;
/// that animation gets cancelled by the state changes a tap triggers, which is
/// why the border froze the moment you clicked.)
struct BentoGlowingButtonStyle: ButtonStyle {
    private let corner: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    // Position around the perimeter (one lap every 3s) and the
                    // pulse color, which cycles through the spectrum over time.
                    let travel = (t / 3).truncatingRemainder(dividingBy: 1)
                    let hue = (t * 0.3).truncatingRemainder(dividingBy: 1)

                    ZStack {
                        // Faint always-on base edge.
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1.5)

                        // Two pulses, half a lap apart, in offset colors.
                        pulse(at: travel, hue: hue)
                        pulse(at: (travel + 0.5).truncatingRemainder(dividingBy: 1),
                              hue: (hue + 0.5).truncatingRemainder(dividingBy: 1))
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    /// A single short, rounded-cap arc of light gliding along the border, with a
    /// soft bloom behind a crisp core.
    private func pulse(at phase: Double, hue: Double) -> some View {
        let color = Color(hue: hue, saturation: 0.9, brightness: 1)
        return ZStack {
            BorderArc(start: phase, length: 0.16, cornerRadius: corner)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .blur(radius: 7)
            BorderArc(start: phase, length: 0.13, cornerRadius: corner)
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }
}

/// A short segment of a rounded-rectangle border, starting at `start` (a 0…1
/// fraction of the perimeter) and spanning `length`, wrapping around the seam.
private struct BorderArc: Shape {
    var start: Double
    var length: Double
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let base = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        let from = CGFloat(start)
        let to = CGFloat(start + length)
        if to <= 1 {
            return base.trimmedPath(from: from, to: to)
        }
        // Wraps past the end: draw the tail and the head as two pieces.
        var path = base.trimmedPath(from: from, to: 1)
        path.addPath(base.trimmedPath(from: 0, to: to - 1))
        return path
    }
}
