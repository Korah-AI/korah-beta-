import SwiftUI

/// Twinkling stars background effect matching the web theme, with occasional
/// shooting stars streaking across (mirrors korah.js `spawnShootingStar`).
struct TwinklingStarsBackground: View {
    @State private var stars: [Star] = []
    @State private var shootingStars: [ShootingStar] = []
    @State private var didStartShooting = false
    private let starCount: Int
    private let shootingStarsEnabled: Bool

    init(starCount: Int = 100, shootingStars: Bool = true) {
        self.starCount = starCount
        self.shootingStarsEnabled = shootingStars
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep purple gradient background
                LinearGradient(
                    colors: [
                        Color.adaptive(light: .Light.background, dark: .Dark.background),
                        Color.adaptive(light: .Light.backgroundSecondary, dark: .Dark.backgroundSecondary)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Twinkling stars
                ForEach(stars) { star in
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size, height: star.size)
                        .opacity(star.opacity)
                        .position(x: star.x, y: star.y)
                        .blur(radius: star.blur)
                }

                // Shooting stars
                ForEach(shootingStars) { shooter in
                    ShootingStarView(star: shooter) {
                        shootingStars.removeAll { $0.id == shooter.id }
                    }
                }
            }
            .onAppear {
                if stars.isEmpty {
                    generateStars(in: geometry.size)
                    startTwinkling()
                }
                if shootingStarsEnabled && !didStartShooting {
                    didStartShooting = true
                    startShootingStars(in: geometry.size)
                }
            }
            // Ensure stars re-position if the screen rotates or size changes
            .onChange(of: geometry.size) { _, newSize in
                if newSize != .zero {
                    generateStars(in: newSize)
                }
            }
        }
    }

    // MARK: - Shooting stars

    private func startShootingStars(in size: CGSize) {
        // Stagger a few initial streaks, then keep spawning at random intervals.
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 3 + Double.random(in: 0...2)) {
                spawnShootingStar(in: size)
            }
        }
    }

    private func spawnShootingStar(in size: CGSize) {
        guard size.width > 0 else { return }
        let star = ShootingStar(
            start: CGPoint(
                x: CGFloat.random(in: size.width * 0.05...size.width * 0.55),
                y: CGFloat.random(in: size.height * 0.05...size.height * 0.6)
            ),
            angle: Double.random(in: 25...45),
            length: CGFloat.random(in: 120...220),
            travel: size.width * CGFloat.random(in: 0.7...1.1),
            duration: Double.random(in: 1.5...3.0)
        )
        shootingStars.append(star)
        // Schedule the next spawn after this one clears.
        DispatchQueue.main.asyncAfter(deadline: .now() + star.duration + Double.random(in: 6...16)) {
            spawnShootingStar(in: size)
        }
    }
    
    private func generateStars(in size: CGSize) {
        // If size is zero, we can't generate stars properly yet
        guard size.width > 0 && size.height > 0 else { return }
        
        stars = (0..<starCount).map { _ in
            Star(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...1.0),
                blur: CGFloat.random(in: 0...1.5)
            )
        }
    }
    
    private func startTwinkling() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: Double.random(in: 1...3))) {
                for index in stars.indices {
                    // Only update a small subset of stars for a more natural effect
                    if Int.random(in: 0...10) == 0 {
                        stars[index].opacity = Double.random(in: 0.3...1.0)
                    }
                }
            }
        }
    }
}

/// Individual star model
private struct Star: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var blur: CGFloat
}

// MARK: - Shooting Star

/// A single streak that flies across the field, then removes itself.
struct ShootingStar: Identifiable {
    let id = UUID()
    let start: CGPoint
    let angle: Double      // degrees, measured downward from horizontal
    let length: CGFloat
    let travel: CGFloat    // distance travelled along the angle
    let duration: Double
}

private struct ShootingStarView: View {
    let star: ShootingStar
    let onFinish: () -> Void

    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        let radians = star.angle * .pi / 180
        let dx = cos(radians) * star.travel
        let dy = sin(radians) * star.travel

        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color(red: 0.655, green: 0.545, blue: 0.980).opacity(0.8), // #a78bfa
                        Color.white
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: star.length, height: 2)
            .shadow(color: Color(red: 0.655, green: 0.545, blue: 0.980).opacity(0.6), radius: 4)
            .rotationEffect(.radians(radians), anchor: .center)
            .position(
                x: star.start.x + dx * progress,
                y: star.start.y + dy * progress
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: star.duration)) { progress = 1 }
                // Fade in quickly, then fade out over the tail of the flight.
                withAnimation(.easeIn(duration: star.duration * 0.25)) { opacity = 1 }
                withAnimation(.easeOut(duration: star.duration * 0.45).delay(star.duration * 0.55)) { opacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + star.duration) { onFinish() }
            }
    }
}
