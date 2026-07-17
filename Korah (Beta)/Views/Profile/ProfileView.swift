import SwiftUI
import Charts
import FirebaseFirestore
import PhotosUI

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
    @State private var pfpStore = ProfileImageStore.shared

    @State private var showGoalEditor = false
    @State private var staging: SATStagingConfig?
    @State private var reviewQuery: SATQuery?
    @State private var showSignOutConfirm = false
    @State private var showClearDataConfirm = false
    @State private var isClearingData = false
    @State private var clearDataMessage: String?
    @State private var pfpPickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    accountCard(scrollProxy: scrollProxy)

                    if model.isLoading && !model.hasLoadedOnce {
                        SATProfileSkeleton()
                    } else if model.totals.answered == 0 && model.profile == nil {
                        emptyProgressState
                    } else {
                        scoreCard

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            sectionHeader("My Stats", systemImage: "chart.bar.fill", tint: .satStatBlue)
                            statGrid
                        }

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            sectionHeader("Section Breakdown", systemImage: "chart.bar.xaxis", tint: .satTeal)
                            sectionCards
                            if !model.domains.isEmpty {
                                domainChart
                            }
                        }

                        if let top = model.suggestions.first {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                sectionHeader("Focus & Skills", systemImage: "scope", tint: .satCoral)
                                focusBanner(top)
                                if !model.suggestions.isEmpty {
                                    suggestionList
                                }
                            }
                        }

                        if !model.bookmarks.isEmpty || !model.recent.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                sectionHeader("Saved & Activity", systemImage: "bookmark.fill", tint: .kGold)
                                if !model.bookmarks.isEmpty {
                                    savedSection
                                }
                                if !model.recent.isEmpty {
                                    recentSection
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        sectionHeader("Settings", systemImage: "gearshape.fill", tint: .korahPink)
                        preferencesCard
                        dangerCard.id("accountSection")
                        aboutCard
                    }

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
            .navigationDestination(item: $reviewQuery) { query in
                SATPlayerView(query: query)
            }
            .task { await model.load() }
            .task { pfpStore.load(for: authManager.currentUser?.id ?? "") }
            .refreshable { await model.load() }
            .onChange(of: pfpPickerItem) { _, newItem in
                guard let newItem, let uid = authManager.currentUser?.id else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        pfpStore.save(uiImage, for: uid)
                    }
                    pfpPickerItem = nil
                }
            }
            .alert("Data cleared", isPresented: Binding(
                get: { clearDataMessage != nil },
                set: { if !$0 { clearDataMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(clearDataMessage ?? "")
            }
            .overlay {
                if showSignOutConfirm {
                    KConfirmationPopup(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Sign out of Korah?",
                        message: "You can always sign back in with the same account.",
                        confirmTitle: "Sign Out",
                        onConfirm: {
                            showSignOutConfirm = false
                            try? authManager.logout()
                        },
                        onCancel: { showSignOutConfirm = false }
                    )
                } else if showClearDataConfirm {
                    KConfirmationPopup(
                        icon: "trash",
                        title: "Delete all your data?",
                        message: "This permanently deletes your chats, flashcards, guides, and practice tests from all devices. SAT progress is kept.",
                        confirmTitle: "Delete Everything",
                        onConfirm: {
                            showClearDataConfirm = false
                            Task { await clearAllData() }
                        },
                        onCancel: { showClearDataConfirm = false }
                    )
                } else if showGoalEditor {
                    SATGoalEditorPopup(model: model, onClose: { showGoalEditor = false })
                } else if let staging {
                    SATStagingPopup(
                        config: staging,
                        onStart: { ids in reviewQuery = SATQuery(questionIds: ids) },
                        onClose: { self.staging = nil }
                    )
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSignOutConfirm)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showClearDataConfirm)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showGoalEditor)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: staging != nil)
            }
        }
    }

    // MARK: - Account header

    private func accountCard(scrollProxy: ScrollViewProxy) -> some View {
        HStack(spacing: Spacing.md) {
            PhotosPicker(selection: $pfpPickerItem, matching: .images) {
                avatarView
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { scrollProxy.scrollTo("accountSection", anchor: .top) }
            } label: {
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authManager.currentUser?.firstName ?? "Student")
                            .font(.kHeadline)
                            .foregroundStyle(.white)
                        if let email = authManager.currentUser?.email, !email.isEmpty {
                            Text(email)
                                .font(.kCaption)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.kAccent, Color.kAccentLight],
                           startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.kAccent.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        if let uiImage = pfpStore.image {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Image("newlogo2")
                .resizable()
                .scaledToFit()
                .padding(9)
                .background(Color.white.opacity(0.18))
        }
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

    // MARK: - Section header

    /// A small labelled divider between groups of cards — mirrors
    /// `SATHomeView.sectionHeader` so both dashboards read the same way.
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

    // MARK: - Score progress

    private var scoreCard: some View {
        SATGradientCard(title: "Score Goals",
                        subtitle: goalHeadline,
                        systemImage: "target",
                        tint: .kSuccess) {
            scoreRow(label: "Reading & Writing", current: model.profile?.englishScore, goal: model.profile?.englishGoal, tint: .satStatBlue)
            scoreRow(label: "Math", current: model.profile?.mathScore, goal: model.profile?.mathGoal, tint: .kSuccess)

            SATCardButton(title: "Update goals", tint: .kSuccess) {
                showGoalEditor = true
            }
        }
    }

    private var goalHeadline: String {
        guard let profile = model.profile,
              let current = profile.currentScore, let goal = profile.goalScore else {
            return model.profile?.goalScore != nil ? "Goal set!" : "No goal yet"
        }
        let remaining = goal - current
        return remaining <= 0 ? "Goals reached! 🎉" : "\(remaining) points to go"
    }

    private func scoreRow(label: String, current: Int?, goal: Int?, tint: Color) -> some View {
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
                            .fill(tint)
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
            statCard(icon: "checkmark.circle.fill", tint: .kSuccess,
                     value: "\(model.totals.answered)",
                     label: "Questions Answered",
                     action: {
                         staging = SATStagingConfig(
                            title: "Questions Attempted",
                            systemImage: "checkmark.circle.fill",
                            tint: .kSuccess,
                            load: { await SATStaging.attempted() })
                     })
            statCard(icon: "target", tint: .satStatBlue,
                     value: model.totals.answered > 0 ? "\(Int((model.totals.accuracy * 100).rounded()))%" : "—",
                     label: "Accuracy")
            statCard(icon: "bolt.fill", tint: .kGold,
                     value: model.totals.totalXP.formatted(),
                     label: "Level \(SATXP.level(for: model.totals.totalXP))")
            statCard(icon: "clock.fill", tint: .korahPink,
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
    @ViewBuilder
    private func statCard(icon: String, tint: Color, value: String, label: String,
                          hint: String? = nil, action: (() -> Void)? = nil) -> some View {
        let card = SATGradientCard(title: label, systemImage: icon, tint: tint, compact: true) {
            Text(value)
                .font(.jakarta(24, relativeTo: .title2).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let hint {
                Text(hint)
                    .font(.kCaption.weight(.bold))
                    .foregroundStyle(tint)
            }
        }
        if let action {
            Button(action: action) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }

    // MARK: - Section cards

    private var sectionCards: some View {
        HStack(spacing: Spacing.sm) {
            sectionCard(section: "english", label: "Reading & Writing")
            sectionCard(section: "math", label: "Math")
        }
    }

    /// A per-section accuracy tile with a Practice / Review button.
    private func sectionCard(section: String, label: String) -> some View {
        let tint: Color = section == "english" ? .satStatBlue : .kSuccess
        let domains = model.domains.filter { $0.section == section }
        let attempts = domains.reduce(0) { $0 + $1.attempts }
        let weighted = attempts > 0
            ? domains.reduce(0.0) { $0 + $1.accuracy * Double($1.attempts) } / Double(attempts)
            : 0
        let missed = section == "english" ? model.missedEnglish : model.missedMath

        return SATGradientCard(title: label, systemImage: "chart.bar.fill", tint: tint) {
            Text(attempts > 0 ? "\(Int((weighted * 100).rounded()))%" : "—")
                .font(.jakarta(30, relativeTo: .title).weight(.bold))
                .foregroundStyle(Color.kTextPrimary)

            SATCardButton(title: missed.isEmpty ? "Practice" : "Review \(missed.count)", tint: tint) {
                staging = SATStagingConfig(
                    title: label,
                    systemImage: "chart.bar.fill",
                    tint: tint,
                    load: { await SATStaging.section(section) })
            }
        }
    }

    // MARK: - Focus banner

    private func focusBanner(_ top: SATAnalyticsService.SkillSuggestion) -> some View {
        SATGradientCard(title: "Focus Skill",
                        subtitle: top.skillName,
                        systemImage: "scope",
                        tint: .satCoral) {
            Text(top.attempts > 0
                 ? "\(top.domain) · \(Int((top.accuracy * 100).rounded()))% over \(top.attempts) attempt\(top.attempts == 1 ? "" : "s")"
                 : "\(top.domain) · not yet practiced")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SATCardButton(title: "Practice this skill", tint: .satCoral) {
                let query = model.practiceQuery(for: top)
                staging = SATStagingConfig(
                    title: top.skillName,
                    systemImage: "scope",
                    tint: .satCoral,
                    load: { await SATStaging.bank(query) })
            }
        }
    }

    // MARK: - Domain chart (Swift Charts)

    private var domainChart: some View {
        SATGradientCard(title: "Accuracy by domain",
                        systemImage: "chart.bar.xaxis",
                        tint: .satTeal) {
            Chart(model.domains.sorted { $0.attempts > $1.attempts }) { domain in
                BarMark(
                    x: .value("Accuracy", domain.accuracy * 100),
                    y: .value("Domain", domain.domain)
                )
                .foregroundStyle(by: .value("Domain", domain.domain))
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text("\(Int((domain.accuracy * 100).rounded()))%")
                        .font(.kCaption2)
                        .foregroundStyle(Color.kTextTertiary)
                }
            }
            // Solid, distinct colour per domain (no gradient).
            .chartForegroundStyleScale(range: Self.domainBarColors)
            .chartLegend(.hidden)
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
    }

    // MARK: - Suggestions

    private var suggestionList: some View {
        SATGradientCard(title: "Suggested skills",
                        systemImage: "lightbulb.fill",
                        tint: .kGold) {
            ForEach(Array(model.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                HStack(spacing: Spacing.sm) {
                    Text("\(index + 1)")
                        .font(.kCaption.bold())
                        .foregroundStyle(Color.kGold)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.kGold.opacity(0.12)))
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
                        let query = model.practiceQuery(for: suggestion)
                        staging = SATStagingConfig(
                            title: suggestion.skillName,
                            systemImage: "lightbulb.fill",
                            tint: .kGold,
                            load: { await SATStaging.bank(query) })
                    }
                    .font(.kCaption.bold())
                    .foregroundStyle(Color.kGold)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Saved questions

    private var savedSection: some View {
        SATGradientCard(title: "Saved questions",
                        systemImage: "bookmark.fill",
                        tint: .kGold) {
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
                    .foregroundStyle(Color.kGold)
                }
                .padding(.vertical, 3)
            }

            SATCardButton(title: "Practice all saved", tint: .kGold) {
                staging = SATStagingConfig(
                    title: "Saved Questions",
                    systemImage: "bookmark.fill",
                    tint: .kGold,
                    load: { await SATStaging.bookmarks() })
            }
        }
    }

    // MARK: - Recent activity

    private var recentSection: some View {
        SATGradientCard(title: "Recent activity",
                        systemImage: "clock.arrow.circlepath",
                        tint: .satStatBlue) {
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
    }

    private func relativeTime(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter.satShared.date(from: iso)
                ?? ISO8601DateFormatter().date(from: iso) else { return "" }
        return date.formatted(.relative(presentation: .named))
    }

    // MARK: - Preferences

    private var preferencesCard: some View {
        SATGradientCard(title: "Preferences",
                        systemImage: "gearshape.fill",
                        tint: .korahPink) {
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
                .tint(Color.korahPink)
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
                .tint(Color.korahPink)
            }
        }
    }

    // MARK: - Danger zone

    private var dangerCard: some View {
        SATGradientCard(title: "Account",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        tint: .satCoral) {
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
    }

    // MARK: - About

    private var aboutCard: some View {
        SATGradientCard(title: "About",
                        systemImage: "info.circle.fill",
                        tint: .satStatBlue) {
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

struct SATGoalEditorPopup: View {
    let model: SATDashboardModel
    let onClose: () -> Void

    @State private var englishCurrent: Int?
    @State private var englishGoal: Int?
    @State private var mathCurrent: Int?
    @State private var mathGoal: Int?

    // Solid, vivid section tints — matching the Practice Rush subject cards.
    private static let englishTint = Color(red: 0.30, green: 0.51, blue: 0.94)  // blue
    private static let mathTint = Color(red: 0.22, green: 0.65, blue: 0.45)     // green

    private var canSave: Bool { englishGoal != nil || mathGoal != nil }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: Spacing.md) {
                Text("Score Goals")
                    .font(.kTitle3.weight(.bold))
                    .foregroundStyle(Color.kTextPrimary)

                section(title: "Reading & Writing", tint: Self.englishTint,
                        current: $englishCurrent, goal: $englishGoal)
                section(title: "Math", tint: Self.mathTint,
                        current: $mathCurrent, goal: $mathGoal)

                VStack(spacing: Spacing.xs) {
                    Button {
                        Task {
                            await model.saveGoals(
                                englishScore: englishCurrent, englishGoal: englishGoal,
                                mathScore: mathCurrent, mathGoal: mathGoal)
                        }
                        Haptics.success()
                        onClose()
                    } label: {
                        Text("Save goals")
                            .font(.kSubheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.kSuccess))
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)

                    Button(action: onClose) {
                        Text("Cancel")
                            .font(.kSubheadline.weight(.semibold))
                            .foregroundStyle(Color.kTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.kSurface))
                    }
                }
            }
            .padding(Spacing.lg)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.kSurfaceElevated))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.kBorder.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
            .padding(.horizontal, Spacing.lg)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .onAppear {
            englishCurrent = model.profile?.englishScore
            englishGoal = model.profile?.englishGoal
            mathCurrent = model.profile?.mathScore
            mathGoal = model.profile?.mathGoal
        }
    }

    private func section(title: String, tint: Color,
                         current: Binding<Int?>, goal: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.kHeadline)
                .foregroundStyle(.white)
            ScoreSlider(label: "Current", value: current)
            ScoreSlider(label: "Goal", value: goal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous).fill(tint))
    }
}

// MARK: - Score slider

/// A range slider for picking an SAT score (200–800 in steps of 10), styled
/// for a solid coloured card with a large white read-out — mirrors the
/// onboarding `SnapSlider`.
private struct ScoreSlider: View {
    let label: String
    @Binding var value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.kCaption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(value.map(String.init) ?? "—")
                    .font(.kHeadline.monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            Slider(
                value: Binding(
                    get: { Double(value ?? 200) },
                    set: { newValue in
                        let snapped = min(800, max(200, (Int(newValue.rounded()) / 10) * 10))
                        guard snapped != value else { return }
                        value = snapped
                        Haptics.selection()
                    }
                ),
                in: 200...800,
                step: 10
            )
            .tint(.white)
        }
    }
}

// MARK: - Profile palette

private extension Color {
    /// Coral/red-orange used for error + focus call-to-actions.
    static let satCoral = Color(red: 0.91, green: 0.36, blue: 0.27)
    /// Blue used for the "attempted" and momentum accents.
    static let satStatBlue = Color(red: 0.38, green: 0.56, blue: 0.96)
    /// Teal used for the account header and domain chart.
    static let satTeal = Color(red: 0.20, green: 0.68, blue: 0.66)
    /// Pink/rose used for the "All-Time Practice" stat and preferences card.
    static let korahPink = Color(red: 0.93, green: 0.35, blue: 0.60)
}

private extension ProfileView {
    /// A rotating palette of muted, distinct colours so each bar in the
    /// "Accuracy by domain" chart reads as its own solid colour.
    static let domainBarColors: [Color] = [
        Color(red: 0.38, green: 0.56, blue: 0.96),  // blue
        Color(red: 0.24, green: 0.72, blue: 0.51),  // green
        Color(red: 0.95, green: 0.70, blue: 0.28),  // gold
        Color(red: 0.91, green: 0.42, blue: 0.36),  // coral
        Color(red: 0.72, green: 0.45, blue: 0.28),  // terracotta
        Color(red: 0.30, green: 0.72, blue: 0.78),  // teal
        Color(red: 0.90, green: 0.47, blue: 0.72),  // pink
        Color(red: 0.56, green: 0.62, blue: 0.72),  // slate
    ]
}
