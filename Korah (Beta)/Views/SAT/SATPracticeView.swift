import SwiftUI

// MARK: - Practice tab
// Practice hub: a Practice Rush hero, difficulty filter chips, per-section
// domain cards with your accuracy, and an adaptive set built from the
// questions you've been missing.

struct SATPracticeView: View {
    @State private var bank = SATBankStore.shared
    /// Difficulty chip selection; nil = All.
    @State private var difficulty: String?
    @State private var missedIds: [String] = []
    @State private var startQuery: SATQuery?
    @State private var showBank = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    subtitle

                    rushHero

                    difficultyChips

                    sectionCard(SATCatalog.english, icon: "book.fill",
                                gradient: Self.englishGradient)
                    sectionCard(SATCatalog.math, icon: "sum",
                                gradient: Self.mathGradient)

                    adaptiveSetCard

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
            }
            .kBackground(withStars: true)
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SATBankView()
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                }
            }
            .navigationDestination(item: $startQuery) { query in
                SATPlayerView(query: query)
            }
            .navigationDestination(isPresented: $showBank) {
                SATBankView()
            }
            .task {
                await bank.loadIfNeeded()
                await loadMissed()
            }
            .refreshable {
                await bank.loadStats(force: true)
                await bank.loadProgress()
                await loadMissed()
            }
        }
    }

    // MARK: - Subtitle

    private var subtitle: some View {
        Text(bank.stats.map { "\($0.totalQuestions)+ real College Board questions." }
             ?? "Real College Board questions.")
            .font(.kSubheadline)
            .foregroundStyle(Color.kTextSecondary)
    }

    // MARK: - Practice Rush hero

    private var rushHero: some View {
        NavigationLink {
            SATRushView()
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .offset(x: 40, y: -50)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2.weight(.bold))
                        Text("PRACTICE RUSH")
                            .font(.kCaption2.weight(.heavy))
                            .kerning(1.2)
                    }
                    .foregroundStyle(Color.white.opacity(0.85))

                    Text("Jump into a rush")
                        .font(.kTitle2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Short-term studying - streaks - instant feedback")
                        .font(.kFootnote)
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.lg)
            }
            .background(Self.rushGradient)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .shadow(color: Self.rushShadow, radius: 20, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Difficulty chips

    private var difficultyChips: some View {
        HStack(spacing: Spacing.xs) {
            difficultyChip(label: "All", code: nil)
            ForEach(SATCatalog.difficulties, id: \.code) { entry in
                difficultyChip(label: entry.label, code: entry.code)
            }
        }
    }

    private func difficultyChip(label: String, code: String?) -> some View {
        let selected = difficulty == code
        let color = Self.chipColor(code)
        return Button {
            withAnimation(KAnimation.quick) { difficulty = code }
            Haptics.selection()
        } label: {
            Text(label)
                .font(.kSubheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Capsule().fill(selected ? AnyShapeStyle(color) : AnyShapeStyle(Color.kSurface)))
                .overlay(Capsule().stroke(selected ? Color.clear : color.opacity(0.55), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    /// All → blue, Easy → green, Medium → orange, Hard → red.
    private static func chipColor(_ code: String?) -> Color {
        switch code {
        case "E": return chipGreen
        case "M": return chipOrange
        case "H": return chipRed
        default:  return chipBlue
        }
    }

    // MARK: - Section cards (all four domains each)

    private func sectionCard(_ section: SATSectionInfo, icon: String,
                             gradient: LinearGradient) -> some View {
        VStack(spacing: 0) {
            // Gradient header
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(SATCatalog.sectionLabels[section.key] ?? section.label)
                        .font(.kTitle3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(headerLine(for: section))
                        .font(.kCaption)
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.2))
                    )
            }
            .padding(Spacing.md)
            .background(gradient)

            // Domain rows
            ForEach(Array(section.domains.enumerated()), id: \.element.id) { index, domain in
                if index > 0 {
                    Divider().overlay(Color.kBorder.opacity(0.4))
                }
                domainRow(section: section, domain: domain)
            }
        }
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(Color.kBorder.opacity(0.6), lineWidth: 1)
        )
    }

    private func headerLine(for section: SATSectionInfo) -> String {
        let count = section.domains.reduce(0) { $0 + questionCount(forDomain: $1.code) }
        return count > 0
            ? "\(section.domains.count) domains · \(count) questions"
            : "\(section.domains.count) domains"
    }

    private func domainRow(section: SATSectionInfo, domain: SATDomainInfo) -> some View {
        Button {
            showBank = true
            Haptics.medium()
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(domain.name)
                    .font(.kSubheadline.weight(.medium))
                    .foregroundStyle(Color.kTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: Spacing.sm)

                let accuracy = accuracy(forDomain: domain)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.kBorder.opacity(0.5))
                    Capsule()
                        .fill(section.key == "math" ? Color.kSuccess : Self.englishBlue)
                        .frame(width: 64 * CGFloat(accuracy ?? 0) / 100)
                }
                .frame(width: 64, height: 6)

                Text(accuracy.map { "\($0)%" } ?? "—")
                    .font(.kCaption.monospacedDigit())
                    .foregroundStyle(Color.kTextTertiary)
                    .frame(width: 38, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Adaptive set (questions you've been missing)

    private var adaptiveSetCard: some View {
        Button {
            guard !missedIds.isEmpty else { return }
            startQuery = SATQuery(questionIds: Array(missedIds.shuffled().prefix(10)))
            Haptics.medium()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "target")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.kGold)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.kGold.opacity(0.15)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Adaptive set")
                        .font(.kHeadline)
                        .foregroundStyle(Color.kTextPrimary)
                    Text(missedIds.isEmpty
                         ? "Miss a question and it'll land here to retry."
                         : "\(min(10, missedIds.count)) questions · targets your weak spots")
                        .font(.kFootnote)
                        .foregroundStyle(Color.kTextSecondary)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(missedIds.isEmpty ? Color.kTextTertiary : Color.kGold)
            }
            .padding(Spacing.md)
            .satCard(tint: .kGold, cornerRadius: CornerRadius.xl, solid: true)
            .opacity(missedIds.isEmpty ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(missedIds.isEmpty)
    }

    private func loadMissed() async {
        let missed = (try? await SATAnalyticsService.shared.getMissedBySection()) ?? (english: [], math: [])
        missedIds = missed.english + missed.math
    }

    // MARK: - Stats helpers (respect the difficulty chip without touching
    // the shared bank filter state)

    private func questionCount(forDomain code: String) -> Int {
        guard let stats = bank.stats else { return 0 }
        guard let difficulty else { return stats.domainBreakdown[code] ?? 0 }
        return stats.domainBreakdownByDifficulty[code]?.count(for: [difficulty]) ?? 0
    }

    /// Accuracy (0–100) across a domain's skills, or nil if unattempted.
    private func accuracy(forDomain domain: SATDomainInfo) -> Int? {
        var attempts = 0, correct = 0
        for skill in domain.skills {
            guard let stat = bank.skillProgress[skill.code] else { continue }
            if let difficulty {
                if let bucket = stat.byDifficulty?[difficulty] {
                    attempts += bucket.attempts
                    correct += bucket.correct
                }
            } else {
                attempts += stat.attempts
                correct += stat.correct
            }
        }
        guard attempts > 0 else { return nil }
        return Int((Double(correct) / Double(attempts) * 100).rounded())
    }

    // MARK: - Palette

    private static let englishBlue = Color(red: 0.38, green: 0.56, blue: 0.96)

    // Practice Rush hero — a warm rose→amber sunset, distinct from the purple,
    // blue and green used elsewhere on the screen.
    private static let rushGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.37, blue: 0.49), Color(red: 1.0, green: 0.62, blue: 0.27)],
        startPoint: .leading, endPoint: .trailing)
    private static let rushShadow = Color(red: 1.0, green: 0.45, blue: 0.38).opacity(0.35)

    // Difficulty chip colours: All / Easy / Medium / Hard.
    private static let chipBlue   = Color(red: 0.30, green: 0.56, blue: 0.96)
    private static let chipGreen  = Color(red: 0.20, green: 0.72, blue: 0.48)
    private static let chipOrange = Color(red: 0.96, green: 0.60, blue: 0.20)
    private static let chipRed    = Color(red: 0.93, green: 0.35, blue: 0.35)

    private static let englishGradient = LinearGradient(
        colors: [Color(red: 0.30, green: 0.51, blue: 0.94), Color(red: 0.30, green: 0.71, blue: 0.91)],
        startPoint: .leading, endPoint: .trailing)

    private static let mathGradient = LinearGradient(
        colors: [Color(red: 0.22, green: 0.65, blue: 0.45), Color(red: 0.36, green: 0.78, blue: 0.55)],
        startPoint: .leading, endPoint: .trailing)
}
