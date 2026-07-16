import SwiftUI

// MARK: - Shared SAT card styling
// The tinted dark card surface used across all SAT screens (Home, Profile,
// Practice, Question Bank): a subtly tinted fill over the dark background
// with a matching hairline border, plus a semi-transparent Korah logo
// watermark tucked into the corner for a bit of branded texture.
// Centralized here so every screen renders cards identically.

extension View {
    func satCard(tint: Color, cornerRadius: CGFloat = 22, logo: String = "newlogo3", solid: Bool = false) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.kSurface.opacity(solid ? 1 : 0.55))
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

    /// The standard SAT dashboard card, matching the Practice screen's section
    /// cards: a flat dark surface with a hairline border and no gradient. Colour
    /// is reserved for small accents (eyebrow labels, icons, progress bars) so
    /// the body text can stay simple white/grey — no bright fills, no glow.
    func satDarkCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.kSurface)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.kBorder.opacity(0.6), lineWidth: 1)
            )
    }
}

// MARK: - Gradient section card

/// A Practice-style dashboard card: a coloured gradient header (title, optional
/// subtitle, and an icon in a rounded square) sitting on top of a dark
/// `kSurface` body that holds the card's content — finished with a hairline
/// border. Mirrors the "Reading & Writing" / "Math" section cards on the
/// Practice screen so every dashboard reads the same. Colour lives in the
/// header; body text stays simple white/grey.
struct SATGradientCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    let tint: Color
    var cornerRadius: CGFloat = 22
    /// Shrinks the header title/icon for tightly-packed grid tiles (e.g. the
    /// "My Stats" bento grid), where the default `kTitle3` header wraps or
    /// crowds a short, narrow card.
    var compact: Bool = false
    let content: Content

    init(title: String, subtitle: String? = nil, systemImage: String,
         tint: Color, cornerRadius: CGFloat = 22, compact: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Gradient header
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(compact ? .kFootnote.weight(.bold) : .kTitle3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(compact ? 1 : nil)
                        .minimumScaleFactor(compact ? 0.85 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.kCaption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: systemImage)
                    .font(compact ? .caption.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: compact ? 26 : 36, height: compact ? 26 : 36)
                    .background(
                        RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
                            .fill(Color.white.opacity(0.2))
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(compact ? Spacing.sm : Spacing.md)
            .background(
                LinearGradient(colors: [tint, tint.lightened(by: 0.18)],
                               startPoint: .leading, endPoint: .trailing)
            )

            // Body — a lightened surface with a wash of the header tint so it
            // stays clearly visible against the dark app background and reads as
            // one piece with the coloured header. Never a near-black fill.
            VStack(alignment: .leading, spacing: Spacing.sm) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(compact ? Spacing.sm : Spacing.md)
            .background(
                ZStack {
                    Color.kSurfaceElevated
                    tint.opacity(0.14)
                }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }
}

/// The filled call-to-action button that sits at the bottom of a
/// `SATGradientCard`, tinted to match the card's header and navigating to the
/// relevant page.
struct SATCardButton: View {
    let title: String
    var systemImage: String = "arrow.right"
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: systemImage)
                    .font(.footnote.weight(.bold))
            }
            .font(.kSubheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}

// MARK: - Colour helpers

extension Color {
    /// Returns a lighter, slightly desaturated variant of the colour, used to
    /// build the two-tone solid gradient on the bright dashboard cards.
    func lightened(by amount: CGFloat) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return Color(
            hue: Double(h),
            saturation: Double(max(0, s - amount * 0.35)),
            brightness: Double(min(1, b + amount)),
            opacity: Double(a)
        )
    }
}
