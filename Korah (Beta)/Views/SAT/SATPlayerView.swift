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
        .toolbar(.hidden, for: .tabBar)
        .task {
            HTMLContentView.warmUp()
            await session.load()
        }
        .onDisappear { session.endSession() }
        .sheet(isPresented: $showNavigator) {
            SATNavigatorSheet(session: session)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCalculator) {
            DesmosCalculatorSheet()
        }
        .overlay { sessionInfoOverlay }
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
        // Meta bar lives above the pager so it stays truly fixed under the nav
        // bar — no per-page scroll inset that can tuck under the toolbar.
        .safeAreaInset(edge: .top, spacing: 0) { metaBar }
    }

    // MARK: - Fixed meta bar (topic · difficulty · bookmark)

    @ViewBuilder
    private var metaBar: some View {
        if let question = session.currentQuestion {
            HStack(spacing: Spacing.sm) {
                if !question.domain.isEmpty {
                    chip(question.domain, tint: domainTint(question.domain))
                }
                if let label = SATCatalog.difficultyLabels[question.difficulty] {
                    chip(label, tint: difficultyTint(question.difficulty))
                }
                Spacer()
                Button {
                    session.toggleBookmark(question)
                    Haptics.light()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: session.isBookmarked(question) ? "bookmark.fill" : "bookmark")
                            .font(.body.weight(.semibold))
                        Text("Mark For Review")
                            .font(.kCaption.weight(.semibold))
                    }
                    .foregroundStyle(session.isBookmarked(question) ? Color.kGold : Color.kTextTertiary)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.kBackground)
            .overlay(alignment: .bottom) {
                Divider().opacity(0.4)
            }
        }
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.kFootnote.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint))
    }

    /// A distinct colour per SAT domain so topics are recognisable at a glance.
    private func domainTint(_ domain: String) -> Color {
        switch domain {
        case "Information and Ideas": return Color(red: 0.36, green: 0.42, blue: 0.95)  // indigo
        case "Craft and Structure": return Color(red: 0.30, green: 0.70, blue: 0.78)    // cyan
        case "Expression of Ideas": return Color(red: 0.20, green: 0.68, blue: 0.55)    // teal-green
        case "Standard English Conventions": return Color(red: 0.30, green: 0.51, blue: 0.94)  // blue
        case "Algebra": return Color(red: 0.85, green: 0.35, blue: 0.62)                // magenta
        case "Advanced Math": return Color(red: 0.55, green: 0.40, blue: 0.88)          // purple
        case "Problem-Solving and Data Analysis": return Color(red: 0.95, green: 0.62, blue: 0.20)  // amber
        case "Geometry and Trigonometry": return Color(red: 0.95, green: 0.45, blue: 0.35)  // coral
        default: return .kAccent
        }
    }

    private func difficultyTint(_ difficulty: String) -> Color {
        switch difficulty {
        case "E": return .kSuccess
        case "M": return .kGold
        case "H": return .kError
        default: return .kTextSecondary
        }
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showSessionInfo.toggle()
                }
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(showSessionInfo ? Color.kAccent : Color.kTextSecondary)
            }
        }
    }

    // MARK: - Custom session info dropdown

    @ViewBuilder
    private var sessionInfoOverlay: some View {
        if showSessionInfo {
            ZStack(alignment: .topTrailing) {
                // Tap-outside-to-dismiss scrim.
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) { showSessionInfo = false }
                    }

                sessionInfoCard
                    .padding(.trailing, Spacing.md)
                    .padding(.top, Spacing.xs)
                    .transition(.scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity))
            }
        }
    }

    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Practice Details")
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)

            infoRow(icon: "doc.text", label: "Assessment", value: assessment)

            if !session.query.difficulties.isEmpty {
                let labels = session.query.difficulties
                    .compactMap { SATCatalog.difficultyLabels[$0] }.sorted()
                infoRow(icon: "chart.bar", label: "Difficulty", value: labels.joined(separator: ", "))
            }
            if !session.query.domains.isEmpty {
                infoRow(icon: "square.grid.2x2", label: "Domains",
                        value: session.query.domains.sorted().joined(separator: ", "))
            }

            Divider().opacity(0.5)

            infoRow(icon: "checkmark.circle", label: "Progress",
                    value: "\(session.answeredCount)/\(session.questions.count) · \(session.correctCount) correct")
        }
        .padding(Spacing.md)
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Color.kSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(Color.kBorder, lineWidth: 1)
        )
        .kShadowMedium()
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.kCaption)
                .foregroundStyle(Color.kAccent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.kCaption2)
                    .foregroundStyle(Color.kTextTertiary)
                Text(value)
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextPrimary)
            }
        }
    }

    // MARK: - Loading / message states

    private var loadingView: some View {
        // Skeleton of the question layout instead of a blocking spinner —
        // the page appears "already there" and fills in as data lands.
        ScrollView {
            SATQuestionSkeleton()
        }
        .scrollDisabled(true)
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
    @State private var showStubRetry = false
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
        .buttonStyle(.kPink)
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
                HStack(spacing: Spacing.xs) {
                    Image("newlogo2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text("Step-by-step with Korah")
                        .font(.kHeadline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.Button.medium)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous)
                        .fill(SATAccent.violet.solid)
                )
            }
            .buttonStyle(.plain)
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
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SATQuestionSkeleton()
                // Only surface the retry affordance once the skeleton has
                // clearly stalled — a flash of "Retry" on a fast load is noise.
                if showStubRetry {
                    Button("Taking a while — Retry") {
                        Task { await session.ensureDetail(at: index) }
                    }
                    .buttonStyle(.kGhost)
                    .font(.kCaption)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                }
            }
        }
        .scrollDisabled(true)
        .task { await session.ensureDetail(at: index) }
        .task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation { showStubRetry = true }
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

                    HTMLContentView(html: option.text, fontSize: 16,
                                     textColorOverride: revealState == .none ? nil : .white)
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
                .overlay {
                    if isEliminated && revealState == .none {
                        Rectangle()
                            .fill(Color.kTextSecondary.opacity(0.7))
                            .frame(height: 1.5)
                            .padding(.horizontal, Spacing.sm)
                    }
                }
                .opacity(isEliminated && revealState == .none ? 0.35 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isEliminated)

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
        case .correct: return .kSuccess
        case .incorrect: return .kError
        case .none: return isSelected ? Color.kAccent.opacity(0.10) : Color.kSurface
        }
    }

    private var borderColor: Color {
        switch revealState {
        case .correct, .incorrect: return .clear
        case .none: return isSelected ? .kAccent : .kBorder
        }
    }

    private var keyColor: Color {
        switch revealState {
        case .correct, .incorrect: return .white
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.md) {
                legendItem(color: .kSuccess, label: "Correct")
                legendItem(color: .kError, label: "Incorrect")
                legendItem(color: .kGold, label: "Attempted")
                Spacer()
                Text("\(session.questions.count) total")
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextTertiary)
            }
            legendItem(color: .kAccent, label: "Correct after 2+ attempts")
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
        case "correctAfterRetry": .kAccent
        case "incorrect": .kError
        case "attempted": .kGold
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
    @State private var chat: SATFollowUpChat
    @FocusState private var chatFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(question: SATQuestion) {
        self.question = question
        _chat = State(initialValue: SATFollowUpChat(question: question))
    }

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
            .safeAreaInset(edge: .bottom) {
                if source == .korah && explanation != nil {
                    chatComposer
                }
            }
        }
        .task { await loadKorahExplanation() }
    }

    @ViewBuilder
    private var korahContent: some View {
        if isLoading {
            korahSkeleton
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

            followUpChat
        } else if let loadError {
            Text(loadError)
                .font(.kSubheadline)
                .foregroundStyle(Color.kError)
            Button("Try again") { Task { await loadKorahExplanation(force: true) } }
                .buttonStyle(.kSecondary)
        }
    }

    // MARK: - Loading skeleton (mirrors the summary + step-card layout)

    private var korahSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SkeletonBox(height: 15)
            SkeletonBox(height: 15).frame(width: 200)
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        SkeletonBox(cornerRadius: CornerRadius.xxl, height: 22).frame(width: 22)
                        SkeletonBox(height: 16).frame(width: 130)
                    }
                    SkeletonBox(height: 13)
                    SkeletonBox(height: 13).frame(width: 240)
                }
                .padding(Spacing.md)
                .kGlassEffect(cornerRadius: CornerRadius.lg)
            }
        }
    }

    // MARK: - Follow-up chat (compact ask-Korah below the steps)

    private var followUpChat: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Divider().opacity(0.5)

            HStack(spacing: Spacing.xs) {
                Image("newlogo2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("Ask Korah a follow-up")
                    .font(.kHeadline)
                    .foregroundStyle(Color.kTextPrimary)
            }

            if chat.messages.isEmpty {
                Text("Still stuck on something? Ask anything about this question.")
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextSecondary)
            }

            ForEach(chat.messages) { message in
                chatBubble(message)
            }
        }
        .padding(.top, Spacing.xs)
    }

    @ViewBuilder
    private func chatBubble(_ message: SATFollowUpChat.Msg) -> some View {
        if message.role == "user" {
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.kSubheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.bubble, style: .continuous)
                            .fill(SATAccent.violet.solid)
                    )
            }
        } else {
            HStack {
                if message.text.isEmpty && message.isStreaming {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        SkeletonBox(height: 13).frame(width: 200)
                        SkeletonBox(height: 13).frame(width: 150)
                    }
                    .padding(Spacing.sm)
                    .kGlassEffect(cornerRadius: CornerRadius.bubble)
                } else {
                    LatexMarkdownView(content: message.text, isStreaming: message.isStreaming)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .kGlassEffect(cornerRadius: CornerRadius.bubble)
                }
                Spacer(minLength: 24)
            }
        }
    }

    private var chatComposer: some View {
        HStack(spacing: Spacing.xs) {
            TextField("Ask about this question…", text: $chat.input, axis: .vertical)
                .font(.kSubheadline)
                .lineLimit(1...4)
                .focused($chatFocused)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.kSurface))
                .overlay(Capsule().stroke(Color.kBorder, lineWidth: 1))
                .onSubmit { chat.send() }

            Button {
                if chat.isStreaming {
                    chat.stop()
                } else {
                    chat.send()
                    chatFocused = false
                }
            } label: {
                Image(systemName: chat.isStreaming ? "stop.fill" : "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(SATAccent.violet.solid))
            }
            .disabled(!chat.isStreaming && chat.input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(.bar)
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

// MARK: - Follow-up chat model
// A lightweight streaming chat seeded with the current question's context, so
// the student can keep asking Korah about the same problem after the worked
// steps. Mirrors MathChatModel but without the Desmos plumbing.

@MainActor
@Observable
final class SATFollowUpChat {
    struct Msg: Identifiable, Equatable {
        let id = UUID()
        let role: String        // "user" | "assistant"
        var text: String
        var isStreaming = false
    }

    var messages: [Msg] = []
    var input = ""
    var isStreaming = false

    private let systemPrompt: String
    private var streamTask: Task<Void, Never>?

    init(question: SATQuestion) {
        let context = SATExplanationService.shared.contextBlock(for: question)
        systemPrompt = """
        You are Korah, a friendly SAT tutor helping a student with one specific SAT question they just reviewed. Answer their follow-up questions about it clearly.

        Keep replies short and conversational: a few sentences or a couple of quick steps, then stop and let them ask again. Use Markdown and KaTeX ($inline$ or $$display$$) for any math.

        Here is the question in context:
        \(context)
        """
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        input = ""
        messages.append(Msg(role: "user", text: text))
        Haptics.light()

        let assistant = Msg(role: "assistant", text: "", isStreaming: true)
        let assistantId = assistant.id
        messages.append(assistant)
        isStreaming = true

        var api: [AIChatMessage] = [AIChatMessage(role: "system", content: systemPrompt)]
        for message in messages where message.id != assistantId {
            api.append(AIChatMessage(role: message.role, content: message.text))
        }

        streamTask = Task {
            do {
                let full = try await KorahAIClient.shared.stream(
                    messages: api, temperature: 0.4
                ) { [weak self] _, accumulated in
                    Task { @MainActor [weak self] in
                        self?.update(id: assistantId, text: accumulated, streaming: true)
                    }
                }
                update(id: assistantId, text: full, streaming: false)
            } catch {
                if let index = messages.firstIndex(where: { $0.id == assistantId }) {
                    if messages[index].text.isEmpty {
                        messages[index].text = "Couldn't respond right now. Please try again."
                    }
                    messages[index].isStreaming = false
                }
            }
            isStreaming = false
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let index = messages.lastIndex(where: { $0.role == "assistant" }) {
            messages[index].isStreaming = false
        }
    }

    private func update(id: UUID, text: String, streaming: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = text
        messages[index].isStreaming = streaming
    }
}

// MARK: - Pink primary button (for the Check Answer action)

private struct KPinkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: ComponentSize.Button.medium)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.85, green: 0.24, blue: 0.52),   // deep pink
                                 Color(red: 0.96, green: 0.44, blue: 0.66)],  // rose
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: Color(red: 0.93, green: 0.35, blue: 0.60).opacity(0.4), radius: 16, x: 0, y: 6)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == KPinkButtonStyle {
    static var kPink: KPinkButtonStyle { KPinkButtonStyle() }
}
