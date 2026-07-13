import SwiftUI
import Charts
import FirebaseFirestore

// MARK: - Profile tab (Progress dashboard + settings)
// Now the home of the SAT progress analytics that used to live in
// SATDashboardView: score goals, totals, section + domain accuracy, focus
// suggestions, saved questions, recent activity — followed by the account
// preferences, sign out, and clear-data controls.

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(FirestoreStudyService.self) private var studyService
    @Environment(FirestoreConversationService.self) private var conversationService

    @State private var themeManager = ThemeManager.shared
    @State private var bank = SATBankStore.shared
    @State private var model = SATDashboardModel()

    @State private var showGoalEditor = false
    @State private var reviewQuery: SATQuery?
    @State private var showSignOutConfirm = false
    @State private var showClearDataConfirm = false
    @State private var isClearingData = false
    @State private var clearDataMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    accountCard

                    if model.isLoading && !model.hasLoadedOnce {
                        ProgressView("Loading your progress…")
                            .tint(Color.kAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.section)
                    } else if model.totals.answered == 0 && model.profile == nil {
                        emptyProgressState
                    } else {
                        scoreCard
                        statGrid
                        sectionCards
                        if let top = model.suggestions.first {
                            focusBanner(top)
                        }
                        if !model.domains.isEmpty {
                            domainChart
                        }
                        if !model.suggestions.isEmpty {
                            suggestionList
                        }
                        if !model.bookmarks.isEmpty {
                            savedSection
                        }
                        if !model.recent.isEmpty {
                            recentSection
                        }
                    }

                    preferencesCard
                    dangerCard
                    aboutCard

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
            }
            .kBackground(withStars: true)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showGoalEditor = true
                    } label: {
                        Image(systemName: "target")
                    }
                }
            }
            .sheet(isPresented: $showGoalEditor) {
                SATGoalEditorSheet(model: model)
                    .presentationDetents([.medium])
            }
            .navigationDestination(item: $reviewQuery) { query in
                SATPlayerView(query: query)
            }
            .task { await model.load() }
            .refreshable { await model.load() }
            .confirmationDialog("Sign out of Korah?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    try? authManager.logout()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete all your data?", isPresented: $showClearDataConfirm, titleVisibility: .visible) {
                Button("Delete conversations & study items", role: .destructive) {
                    Task { await clearAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your chats, flashcards, guides, and practice tests from all devices. SAT progress is kept.")
            }
            .alert("Data cleared", isPresented: Binding(
                get: { clearDataMessage != nil },
                set: { if !$0 { clearDataMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(clearDataMessage ?? "")
            }
        }
    }

    // MARK: - Account header

    private var accountCard: some View {
        HStack(spacing: Spacing.md) {
            Image("korahimg")
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.kAccent.opacity(0.4), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(authManager.currentUser?.firstName ?? "Student")
                    .font(.kHeadline)
                    .foregroundStyle(Color.kTextPrimary)
                if let email = authManager.currentUser?.email, !email.isEmpty {
                    Text(email)
                        .font(.kCaption)
                        .foregroundStyle(Color.kTextSecondary)
                }
            }
            Spacer()
        }
        .padding(Spacing.md)
        .satCard(tint: .kAccent, logo: "newlogo2")
    }

    // MARK: - Empty progress state

    private var emptyProgressState: some View {
        VStack(spacing: Spacing.md) {
            Image("korahwave")
                .resizable()
                .scaledToFit()
                .frame(height: 110)
            Text("Do your first practice")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)
            Text("Answer a few questions in the bank or a rush and your progress will show up here.")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .multilineTextAlignment(.center)
            Button("Set score goals") { showGoalEditor = true }
                .buttonStyle(.kSecondary)
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.section)
    }

    // MARK: - Score progress

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Score Goals")
                    .font(.kHeadline)
                    .foregroundStyle(Color.kTextPrimary)
                Spacer()
                Text(goalHeadline)
                    .font(.kSubheadline.bold())
                    .kGradientText()
            }

            scoreRow(label: "Reading & Writing", current: model.profile?.englishScore, goal: model.profile?.englishGoal)
            scoreRow(label: "Math", current: model.profile?.mathScore, goal: model.profile?.mathGoal)
        }
        .padding(Spacing.md)
        .satCard(tint: .kSuccess, logo: "newlogo3")
    }

    private var goalHeadline: String {
        guard let profile = model.profile,
              let current = profile.currentScore, let goal = profile.goalScore else {
            return model.profile?.goalScore != nil ? "Goal set!" : "No goal yet"
        }
        let remaining = goal - current
        return remaining <= 0 ? "Goals reached! 🎉" : "\(remaining) points to go"
    }

    private func scoreRow(label: String, current: Int?, goal: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextSecondary)
                Spacer()
                Text("\(current.map(String.init) ?? "—") / \(goal.map(String.init) ?? "—")")
                    .font(.kCaption.monospacedDigit())
                    .foregroundStyle(Color.kTextTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.kBorder.opacity(0.5))
                    if let current, let goal, goal > 200 {
                        let fraction = max(0, min(1, Double(current - 200) / Double(goal - 200)))
                        Capsule()
                            .fill(LinearGradient.kPurpleGradient)
                            .frame(width: geo.size.width * fraction)
                    }
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Stat grid

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
            statCard(icon: "checkmark.circle.fill", tint: .kSuccess, logo: "newlogo5",
                     value: "\(model.totals.answered)",
                     label: "Questions Answered")
            statCard(icon: "target", tint: .kAccent, logo: "newlogo10",
                     value: model.totals.answered > 0 ? "\(Int((model.totals.accuracy * 100).rounded()))%" : "—",
                     label: "Accuracy")
            statCard(icon: "bolt.fill", tint: .kGold, logo: "newlogo11",
                     value: model.totals.totalXP.formatted(),
                     label: "Level \(SATXP.level(for: model.totals.totalXP))")
            statCard(icon: "clock.fill", tint: .kAccentLight, logo: "newlogo12",
                     value: practiceTimeText,
                     label: "All-Time Practice")
        }
    }

    private var practiceTimeText: String {
        let seconds = model.totals.practiceTime
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    /// Mirrors `SATHomeView.statCard`: small label, large value, spacer,
    /// icon pinned bottom-trailing — at the same fixed height so every
    /// card in the grid lines up identically.
    private func statCard(icon: String, tint: Color, logo: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.kFootnote.weight(.medium))
                .foregroundStyle(Color.kTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.jakarta(30, relativeTo: .title).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 118)
        .padding(Spacing.md)
        .satCard(tint: tint, logo: logo)
    }

    // MARK: - Section cards

    private var sectionCards: some View {
        HStack(spacing: Spacing.sm) {
            sectionCard(section: "english", label: "Reading & Writing")
            sectionCard(section: "math", label: "Math")
        }
    }

    /// Mirrors `SATHomeView.actionStatCard`: label, large value, spacer,
    /// then a pill button + trailing icon pinned to the bottom.
    private func sectionCard(section: String, label: String) -> some View {
        let tint: Color = section == "english" ? .satStatBlue : .kSuccess
        let domains = model.domains.filter { $0.section == section }
        let attempts = domains.reduce(0) { $0 + $1.attempts }
        let weighted = attempts > 0
            ? domains.reduce(0.0) { $0 + $1.accuracy * Double($1.attempts) } / Double(attempts)
            : 0
        let missed = section == "english" ? model.missedEnglish : model.missedMath
        let buttonSolid = !missed.isEmpty

        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.kFootnote.weight(.medium))
                .foregroundStyle(Color.kTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(attempts > 0 ? "\(Int((weighted * 100).rounded()))%" : "—")
                .font(.jakarta(30, relativeTo: .title).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
            Spacer(minLength: 8)
            HStack(alignment: .bottom) {
                Button {
                    if missed.isEmpty {
                        reviewQuery = SATQuery(sections: [section])
                    } else {
                        reviewQuery = SATQuery(questionIds: Array(missed.prefix(20)))
                    }
                } label: {
                    Text(missed.isEmpty ? "Practice" : "Review \(missed.count)")
                        .font(.kCaption.weight(.bold))
                        .foregroundStyle(buttonSolid ? .white : Color.kTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(buttonSolid ? AnyShapeStyle(tint) : AnyShapeStyle(Color.white.opacity(0.06)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(buttonSolid ? Color.clear : Color.kBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Image(systemName: "chart.bar.fill")
                    .font(.callout)
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 150)
        .padding(Spacing.md)
        .satCard(tint: tint, logo: section == "english" ? "newlogo0" : "newlogo2")
    }

    // MARK: - Focus banner

    private func focusBanner(_ top: SATAnalyticsService.SkillSuggestion) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "scope")
                .font(.title3)
                .foregroundStyle(Color.satCoral)
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus on: \(top.skillName)")
                    .font(.kSubheadline.bold())
                    .foregroundStyle(Color.kTextPrimary)
                Text(top.attempts > 0
                     ? "\(top.domain) · \(Int((top.accuracy * 100).rounded()))% over \(top.attempts) attempt\(top.attempts == 1 ? "" : "s")"
                     : "\(top.domain) · not yet practiced")
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextSecondary)
            }
            Spacer()
            Button("Go") {
                reviewQuery = model.practiceQuery(for: top)
            }
            .font(.kCaption.bold())
            .buttonStyle(.kSecondary)
            .frame(width: 60)
        }
        .padding(Spacing.md)
        .satCard(tint: .satCoral, logo: "newlogo5")
    }

    // MARK: - Domain chart (Swift Charts)

    private var domainChart: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Accuracy by domain")
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)

            Chart(model.domains.sorted { $0.attempts > $1.attempts }) { domain in
                BarMark(
                    x: .value("Accuracy", domain.accuracy * 100),
                    y: .value("Domain", domain.domain)
                )
                .foregroundStyle(LinearGradient.kPurpleGradient)
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text("\(Int((domain.accuracy * 100).rounded()))%")
                        .font(.kCaption2)
                        .foregroundStyle(Color.kTextTertiary)
                }
            }
            // Extend past 100 so the trailing "%" annotation on a maxed-out
            // bar has room to sit inside the card instead of spilling past
            // its border.
            .chartXScale(domain: 0...120)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(Color.kTextSecondary)
                }
            }
            .frame(height: CGFloat(model.domains.count) * 42 + 20)
        }
        .padding(Spacing.md)
        .satCard(tint: .kAccent, logo: "newlogo10")
    }

    // MARK: - Suggestions

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Suggested skills")
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)

            ForEach(Array(model.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                HStack(spacing: Spacing.sm) {
                    Text("\(index + 1)")
                        .font(.kCaption.bold())
                        .foregroundStyle(Color.kAccent)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.kAccent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.skillName)
                            .font(.kSubheadline)
                            .foregroundStyle(Color.kTextPrimary)
                            .lineLimit(2)
                        Text("\(suggestion.domain) · \(SATCatalog.sectionLabels[suggestion.section] ?? suggestion.section)")
                            .font(.kCaption2)
                            .foregroundStyle(Color.kTextTertiary)
                    }
                    Spacer()
                    Text(suggestion.attempts > 0
                         ? "\(Int((suggestion.accuracy * 100).rounded()))%"
                         : "New")
                        .font(.kCaption)
                        .foregroundStyle(Color.kTextSecondary)
                    Button("Practice") {
                        reviewQuery = model.practiceQuery(for: suggestion)
                    }
                    .font(.kCaption.bold())
                    .foregroundStyle(Color.kAccent)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(Spacing.md)
        .satCard(tint: .kGold, logo: "newlogo11")
    }

    // MARK: - Saved questions

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Saved questions")
                    .font(.kHeadline)
                    .foregroundStyle(Color.kTextPrimary)
                Spacer()
                Button("Practice all") {
                    let ids = model.bookmarks.map(\.questionId).prefix(50)
                    reviewQuery = SATQuery(questionIds: Array(ids))
                }
                .font(.kCaption.bold())
                .foregroundStyle(Color.kAccent)
            }

            ForEach(model.bookmarks.prefix(6)) { bookmark in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(Color.kGold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bookmark.domain.isEmpty ? "Question" : bookmark.domain)
                            .font(.kSubheadline)
                            .foregroundStyle(Color.kTextPrimary)
                        Text(SATCatalog.sectionLabels[bookmark.section] ?? bookmark.section)
                            .font(.kCaption2)
                            .foregroundStyle(Color.kTextTertiary)
                    }
                    Spacer()
                    Button("Open") {
                        reviewQuery = SATQuery(questionIds: [bookmark.questionId])
                    }
                    .font(.kCaption.bold())
                    .foregroundStyle(Color.kAccent)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(Spacing.md)
        .satCard(tint: .kGold, logo: "newlogo12")
    }

    // MARK: - Recent activity

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Recent activity")
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)

            ForEach(model.recent) { attempt in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: attempt.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(attempt.correct ? Color.kSuccess : Color.kError)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(attempt.domain.isEmpty ? "Question" : attempt.domain)
                            .font(.kSubheadline)
                            .foregroundStyle(Color.kTextPrimary)
                        Text("\(SATCatalog.difficultyLabels[attempt.difficulty] ?? attempt.difficulty) · \(relativeTime(attempt.ts))")
                            .font(.kCaption2)
                            .foregroundStyle(Color.kTextTertiary)
                    }
                    Spacer()
                    Text(attempt.xp >= 0 ? "+\(attempt.xp) XP" : "\(attempt.xp) XP")
                        .font(.kCaption.bold())
                        .foregroundStyle(attempt.correct ? Color.kSuccess : Color.kError)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(Spacing.md)
        .satCard(tint: .satStatBlue, logo: "newlogo0")
    }

    private func relativeTime(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter.satShared.date(from: iso)
                ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        return date.formatted(.relative(presentation: .named))
    }

    // MARK: - Preferences

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Preferences")
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)

            HStack {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextPrimary)
                Spacer()
                Picker("", selection: $themeManager.themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.kAccent)
            }

            Divider().overlay(Color.kBorder.opacity(0.4))

            HStack {
                Label("Assessment", systemImage: "graduationcap")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextPrimary)
                Spacer()
                Picker("", selection: $bank.assessment) {
                    ForEach(SATCatalog.assessments, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
                .tint(Color.kAccent)
            }
        }
        .padding(Spacing.md)
        .satCard(tint: .kAccent, logo: "newlogo3")
    }

    // MARK: - Danger zone

    private var dangerCard: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                showClearDataConfirm = true
            } label: {
                HStack {
                    if isClearingData {
                        ProgressView()
                        Text("Clearing…")
                            .foregroundStyle(Color.kTextPrimary)
                    } else {
                        Label("Clear all data", systemImage: "trash")
                            .foregroundStyle(Color.kError)
                    }
                    Spacer()
                }
                .font(.kSubheadline)
            }
            .disabled(isClearingData)

            Divider().overlay(Color.kBorder.opacity(0.4))

            Button {
                showSignOutConfirm = true
            } label: {
                HStack {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Color.kError)
                    Spacer()
                }
                .font(.kSubheadline)
            }
        }
        .padding(Spacing.md)
        .satCard(tint: .satCoral, logo: "newlogo5")
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Version")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextSecondary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextTertiary)
            }
            Text("Korah is 100% free. Your data is yours.")
                .font(.kCaption2)
                .foregroundStyle(Color.kTextTertiary)
        }
        .padding(Spacing.md)
        .satCard(tint: .satStatBlue, logo: "newlogo2")
    }

    // MARK: - Clear data (mirrors web clearAllData: conversations + study items)

    private func clearAllData() async {
        guard let uid = authManager.currentUser?.id else { return }
        isClearingData = true
        defer { isClearingData = false }

        let db = Firestore.firestore()
        let collections = ["conversations", "flashcardSets", "studyGuides", "practiceTests"]
        var deleted = 0
        for name in collections {
            if let snapshot = try? await db.collection("users").document(uid)
                .collection(name).getDocuments() {
                for document in snapshot.documents {
                    try? await document.reference.delete()
                    deleted += 1
                }
            }
        }
        clearDataMessage = "Deleted \(deleted) item\(deleted == 1 ? "" : "s")."
        Haptics.success()
    }
}

// MARK: - Dashboard model

@MainActor
@Observable
final class SATDashboardModel {
    private(set) var profile: SATProfile?
    private(set) var totals = SATTotals()
    private(set) var suggestions: [SATAnalyticsService.SkillSuggestion] = []
    private(set) var domains: [SATAnalyticsService.DomainAccuracy] = []
    private(set) var recent: [SATAttempt] = []
    private(set) var bookmarks: [SATBookmark] = []
    private(set) var missedEnglish: [String] = []
    private(set) var missedMath: [String] = []
    private(set) var isLoading = false
    private(set) var hasLoadedOnce = false

    func load() async {
        isLoading = true
        defer { isLoading = false; hasLoadedOnce = true }
        let service = SATAnalyticsService.shared
        async let profileTask = try? service.getProfile()
        async let totalsTask = try? service.getTotals()
        async let suggestionsTask = try? service.suggestSkills(top: 6)
        async let domainsTask = try? service.getDomainBreakdown()
        async let recentTask = try? service.getRecentAttempts(limit: 8)
        async let bookmarksTask = try? service.getBookmarks()
        async let missedTask = try? service.getMissedBySection(limitPerSection: 50)

        profile = await profileTask
        totals = await totalsTask ?? SATTotals()
        suggestions = await suggestionsTask ?? []
        domains = (await domainsTask ?? []).filter { $0.attempts > 0 }
        recent = await recentTask ?? []
        bookmarks = (await bookmarksTask ?? []).sorted { $0.ts > $1.ts }
        if let missed = await missedTask {
            missedEnglish = missed.english
            missedMath = missed.math
        }
    }

    func practiceQuery(for suggestion: SATAnalyticsService.SkillSuggestion) -> SATQuery {
        SATQuery(
            sections: [suggestion.section],
            domains: [suggestion.domain],
            skills: [suggestion.skillCd],
            limit: 10
        )
    }

    func saveGoals(englishScore: Int?, englishGoal: Int?, mathScore: Int?, mathGoal: Int?) async {
        try? await SATAnalyticsService.shared.saveProfile(
            mathScore: mathScore, englishScore: englishScore,
            mathGoal: mathGoal, englishGoal: englishGoal)
        await load()
    }
}

// MARK: - Goal editor sheet

struct SATGoalEditorSheet: View {
    let model: SATDashboardModel
    @Environment(\.dismiss) private var dismiss

    @State private var englishCurrent = ""
    @State private var englishGoal = ""
    @State private var mathCurrent = ""
    @State private var mathGoal = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading & Writing (200–800)") {
                    TextField("Current score", text: $englishCurrent)
                        .keyboardType(.numberPad)
                    TextField("Goal score", text: $englishGoal)
                        .keyboardType(.numberPad)
                }
                Section("Math (200–800)") {
                    TextField("Current score", text: $mathCurrent)
                        .keyboardType(.numberPad)
                    TextField("Goal score", text: $mathGoal)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Score Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await model.saveGoals(
                                englishScore: Int(englishCurrent),
                                englishGoal: Int(englishGoal),
                                mathScore: Int(mathCurrent),
                                mathGoal: Int(mathGoal))
                            dismiss()
                        }
                    }
                    .disabled(Int(englishGoal) == nil && Int(mathGoal) == nil)
                }
            }
            .onAppear {
                englishCurrent = model.profile?.englishScore.map(String.init) ?? ""
                englishGoal = model.profile?.englishGoal.map(String.init) ?? ""
                mathCurrent = model.profile?.mathScore.map(String.init) ?? ""
                mathGoal = model.profile?.mathGoal.map(String.init) ?? ""
            }
        }
    }
}

// MARK: - Profile palette

private extension Color {
    /// Coral/red-orange used for error + focus call-to-actions.
    static let satCoral = Color(red: 0.91, green: 0.36, blue: 0.27)
    /// Blue used for the "attempted" and momentum accents.
    static let satStatBlue = Color(red: 0.38, green: 0.56, blue: 0.96)
}
