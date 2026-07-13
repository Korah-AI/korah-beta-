import SwiftUI

// MARK: - SAT Home
// The app's landing tab: hero header, quick stats strip, and glass cards
// into the four SAT surfaces (Bank / Rush / Dashboard / Desmos Chat).

struct SATHomeView: View {
    @State private var bank = SATBankStore.shared
    @State private var totals = SATTotals()
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    hero
                    statsStrip
                    cards
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, Spacing.md)
            }
            .kBackground(withStars: true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image("newlogo2")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                        Text("Korah")
                            .font(.kHeadline)
                            .kGradientText()
                    }
                }
            }
            .task {
                await bank.loadIfNeeded()
                totals = (try? await SATAnalyticsService.shared.getTotals()) ?? SATTotals()
            }
            .refreshable {
                await bank.loadStats(force: true)
                totals = (try? await SATAnalyticsService.shared.getTotals()) ?? SATTotals()
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Hey, \(authManager.currentUser?.firstName ?? "there")!")
                .font(.kLargeTitle)
                .foregroundStyle(Color.kTextPrimary)
            Text("Ready to raise your SAT score?")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: Spacing.sm) {
            stat(value: totals.answered.formatted(), label: "Answered",
                 icon: "checkmark.circle.fill", tint: .kSuccess)
            stat(value: totals.answered > 0 ? "\(Int((totals.accuracy * 100).rounded()))%" : "—",
                 label: "Accuracy", icon: "target", tint: .kAccent)
            stat(value: totals.totalXP.formatted(), label: "XP · Lv \(SATXP.level(for: totals.totalXP))",
                 icon: "bolt.fill", tint: .kGold)
            if let stats = bank.stats {
                stat(value: stats.totalQuestions.formatted(), label: "In bank",
                     icon: "books.vertical.fill", tint: .kAccentLight)
            }
        }
    }

    private func stat(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.kCaption2)
                .foregroundStyle(Color.kTextTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .kGlassEffect(cornerRadius: CornerRadius.md)
    }

    // MARK: - Surface cards

    private var cards: some View {
        VStack(spacing: Spacing.sm) {
            NavigationLink {
                SATBankView()
            } label: {
                surfaceCard(
                    icon: "books.vertical.fill",
                    title: "Question Bank",
                    blurb: "Practice official College Board questions by topic and difficulty.",
                    tint: .kAccent, prominent: true)
            }

            NavigationLink {
                SATRushView()
            } label: {
                surfaceCard(
                    icon: "bolt.fill",
                    title: "Practice Rush",
                    blurb: "Rapid-fire questions. Build streaks, earn XP.",
                    tint: .kGold)
            }

            NavigationLink {
                SATDashboardView()
            } label: {
                surfaceCard(
                    icon: "chart.bar.fill",
                    title: "Dashboard",
                    blurb: "Accuracy by skill, score goals, and what to study next.",
                    tint: .kSuccess)
            }

            NavigationLink {
                MathChatView()
            } label: {
                surfaceCard(
                    icon: "function",
                    title: "Desmos Chat",
                    blurb: "Ask math questions — Korah answers with live graphs.",
                    tint: .kAccentLight)
            }
        }
        .buttonStyle(.plain)
    }

    private func surfaceCard(icon: String, title: String, blurb: String,
                             tint: Color, prominent: Bool = false) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(prominent ? .kTitle3 : .kHeadline)
                    .foregroundStyle(Color.kTextPrimary)
                Text(blurb)
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.kTextTertiary)
        }
        .padding(Spacing.md)
        .kGlassEffect(cornerRadius: CornerRadius.xl, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(prominent ? tint.opacity(0.4) : .clear, lineWidth: 1.5)
        )
        .kShadowGlow()
    }
}
