import SwiftUI

// MARK: - Practice Rush
// Endless gamified practice (mirrors sat/rush.html): 3-step setup wizard →
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
            limit: nil,
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
                question: question, correct: isCorrect, timeSpent: elapsed)) ?? 0
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
        for offset in 1...3 {
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
                ProgressView("Loading questions…")
                    .tint(Color.kAccent)
                    .foregroundStyle(Color.kTextSecondary)
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
                        .fill(step == wizardStep ? Color.kAccent : Color.kBorder)
                        .frame(width: step == wizardStep ? 24 : 8, height: 8)
                }
            }
            .padding(.top, Spacing.md)

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
                        blurb: "Algebra, advanced math, data analysis, geometry")
            subjectCard(key: "english", icon: "book.fill", title: "Reading & Writing",
                        blurb: "Reading comprehension, grammar, and expression")
        }
    }

    private func subjectCard(key: String, icon: String, title: String, blurb: String) -> some View {
        let selected = rush.subject == key
        return Button {
            rush.subject = key
            rush.clearDomains()
            Haptics.selection()
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(Color.kAccent)
                Text(title)
                    .font(.kHeadline)
                    .foregroundStyle(Color.kTextPrimary)
                Text(blurb)
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .kGlassEffect(cornerRadius: CornerRadius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(selected ? Color.kAccent : .clear, lineWidth: 2)
            )
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

            HStack {
                Button("Select all") { rush.selectAllDomains(); Haptics.light() }
                    .buttonStyle(.kGhost)
                Button("Clear") { rush.clearDomains(); Haptics.light() }
                    .buttonStyle(.kGhost)
                Spacer()
            }

            ForEach(rush.sectionInfo.domains) { domain in
                domainCard(domain)
            }
        }
    }

    private func domainCard(_ domain: SATDomainInfo) -> some View {
        let selected = rush.selectedDomains.contains(domain.code)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                withAnimation(KAnimation.quick) { rush.toggleDomain(domain) }
                Haptics.selection()
            } label: {
                HStack {
                    Text(domain.name)
                        .font(.kHeadline)
                        .foregroundStyle(Color.kTextPrimary)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.kAccent : Color.kTextTertiary)
                }
            }
            .buttonStyle(.plain)

            if selected {
                FlowLayoutChips(items: domain.skills.map { skill in
                    (skill.code, skill.name, rush.selectedSkills.contains(skill.code))
                }) { code in
                    if rush.selectedSkills.contains(code) { rush.selectedSkills.remove(code) }
                    else { rush.selectedSkills.insert(code) }
                    Haptics.light()
                }
            } else {
                Text(domain.skills.prefix(3).map(\.name).joined(separator: " · "))
                    .font(.kCaption2)
                    .foregroundStyle(Color.kTextTertiary)
                    .lineLimit(1)
            }
        }
        .padding(Spacing.md)
        .kGlassEffect(cornerRadius: CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(selected ? Color.kAccent.opacity(0.6) : .clear, lineWidth: 1.5)
        )
    }

    private var difficultyStep: some View {
        VStack(spacing: Spacing.md) {
            Text("Choose difficulty")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)

            ForEach(SATCatalog.difficulties, id: \.code) { difficulty in
                let selected = rush.selectedDifficulties.contains(difficulty.code)
                Button {
                    if selected { rush.selectedDifficulties.remove(difficulty.code) }
                    else { rush.selectedDifficulties.insert(difficulty.code) }
                    Haptics.selection()
                } label: {
                    HStack {
                        Text(difficulty.label)
                            .font(.kHeadline)
                            .foregroundStyle(Color.kTextPrimary)
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? Color.kAccent : Color.kTextTertiary)
                    }
                    .padding(Spacing.md)
                    .kGlassEffect(cornerRadius: CornerRadius.lg)
                }
                .buttonStyle(.plain)
            }

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
            Button(wizardStep == 3 ? "Start Rush" : "Next") {
                if wizardStep < 3 {
                    wizardStep += 1
                } else {
                    Task { await rush.start() }
                }
                Haptics.medium()
            }
            .buttonStyle(.kPrimary)
            .disabled(!canAdvance)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    private var canAdvance: Bool {
        switch wizardStep {
        case 1: return rush.subject != nil
        case 2: return !rush.selectedSkills.isEmpty
        default: return !rush.selectedDifficulties.isEmpty
        }
    }

    // MARK: - Player

    @ViewBuilder
    private var player: some View {
        if let question = rush.currentQuestion {
            VStack(spacing: 0) {
                // Progress + streak header
                HStack(spacing: Spacing.sm) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.kBorder.opacity(0.5))
                            Capsule()
                                .fill(LinearGradient.kPurpleGradient)
                                .frame(width: geo.size.width * CGFloat(rush.position) / CGFloat(max(1, rush.questions.count)))
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

                    Text(String(format: "%d:%02d", rush.questionElapsed / 60, rush.questionElapsed % 60))
                        .font(.kCaption.monospacedDigit())
                        .foregroundStyle(Color.kTextTertiary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        if question.loaded {
                            rushQuestionBody(question)
                        } else {
                            ProgressView()
                                .tint(Color.kAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.section)
                                .task { await rush.ensureDetail(at: rush.position) }
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, Spacing.md)
                }

                // Check / Continue button
                Button {
                    if rush.checkedCurrent {
                        rush.advance()
                    } else {
                        rush.check()
                        if rush.lastCorrect { Haptics.success() } else { Haptics.error() }
                    }
                } label: {
                    Text(rush.checkedCurrent ? "Continue" : "Check")
                }
                .buttonStyle(.kPrimary)
                .disabled(!rush.checkedCurrent && rush.selectedAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
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

        return Button {
            guard !rush.checkedCurrent else { return }
            rush.selectedAnswer = option.key
            Haptics.selection()
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text(option.key)
                    .font(.kHeadline)
                    .foregroundStyle(revealCorrect ? Color.kSuccess : revealWrong ? Color.kError : selected ? .white : Color.kTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(selected && !rush.checkedCurrent ? Color.kAccent : .clear))
                    .overlay(Circle().stroke(revealCorrect ? Color.kSuccess : revealWrong ? Color.kError : Color.kBorder, lineWidth: 1.5))
                HTMLContentView(html: option.text, fontSize: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(revealCorrect ? Color.kSuccess.opacity(0.1) : revealWrong ? Color.kError.opacity(0.1) : selected ? Color.kAccent.opacity(0.1) : Color.kSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(revealCorrect ? Color.kSuccess : revealWrong ? Color.kError : selected ? Color.kAccent : Color.kBorder, lineWidth: selected || revealCorrect || revealWrong ? 1.5 : 1)
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

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Image("korahcheer")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
                    .padding(.top, Spacing.lg)

                Text("Rush complete!")
                    .font(.kLargeTitle)
                    .kGradientText()

                Text(rush.answered > 0
                     ? "You answered \(rush.answered) question\(rush.answered == 1 ? "" : "s"). Keep the streak going!"
                     : "You didn't answer any questions this time.")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextSecondary)
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                    statCard(icon: "target", tint: .kAccent, value: "\(rush.accuracy)%", label: "Accuracy")
                    statCard(icon: "checkmark.circle.fill", tint: .kSuccess, value: "\(rush.correct)/\(rush.answered)", label: "Correct")
                    statCard(icon: "clock.fill", tint: .kAccentLight, value: timeString, label: "Time")
                    statCard(icon: "bolt.fill", tint: .kGold, value: (rush.xp >= 0 ? "+" : "") + "\(rush.xp)", label: "XP earned")
                    statCard(icon: "flame.fill", tint: .kError, value: "\(rush.maxStreak)", label: "Best streak")
                    statCard(icon: "books.vertical.fill", tint: .kAccent, value: "\(rush.answered)", label: "Answered")
                }

                // Per-domain breakdown
                let entries = rush.perDomain.filter { $0.value.answered > 0 }.sorted { $0.key < $1.key }
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("By domain")
                            .font(.kHeadline)
                            .foregroundStyle(Color.kTextPrimary)
                        ForEach(entries, id: \.key) { name, bucket in
                            let percent = Int((Double(bucket.correct) / Double(bucket.answered) * 100).rounded())
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(name)
                                        .font(.kSubheadline)
                                        .foregroundStyle(Color.kTextSecondary)
                                    Spacer()
                                    Text("\(bucket.correct)/\(bucket.answered) · \(percent)%")
                                        .font(.kCaption)
                                        .foregroundStyle(Color.kTextTertiary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.kBorder.opacity(0.5))
                                        Capsule().fill(LinearGradient.kPurpleGradient)
                                            .frame(width: geo.size.width * CGFloat(percent) / 100)
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                    }
                    .padding(Spacing.md)
                    .kGlassEffect(cornerRadius: CornerRadius.lg)
                }

                Button("Practice again") { onAgain() }
                    .buttonStyle(.kPrimary)
                Button("Back to SAT home") { onExit() }
                    .buttonStyle(.kGhost)
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
                .foregroundStyle(tint)
            Text(value)
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.kCaption2)
                .foregroundStyle(Color.kTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .kGlassEffect(cornerRadius: CornerRadius.md)
    }
}

// MARK: - Simple flow layout of skill chips

struct FlowLayoutChips: View {
    let items: [(code: String, label: String, selected: Bool)]
    let onTap: (String) -> Void

    var body: some View {
        FlexibleChipLayout(spacing: 6) {
            ForEach(items, id: \.code) { item in
                Button {
                    onTap(item.code)
                } label: {
                    Text(item.label)
                        .font(.kCaption)
                        .foregroundStyle(item.selected ? .white : Color.kTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(item.selected ? Color.kAccent : Color.kSurface))
                        .overlay(Capsule().stroke(item.selected ? .clear : Color.kBorder, lineWidth: 1))
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
