import SwiftUI

// MARK: - Practice tab
// A simple hub that routes into the two ways to practice: the Question Bank
// (self-directed topic browsing) and Practice Rush (endless gamified drill).

struct SATPracticeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    header

                    NavigationLink {
                        SATBankView()
                    } label: {
                        practiceOption(
                            title: "Question Bank",
                            subtitle: "Browse official questions by topic and build your own set.",
                            icon: "square.grid.2x2.fill",
                            tint: .kAccent,
                            logo: "newlogo10")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SATRushView()
                    } label: {
                        practiceOption(
                            title: "Practice Rush",
                            subtitle: "An endless, gamified drill with streaks and instant feedback.",
                            icon: "bolt.fill",
                            tint: .kGold,
                            logo: "newlogo5")
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
            }
            .kBackground(withStars: true)
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ready to practice?")
                    .font(.kTitle2.weight(.bold))
                    .foregroundStyle(Color.kTextPrimary)
                Text("Pick how you want to train today.")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextSecondary)
            }
            Spacer()
            Image("newlogo3")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .shadow(color: Color.kGlow, radius: 10)
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: - Option card

    private func practiceOption(title: String, subtitle: String,
                                icon: String, tint: Color, logo: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 58, height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.kTitle3.weight(.bold))
                    .foregroundStyle(Color.kTextPrimary)
                Text(subtitle)
                    .font(.kFootnote)
                    .foregroundStyle(Color.kTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            Image(systemName: "arrow.right")
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .satCard(tint: tint, logo: logo)
    }
}
