import SwiftUI

/// Modern, animated loading overlay with customizable messages and styles
struct ModernLoadingOverlay: View {
    let message: String
    let subtitle: String?
    let accentColor: Color
    
    @State private var isAnimating = false
    
    init(message: String, subtitle: String? = nil, accentColor: Color = .purple) {
        self.message = message
        self.subtitle = subtitle
        self.accentColor = accentColor
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .transition(.opacity)
            
            VStack(spacing: 24) {
                // Animated spinning rings
                ZStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.8), accentColor.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 60 - CGFloat(index * 15), height: 60 - CGFloat(index * 15))
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .animation(
                                Animation.linear(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.2),
                                value: isAnimating
                            )
                    }
                }
                .frame(width: 70, height: 70)
                .onAppear {
                    isAnimating = true
                }
                
                VStack(spacing: 12) {
                    Text(message)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(white: 0.15))
            )
            .padding(.horizontal, 40)
        }
    }
}

/// Compact loading indicator for inline use
struct CompactLoadingIndicator: View {
    let message: String
    let accentColor: Color
    
    init(message: String = "Loading...", accentColor: Color = .purple) {
        self.message = message
        self.accentColor = accentColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                .scaleEffect(0.9)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

/// Pulsing dots animation for subtle loading states
struct PulsingDotsLoader: View {
    @State private var animating = false
    let accentColor: Color
    
    init(accentColor: Color = .purple) {
        self.accentColor = accentColor
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

/// Success animation overlay
struct SuccessOverlay: View {
    let message: String
    let accentColor: Color
    @Binding var isPresented: Bool
    
    init(message: String, accentColor: Color = .green, isPresented: Binding<Bool>) {
        self.message = message
        self.accentColor = accentColor
        self._isPresented = isPresented
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(accentColor)
                }
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(white: 0.15))
                    .shadow(color: accentColor.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
            .transition(.scale.combined(with: .opacity))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isPresented = false
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        ModernLoadingOverlay(
            message: "Generating Study Guide",
            subtitle: "This may take a few moments",
            accentColor: .blue
        )
    }
    .korahGradientBackground()
}
