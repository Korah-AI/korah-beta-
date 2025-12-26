import SwiftUI

struct CongratulationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var animateConfetti = false
    @State private var showContent = false
    
    let title: String
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            ConfettiView(animate: $animateConfetti)
            
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(showContent ? 1 : 0.3)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showContent)
                
                Text(title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: showContent)
                
                Text(message)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showContent)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .black],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: showContent)
            }
        }
        .onAppear {
            BLEManager.shared.sendCommand("CELEBRATE")
            
            withAnimation {
                showContent = true
                animateConfetti = true
            }
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

struct ConfettiView: View {
    @Binding var animate: Bool
    
    var body: some View {
        ZStack {
            ForEach(0..<50) { index in
                ConfettiPiece(animate: animate, delay: Double(index) * 0.02)
            }
        }
    }
}

struct ConfettiPiece: View {
    let animate: Bool
    let delay: Double
    
    @State private var yOffset: CGFloat = -100
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]
    private let randomColor: Color
    private let randomX: CGFloat
    private let randomRotation: Double
    
    init(animate: Bool, delay: Double) {
        self.animate = animate
        self.delay = delay
        self.randomColor = colors.randomElement() ?? .purple
        self.randomX = CGFloat.random(in: -150...150)
        self.randomRotation = Double.random(in: 0...720)
    }
    
    var body: some View {
        Rectangle()
            .fill(randomColor)
            .frame(width: 8, height: 15)
            .cornerRadius(2)
            .offset(x: xOffset, y: yOffset)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                if animate {
                    withAnimation(
                        .easeIn(duration: 1.5)
                        .delay(delay)
                    ) {
                        yOffset = UIScreen.main.bounds.height + 100
                        xOffset = randomX
                        rotation = randomRotation
                        opacity = 0
                    }
                }
            }
    }
}

#Preview {
    CongratulationsView(
        title: "Amazing Work!",
        message: "You've completed your focus session. Time for a break!"
    )
}
