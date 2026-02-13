import SwiftUI

struct FloatingTimerIndicator: View {
    @State private var timerManager = FocusTimerManager.shared
    @State private var showTimer = false
    
    var body: some View {
        // Show when timer is active (running or paused), hide only when reset
        if timerManager.timeRemaining < timerManager.totalTime || timerManager.isTimerRunning {
            Button(action: {
                showTimer = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(timerManager.progress))
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: timerManager.isTimerRunning ? [Color.orange, Color.pink, Color.purple] : [Color.purple, Color.blue, Color.purple]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timerManager.timeRemaining)
                    
                    Image(systemName: timerManager.isTimerRunning ? "flame.fill" : "pause.fill")
                        .font(.system(size: 24))
                        .foregroundColor(timerManager.isTimerRunning ? .orange : .white)
                }
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .sheet(isPresented: $showTimer) {
                FocusTimerSheetView(isPresented: $showTimer)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
}

struct FocusTimerSheetView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            FocusTimerView(onDismiss: {
                isPresented = false
            })
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            HStack {
                FloatingTimerIndicator()
                    .padding()
                Spacer()
            }
        }
    }
}
