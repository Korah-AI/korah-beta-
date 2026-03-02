import SwiftUI

/// Twinkling stars background effect matching the web theme
struct TwinklingStarsBackground: View {
    @State private var stars: [Star] = []
    private let starCount: Int
    
    init(starCount: Int = 100) {
        self.starCount = starCount
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
            }
            .onAppear {
                generateStars(in: geometry.size)
                startTwinkling()
            }
        }
    }
    
    private func generateStars(in size: CGSize) {
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
                    if Bool.random() {
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

// MARK: - View Extension

extension View {
    /// Apply twinkling stars background
    func withTwinklingStars(starCount: Int = 100) -> some View {
        self.background(
            TwinklingStarsBackground(starCount: starCount)
        )
    }
}
