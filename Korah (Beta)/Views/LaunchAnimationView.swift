import SwiftUI

// MARK: - Launch sequence
// Covers the app from its first frame until the content beneath is ready.
// There is intentionally NO spinner anywhere in this flow — while Firebase
// checks auth the user only ever sees the app icon. Phases:
//   1. icon   — app icon alone, centered (the "loading" state).
//   2. lockup — the icon slides left while "Korah AI" slides/fades in
//               where the icon was.
//   3. zoom   — the lockup flies toward the viewer and fades out,
//               revealing the app underneath.

struct LaunchAnimationView: View {
    /// Whether the content beneath the overlay is ready (auth check done).
    /// The final zoom waits for both the intro animation and this flag.
    let isReady: Bool
    let onComplete: () -> Void

    @State private var slid = false
    @State private var introDone = false
    @State private var zooming = false
    /// Mirrors `isReady` into @State: the long-running .task captures the
    /// view value from launch (when isReady was false), so it must read
    /// readiness through state storage, which is always current.
    @State private var ready = false

    // Lockup geometry: 88pt icon + gap + "Korah AI" at 44pt bold ≈ 300pt
    // wide, so the icon rests at -108 and the text centers at +56.
    private let iconSlide: CGFloat = -108
    private let textCenter: CGFloat = 56

    var body: some View {
        ZStack {
            TwinklingStarsBackground(starCount: 80, shootingStars: false)
                .ignoresSafeArea()
                .scaleEffect(zooming ? 1.35 : 1)

            ZStack {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .kShadowGlow()
                    .offset(x: slid ? iconSlide : 0)

                Text("Korah AI")
                    .foregroundStyle(Color.kTextPrimary)
                    .font(.jakarta(44).weight(.bold))
                    .fixedSize()
                    .offset(x: slid ? textCenter : textCenter - 40)
                    .opacity(slid ? 1 : 0)
            }
            .scaleEffect(zooming ? 12 : 1)
        }
        .opacity(zooming ? 0 : 1)
        .task {
            if isReady { ready = true }
            // Let the bare icon breathe for a beat before the reveal.
            try? await Task.sleep(nanoseconds: 550_000_000)
            withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                slid = true
            }
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            introDone = true
            maybeFinish()
        }
        .onChange(of: isReady) { _, newValue in
            if newValue {
                ready = true
                maybeFinish()
            }
        }
    }

    /// Fires the zoom-out once the intro has played AND the app is ready.
    private func maybeFinish() {
        guard introDone, ready, !zooming else { return }
        withAnimation(.easeIn(duration: 0.45)) {
            zooming = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
}

#Preview {
    LaunchAnimationView(isReady: true, onComplete: {})
}
