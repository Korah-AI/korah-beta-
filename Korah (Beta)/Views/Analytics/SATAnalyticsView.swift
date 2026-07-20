import SwiftUI

// MARK: - Analytics tab
// The full progress report: headline stats, weekly activity trend, study-time
// splits, the topics costing the most points, per-section topic accuracy,
// pacing, and the coaching extras (goal pace, momentum, neglected skills,
// first-try vs retry, consistency heatmap). Everything derives from
// SATAnalyticsModel's single fetch; the range chip re-filters in memory.

struct SATAnalyticsView: View {
    @State private var model = SATAnalyticsModel()
    @State private var staging: SATStagingConfig?
    @State private var reviewQuery: SATQuery?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    if model.isLoading && !model.hasLoadedOnce {
                        SATProfileSkeleton()
                    } else if model.allAttempts.isEmpty {
                        emptyState
                    } else {
                        content
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
                .animation(KAnimation.standard, value: model.range)
            }
            .kBackground(withStars: true)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $reviewQuery) { query in
                SATPlayerView(query: query)
            }
            .task { await model.load() }
            .refreshable { await model.load() }
            .overlay {
                if let staging {
                    SATStagingPopup(
                        config: staging,
                        onStart: { ids in reviewQuery = SATQuery(questionIds: ids) },
                        onClose: { self.staging = nil }
                    )
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: staging != nil)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            Text("Analytics")
                .font(.kLargeTitle)
                .foregroundStyle(Color.kTextPrimary)
            AnalyticsRangeDropdown(selection: $model.range)
            Spacer(minLength: 0)
        }
        .zIndex(1)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.satStatBlue)
            Text("No numbers yet")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)
            Text("Answer a few questions and this page turns into your full progress report.")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextPrimary)
                .multilineTextAlignment(.center)
            Button {
                staging = SATStagingConfig(
                    title: "Quick 10",
                    systemImage: "bolt.fill",
                    tint: .kAccent,
                    load: { await SATStaging.bank(SATQuery(sections: ["english", "math"], limit: 10, random: true)) })
            } label: {
                Text("Try 10 questions")
                    .font(.kHeadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: ComponentSize.Button.medium)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous)
                            .fill(Color.korahPink)
                    )
            }
            .frame(maxWidth: 220)
            .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        // Fill the scroll viewport so the whole state sits centered on
        // screen instead of hugging the navigation title.
        .containerRelativeFrame(.vertical, alignment: .center)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        statGrid

        goalPaceCard

        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Activity", systemImage: "chart.bar.fill", tint: .satStatBlue)
            trendCard
            momentumCard
        }

        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Study Time", systemImage: "clock.fill", tint: .satAmber)
            timeDonuts
            difficultyTimeCard
        }

        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Where You Lose Points", systemImage: "scope", tint: .satCoral)
            costingCard
            pacingCard
        }

        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Accuracy by Topic", systemImage: "chart.bar.xaxis", tint: .satTeal)
            topicCard(section: "english", label: "Reading & Writing", tint: .satEnglishBlue)
            topicCard(section: "math", label: "Math", tint: .satMathGreen)
        }

        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Habits", systemImage: "flame.fill", tint: .korahPink)
            neglectedCard
            retryCard
            heatmapCard
            recentCard
        }

        Spacer(minLength: 40)
    }

    // MARK: - Section header (mirrors ProfileView/SATHomeView)

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

    // MARK: - Stat grid

    private var statGrid: some View {
        let savedAction: (() -> Void)? = model.savedCount == 0 ? nil : {
            staging = SATStagingConfig(
                title: "Saved Questions",
                systemImage: "bookmark.fill",
                tint: .kGold,
                load: { await SATStaging.bookmarks() })
        }
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
            statCard(icon: "checkmark.circle.fill", tint: .satStatBlue,
                     value: "\(model.attemptedCount)",
                     label: "Questions Attempted")
            statCard(icon: "target", tint: .kSuccess,
                     value: model.attemptedCount > 0 ? AnalyticsFormat.percent(model.accuracy) : "—",
                     label: "Accuracy")
            statCard(icon: "bookmark.fill", tint: .kGold,
                     value: "\(model.savedCount)",
                     label: "Saved Questions",
                     action: savedAction)
            statCard(icon: "flame.fill", tint: .satAmber,
                     value: "\(model.streak)",
                     label: "Study Streak")
        }
    }

    @ViewBuilder
    private func statCard(icon: String, tint: Color, value: String, label: String,
                          action: (() -> Void)? = nil) -> some View {
        let card = SATGradientCard(title: label, systemImage: icon, tint: tint, compact: true) {
            Text(value)
                .font(.jakarta(24, relativeTo: .title2).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        if let action {
            Button(action: action) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }

    // MARK: - Goal pace

    @ViewBuilder
    private var goalPaceCard: some View {
        if let gap = model.pointsToGoal {
            SATGradientCard(title: "Goal pace",
                            subtitle: gap <= 0 ? "Goal reached! 🎉" : "\(gap) points to go",
                            systemImage: "target",
                            tint: .kSuccess) {
                HStack(spacing: Spacing.sm) {
                    paceStat(value: gap <= 0 ? "Done" : "\(gap)", label: "Points to go")
                    if let days = model.daysUntilTest {
                        paceStat(value: "\(days)", label: days == 1 ? "Day left" : "Days left")
                    }
                    paceStat(value: String(format: "%.1f", model.recentDailyPace), label: "Q/day, last 14")
                }

                if gap > 0, let target = model.suggestedDailyQuestions {
                    Text("Aim for ~\(target) questions a day")
                        .font(.kBodyBold)
                        .foregroundStyle(Color.kSuccess)
                        .contentTransition(.numericText())
                    Text("A rough pace from your score gap and calendar, not a promise. Consistency beats volume.")
                        .font(.kCaption2)
                        .foregroundStyle(Color.kTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            SATGradientCard(title: "Goal pace",
                            subtitle: "No goal yet",
                            systemImage: "target",
                            tint: .kSuccess) {
                Text("Set your current and goal scores on the Profile tab and this card starts pacing you to test day.")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func paceStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.jakarta(22, relativeTo: .title2).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text(label)
                .font(.kCaption2)
                .foregroundStyle(Color.kTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Activity trend

    private var trendCard: some View {
        SATGradientCard(title: "Activity trend",
                        subtitle: "Each bar is one week",
                        systemImage: "chart.bar.fill",
                        tint: .satStatBlue) {
            HStack(spacing: Spacing.md) {
                legendChip(count: model.correctCount, label: "Correct", tint: .kSuccess, icon: "checkmark.circle.fill")
                legendChip(count: model.wrongCount, label: "Wrong", tint: .kError, icon: "xmark.circle.fill")
            }

            if model.weekBuckets.isEmpty {
                Text("No attempts in this range yet.")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextPrimary)
            } else {
                AnalyticsTrendChart(buckets: model.weekBuckets)
                Text("Darker segments are harder questions. Wrong stacks under correct.")
                    .font(.kCaption2)
                    .foregroundStyle(Color.kTextPrimary)
            }
        }
    }

    private func legendChip(count: Int, label: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text("\(count)")
                .font(.kHeadline.monospacedDigit())
                .foregroundStyle(Color.kTextPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.kCaption)
                .foregroundStyle(Color.kTextPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 1))
    }

    // MARK: - Momentum

    private var momentumCard: some View {
        let momentum = model.momentum
        return SATGradientCard(title: "Momentum",
                               subtitle: "Trailing 7 days vs the 7 before",
                               systemImage: "arrow.up.right",
                               tint: .satTeal) {
            HStack(spacing: Spacing.sm) {
                momentumColumn(title: "This week",
                               attempts: momentum.attemptsThisWeek,
                               accuracy: momentum.accuracyThisWeek,
                               highlighted: true)
                momentumColumn(title: "Last week",
                               attempts: momentum.attemptsLastWeek,
                               accuracy: momentum.accuracyLastWeek,
                               highlighted: false)
            }

            HStack(spacing: Spacing.md) {
                deltaLabel(value: momentum.volumeDelta,
                           text: momentum.volumeDelta == 0 ? "Same volume"
                               : "\(abs(momentum.volumeDelta)) \(momentum.volumeDelta > 0 ? "more" : "fewer") questions")
                if let delta = momentum.accuracyDelta {
                    let points = Int((delta * 100).rounded())
                    deltaLabel(value: points,
                               text: points == 0 ? "Accuracy flat"
                                   : "Accuracy \(points > 0 ? "up" : "down") \(abs(points))%")
                }
            }
        }
    }

    private func momentumColumn(title: String, attempts: Int, accuracy: Double?, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.kCaption2.weight(.bold))
                .foregroundStyle(highlighted ? Color.satTeal : Color.kTextPrimary)
                .textCase(.uppercase)
            Text("\(attempts)")
                .font(.jakarta(22, relativeTo: .title2).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
                .contentTransition(.numericText())
            Text(accuracy.map { "\(AnalyticsFormat.percent($0)) accuracy" } ?? "No attempts")
                .font(.kCaption2)
                .foregroundStyle(Color.kTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(highlighted ? Color.satTeal.opacity(0.12) : Color.kSurface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .stroke(highlighted ? Color.satTeal.opacity(0.28) : Color.kBorder.opacity(0.4), lineWidth: 1)
        )
    }

    private func deltaLabel(value: Int, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: value > 0 ? "arrow.up.right" : value < 0 ? "arrow.down.right" : "minus")
                .font(.caption2.weight(.bold))
            Text(text)
                .font(.kCaption)
        }
        .foregroundStyle(value > 0 ? Color.kSuccess : value < 0 ? Color.kError : Color.kTextPrimary)
    }

    // MARK: - Study time donuts

    private var timeDonuts: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            SATGradientCard(title: "By section", systemImage: "book.fill",
                            tint: .satEnglishBlue, compact: true) {
                AnalyticsTimeDonut(
                    slices: [
                        AnalyticsDonutSlice(label: "English", seconds: model.timeEnglish, color: .satEnglishBlue),
                        AnalyticsDonutSlice(label: "Math", seconds: model.timeMath, color: .satMathGreen),
                    ],
                    centerTitle: AnalyticsFormat.duration(model.totalTimedSeconds),
                    centerCaption: "question time")
            }
            SATGradientCard(title: "By activity", systemImage: "square.grid.2x2.fill",
                            tint: .satAmber, compact: true) {
                AnalyticsTimeDonut(
                    slices: [
                        AnalyticsDonutSlice(label: "Questions", seconds: model.timeQuestions, color: .satAmber),
                        AnalyticsDonutSlice(label: "Rush", seconds: model.timeRush, color: .korahPink),
                    ],
                    centerTitle: AnalyticsFormat.duration(model.totalTimedSeconds),
                    centerCaption: "total")
            }
        }
    }

    // MARK: - Time per difficulty

    private var difficultyTimeCard: some View {
        SATGradientCard(title: "Time per difficulty",
                        subtitle: "Average seconds per question",
                        systemImage: "stopwatch.fill",
                        tint: .satAmber) {
            HStack(alignment: .top, spacing: Spacing.md) {
                difficultyColumn(label: "Reading & Writing", tint: .satEnglishBlue,
                                 rows: model.difficultyTimes(section: "english"))
                difficultyColumn(label: "Math", tint: .satMathGreen,
                                 rows: model.difficultyTimes(section: "math"))
            }
        }
    }

    private func difficultyColumn(label: String, tint: Color, rows: [AnalyticsDifficultyTime]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.kCaption.weight(.bold))
                .foregroundStyle(tint)
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    Image(systemName: difficultyIcon(row.difficulty))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(difficultyColor(row.difficulty))
                        .frame(width: 16)
                    Text(SATCatalog.difficultyLabels[row.difficulty] ?? row.difficulty)
                        .font(.kCaption)
                        .foregroundStyle(Color.kTextPrimary)
                    Spacer(minLength: 4)
                    Text(row.attempts > 0 ? AnalyticsFormat.shortDuration(row.averageSeconds) : "—")
                        .font(.kCaption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.kTextPrimary)
                        .contentTransition(.numericText())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func difficultyIcon(_ difficulty: String) -> String {
        switch difficulty {
        case "H": return "bolt.fill"
        case "M": return "flame.fill"
        default: return "leaf.fill"
        }
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "H": return .kError
        case "M": return .kGold
        default: return .kSuccess
        }
    }

    // MARK: - Topics costing the most points

    @ViewBuilder
    private var costingCard: some View {
        let topics = model.costingTopics
        if !topics.isEmpty {
            SATGradientCard(title: "Topics costing the most points",
                            subtitle: "Ranked by misses and attempts",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .satCoral) {
                ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                    let tint = Color.analyticsPalette[index % Color.analyticsPalette.count]
                    HStack(spacing: Spacing.sm) {
                        Text(String(format: "%02d", index + 1))
                            .font(.kCaption.bold().monospacedDigit())
                            .foregroundStyle(tint)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(tint.opacity(0.14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(topic.skillName)
                                .font(.kSubheadline.weight(.semibold))
                                .foregroundStyle(Color.kTextPrimary)
                                .lineLimit(2)
                            Text("\(SATCatalog.sectionLabels[topic.section] ?? topic.section) · \(topic.attempts) attempt\(topic.attempts == 1 ? "" : "s")")
                                .font(.kCaption2)
                                .foregroundStyle(Color.kTextPrimary)
                        }
                        Spacer(minLength: 4)
                        Text("\(Int((topic.missRate * 100).rounded()))% missed")
                            .font(.kCaption.weight(.bold))
                            .foregroundStyle(tint)
                        Button("Practice") {
                            practice(skillCd: topic.skillCd, skillName: topic.skillName,
                                     domain: topic.domain, section: topic.section, tint: tint)
                        }
                        .font(.kCaption.bold())
                        .foregroundStyle(tint)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Pacing quadrant

    @ViewBuilder
    private var pacingCard: some View {
        let pacing = model.pacing
        if pacing.total > 0 {
            SATGradientCard(title: "Pacing",
                            subtitle: "Fast or slow vs your own median",
                            systemImage: "hare.fill",
                            tint: .satIndigo) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.xs) {
                    AnalyticsQuadrantTile(title: "Quick + right", count: pacing.fastRight,
                                          total: pacing.total, tint: .kSuccess, systemImage: "hare.fill")
                    AnalyticsQuadrantTile(title: "Quick + wrong", count: pacing.fastWrong,
                                          total: pacing.total, tint: .kError, systemImage: "exclamationmark.circle.fill")
                    AnalyticsQuadrantTile(title: "Slow + right", count: pacing.slowRight,
                                          total: pacing.total, tint: .satTeal, systemImage: "tortoise.fill")
                    AnalyticsQuadrantTile(title: "Slow + wrong", count: pacing.slowWrong,
                                          total: pacing.total, tint: .kGold, systemImage: "hourglass")
                }

                Text(pacing.headline)
                    .font(.kSubheadline.weight(.semibold))
                    .foregroundStyle(Color.kTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Accuracy by topic

    @ViewBuilder
    private func topicCard(section: String, label: String, tint: Color) -> some View {
        let domains = model.domainStats(section: section)
        if !domains.isEmpty {
            SATGradientCard(title: label,
                            subtitle: "Accuracy by topic",
                            systemImage: "chart.bar.xaxis",
                            tint: tint) {
                ForEach(domains) { domain in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(domain.domain)
                                .font(.kSubheadline.weight(.semibold))
                                .foregroundStyle(Color.kTextPrimary)
                            Text("\(domain.attempts)")
                                .font(.kCaption2.monospacedDigit())
                                .foregroundStyle(Color.kTextPrimary)
                            Spacer()
                            Text(AnalyticsFormat.percent(domain.accuracy))
                                .font(.kCaption.monospacedDigit().weight(.bold))
                                .foregroundStyle(accuracyColor(domain.accuracy))
                                .contentTransition(.numericText())
                        }
                        AnalyticsAccuracyBar(fraction: domain.accuracy, tint: accuracyColor(domain.accuracy))

                        ForEach(domain.skills.prefix(3)) { skill in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(accuracyColor(skill.accuracy).opacity(0.8))
                                    .frame(width: 5, height: 5)
                                Text(skill.skillName)
                                    .font(.kCaption2)
                                    .foregroundStyle(Color.kTextPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(AnalyticsFormat.percent(skill.accuracy)) · \(skill.attempts)")
                                    .font(.kCaption2.monospacedDigit())
                                    .foregroundStyle(Color.kTextPrimary)
                            }
                            .padding(.leading, 2)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    /// ≥85% green, 60–84% gold, below red — matches the web report's banding.
    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.85 { return .kSuccess }
        if accuracy >= 0.60 { return .kGold }
        return .kError
    }

    // MARK: - Neglected skills

    @ViewBuilder
    private var neglectedCard: some View {
        let skills = model.neglectedSkills
        if !skills.isEmpty {
            SATGradientCard(title: "Going stale",
                            subtitle: "Skills you haven't touched lately",
                            systemImage: "zzz",
                            tint: .satIndigo) {
                ForEach(Array(skills.enumerated()), id: \.element.id) { index, skill in
                    let tint = Color.analyticsPalette[(index + 5) % Color.analyticsPalette.count]
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.caption)
                            .foregroundStyle(tint)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(tint.opacity(0.14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(skill.skillName)
                                .font(.kSubheadline.weight(.semibold))
                                .foregroundStyle(Color.kTextPrimary)
                                .lineLimit(2)
                            Text(skill.daysSinceSeen.map { "\(skill.domain) · \($0) days ago" }
                                 ?? "\(skill.domain) · never attempted")
                                .font(.kCaption2)
                                .foregroundStyle(Color.kTextPrimary)
                        }
                        Spacer(minLength: 4)
                        Button("Practice") {
                            practice(skillCd: skill.skillCd, skillName: skill.skillName,
                                     domain: skill.domain, section: skill.section, tint: tint)
                        }
                        .font(.kCaption.bold())
                        .foregroundStyle(tint)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - First try vs retry

    @ViewBuilder
    private var retryCard: some View {
        let stats = model.retryStats
        if stats.retryAttempts > 0, let first = stats.firstTryAccuracy, let retry = stats.retryAccuracy {
            SATGradientCard(title: "First try vs retry",
                            subtitle: "Do your reviews stick?",
                            systemImage: "arrow.counterclockwise",
                            tint: .korahPink) {
                HStack(spacing: Spacing.sm) {
                    retryColumn(value: AnalyticsFormat.percent(first),
                                label: "First try · \(stats.firstTryAttempts)")
                    retryColumn(value: AnalyticsFormat.percent(retry),
                                label: "Retries · \(stats.retryAttempts)")
                }
                Text(retry >= first
                     ? "Retries beat first tries. Reviews are sticking, so keep redoing misses."
                     : "Retries score below first tries. Read the explanation before re-attempting.")
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func retryColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.jakarta(22, relativeTo: .title2).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.kCaption2)
                .foregroundStyle(Color.kTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Consistency heatmap

    @ViewBuilder
    private var heatmapCard: some View {
        let weeks = model.heatWeeks
        if !weeks.isEmpty {
            SATGradientCard(title: "Consistency",
                            subtitle: "Last 12 weeks of practice",
                            systemImage: "calendar",
                            tint: .satMathGreen) {
                AnalyticsHeatmap(weeks: weeks, maxCount: model.maxHeatCount)
            }
        }
    }

    // MARK: - Recent activity (moved here from the Profile dashboard)

    @ViewBuilder
    private var recentCard: some View {
        let recent = model.recentAttempts
        if !recent.isEmpty {
            SATGradientCard(title: "Recent activity",
                            systemImage: "clock.arrow.circlepath",
                            tint: .satStatBlue) {
                ForEach(recent) { attempt in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: attempt.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(attempt.correct ? Color.kSuccess : Color.kError)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attempt.domain.isEmpty ? "Question" : attempt.domain)
                                .font(.kSubheadline)
                                .foregroundStyle(Color.kTextPrimary)
                            Text("\(SATCatalog.difficultyLabels[attempt.difficulty] ?? attempt.difficulty) · \(attempt.date.formatted(.relative(presentation: .named)))")
                                .font(.kCaption2)
                                .foregroundStyle(Color.kTextPrimary)
                        }
                        Spacer()
                        Text(attempt.xp >= 0 ? "+\(attempt.xp) XP" : "\(attempt.xp) XP")
                            .font(.kCaption.bold())
                            .foregroundStyle(attempt.correct ? Color.kSuccess : Color.kError)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    // MARK: - Practice hand-off

    private func practice(skillCd: String, skillName: String, domain: String,
                          section: String, tint: Color) {
        let query = model.practiceQuery(skillCd: skillCd, domain: domain, section: section)
        staging = SATStagingConfig(
            title: skillName,
            systemImage: "scope",
            tint: tint,
            load: { await SATStaging.bank(query) })
    }
}

// MARK: - Range dropdown
// Custom pink-filled dropdown for the time-range filter, replacing the
// system Menu so it can sit inline next to the "Analytics" title.

private struct AnalyticsRangeDropdown: View {
    @Binding var selection: AnalyticsRange
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Haptics.light()
                withAnimation(KAnimation.quick) { isOpen.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.bold))
                    Text(selection.rawValue)
                        .font(.kCaption.weight(.bold))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.korahPink))
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(AnalyticsRange.allCases) { range in
                        Button {
                            Haptics.selection()
                            withAnimation(KAnimation.quick) {
                                selection = range
                                isOpen = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(range.rawValue)
                                    .font(.kCaption.weight(range == selection ? .bold : .regular))
                                Spacer(minLength: 8)
                                if range == selection {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                }
                            }
                            .foregroundStyle(range == selection ? Color.korahPink : Color.kTextPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 140)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(Color.kSurfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .stroke(Color.korahPink.opacity(0.3), lineWidth: 1)
                )
                .kShadowMedium()
                .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Analytics palette
// The design-guide vivid palette (SATRushView.cardPalette order), rotated by
// index so adjacent rows never share a hue.

extension Color {
    static let analyticsPalette: [Color] = [
        Color(red: 0.36, green: 0.42, blue: 0.95),  // indigo
        Color(red: 0.95, green: 0.45, blue: 0.35),  // coral
        Color(red: 0.20, green: 0.68, blue: 0.55),  // teal-green
        Color(red: 0.85, green: 0.35, blue: 0.62),  // magenta
        Color(red: 0.95, green: 0.62, blue: 0.20),  // amber
        Color(red: 0.30, green: 0.70, blue: 0.78),  // cyan
        Color(red: 0.55, green: 0.40, blue: 0.88),  // purple
        Color(red: 0.90, green: 0.30, blue: 0.45),  // rose
        Color(red: 0.40, green: 0.62, blue: 0.30),  // moss
        Color(red: 0.20, green: 0.55, blue: 0.90),  // blue
        Color(red: 0.93, green: 0.28, blue: 0.55),  // pink
    ]
}

// Section + accent tints, mirroring the values ProfileView and the Rush
// wizard already use (fileprivate there, so they're re-declared here).
private extension Color {
    static let satStatBlue = Color(red: 0.38, green: 0.56, blue: 0.96)
    static let satTeal = Color(red: 0.20, green: 0.68, blue: 0.66)
    static let satCoral = Color(red: 0.91, green: 0.36, blue: 0.27)
    static let korahPink = Color(red: 0.93, green: 0.35, blue: 0.60)
    static let satAmber = Color(red: 0.95, green: 0.62, blue: 0.20)
    static let satIndigo = Color(red: 0.36, green: 0.42, blue: 0.95)
    /// Subject-owned hues from the design guide: Math is green, R&W is blue.
    static let satEnglishBlue = Color(red: 0.30, green: 0.51, blue: 0.94)
    static let satMathGreen = Color(red: 0.22, green: 0.65, blue: 0.45)
}

#Preview {
    SATAnalyticsView()
        .environment(AuthManager.shared)
}
