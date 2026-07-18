import SwiftUI

// MARK: - Study plan calendar
// Month grid of rounded day cells (Monday-first, like the design sample):
// study days are tinted by subject, tapping one reveals that day's sessions
// with times and topics plus completion toggles. Korah's short feedback sits
// on top so the plan never reads as a wall of text.

struct StudyPlanView: View {
    /// Called when the user replaces their plan with a fresh one.
    var onCreateNew: () -> Void = {}

    private var service: StudyPlanService { .shared }

    @State private var displayedMonth = Date()
    @State private var selectedDate: String?
    @State private var showReplaceConfirm = false
    @State private var didAutoFocus = false

    var body: some View {
        Group {
            if let plan = service.plan {
                planContent(plan)
            } else {
                emptyState
            }
        }
        .kBackground(withStars: true)
        .navigationTitle("Study plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if service.plan != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showReplaceConfirm = true } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
        }
        .confirmationDialog("Start a new plan?", isPresented: $showReplaceConfirm, titleVisibility: .visible) {
            Button("Replace my plan", role: .destructive) {
                Task {
                    try? await service.deletePlan()
                    onCreateNew()
                }
            }
            Button("Keep this one", role: .cancel) {}
        }
        .onAppear { autoFocus() }
    }

    // MARK: - Content

    private func planContent(_ plan: StudyPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                StudyPlanFeedbackCard(feedback: plan.feedback)
                progressCard(plan)
                calendarCard(plan)
                dayDetail(plan)
                Spacer(minLength: 32)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
        }
    }

    private func progressCard(_ plan: StudyPlan) -> some View {
        let done = plan.sessions.filter(\.completed).count
        let total = plan.sessions.count
        let fraction = total > 0 ? Double(done) / Double(total) : 0
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("\(done) of \(total) session\(total == 1 ? "" : "s") done")
                    .font(.kSubheadline.weight(.semibold))
                    .foregroundStyle(Color.kTextPrimary)
                    .contentTransition(.numericText())
                Spacer()
                Text("Test day \(testDayLabel(plan))")
                    .font(.kCaption)
                    .foregroundStyle(Color.kGold)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.kSuccess)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 7)
            .animation(KAnimation.standard, value: fraction)
        }
        .padding(Spacing.md)
        .satDarkCard()
    }

    private func testDayLabel(_ plan: StudyPlan) -> String {
        guard let date = StudyPlanDates.date(from: plan.testDate) else { return plan.testDate }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: - Calendar

    private func calendarCard(_ plan: StudyPlan) -> some View {
        let sessionsByDate = plan.sessionsByDate
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.kTitle2.weight(.bold))
                    .foregroundStyle(Color.kTextPrimary)
                    .contentTransition(.numericText())
                Spacer()
                Button { stepMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.kTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                Button { stepMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.kTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            // Weekday header (today's column tinted)
            HStack(spacing: 6) {
                ForEach(Array(StudyPlanDates.dayLabels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.kCaption.weight(.semibold))
                        .foregroundStyle(index == todayColumn ? Color.kAccentLight : Color.kTextTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day, plan: plan, sessions: sessionsByDate[StudyPlanDates.dayString(day)] ?? [])
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .satDarkCard()
        .animation(KAnimation.quick, value: selectedDate)
    }

    private func dayCell(_ day: Date, plan: StudyPlan, sessions: [StudyPlanSession]) -> some View {
        let key = StudyPlanDates.dayString(day)
        let isToday = Calendar.current.isDateInToday(day)
        let isSelected = selectedDate == key
        let isTestDay = key == plan.testDate
        let tint = cellTint(sessions: sessions, isTestDay: isTestDay)

        return Button {
            guard !sessions.isEmpty || isTestDay else { return }
            withAnimation(KAnimation.quick) { selectedDate = key }
            Haptics.selection()
        } label: {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.kCaption.weight(.bold))
                    .foregroundStyle(tint == nil ? Color.kTextTertiary : .white)
                if isTestDay {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                } else if !sessions.isEmpty {
                    HStack(spacing: 2.5) {
                        ForEach(sessions.prefix(3)) { session in
                            Circle()
                                .fill(Color.white.opacity(session.completed ? 1 : 0.45))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint ?? Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.95)
                            : (isToday ? Color.kAccentLight.opacity(0.8) : .clear),
                            lineWidth: isSelected ? 2 : 1.5)
            )
            .scaleEffect(isSelected ? 1.05 : 1)
        }
        .buttonStyle(.plain)
    }

    private func cellTint(sessions: [StudyPlanSession], isTestDay: Bool) -> Color? {
        if isTestDay { return .kGold }
        guard !sessions.isEmpty else { return nil }
        let subjects = Set(sessions.map(\.subject))
        if subjects == ["math"] { return Self.mathTint }
        if subjects == ["english"] { return Self.englishTint }
        return StudyPlanSetupView.indigo
    }

    // MARK: - Day detail

    @ViewBuilder
    private func dayDetail(_ plan: StudyPlan) -> some View {
        if let selectedDate, let day = StudyPlanDates.date(from: selectedDate) {
            let sessions = plan.sessionsByDate[selectedDate] ?? []
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.kHeadline)
                        .foregroundStyle(Color.kTextPrimary)
                    Spacer()
                    if !sessions.isEmpty {
                        Text("\(sessions.reduce(0) { $0 + $1.durationMin }) min")
                            .font(.kCaption.weight(.bold))
                            .foregroundStyle(Color.kTextTertiary)
                    }
                }

                if selectedDate == plan.testDate {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "flag.fill")
                            .font(.headline)
                            .foregroundStyle(Color.kGold)
                        Text("Test day. You've got this!")
                            .font(.kSubheadline.weight(.semibold))
                            .foregroundStyle(Color.kTextPrimary)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(Color.kGold.opacity(0.12))
                    )
                }

                ForEach(sessions) { session in
                    StudyPlanSessionRow(session: session) {
                        service.setCompleted(sessionId: session.id, completed: !session.completed)
                        session.completed ? Haptics.light() : Haptics.success()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(Spacing.md)
            .satCard(tint: StudyPlanSetupView.indigo)
        } else {
            Text("Tap a colored day to see what's planned.")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextTertiary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.xs)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(Color.kTextTertiary)
            Text("No plan yet.")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)
            Button("Create my study plan") { onCreateNew() }
                .buttonStyle(.kPrimary)
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
    }

    // MARK: - Month math

    /// Cells for the displayed month: leading nils pad to Monday-first.
    private var monthCells: [Date?] {
        let cal = Calendar.current
        guard let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        let leadingBlanks = (cal.component(.weekday, from: firstOfMonth) + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            cells.append(cal.date(byAdding: .day, value: day - 1, to: firstOfMonth))
        }
        return cells
    }

    private var todayColumn: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    private func stepMonth(_ delta: Int) {
        withAnimation(KAnimation.quick) {
            displayedMonth = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
        }
        Haptics.light()
    }

    /// Focus today when it has sessions, otherwise the next upcoming session.
    private func autoFocus() {
        guard !didAutoFocus, let plan = service.plan else { return }
        didAutoFocus = true
        let todayKey = StudyPlanDates.dayString(Date())
        if plan.sessionsByDate[todayKey] != nil {
            selectedDate = todayKey
        } else if let next = plan.sessions.first(where: { $0.date >= todayKey }) {
            selectedDate = next.date
            if let date = StudyPlanDates.date(from: next.date) {
                displayedMonth = date
            }
        }
    }

    static let mathTint = Color(red: 0.22, green: 0.65, blue: 0.45)
    static let englishTint = Color(red: 0.30, green: 0.51, blue: 0.94)
}

// MARK: - Feedback card (shared with the setup preview)

struct StudyPlanFeedbackCard: View {
    let feedback: StudyPlanFeedback

    var body: some View {
        SATGradientCard(title: "Korah's take",
                        subtitle: "Your plan at a glance",
                        systemImage: "sparkles",
                        tint: StudyPlanSetupView.indigo) {
            if !feedback.headline.isEmpty {
                Text(feedback.headline)
                    .font(.kBodyBold)
                    .foregroundStyle(Color.kTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(feedback.priorities.enumerated()), id: \.offset) { _, priority in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "target")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(StudyPlanSetupView.indigo)
                        .padding(.top, 2)
                    Text(priority)
                        .font(.kSubheadline)
                        .foregroundStyle(Color.kTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !feedback.weeklyFocus.isEmpty {
                Text(feedback.weeklyFocus)
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Session row (shared with the setup preview)

struct StudyPlanSessionRow: View {
    let session: StudyPlanSession
    var showsDate = false
    var onToggle: (() -> Void)? = nil

    private var tint: Color {
        session.subject == "math" ? StudyPlanView.mathTint : StudyPlanView.englishTint
    }

    private var timeLine: String {
        var parts: [String] = []
        if showsDate, let date = StudyPlanDates.date(from: session.date) {
            parts.append(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        }
        if !session.startTimeLabel.isEmpty {
            parts.append(session.startTimeLabel)
        }
        parts.append("\(session.durationMin) min")
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(timeLine)
                    .font(.kCaption.weight(.bold))
                    .foregroundStyle(tint)
                Text(session.skillName)
                    .font(.kSubheadline.weight(.semibold))
                    .foregroundStyle(Color.kTextPrimary)
                    .strikethrough(session.completed, color: Color.kTextTertiary)
                Text(session.activity)
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)

            if let onToggle {
                Button {
                    withAnimation(KAnimation.quick) { onToggle() }
                } label: {
                    Image(systemName: session.completed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(session.completed ? Color.kSuccess : Color.kTextTertiary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Color.white.opacity(session.completed ? 0.03 : 0.06))
        )
        .opacity(session.completed ? 0.7 : 1)
        .animation(KAnimation.quick, value: session.completed)
    }
}
