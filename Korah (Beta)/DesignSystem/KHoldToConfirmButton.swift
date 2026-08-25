import SwiftUI

/// A destructive confirm button that only fires after the user holds it for
/// a full five seconds. The fill sweeps across as they hold, ticks a haptic
/// every second, and snaps back the instant they let go, so something as
/// final as deleting an account can never happen on a stray tap.
struct KHoldToConfirmButton: View {
    let title: String
    var tint: Color = .kError
    var duration: Double = 5
    let onComplete: () -> Void

    @State private var progress: Double = 0
    @State private var isHolding = false
    @State private var lastTickedSecond = 0
    @State private var didComplete = false

    private let ticker = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous)
    }

    private var secondsLeft: Int {
        max(1, Int((duration * (1 - progress)).rounded(.up)))
    }

    private var label: String {
        isHolding ? "Keep holding, \(secondsLeft)" : title
    }

    var body: some View {
        ZStack {
            shape.fill(Color.kSurface)

            GeometryReader { geo in
                shape
                    .fill(tint)
                    .frame(width: geo.size.width * progress)
            }

            HStack(spacing: 8) {
                Image(systemName: isHolding ? "hand.tap.fill" : "trash.fill")
                Text(label)
                    .contentTransition(.numericText())
            }
            .font(.kSubheadline.weight(.bold))
            .foregroundStyle(.white)
        }
        .frame(height: ComponentSize.Button.large)
        .clipShape(shape)
        .overlay(shape.stroke(tint.opacity(0.55), lineWidth: 1))
        .scaleEffect(isHolding ? 0.98 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHolding)
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginHold() }
                .onEnded { _ in cancelHold() }
        )
        .onReceive(ticker) { _ in advance() }
        .accessibilityLabel(title)
        .accessibilityHint("Hold for \(Int(duration)) seconds to confirm")
    }

    private func beginHold() {
        guard !isHolding, !didComplete else { return }
        isHolding = true
        lastTickedSecond = 0
        Haptics.medium()
    }

    private func cancelHold() {
        guard !didComplete else { return }
        isHolding = false
        withAnimation(KAnimation.standard) { progress = 0 }
    }

    /// Drives the fill in real time, so `.linear` framing is intentional here:
    /// the bar is representing the seconds themselves.
    private func advance() {
        guard isHolding, !didComplete else { return }

        progress = min(1, progress + 0.02 / duration)

        let elapsedSecond = Int(progress * duration)
        if elapsedSecond != lastTickedSecond {
            lastTickedSecond = elapsedSecond
            Haptics.light()
        }

        if progress >= 1 {
            didComplete = true
            isHolding = false
            Haptics.success()
            onComplete()
        }
    }
}
