import SwiftUI

// MARK: - Practice Rush
// Gamified practice rush (mirrors sat/rush.html): 3-step setup wizard →
// Duolingo-style check/continue loop with streaks → celebration summary.

@MainActor
@Observable
final class SATRushSession {

    enum Phase { case onboarding, loading, playing, empty, error(String), celebration }

    // Setup selection
    var subject: String?                       // "math" | "english"
    var selectedDomains: Set<String> = []      // domain codes
    var selectedSkills: Set<String> = []       // skill codes
    var selectedDifficulties: Set<String> = []
    var randomize = true
    var timeLimit = 60                         // seconds allowed per question
    var questionCount = 15                      // how many questions this rush

    // Session state
    var phase: Phase = .onboarding
    private(set) var questions: [SATQuestion] = []
    private(set) var position = 0
    var selectedAnswer: String = ""
    private(set) var checkedCurrent = false
    private(set) var lastCorrect = false

    // Stats
    private(set) var streak = 0
    private(set) var answered = 0
    private(set) var correct = 0
    private(set) var xp = 0
    private(set) var maxStreak = 0
    private(set) var totalTime = 0
    private(set) var perDomain: [String: (answered: Int, correct: Int)] = [:]

    // Per-question timer
    private(set) var questionElapsed = 0
    private var timerTask: Task<Void, Never>?
    private var hydrating: Set<Int> = []

    var sectionInfo: SATSectionInfo {
        subject == "math" ? SATCatalog.math : SATCatalog.english
    }

    var currentQuestion: SATQuestion? {
        questions.indices.contains(position) ? questions[position] : nil
    }

    var accuracy: Int { answered > 0 ? Int((Double(correct) / Double(answered) * 100).rounded()) : 0 }

    // MARK: - Setup helpers

    func toggleDomain(_ domain: SATDomainInfo) {
        let codes = domain.skills.map(\.code)
        if selectedDomains.contains(domain.code) {
            selectedDomains.remove(domain.code)
            codes.forEach { selectedSkills.remove($0) }
        } else {
            selectedDomains.insert(domain.code)
            codes.forEach { selectedSkills.insert($0) }
        }
    }

    func selectAllDomains() {
        for domain in sectionInfo.domains {
            selectedDomains.insert(domain.code)
            domain.skills.forEach { selectedSkills.insert($0.code) }
        }
    }

    func clearDomains() {
        selectedDomains.removeAll()
        selectedSkills.removeAll()
    }

    func resetSetup() {
        subject = nil
        clearDomains()
        selectedDifficulties.removeAll()
        randomize = true
        phase = .onboarding
    }

    // MARK: - Session

    func start() async {
        guard let subject else { return }
        phase = .loading
        answered = 0; correct = 0; xp = 0; streak = 0; maxStreak = 0
        totalTime = 0; perDomain = [:]; position = 0
        selectedAnswer = ""; checkedCurrent = false

        var domainNames: Set<String> = []
        for domain in sectionInfo.domains where selectedDomains.contains(domain.code) {
            domainNames.insert(domain.name)
        }
        let query = SATQuery(
            sections: [subject],
            domains: domainNames,
            skills: selectedSkills,
            difficulties: selectedDifficulties,
            assessment: "SAT",
            limit: questionCount,
            random: randomize
        )
        do {
            let response = try await SATService.shared.fetchQuestions(query)
            questions = response.questions
            guard !questions.isEmpty else {
                phase = .empty
                return
            }
            phase = .playing
            startTimer()
            await hydrateAhead()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func check() {
        guard let question = currentQuestion, !checkedCurrent,
              !selectedAnswer.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        checkedCurrent = true
        stopTimer()

        let isCorrect = SATAnswerCheck.isCorrect(question: question, answer: selectedAnswer)
        lastCorrect = isCorrect
        answered += 1
        totalTime += questionElapsed

        let domainName = question.domain.isEmpty ? "Other" : question.domain
        var bucket = perDomain[domainName] ?? (0, 0)
        bucket.answered += 1
        if isCorrect {
            bucket.correct += 1
            correct += 1
            streak += 1
            maxStreak = max(maxStreak, streak)
        } else {
            streak = 0
        }
        perDomain[domainName] = bucket

        let elapsed = questionElapsed
        Task {
            let earned = (try? await SATAnalyticsService.shared.recordAttempt(
                question: question, correct: isCorrect, timeSpent: elapsed,
                mode: "rush")) ?? 0
            xp += earned
        }
    }

    func advance() {
        guard position < questions.count - 1 else {
            finish()
            return
        }
        position += 1
        selectedAnswer = ""
        checkedCurrent = false
        startTimer()
        Task { await hydrateAhead() }
    }

    func finish() {
        stopTimer()
        phase = .celebration
    }

    // MARK: - Hydration

    private func hydrateAhead() async {
        await ensureDetail(at: position)
        for offset in 1...4 {
            let index = position + offset
            if index < questions.count {
                Task { await self.ensureDetail(at: index) }
            }
        }
    }

    func ensureDetail(at index: Int) async {
        guard questions.indices.contains(index) else { return }
        let question = questions[index]
        guard !question.loaded, !hydrating.contains(index) else { return }
        let key = question.detailKey.isEmpty ? question.id : question.detailKey
        guard !key.isEmpty else { return }
        hydrating.insert(index)
        defer { hydrating.remove(index) }
        if let detail = try? await SATService.shared.fetchDetail(id: key),
           questions.indices.contains(index), questions[index].id == question.id {
            questions[index].overlay(detail)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        questionElapsed = 0
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.questionElapsed += 1
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}

// MARK: - View

struct SATRushView: View {
    @State private var rush = SATRushSession()
    @State private var wizardStep = 1
    @State private var showExitConfirm = false
    @State private var showCalculator = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.kBackground.ignoresSafeArea()

            switch rush.phase {
            case .onboarding:
                onboarding
            case .loading:
                ScrollView {
                    SATQuestionSkeleton()
                }
                .scrollDisabled(true)
            case .playing:
                player
            case .empty:
                emptyState
            case .error(let message):
                errorState(message)
            case .celebration:
                SATRushCelebrationView(rush: rush, onAgain: {
                    rush.resetSetup()
                    wizardStep = 1
                }, onExit: { dismiss() })
            }
        }
        .navigationTitle("Practice Rush")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .playing = rush.phase {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if rush.subject == "math" {
                        Button { showCalculator = true } label: {
                            Image(systemName: "function")
                        }
                    }
                    Button { showExitConfirm = true } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .sheet(isPresented: $showCalculator) { DesmosCalculatorSheet() }
        .confirmationDialog("End this rush?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("See results", role: .destructive) { rush.finish() }
            Button("Keep going", role: .cancel) {}
        }
    }

    // MARK: - Onboarding wizard

    private var onboarding: some View {
        VStack(spacing: Spacing.lg) {
            // Step dots
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { step in
                    Capsule()
                        .fill(step == wizardStep ? stepTint : Color.kBorder)
                        .frame(width: step == wizardStep ? 24 : 8, height: 8)
                }
            }
            .padding(.top, Spacing.md)
            .animation(KAnimation.quick, value: stepTint)

            ScrollView {
                VStack(spacing: Spacing.md) {
                    switch wizardStep {
                    case 1: subjectStep
                    case 2: domainStep
                    default: difficultyStep
                    }
                }
                .padding(Spacing.md)
            }

            wizardFooter
        }
        .animation(KAnimation.standard, value: wizardStep)
    }

    private var subjectStep: some View {
        VStack(spacing: Spacing.md) {
            Text("What do you want to practice?")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)

            subjectCard(key: "math", icon: "x.squareroot", title: "Math",
                        blurb: "Algebra, advanced math, data analysis, and geometry",
                        tint: Self.mathTint)
            subjectCard(key: "english", icon: "book.fill", title: "Reading & Writing",
                        blurb: "Reading comprehension, grammar, and expression",
                        tint: Self.englishTint)
        }
    }

    private func subjectCard(key: String, icon: String, title: String, blurb: String,
                             tint: Color) -> some View {
        let selected = rush.subject == key
        return Button {
            rush.subject = key
            rush.clearDomains()
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.22))
                        )
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(selected ? 1 : 0.6))
                }
                Spacer(minLength: Spacing.md)
                Text(title)
                    .font(.kTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text(blurb)
                    .font(.kSubheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
            .padding(Spacing.lg)
            .background(
                LinearGradient(colors: [tint, tint.lightened(by: 0.18)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(.white.opacity(selected ? 0.9 : 0), lineWidth: 2.5)
            )
            .kShadowMedium()
            .scaleEffect(selected ? 1.01 : 1)
            .animation(KAnimation.quick, value: selected)
        }
        .buttonStyle(.plain)
    }

    private var domainStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Pick your topics")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            HStack(spacing: Spacing.md) {
                Button { rush.selectAllDomains(); Haptics.light() } label: {
                    Text("Select all")
                        .font(.kSubheadline.weight(.semibold))
                        .foregroundStyle(.pink)
                }
                .buttonStyle(.plain)
                Button { rush.clearDomains(); Haptics.light() } label: {
                    Text("Clear")
                        .font(.kSubheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            ForEach(Array(rush.sectionInfo.domains.enumerated()), id: \.element.id) { index, domain in
                domainCard(domain, tint: Self.cardPalette[index % Self.cardPalette.count])
            }
        }
    }

    /// A vivid colour per topic chip so no two skills read the same — keyed
    /// by skill code so the mapping is stable across re-renders.
    private var skillColors: [String: Color] {
        var map: [String: Color] = [:]
        var i = 0
        for domain in rush.sectionInfo.domains {
            for skill in domain.skills {
                map[skill.code] = Self.chipPalette[i % Self.chipPalette.count]
                i += 1
            }
        }
        return map
    }

    private func domainCard(_ domain: SATDomainInfo, tint: Color) -> some View {
        let selected = rush.selectedDomains.contains(domain.code)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                withAnimation(KAnimation.quick) { rush.toggleDomain(domain) }
                Haptics.selection()
            } label: {
                HStack {
                    Text(domain.name)
                        .font(.kHeadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(.white.opacity(selected ? 1 : 0.65))
                }
            }
            .buttonStyle(.plain)

            if selected {
                FlowLayoutChips(items: domain.skills.map { skill in
                    (skill.code, skill.name, rush.selectedSkills.contains(skill.code),
                     skillColors[skill.code] ?? tint)
                }) { code in
                    if rush.selectedSkills.contains(code) { rush.selectedSkills.remove(code) }
                    else { rush.selectedSkills.insert(code) }
                    Haptics.light()
                }
            } else {
                Text(domain.skills.prefix(3).map(\.name).joined(separator: " · "))
                    .font(.kCaption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(Spacing.md)
        .background(
            LinearGradient(colors: [tint, tint.lightened(by: 0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(.white.opacity(selected ? 0.9 : 0), lineWidth: 2)
        )
    }

    private var difficultyStep: some View {
        VStack(spacing: Spacing.md) {
            Text("Choose difficulty")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)

            ForEach(SATCatalog.difficulties, id: \.code) { difficulty in
                let selected = rush.selectedDifficulties.contains(difficulty.code)
                let tint = Self.difficultyTint(difficulty.code)
                Button {
                    if selected { rush.selectedDifficulties.remove(difficulty.code) }
                    else { rush.selectedDifficulties.insert(difficulty.code) }
                    Haptics.selection()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: Self.difficultyIcon(difficulty.code))
                            .font(.headline)
                            .foregroundStyle(selected ? .white : tint)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected ? Color.white.opacity(0.22) : tint.opacity(0.15))
                            )
                        Text(difficulty.label)
                            .font(.kHeadline)
                            .foregroundStyle(selected ? .white : Color.kTextPrimary)
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? .white : Color.kTextTertiary)
                    }
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .fill(selected
                                  ? AnyShapeStyle(LinearGradient(colors: [tint, tint.lightened(by: 0.18)],
                                                                 startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.kSurface))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .stroke(selected ? .clear : tint.opacity(0.4), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }

            SnapSlider(title: "How many questions?",
                       options: Self.countOptions,
                       value: rush.questionCount,
                       tint: .teal,
                       format: { "\($0)" }) { rush.questionCount = $0 }
                .padding(.top, Spacing.xs)

            SnapSlider(title: "How long per question?",
                       options: Self.timeOptions,
                       value: rush.timeLimit,
                       tint: .orange,
                       format: Self.timeLabel) { rush.timeLimit = $0 }
                .padding(.top, Spacing.xs)

            Toggle(isOn: $rush.randomize) {
                Text("Randomize question order")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextSecondary)
            }
            .tint(Color.kAccent)
            .padding(.horizontal, Spacing.xs)
        }
    }

    private var wizardFooter: some View {
        HStack(spacing: Spacing.sm) {
            if wizardStep > 1 {
                Button("Back") { wizardStep -= 1 }
                    .buttonStyle(.kSecondary)
                    .frame(width: 100)
            }
            Button {
                if wizardStep < 3 {
                    wizardStep += 1
                } else {
                    Task { await rush.start() }
                }
                Haptics.medium()
            } label: {
                Text(wizardStep == 3 ? "Start Rush" : "Next")
                    .font(.kBodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [stepTint, stepTint.lightened(by: 0.18)],
                                                 startPoint: .leading, endPoint: .trailing))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.4)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
        .animation(KAnimation.quick, value: stepTint)
    }

    private var canAdvance: Bool {
        switch wizardStep {
        case 1: return rush.subject != nil
        case 2: return !rush.selectedSkills.isEmpty
        default: return !rush.selectedDifficulties.isEmpty
        }
    }

    // MARK: - Wizard palette
    // Each subject and step reads in its own colour so the flow feels as
    // vivid as onboarding — Math green, Reading & Writing blue, and a
    // distinct "Next" tint per step (never the shared purple gradient).

    private static let mathTint = Color(red: 0.22, green: 0.65, blue: 0.45)     // green
    private static let englishTint = Color(red: 0.30, green: 0.51, blue: 0.94)  // blue

    /// One colour per topic card (Algebra, Advanced Math, …).
    private static let cardPalette: [Color] = [
        Color(red: 0.36, green: 0.42, blue: 0.95),  // indigo
        Color(red: 0.95, green: 0.45, blue: 0.35),  // coral
        Color(red: 0.20, green: 0.68, blue: 0.55),  // teal-green
        Color(red: 0.85, green: 0.35, blue: 0.62),  // magenta
        Color(red: 0.95, green: 0.62, blue: 0.20),  // amber
        Color(red: 0.30, green: 0.70, blue: 0.78)   // cyan
    ]

    /// A larger, distinct set for the individual skill chips.
    private static let chipPalette: [Color] = [
        Color(red: 0.36, green: 0.42, blue: 0.95),  // indigo
        Color(red: 0.95, green: 0.45, blue: 0.35),  // coral
        Color(red: 0.20, green: 0.68, blue: 0.55),  // teal-green
        Color(red: 0.85, green: 0.35, blue: 0.62),  // magenta
        Color(red: 0.95, green: 0.62, blue: 0.20),  // amber
        Color(red: 0.30, green: 0.70, blue: 0.78),  // cyan
        Color(red: 0.55, green: 0.40, blue: 0.88),  // purple
        Color(red: 0.90, green: 0.30, blue: 0.45),  // rose
        Color(red: 0.40, green: 0.62, blue: 0.30),  // moss
        Color(red: 0.20, green: 0.55, blue: 0.90)   // blue
    ]

    /// How many questions a rush runs for.
    private static let countOptions = [10, 15, 20]

    /// Time-per-question choices (30s → 3m) offered in the final setup step.
    private static let timeOptions = [30, 60, 90, 120, 180]

    private static func timeLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let minutes = Double(seconds) / 60
        return minutes == minutes.rounded() ? "\(Int(minutes))m" : String(format: "%.1fm", minutes)
    }

    private var subjectTint: Color {
        switch rush.subject {
        case "math": return Self.mathTint
        case "english": return Self.englishTint
        default: return .kAccent
        }
    }

    /// The "Next" / "Start Rush" tint for the current step — distinct per step.
    private var stepTint: Color {
        switch wizardStep {
        case 1: return subjectTint   // green or blue, matching the picked subject
        case 2: return .teal
        default: return .pink
        }
    }

    private static func difficultyTint(_ code: String) -> Color {
        switch code {
        case "E": return .kSuccess   // Easy — green
        case "M": return .kGold      // Medium — gold
        default: return .kError      // Hard — red
        }
    }

    private static func difficultyIcon(_ code: String) -> String {
        switch code {
        case "E": return "leaf.fill"
        case "M": return "flame.fill"
        default: return "bolt.fill"
        }
    }

    // MARK: - Player

    @ViewBuilder
    private var player: some View {
        if let question = rush.currentQuestion {
            VStack(spacing: 0) {
                // Progress + streak header
                let remaining = max(0, rush.timeLimit - rush.questionElapsed)
                HStack(spacing: Spacing.sm) {
                    GeometryReader { geo in
                        let total = CGFloat(max(1, rush.questions.count))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.kBorder.opacity(0.5))
                            if rush.checkedCurrent {
                                // Between questions: teal shows overall progress / points.
                                Capsule()
                                    .fill(LinearGradient(colors: [.teal, Color.teal.lightened(by: 0.2)],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(rush.answered) / total)
                                    .animation(KAnimation.standard, value: rush.answered)
                            } else {
                                // While answering: orange counts the time down.
                                let timeFraction = rush.timeLimit > 0 ? CGFloat(remaining) / CGFloat(rush.timeLimit) : 0
                                Capsule()
                                    .fill(Color.orange)
                                    .frame(width: geo.size.width * timeFraction)
                                    .animation(.linear(duration: 0.9), value: rush.questionElapsed)
                            }
                        }
                    }
                    .frame(height: 8)

                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(rush.streak > 0 ? Color.kGold : Color.kTextTertiary)
                        Text("\(rush.streak)")
                            .font(.kCaption.bold())
                            .foregroundStyle(Color.kTextSecondary)
                    }

                    Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                        .font(.kCaption.monospacedDigit())
                        .foregroundStyle(remaining <= 10 ? Color.kError : Color.orange)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        if question.loaded {
                            rushQuestionBody(question)
                        } else {
                            SATQuestionSkeleton(showPassage: false, applyPadding: false)
                                .task { await rush.ensureDetail(at: rush.position) }
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // Check / Continue button — green while checking an answer.
                let disabled = !rush.checkedCurrent && rush.selectedAnswer.trimmingCharacters(in: .whitespaces).isEmpty
                Button {
                    if rush.checkedCurrent {
                        rush.advance()
                    } else {
                        rush.check()
                        if rush.lastCorrect { Haptics.success() } else { Haptics.error() }
                    }
                } label: {
                    Text(rush.checkedCurrent ? "Continue" : "Check")
                        .font(.kBodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(rush.checkedCurrent
                                      ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.85, green: 0.24, blue: 0.52),
                                                                              Color(red: 0.96, green: 0.44, blue: 0.66)],
                                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                      : AnyShapeStyle(LinearGradient(colors: [Color.kSuccess, Color.kSuccess.lightened(by: 0.18)],
                                                                     startPoint: .leading, endPoint: .trailing)))
                        )
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .opacity(disabled ? 0.4 : 1)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private func rushQuestionBody(_ question: SATQuestion) -> some View {
        // Meta chips
        HStack(spacing: Spacing.xs) {
            if !question.domain.isEmpty {
                Text(question.domain)
                    .font(.kCaption2.weight(.semibold))
                    .foregroundStyle(Color.kAccent)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.kAccent.opacity(0.12)))
            }
            if let label = SATCatalog.difficultyLabels[question.difficulty] {
                Text(label)
                    .font(.kCaption2.weight(.semibold))
                    .foregroundStyle(Color.kTextSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.kBorder.opacity(0.4)))
            }
        }

        if !question.paragraph.isEmpty {
            HTMLContentView(html: question.paragraph, fontSize: 15)
                .padding(Spacing.sm)
                .kGlassEffect(cornerRadius: CornerRadius.md)
        }

        HTMLContentView(html: question.stem, fontSize: 17)

        if question.isSPR {
            TextField("Type your answer", text: $rush.selectedAnswer)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .disabled(rush.checkedCurrent)
                .font(.kBody)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(Color.kSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .stroke(rushSprBorder(question), lineWidth: 1.5)
                )
        } else {
            VStack(spacing: Spacing.xs) {
                ForEach(question.options) { option in
                    rushChoice(question: question, option: option)
                }
            }
        }

        if rush.checkedCurrent {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: rush.lastCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(rush.lastCorrect ? Color.kSuccess : Color.kError)
                    Text(rush.lastCorrect
                         ? congratsLine
                         : "Correct answer: \(question.correctAnswer)")
                        .font(.kHeadline)
                        .foregroundStyle(Color.kTextPrimary)
                }
                if !question.explanation.isEmpty {
                    HTMLContentView(html: question.explanation, fontSize: 14)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill((rush.lastCorrect ? Color.kSuccess : Color.kError).opacity(0.08))
            )
        }
    }

    private var congratsLine: String {
        rush.streak >= 5 ? "\(rush.streak) in a row! 🔥" :
            ["Nicely done!", "Great job!", "You nailed it!", "Perfect!", "Keep it up!"].randomElement()!
    }

    private func rushSprBorder(_ question: SATQuestion) -> Color {
        guard rush.checkedCurrent else { return Color.kBorder }
        return rush.lastCorrect ? Color.kSuccess : Color.kError
    }

    private func rushChoice(question: SATQuestion, option: SATOption) -> some View {
        let selected = rush.selectedAnswer == option.key
        let revealCorrect = rush.checkedCurrent && option.key == question.correctAnswer
        let revealWrong = rush.checkedCurrent && selected && option.key != question.correctAnswer
        let revealed = revealCorrect || revealWrong
        let revealTint = revealCorrect ? Color.kSuccess : Color.kError

        return Button {
            guard !rush.checkedCurrent else { return }
            rush.selectedAnswer = option.key
            Haptics.selection()
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text(option.key)
                    .font(.kHeadline)
                    .foregroundStyle(revealed || selected ? .white : Color.kTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(selected && !rush.checkedCurrent ? Color.kAccent : .clear))
                    .overlay(Circle().stroke(revealed ? .clear : Color.kBorder, lineWidth: 1.5))
                HTMLContentView(html: option.text, fontSize: 15,
                                 textColorOverride: revealed ? .white : nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(revealed ? revealTint : selected ? Color.kAccent.opacity(0.1) : Color.kSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(revealed ? .clear : selected ? Color.kAccent : Color.kBorder, lineWidth: selected || revealed ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty / error

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(Color.kAccent.opacity(0.7))
            Text("No questions matched those filters.")
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)
            Button("Back to setup") { rush.resetSetup(); wizardStep = 1 }
                .buttonStyle(.kSecondary)
                .frame(maxWidth: 220)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(Color.kError)
            Text(message)
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await rush.start() } }
                .buttonStyle(.kPrimary)
                .frame(maxWidth: 200)
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Celebration

struct SATRushCelebrationView: View {
    let rush: SATRushSession
    let onAgain: () -> Void
    let onExit: () -> Void

    // Solid, vivid palette — mirrors the setup wizard cards (no gradients).
    private static let indigo = Color(red: 0.36, green: 0.42, blue: 0.95)
    private static let coral = Color(red: 0.95, green: 0.45, blue: 0.35)
    private static let tealGreen = Color(red: 0.20, green: 0.68, blue: 0.55)
    private static let magenta = Color(red: 0.85, green: 0.35, blue: 0.62)
    private static let amber = Color(red: 0.95, green: 0.62, blue: 0.20)
    private static let cyan = Color(red: 0.30, green: 0.70, blue: 0.78)
    private static let pink = Color(red: 0.93, green: 0.28, blue: 0.55)

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Image("newlogo3")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
                    .padding(.top, Spacing.lg)

                Text("Rush complete!")
                    .font(.kLargeTitle)
                    .foregroundStyle(.white)

                Text(rush.answered > 0
                     ? "You answered \(rush.answered) question\(rush.answered == 1 ? "" : "s"). Keep the streak going!"
                     : "You didn't answer any questions this time.")
                    .font(.kSubheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                    statCard(icon: "target", tint: Self.indigo, value: "\(rush.accuracy)%", label: "Accuracy")
                    statCard(icon: "checkmark.circle.fill", tint: Self.tealGreen, value: "\(rush.correct)/\(rush.answered)", label: "Correct")
                    statCard(icon: "clock.fill", tint: Self.cyan, value: timeString, label: "Time")
                    statCard(icon: "bolt.fill", tint: Self.amber, value: (rush.xp >= 0 ? "+" : "") + "\(rush.xp)", label: "XP earned")
                    statCard(icon: "flame.fill", tint: Self.coral, value: "\(rush.maxStreak)", label: "Best streak")
                    statCard(icon: "books.vertical.fill", tint: Self.magenta, value: "\(rush.answered)", label: "Answered")
                }

                // Per-domain breakdown
                let entries = rush.perDomain.filter { $0.value.answered > 0 }.sorted { $0.key < $1.key }
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("By domain")
                            .font(.kHeadline)
                            .foregroundStyle(.white)
                        ForEach(Array(entries.enumerated()), id: \.element.key) { index, entry in
                            let (name, bucket) = entry
                            let percent = Int((Double(bucket.correct) / Double(bucket.answered) * 100).rounded())
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(name)
                                        .font(.kSubheadline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(bucket.correct)/\(bucket.answered) · \(percent)%")
                                        .font(.kCaption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.25))
                                        Capsule().fill(.white)
                                            .frame(width: geo.size.width * CGFloat(percent) / 100)
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .fill(Self.indigo)
                    )
                }

                Button { onAgain() } label: {
                    Text("Practice again")
                        .font(.kBodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Self.pink)
                        )
                }
                .buttonStyle(.plain)

                Button { onExit() } label: {
                    Text("Back to SAT home")
                        .font(.kBodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Self.tealGreen)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
        }
    }

    private var timeString: String {
        let minutes = rush.totalTime / 60
        let seconds = rush.totalTime % 60
        return minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
    }

    private func statCard(icon: String, tint: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
            Text(value)
                .font(.kHeadline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.kCaption2)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(tint)
        )
    }
}

// MARK: - Snapping option slider

/// A slider that snaps to a fixed set of options, showing a large read-out of
/// the current value plus tick labels beneath.
struct SnapSlider: View {
    let title: String
    let options: [Int]
    let value: Int
    let tint: Color
    let format: (Int) -> String
    let onChange: (Int) -> Void

    private var index: Int { options.firstIndex(of: value) ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(title)
                    .font(.kHeadline)
                    .foregroundStyle(Color.kTextPrimary)
                Spacer()
                Text(format(value))
                    .font(.kTitle2.weight(.bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }

            Slider(
                value: Binding(
                    get: { Double(index) },
                    set: { newValue in
                        let i = min(options.count - 1, max(0, Int(newValue.rounded())))
                        guard options.indices.contains(i), options[i] != value else { return }
                        withAnimation(KAnimation.quick) { onChange(options[i]) }
                        Haptics.selection()
                    }
                ),
                in: 0...Double(max(1, options.count - 1)),
                step: 1
            )
            .tint(tint)

            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element) { i, option in
                    Text(format(option))
                        .font(.kBody.weight(option == value ? .bold : .regular))
                        .foregroundStyle(option == value ? tint : .white)
                        .frame(maxWidth: .infinity,
                               alignment: i == 0 ? .leading : (i == options.count - 1 ? .trailing : .center))
                }
            }
        }
    }
}

// MARK: - Simple flow layout of skill chips

struct FlowLayoutChips: View {
    let items: [(code: String, label: String, selected: Bool, color: Color)]
    let onTap: (String) -> Void

    var body: some View {
        FlexibleChipLayout(spacing: 6) {
            ForEach(items, id: \.code) { item in
                Button {
                    onTap(item.code)
                } label: {
                    Text(item.label)
                        .font(.kCaption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(item.color.opacity(item.selected ? 1 : 0.55)))
                        .overlay(Capsule().stroke(.white.opacity(item.selected ? 0.95 : 0), lineWidth: 1.5))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Minimal wrapping layout for chips.
struct FlexibleChipLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
