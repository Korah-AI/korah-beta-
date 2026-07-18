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
    @State private var showPlanMenu = false
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
                    Button {
                        Haptics.light()
                        withAnimation(KAnimation.quick) { showPlanMenu.toggle() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
        }
        .overlay {
            if showPlanMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(KAnimation.quick) { showPlanMenu = false }
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            if showPlanMenu {
                planMenu
                    .padding(.top, 6)
                    .padding(.trailing, Spacing.md)
            }
        }
        .overlay {
            if showReplaceConfirm {
                KConfirmationPopup(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Start a new plan?",
                    message: "This replaces your current plan. Progress on completed sessions won't carry over.",
                    confirmTitle: "Start New Plan",
                    onConfirm: {
                        showReplaceConfirm = false
                        Task {
                            try? await service.deletePlan()
                            onCreateNew()
                        }
                    },
                    onCancel: { showReplaceConfirm = false }
                )
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showReplaceConfirm)
        .onAppear { autoFocus() }
    }

    // MARK: - Plan menu (custom dropdown)

    private var planMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.selection()
                withAnimation(KAnimation.quick) { showPlanMenu = false }
                showReplaceConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold))
                    Text("Start a new plan")
                        .font(.kSubheadline.weight(.semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.kError)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 190)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Color.kSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .stroke(Color.kError.opacity(0.3), lineWidth: 1)
        )
        .kShadowMedium()
        .transition(.scale(scale: 0.95, anchor: .topTrailing).combined(with: .opacity))
    }

    // MARK: - Content

    private func planContent(_ plan: StudyPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                StudyPlanFeedbackCard(feedback: plan.feedback)
                progressCard(plan)
                calendarCard(plan)
                eventsList(plan)
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
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Spacer()
                Text("Test day \(testDayLabel(plan))")
                    .font(.kCaption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(.white)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 7)
            .animation(KAnimation.standard, value: fraction)
        }
        .padding(Spacing.md)
        .background(
            LinearGradient(colors: [StudyPlanSetupView.indigo, StudyPlanSetupView.indigo.lightened(by: 0.18)],
                           startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func testDayLabel(_ plan: StudyPlan) -> String {
        guard let date = StudyPlanDates.date(from: plan.testDate) else { return plan.testDate }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: - Calendar

    private func calendarCard(_ plan: StudyPlan) -> some View {
        let sessionsByDate = plan.sessionsByDate
        let tint = StudyPlanSetupView.indigo
        return VStack(spacing: 0) {
            // Gradient header (month/year + chevrons), filled to match the
            // SATHomeView dashboard cards rather than the flat dark body.
            HStack {
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.kTitle2.weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Spacer()
                Button { stepMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
                Button { stepMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
            .background(
                LinearGradient(colors: [tint, tint.lightened(by: 0.18)],
                               startPoint: .leading, endPoint: .trailing)
            )

            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Weekday header (today's column tinted)
                HStack(spacing: 6) {
                    ForEach(Array(StudyPlanDates.dayLabels.enumerated()), id: \.offset) { index, label in
                        Text(label)
                            .font(.kCaption.weight(.semibold))
                            .foregroundStyle(index == todayColumn ? Color.kAccentLight : Color.kTextPrimary)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(
                ZStack {
                    Color.kSurfaceElevated
                    tint.opacity(0.14)
                }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
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

    // MARK: - Events list

    /// Every session in the plan, sorted chronologically. Tapping a calendar
    /// day no longer filters this list — it just pulses the matching rows so
    /// the full plan stays visible at all times.
    private func eventsList(_ plan: StudyPlan) -> some View {
        let sessions = plan.sessions.sorted {
            $0.date == $1.date ? $0.start < $1.start : $0.date < $1.date
        }
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("All sessions")
                .font(.kHeadline)
                .foregroundStyle(Color.kTextPrimary)

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
                StudyPlanSessionRow(session: session, showsDate: true, pulsate: session.date == selectedDate) {
                    service.setCompleted(sessionId: session.id, completed: !session.completed)
                    session.completed ? Haptics.light() : Haptics.success()
                }
            }
        }
        .padding(Spacing.md)
        .satDarkCard()
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
                        iconImage: "newlogo3",
                        tint: StudyPlanSetupView.indigo) {
            if !feedback.headline.isEmpty {
                Text(feedback.headline)
                    .font(.kBodyBold)
                    .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !feedback.weeklyFocus.isEmpty {
                Text(feedback.weeklyFocus)
                    .font(.kCaption)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Session row (shared with the setup preview)

struct StudyPlanSessionRow: View {
    let session: StudyPlanSession
    var showsDate = false
    var pulsate = false
    var onToggle: (() -> Void)? = nil

    @State private var pulseUp = false

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
                .fill(.white.opacity(0.6))
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(timeLine)
                    .font(.kCaption.weight(.bold))
                    .foregroundStyle(.white)
                Text(session.skillName)
                    .font(.kSubheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .strikethrough(session.completed, color: .white.opacity(0.7))
                Text(session.activity)
                    .font(.kCaption)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)

            if let onToggle {
                Button {
                    withAnimation(KAnimation.quick) { onToggle() }
                } label: {
                    Image(systemName: session.completed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(session.completed ? .white : .white.opacity(0.55))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .stroke(.white.opacity(pulsate ? (pulseUp ? 0.95 : 0.35) : 0.15), lineWidth: pulsate ? 2 : 1)
        )
        .scaleEffect(pulsate && pulseUp ? 1.02 : 1)
        .opacity(session.completed ? 0.7 : 1)
        .animation(KAnimation.quick, value: session.completed)
        .onAppear { updatePulse(pulsate) }
        .onChange(of: pulsate) { _, newValue in updatePulse(newValue) }
    }

    private func updatePulse(_ active: Bool) {
        if active {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulseUp = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                pulseUp = false
            }
        }
    }
}
