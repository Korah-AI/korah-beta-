import SwiftUI
import Combine

// MARK: - SAT Home ("Home" tab)
// A dashboard-style landing screen: greeting + daily quote, a live exam
// countdown, quick stats, score journey, today's focus (weakness), momentum,
// and a Learn & Prep section (rotating strategy tips + word of the day).
// All figures are backed by the user's Firestore SAT analytics.

struct SATHomeView: View {
    /// Switches the app to the Profile tab, which now hosts the progress
    /// dashboard that used to live behind `HomeDestination.dashboard`.
    var onOpenProfile: () -> Void = {}

    @Environment(AuthManager.self) private var authManager

    // Live analytics
    @State private var totals = SATTotals()
    @State private var profile: SATProfile?
    @State private var savedIds: [String] = []
    @State private var missedIds: [String] = []
    @State private var topWeakness: SATAnalyticsService.SkillSuggestion?
    @State private var todayCount = 0
    @State private var todayXP = 0

    // UI state
    @State private var path = NavigationPath()
    @State private var now = Date()
    @State private var tipIndex = 0
    @State private var vocabIndex = 0
    @State private var vocabRevealed = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    hero
                    countdownCard
                    statsSection
                    desmosCard
                    scoreJourneyCard
                    focusSection
                    momentumCard
                    learnAndPrepSection
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
            }
            .kBackground(withStars: true)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeDestination.self) { dest in
                switch dest {
                case .bank:      SATBankView()
                case .mathChat:  MathChatView()
                case .rush:      SATRushView()
                case .practice(let plan): SATPlayerView(query: plan.query)
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .onReceive(ticker) { now = $0 }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(greeting),")
                    .font(.kLargeTitle)
                    .foregroundStyle(Color.kTextPrimary)
                Text(displayName)
                    .font(.kLargeTitle)
                    .foregroundStyle(Color.kTextPrimary)
                (Text("\"\(dailyQuote.text)\" ").italic().foregroundColor(.kTextPrimary)
                    + Text("— \(dailyQuote.author)").foregroundColor(.kTextTertiary))
                    .font(.kSubheadline)
                    .padding(.top, 8)
            }

            Image("newlogo11")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .shadow(color: Color.kGlow, radius: 10)
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: - Countdown

    private var countdownCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Time left to SAT exam")
                .font(.kFootnote.weight(.semibold))
                .foregroundStyle(Color.kGold)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                countdownUnit(countdown.days, "days")
                countdownUnit(countdown.hours, "hrs", pad: true)
                countdownUnit(countdown.minutes, "min", pad: true)
                countdownUnit(countdown.seconds, "sec", pad: true)
            }

            Text(examDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .satCard(tint: .kGold, logo: "newlogo11")
    }

    private func countdownUnit(_ value: Int, _ label: String, pad: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(pad ? String(format: "%02d", value) : "\(value)")
                .font(.jakarta(34, relativeTo: .largeTitle).weight(.heavy))
                .foregroundStyle(Color.kTextPrimary)
                .monospacedDigit()
            Text(label)
                .font(.kCaption)
                .foregroundStyle(Color.kTextTertiary)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("My Stats", systemImage: "chart.bar.fill", tint: .satStatBlue)

            HStack(spacing: Spacing.sm) {
                statCard(label: "Questions Attempted",
                         value: "\(totals.answered)",
                         tint: .satStatBlue,
                         icon: "checkmark",
                         iconFilled: true,
                         logo: "newlogo0",
                         action: { path.append(HomeDestination.bank) })

                statCard(label: "Current Accuracy",
                         value: totals.answered > 0 ? "\(Int((totals.accuracy * 100).rounded()))%" : "—",
                         tint: .kSuccess,
                         icon: "chart.bar.fill",
                         logo: "newlogo5",
                         action: { onOpenProfile() })
            }

            HStack(spacing: Spacing.sm) {
                actionStatCard(label: "Saved Questions",
                               value: "\(savedIds.count)",
                               tint: .kAccentLight,
                               buttonTitle: "View Saved",
                               buttonSolid: false,
                               buttonEnabled: !savedIds.isEmpty,
                               trailingIcon: "bookmark.fill",
                               logo: "newlogo10",
                               action: { path.append(HomeDestination.practice(PracticePlan(questionIds: savedIds))) })

                actionStatCard(label: "Recent Errors",
                               value: "\(missedIds.count)",
                               tint: .satCoral,
                               buttonTitle: "Start Review",
                               buttonSolid: true,
                               buttonEnabled: !missedIds.isEmpty,
                               trailingIcon: "clock.arrow.circlepath",
                               logo: "newlogo12",
                               action: { path.append(HomeDestination.practice(PracticePlan(questionIds: missedIds))) })
            }
        }
    }

    private func statCard(label: String, value: String, tint: Color,
                          icon: String, iconFilled: Bool = false,
                          logo: String = "newlogo3",
                          action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.kFootnote.weight(.medium))
                    .foregroundStyle(Color.kTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(value)
                    .font(.jakarta(30, relativeTo: .title).weight(.bold))
                    .foregroundStyle(Color.kTextPrimary)
                Spacer(minLength: 8)
                HStack {
                    Spacer()
                    if iconFilled {
                        Image(systemName: icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.kTextPrimary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    } else {
                        Image(systemName: icon)
                            .font(.callout)
                            .foregroundStyle(tint)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 118)
            .padding(Spacing.md)
            .satCard(tint: tint, logo: logo)
        }
        .buttonStyle(.plain)
    }

    private func actionStatCard(label: String, value: String, tint: Color,
                                buttonTitle: String, buttonSolid: Bool,
                                buttonEnabled: Bool, trailingIcon: String,
                                logo: String = "newlogo3",
                                action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.kFootnote.weight(.medium))
                .foregroundStyle(Color.kTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.jakarta(30, relativeTo: .title).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
            Spacer(minLength: 8)
            HStack(alignment: .bottom) {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.kCaption.weight(.bold))
                        .foregroundStyle(buttonSolid ? .white : Color.kTextPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(buttonSolid ? AnyShapeStyle(Color.satCoral)
                                                  : AnyShapeStyle(Color.white.opacity(0.06)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(buttonSolid ? Color.clear : Color.kBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!buttonEnabled)
                .opacity(buttonEnabled ? 1 : 0.45)

                Spacer()

                Image(systemName: trailingIcon)
                    .font(.callout)
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 150)
        .padding(Spacing.md)
        .satCard(tint: tint, logo: logo)
    }

    // MARK: - Desmos

    private var desmosCard: some View {
        Button {
            path.append(HomeDestination.mathChat)
        } label: {
            VStack(spacing: Spacing.xs) {
                Text("Learn how to use Desmos")
                    .font(.kTitle3.weight(.bold))
                    .foregroundStyle(Color.kTextPrimary)
                (Text("Get started in ").foregroundColor(.kTextSecondary)
                    + Text("Desmos Chat").foregroundColor(.kGold).bold()
                    + Text(" to get that math score up, fast.").foregroundColor(.kTextSecondary))
                    .font(.kSubheadline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
            .padding(.horizontal, Spacing.lg)
            .satCard(tint: .kGold, logo: "newlogo2")
        }
        .buttonStyle(.plain)
    }

    // MARK: - Score Journey

    private var scoreJourneyCard: some View {
        VStack(spacing: Spacing.md) {
            Text("Score Journey")
                .font(.kTitle3.weight(.bold))
                .foregroundStyle(Color.kTextPrimary)

            scoreRow(label: "Reading & Writing",
                     current: profile?.englishScore, goal: profile?.englishGoal,
                     tint: .satStatBlue)
            scoreRow(label: "Math",
                     current: profile?.mathScore, goal: profile?.mathGoal,
                     tint: .kSuccess)

            Button {
                onOpenProfile()
            } label: {
                Text(hasGoals ? "Update your score goals" : "Set a goal to track your progress.")
                    .font(.kFootnote)
                    .foregroundStyle(Color.kTextTertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .satCard(tint: .kSuccess, logo: "newlogo3")
    }

    private func scoreRow(label: String, current: Int?, goal: Int?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label.uppercased())
                    .font(.kCaption.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(tint)
                Spacer()
                Text("\(current.map(String.init) ?? "—") / \(goal.map(String.init) ?? "—")")
                    .font(.kSubheadline.weight(.semibold))
                    .foregroundStyle(Color.kTextSecondary)
            }
            ScoreBar(fraction: scoreFraction(current: current, goal: goal), tint: tint)
        }
    }

    // MARK: - Today's Focus

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Today's Focus", systemImage: "target", tint: .kSuccess)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("#1 Weakness to Fix")
                    .font(.kCaption.weight(.semibold))
                    .foregroundStyle(Color.satCoral)
                Text(focusTitle)
                    .font(.kTitle3.weight(.bold))
                    .foregroundStyle(Color.kTextPrimary)
                Text(focusSubtitle)
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    path.append(HomeDestination.practice(focusPlan))
                } label: {
                    HStack(spacing: 6) {
                        Text("Start Practicing")
                        Image(systemName: "arrow.right")
                    }
                    .font(.kSubheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.satCoral)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .satCard(tint: .satCoral, logo: "newlogo5")
        }
    }

    // MARK: - Momentum

    private var momentumCard: some View {
        Button {
            path.append(HomeDestination.rush)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("TODAY'S MOMENTUM")
                        .font(.kCaption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(Color.satStatBlue)
                    Spacer()
                    Image(systemName: "clock.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.satStatBlue)
                }

                HStack(spacing: Spacing.xxl) {
                    momentumStat(value: "\(todayCount)", label: "QUESTIONS")
                    momentumStat(value: "\(todayXP)", label: "XP EARNED")
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                Text(todayCount > 0 ? "Nice work — keep the streak alive!"
                                    : "Start practicing to build momentum!")
                    .font(.kFootnote)
                    .foregroundStyle(Color.kTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .satCard(tint: .satStatBlue, logo: "newlogo0")
        }
        .buttonStyle(.plain)
    }

    private func momentumStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.jakarta(28, relativeTo: .title).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
            Text(label)
                .font(.kCaption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.kTextTertiary)
        }
    }

    // MARK: - Learn & Prep

    private var learnAndPrepSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Learn & Prep", systemImage: "lightbulb.fill", tint: .kGold)
            tipCard
            wordOfDayCard
        }
    }

    private var tipCard: some View {
        let tip = Self.tips[tipIndex]
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: tip.icon)
                .font(.title3)
                .foregroundStyle(Color.kGold)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.kGold.opacity(0.15))
                )

            Text(tip.category)
                .font(.kTitle3.weight(.bold))
                .foregroundStyle(Color.kGold)

            Text(tip.body)
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                HStack(spacing: 6) {
                    ForEach(Self.tips.indices, id: \.self) { i in
                        Circle()
                            .fill(i == tipIndex ? Color.kGold : Color.white.opacity(0.15))
                            .frame(width: 6, height: 6)
                    }
                }
                Spacer()
                Button {
                    withAnimation(KAnimation.quick) {
                        tipIndex = (tipIndex + 1) % Self.tips.count
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Next tip")
                        Image(systemName: "arrow.right")
                    }
                    .font(.kCaption.weight(.bold))
                    .foregroundStyle(Color.kGold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.kGold.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .satCard(tint: .kGold, logo: "newlogo10")
    }

    private var wordOfDayCard: some View {
        let word = Self.vocab[vocabIndex]
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("WORD OF THE DAY")
                .font(.kCaption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Color.satStatBlue)

            Text(word.word)
                .font(.jakarta(34, relativeTo: .largeTitle).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)

            Text(word.partOfSpeech)
                .font(.kSubheadline.italic())
                .foregroundStyle(Color.kTextTertiary)

            if vocabRevealed {
                Text(word.definition)
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .transition(.opacity)
            } else {
                Button {
                    withAnimation(KAnimation.quick) { vocabRevealed = true }
                } label: {
                    HStack(spacing: 6) {
                        Text("Tap to reveal definition")
                        Image(systemName: "arrow.right")
                    }
                    .font(.kSubheadline.weight(.semibold))
                    .foregroundStyle(Color.satStatBlue)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            HStack {
                Button { stepVocab(-1) } label: {
                    vocabNavLabel("Prev", systemImage: "arrow.left", leading: true)
                }
                .buttonStyle(.plain)

                Spacer()
                Text("\(vocabIndex + 1) / \(Self.vocab.count)")
                    .font(.kFootnote.weight(.medium))
                    .foregroundStyle(Color.kTextTertiary)
                Spacer()

                Button { stepVocab(1) } label: {
                    vocabNavLabel("Next", systemImage: "arrow.right", leading: false)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .satCard(tint: .satStatBlue, logo: "newlogo12")
    }

    private func vocabNavLabel(_ title: String, systemImage: String, leading: Bool) -> some View {
        HStack(spacing: 6) {
            if leading { Image(systemName: systemImage) }
            Text(title)
            if !leading { Image(systemName: systemImage) }
        }
        .font(.kCaption.weight(.bold))
        .foregroundStyle(Color.kTextPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.kBorder, lineWidth: 1)
        )
    }

    private func stepVocab(_ delta: Int) {
        withAnimation(KAnimation.quick) {
            let count = Self.vocab.count
            vocabIndex = (vocabIndex + delta + count) % count
            vocabRevealed = false
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)
        }
    }

    // MARK: - Derived values

    private var greeting: String {
        switch Calendar.current.component(.hour, from: now) {
        case ..<12: return "Good morning"
        case ..<18: return "Good afternoon"
        default:    return "Good evening"
        }
    }

    private var displayName: String {
        let user = authManager.currentUser
        let parts = [user?.firstName, user?.lastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "there" : parts.joined(separator: " ")
    }

    private var dailyQuote: Quote {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
        return Self.quotes[day % Self.quotes.count]
    }

    /// Next upcoming SAT date (falls back to a fixed 2026 date).
    private var examDate: Date {
        let cal = Calendar.current
        let upcoming = Self.examDates.compactMap { cal.date(from: $0) }
        return upcoming.first { $0 > now } ?? cal.date(from: DateComponents(year: 2026, month: 8, day: 22))!
    }

    private var countdown: (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let diff = max(0, Int(examDate.timeIntervalSince(now)))
        return (diff / 86_400, (diff % 86_400) / 3600, (diff % 3600) / 60, diff % 60)
    }

    private var hasGoals: Bool {
        profile?.englishGoal != nil || profile?.mathGoal != nil
    }

    private func scoreFraction(current: Int?, goal: Int?) -> Double {
        if let current, let goal, goal > 200 {
            return max(0, min(1, Double(current - 200) / Double(goal - 200)))
        }
        if let current { return max(0, min(1, Double(current - 200) / 600.0)) }
        return 0
    }

    private var focusTitle: String {
        guard let w = topWeakness, w.attempts > 0 else { return "Start practicing" }
        return w.skillName
    }

    private var focusSubtitle: String {
        guard let w = topWeakness, w.attempts > 0 else {
            return "Answer a few questions to see your weaknesses"
        }
        let pct = Int((w.accuracy * 100).rounded())
        return "\(pct)% accuracy in \(w.domain) — let's turn that around."
    }

    private var focusPlan: PracticePlan {
        if let w = topWeakness, !w.skillCd.isEmpty {
            return PracticePlan(skills: [w.skillCd], limit: 10, random: true)
        }
        return PracticePlan(limit: 10, random: true)
    }

    // MARK: - Load

    private func load() async {
        let service = SATAnalyticsService.shared
        async let totalsTask = service.getTotals()
        async let profileTask = service.getProfile()
        async let bookmarksTask = service.getBookmarks()
        async let missedTask = service.getMissedBySection()
        async let weaknessTask = service.suggestSkills(top: 1)
        async let attemptsTask = service.getRecentAttempts(limit: 100)

        totals = (try? await totalsTask) ?? SATTotals()
        profile = try? await profileTask
        savedIds = ((try? await bookmarksTask) ?? []).map(\.questionId)
        let missed = (try? await missedTask) ?? (english: [], math: [])
        missedIds = missed.english + missed.math
        topWeakness = (try? await weaknessTask)?.first

        let attempts = (try? await attemptsTask) ?? []
        let todays = attempts.filter { att in
            guard let date = Self.parseTimestamp(att.ts) else { return false }
            return Calendar.current.isDateInToday(date)
        }
        todayCount = todays.count
        todayXP = todays.filter { $0.xp > 0 }.reduce(0) { $0 + $1.xp }
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        ISO8601DateFormatter.satShared.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    // MARK: - Static content

    private static let examDates: [DateComponents] = [
        DateComponents(year: 2026, month: 8, day: 22),
        DateComponents(year: 2026, month: 10, day: 3),
        DateComponents(year: 2026, month: 11, day: 7),
        DateComponents(year: 2026, month: 12, day: 5),
        DateComponents(year: 2027, month: 3, day: 13),
    ]

    private static let quotes: [Quote] = [
        Quote(text: "Is it better to cook, or to get cooked?", author: "Korah, 2026"),
        Quote(text: "Small steps every day add up to big score gains.", author: "Korah, 2026"),
        Quote(text: "The expert in anything was once a beginner.", author: "Korah, 2026"),
        Quote(text: "Discipline is choosing what you want most over what you want now.", author: "Korah, 2026"),
    ]

    private static let tips: [StudyTip] = [
        StudyTip(category: "READING STRATEGY", icon: "text.book.closed.fill",
                 body: "Read the question before the passage. Know exactly what you're looking for before you start reading."),
        StudyTip(category: "MATH STRATEGY", icon: "function",
                 body: "When the algebra gets messy, plug in the answer choices. Working backwards is often faster than solving."),
        StudyTip(category: "GRAMMAR RULE", icon: "textformat.abc",
                 body: "Shorter is usually better. When a sentence is clear and concise, it's often the correct answer."),
        StudyTip(category: "TIME MANAGEMENT", icon: "clock.fill",
                 body: "Never leave a question blank. There's no penalty for guessing, so always fill in an answer."),
        StudyTip(category: "VOCAB IN CONTEXT", icon: "character.book.closed.fill",
                 body: "Predict the meaning of a hard word from the sentence before you ever look at the choices."),
    ]

    private static let vocab: [VocabWord] = [
        VocabWord(word: "Pragmatic", partOfSpeech: "adjective",
                  definition: "Dealing with things sensibly and realistically in a practical rather than idealistic way."),
        VocabWord(word: "Ephemeral", partOfSpeech: "adjective",
                  definition: "Lasting for a very short time; fleeting."),
        VocabWord(word: "Ubiquitous", partOfSpeech: "adjective",
                  definition: "Present, appearing, or found everywhere."),
        VocabWord(word: "Candor", partOfSpeech: "noun",
                  definition: "The quality of being open, honest, and sincere in expression; frankness."),
        VocabWord(word: "Meticulous", partOfSpeech: "adjective",
                  definition: "Showing great attention to detail; very careful and precise."),
        VocabWord(word: "Ambivalent", partOfSpeech: "adjective",
                  definition: "Having mixed, contradictory, or uncertain feelings about something."),
    ]
}

// MARK: - Supporting types

/// A destination on the Home navigation stack.
enum HomeDestination: Hashable {
    case bank
    case mathChat
    case rush
    case practice(PracticePlan)
}

/// Value-type description of a practice session, safe to store in NavigationPath.
struct PracticePlan: Hashable {
    var questionIds: [String] = []
    var skills: [String] = []
    var limit: Int? = nil
    var random: Bool = false

    var query: SATQuery {
        SATQuery(skills: Set(skills), limit: limit, random: random, questionIds: questionIds)
    }
}

private struct Quote {
    let text: String
    let author: String
}

private struct StudyTip {
    let category: String
    let icon: String
    let body: String
}

private struct VocabWord {
    let word: String
    let partOfSpeech: String
    let definition: String
}

// MARK: - Score progress bar

private struct ScoreBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Home palette

private extension Color {
    /// Coral/red-orange used for error + focus call-to-actions.
    static let satCoral = Color(red: 0.91, green: 0.36, blue: 0.27)
    /// Blue used for the "attempted" and momentum accents.
    static let satStatBlue = Color(red: 0.38, green: 0.56, blue: 0.96)
}
