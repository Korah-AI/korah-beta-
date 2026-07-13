import SwiftUI

// MARK: - SAT Question Player
// Mobile-first take on the web player (sat/questions.html): horizontal
// page-swiping between questions, large tap targets for MCQ, SPR keyboard
// entry, check → reveal + explanation, bookmark, stopwatch, navigator grid.

struct SATPlayerView: View {
    @State private var session: SATPlayerSession
    @State private var showNavigator = false
    @State private var showCalculator = false
    @State private var showSessionInfo = false
    @Environment(\.dismiss) private var dismiss

    private let assessment: String

    init(query: SATQuery) {
        _session = State(initialValue: SATPlayerSession(query: query))
        assessment = query.assessment
    }

    var body: some View {
        ZStack {
            Color.kBackground.ignoresSafeArea()

            switch session.loadState {
            case .loading:
                loadingView
            case .empty:
                messageView(icon: "tray", title: "No matching questions",
                            message: "Try another topic or difficulty selection.")
            case .error(let message):
                messageView(icon: "wifi.exclamationmark", title: "Couldn't load questions",
                            message: message, retry: { Task { await session.load() } })
            case .ready:
                pager
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { await session.load() }
        .onDisappear { session.endSession() }
        .sheet(isPresented: $showNavigator) {
            SATNavigatorSheet(session: session)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCalculator) {
            DesmosCalculatorSheet()
        }
        .confirmationDialog("Practice Details", isPresented: $showSessionInfo, titleVisibility: .visible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sessionSummary)
        }
    }

    // MARK: - Pager

    private var pager: some View {
        TabView(selection: $session.currentIndex) {
            ForEach(Array(session.questions.enumerated()), id: \.element.id) { index, _ in
                SATQuestionPageView(session: session, index: index, assessment: assessment)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button {
                showNavigator = true
            } label: {
                HStack(spacing: 6) {
                    Text("Question \(session.currentIndex + 1) of \(session.questions.count)")
                        .font(.kSubheadline)
                        .foregroundStyle(Color.kTextPrimary)
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(Color.kTextSecondary)
                }
            }
            .disabled(session.loadState != .ready)
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                session.stopwatchPaused.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: session.stopwatchPaused ? "play.fill" : "pause.fill")
                        .font(.caption2)
                    Text(session.stopwatchText)
                        .font(.kCaption.monospacedDigit())
                }
                .foregroundStyle(Color.kTextSecondary)
            }

            if session.currentQuestion?.section == "math" {
                Button {
                    showCalculator = true
                } label: {
                    Image(systemName: "function")
                }
            }

            Button {
                showSessionInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
        }
    }

    private var sessionSummary: String {
        var parts: [String] = []
        parts.append("Assessment: \(assessment)")
        if !session.query.difficulties.isEmpty {
            let labels = session.query.difficulties.compactMap { SATCatalog.difficultyLabels[$0] }
            parts.append("Difficulty: \(labels.sorted().joined(separator: ", "))")
        }
        if !session.query.domains.isEmpty {
            parts.append("Domains: \(session.query.domains.sorted().joined(separator: ", "))")
        }
        parts.append("Answered \(session.answeredCount) of \(session.questions.count) · \(session.correctCount) correct")
        return parts.joined(separator: "\n")
    }

    // MARK: - Loading / message states

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(Color.kAccent)
            Text("Fetching your session from the College Board question bank…")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)
        }
    }

    private func messageView(icon: String, title: String, message: String,
                             retry: (() -> Void)? = nil) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.kAccent.opacity(0.7))
            Text(title)
                .font(.kTitle3)
                .foregroundStyle(Color.kTextPrimary)
            Text(message)
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Retry", action: retry)
                    .buttonStyle(.kPrimary)
                    .frame(maxWidth: 200)
            }
            Button("Back to bank") { dismiss() }
                .buttonStyle(.kGhost)
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Single question page

struct SATQuestionPageView: View {
    @Bindable var session: SATPlayerSession
    let index: Int
    let assessment: String

    @State private var sprInput = ""
    @State private var showExplanationSheet = false
    @FocusState private var sprFocused: Bool

    private var question: SATQuestion? {
        session.questions.indices.contains(index) ? session.questions[index] : nil
    }

    var body: some View {
        Group {
            if let question, question.loaded {
                content(question)
            } else {
                stubView
            }
        }
        .onAppear {
            if let question { sprInput = session.answer(for: question) ?? "" }
        }
    }

    // MARK: - Loaded question

    private func content(_ question: SATQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Meta chips
                HStack(spacing: Spacing.xs) {
                    if !question.domain.isEmpty {
                        chip(question.domain, tint: Color.kAccent)
                    }
                    if let label = SATCatalog.difficultyLabels[question.difficulty] {
                        chip(label, tint: difficultyTint(question.difficulty))
                    }
                    Spacer()
                    Button {
                        session.toggleBookmark(question)
                        Haptics.light()
                    } label: {
                        Image(systemName: session.isBookmarked(question) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(session.isBookmarked(question) ? Color.kGold : Color.kTextTertiary)
                    }
                }

                // Stimulus / passage
                if !question.paragraph.isEmpty {
                    HTMLContentView(html: question.paragraph, fontSize: 16)
                        .padding(Spacing.md)
                        .kGlassEffect(cornerRadius: CornerRadius.lg)
                }

                // Stem
                HTMLContentView(html: question.stem, fontSize: 17)

                // Answers
                if question.isSPR {
                    sprEntry(question)
                } else {
                    mcqRows(question)
                }

                // Check button
                checkButton(question)

                // Feedback
                if session.isChecked(question) || session.explanationShown {
                    feedbackPanel(question)
                }

                Spacer(minLength: 90)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showExplanationSheet) {
            SATExplanationSheet(question: question)
        }
    }

    // MARK: - MCQ rows (large tap targets + eliminate)

    private func mcqRows(_ question: SATQuestion) -> some View {
        VStack(spacing: Spacing.xs) {
            ForEach(question.options) { option in
                SATAnswerRow(
                    option: option,
                    isSelected: session.answer(for: question) == option.key,
                    isEliminated: session.eliminatedKeys(for: question).contains(option.key),
                    revealState: revealState(question, option: option),
                    onTap: {
                        session.select(answer: option.key, for: question)
                        Haptics.selection()
                    },
                    onEliminate: {
                        session.toggleEliminate(key: option.key, for: question)
                        Haptics.light()
                    }
                )
            }
        }
    }

    private func revealState(_ question: SATQuestion, option: SATOption) -> SATAnswerRow.Reveal {
        guard session.isChecked(question) else { return .none }
        if option.key == question.correctAnswer { return .correct }
        if session.answer(for: question) == option.key { return .incorrect }
        return .none
    }

    // MARK: - SPR entry

    private func sprEntry(_ question: SATQuestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Enter your answer")
                .font(.kCaption)
                .foregroundStyle(Color.kTextSecondary)
            TextField("Type a number or expression", text: $sprInput)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($sprFocused)
                .disabled(session.isChecked(question))
                .font(.kBody)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(Color.kSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .stroke(sprBorderColor(question), lineWidth: 1.5)
                )
                .onChange(of: sprInput) { _, newValue in
                    session.select(answer: newValue, for: question)
                }
        }
    }

    private func sprBorderColor(_ question: SATQuestion) -> Color {
        guard session.isChecked(question) else { return Color.kBorder }
        return session.isCorrect(question) ? Color.kSuccess : Color.kError
    }

    // MARK: - Check button + feedback

    private func checkButton(_ question: SATQuestion) -> some View {
        let answered = !(session.answer(for: question) ?? "")
            .trimmingCharacters(in: .whitespaces).isEmpty
        let checked = session.isChecked(question)
        let isLast = index == session.questions.count - 1

        return Button {
            if checked {
                if !isLast {
                    withAnimation { session.currentIndex = index + 1 }
                }
            } else {
                session.check(question, assessment: assessment)
                sprFocused = false
                if session.isCorrect(question) { Haptics.success() } else { Haptics.error() }
            }
        } label: {
            Text(checked ? (isLast ? "Session complete" : "Next question") : "Check Answer")
        }
        .buttonStyle(.kPrimary)
        .disabled(checked ? isLast : !answered)
        .padding(.top, Spacing.xs)
    }

    private func feedbackPanel(_ question: SATQuestion) -> some View {
        let checked = session.isChecked(question)
        let correct = session.isCorrect(question)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            if checked {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(correct ? Color.kSuccess : Color.kError)
                    Text(correct ? "Correct." : "Correct answer: \(question.correctAnswer)")
                        .font(.kHeadline)
                        .foregroundStyle(Color.kTextPrimary)
                    Spacer()
                    if let xp = session.earnedXP[question.id] {
                        Text(xp >= 0 ? "+\(xp) XP" : "\(xp) XP")
                            .font(.kCaption.bold())
                            .foregroundStyle(xp >= 0 ? Color.kSuccess : Color.kError)
                    }
                }
            }

            if !question.explanation.isEmpty {
                HTMLContentView(html: question.explanation, fontSize: 15)
            }

            Button {
                showExplanationSheet = true
            } label: {
                Label("Step-by-step with Korah", systemImage: "sparkles")
                    .font(.kSubheadline)
            }
            .buttonStyle(.kSecondary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill((checked && !correct ? Color.kError : Color.kSuccess).opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke((checked && !correct ? Color.kError : Color.kSuccess).opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Stub (not yet hydrated)

    private var stubView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(Color.kAccent)
            Text("Loading question…")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
            Button("Retry") {
                Task { await session.ensureDetail(at: index) }
            }
            .buttonStyle(.kGhost)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await session.ensureDetail(at: index) }
    }

    // MARK: - Small helpers

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.kCaption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    private func difficultyTint(_ difficulty: String) -> Color {
        switch difficulty {
        case "E": return .kSuccess
        case "M": return .kGold
        case "H": return .kError
        default: return .kTextSecondary
        }
    }
}

// MARK: - Answer row

struct SATAnswerRow: View {
    enum Reveal { case none, correct, incorrect }

    let option: SATOption
    let isSelected: Bool
    let isEliminated: Bool
    let revealState: Reveal
    let onTap: () -> Void
    let onEliminate: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text(option.key)
                        .font(.kHeadline)
                        .foregroundStyle(keyColor)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(keyBackground))
                        .overlay(Circle().stroke(borderColor, lineWidth: 1.5))

                    HTMLContentView(html: option.text, fontSize: 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(rowBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .stroke(borderColor, lineWidth: isSelected || revealState != .none ? 1.5 : 1)
                )
                .opacity(isEliminated && revealState == .none ? 0.35 : 1)
            }
            .buttonStyle(.plain)

            // Eliminate toggle (web's ABC strike-out buttons)
            Button(action: onEliminate) {
                Text(option.key)
                    .font(.kCaption)
                    .strikethrough()
                    .foregroundStyle(isEliminated ? Color.kError : Color.kTextTertiary)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle().stroke(isEliminated ? Color.kError.opacity(0.6) : Color.kBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var rowBackground: Color {
        switch revealState {
        case .correct: return Color.kSuccess.opacity(0.10)
        case .incorrect: return Color.kError.opacity(0.10)
        case .none: return isSelected ? Color.kAccent.opacity(0.10) : Color.kSurface
        }
    }

    private var borderColor: Color {
        switch revealState {
        case .correct: return .kSuccess
        case .incorrect: return .kError
        case .none: return isSelected ? .kAccent : .kBorder
        }
    }

    private var keyColor: Color {
        switch revealState {
        case .correct: return .kSuccess
        case .incorrect: return .kError
        case .none: return isSelected ? .white : .kTextSecondary
        }
    }

    private var keyBackground: Color {
        if case .none = revealState, isSelected { return .kAccent }
        return .clear
    }
}

// MARK: - Navigator sheet (question grid)

struct SATNavigatorSheet: View {
    @Bindable var session: SATPlayerSession
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 46), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    legend
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(session.questions.enumerated()), id: \.element.id) { index, question in
                            pill(index: index, question: question)
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.kBackground)
            .navigationTitle("Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: Spacing.md) {
            legendItem(color: .kSuccess, label: "Correct")
            legendItem(color: .kError, label: "Incorrect")
            legendItem(color: .kAccent, label: "Attempted")
            Spacer()
            Text("\(session.questions.count) total")
                .font(.kCaption)
                .foregroundStyle(Color.kTextTertiary)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.kCaption2)
                .foregroundStyle(Color.kTextSecondary)
        }
    }

    private func pill(index: Int, question: SATQuestion) -> some View {
        let state = session.pillState(for: question)
        let isCurrent = index == session.currentIndex
        let color: Color = switch state {
        case "correct": .kSuccess
        case "incorrect": .kError
        case "attempted": .kAccent
        default: .kTextTertiary
        }

        return Button {
            session.currentIndex = index
            dismiss()
        } label: {
            ZStack(alignment: .topTrailing) {
                Text("\(index + 1)")
                    .font(.kSubheadline.weight(.semibold))
                    .foregroundStyle(state == "unanswered" ? Color.kTextSecondary : color)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                            .fill(color.opacity(state == "unanswered" ? 0.06 : 0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                            .stroke(isCurrent ? Color.kAccent : color.opacity(0.4),
                                    lineWidth: isCurrent ? 2 : 1)
                    )
                if session.isBookmarked(question) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.kGold)
                        .offset(x: -3, y: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step-by-step explanation sheet (Korah AI / College Board toggle)

struct SATExplanationSheet: View {
    let question: SATQuestion

    @State private var source: Source = .korah
    @State private var explanation: SATExplanation?
    @State private var loadError: String?
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    enum Source: String, CaseIterable {
        case korah = "Korah"
        case collegeBoard = "College Board"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Picker("Source", selection: $source) {
                        ForEach(Source.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)

                    if !question.correctAnswer.isEmpty {
                        Label("Answer: \(question.correctAnswer)", systemImage: "checkmark.circle.fill")
                            .font(.kHeadline)
                            .foregroundStyle(Color.kSuccess)
                    }

                    switch source {
                    case .korah:
                        korahContent
                    case .collegeBoard:
                        collegeBoardContent
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.kBackground)
            .navigationTitle("Explanation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await loadKorahExplanation() }
    }

    @ViewBuilder
    private var korahContent: some View {
        if isLoading {
            HStack(spacing: Spacing.sm) {
                ProgressView().tint(Color.kAccent)
                Text("Generating step-by-step explanation…")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
        } else if let explanation {
            if let summary = explanation.summary, !summary.isEmpty {
                LatexMarkdownView(content: summary, isStreaming: false)
            }
            ForEach(Array(explanation.steps.enumerated()), id: \.offset) { index, step in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Text("\(index + 1)")
                            .font(.kCaption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.kAccent))
                        Text(step.title)
                            .font(.kHeadline)
                            .foregroundStyle(Color.kTextPrimary)
                    }
                    LatexMarkdownView(content: step.body, isStreaming: false)
                }
                .padding(Spacing.md)
                .kGlassEffect(cornerRadius: CornerRadius.lg)
            }
        } else if let loadError {
            Text(loadError)
                .font(.kSubheadline)
                .foregroundStyle(Color.kError)
            Button("Try again") { Task { await loadKorahExplanation(force: true) } }
                .buttonStyle(.kSecondary)
        }
    }

    @ViewBuilder
    private var collegeBoardContent: some View {
        if question.explanation.isEmpty {
            Text("College Board did not provide an explanation for this question.")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextTertiary)
                .italic()
        } else {
            HTMLContentView(html: question.explanation, fontSize: 16)
                .padding(Spacing.md)
                .kGlassEffect(cornerRadius: CornerRadius.lg)
        }
    }

    private func loadKorahExplanation(force: Bool = false) async {
        guard explanation == nil || force else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            explanation = try await SATExplanationService.shared.explanation(for: question)
        } catch {
            loadError = "Couldn't load an explanation right now. \(error.localizedDescription)"
        }
    }
}
