import SwiftUI

// MARK: - Skeleton loading placeholders
// Shimmering placeholder shapes that mirror the target layout, used instead
// of a bare spinner so loading states feel instant rather than blocking.

struct SkeletonBox: View {
    var cornerRadius: CGFloat = CornerRadius.xs
    var height: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.kTextTertiary.opacity(0.15))
            .frame(height: height)
            .modifier(ShimmerEffect())
    }
}

private struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.8)
                }
                .clipped()
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - SAT question page skeleton

/// Mirrors the shape of a loaded question (meta chips, optional passage,
/// stem, answer rows) so the player/rush pager doesn't flash a blank spinner
/// while a question's detail is hydrating.
struct SATQuestionSkeleton: View {
    var showPassage: Bool = true
    var optionCount: Int = 4
    /// Set false when the caller already applies horizontal/top padding.
    var applyPadding: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                SkeletonBox(cornerRadius: CornerRadius.xxl, height: 22).frame(width: 90)
                SkeletonBox(cornerRadius: CornerRadius.xxl, height: 22).frame(width: 60)
                Spacer()
            }

            if showPassage {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    SkeletonBox(height: 13)
                    SkeletonBox(height: 13)
                    SkeletonBox(height: 13).frame(width: 220)
                }
                .padding(Spacing.md)
                .kGlassEffect(cornerRadius: CornerRadius.lg)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                SkeletonBox(height: 16)
                SkeletonBox(height: 16).frame(width: 260)
            }

            VStack(spacing: Spacing.xs) {
                ForEach(0..<optionCount, id: \.self) { _ in
                    SkeletonBox(cornerRadius: CornerRadius.md, height: 56)
                }
            }
        }
        .padding(.horizontal, applyPadding ? Spacing.md : 0)
        .padding(.top, applyPadding ? Spacing.sm : 0)
    }
}

// MARK: - Profile dashboard skeleton

/// Mirrors the shape of the Profile tab's progress dashboard (score card,
/// stat grid, section cards) so it reads as "already there" while the SAT
/// analytics load, instead of swapping a spinner for the real layout.
struct SATProfileSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Score card
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    SkeletonBox(height: 18).frame(width: 110)
                    Spacer()
                    SkeletonBox(height: 16).frame(width: 90)
                }
                SkeletonBox(height: 8)
                SkeletonBox(height: 8)
            }
            .padding(Spacing.md)
            .satCard(tint: .kSuccess, logo: "newlogo3")

            // Stat grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBox(height: 12).frame(width: 80)
                        SkeletonBox(height: 26).frame(width: 60)
                        Spacer(minLength: 8)
                        HStack { Spacer(); SkeletonBox(cornerRadius: CornerRadius.xxl, height: 18).frame(width: 18) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 118)
                    .padding(Spacing.md)
                    .satCard(tint: .kAccentLight, logo: "newlogo10")
                }
            }

            // Section cards
            HStack(spacing: Spacing.sm) {
                ForEach(0..<2, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBox(height: 12).frame(width: 100)
                        SkeletonBox(height: 26).frame(width: 50)
                        Spacer(minLength: 8)
                        HStack {
                            SkeletonBox(cornerRadius: CornerRadius.md, height: 32).frame(width: 80)
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 150)
                    .padding(Spacing.md)
                    .satCard(tint: index == 0 ? .kAccent : .kSuccess, logo: index == 0 ? "newlogo0" : "newlogo2")
                }
            }
        }
    }
}
