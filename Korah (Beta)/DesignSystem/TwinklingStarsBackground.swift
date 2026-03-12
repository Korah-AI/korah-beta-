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
                if stars.isEmpty {
                    generateStars(in: geometry.size)
                    startTwinkling()
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
