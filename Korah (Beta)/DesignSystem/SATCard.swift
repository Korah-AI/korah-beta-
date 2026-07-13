import SwiftUI

// MARK: - Shared SAT card styling
// The tinted dark card surface used across all SAT screens (Home, Profile,
// Practice, Question Bank): a subtly tinted fill over the dark background
// with a matching hairline border, plus a semi-transparent Korah logo
// watermark tucked into the corner for a bit of branded texture.
// Centralized here so every screen renders cards identically.

extension View {
    func satCard(tint: Color, cornerRadius: CGFloat = 22, logo: String = "newlogo3") -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.kSurface.opacity(0.55))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.18), tint.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Image(logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(-12))
                        .offset(x: 34, y: 26)
                        .opacity(0.18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            // Clip the content itself, not just the tinted background, so
            // any oversized child (a forced frame that's too small for its
            // text, a chart annotation, etc.) can't visually spill past the
            // rounded border.
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.30), lineWidth: 1)
            )
    }
}
