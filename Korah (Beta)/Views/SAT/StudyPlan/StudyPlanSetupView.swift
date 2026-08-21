import SwiftUI
import PhotosUI

// MARK: - Study plan setup wizard
// 4 steps (starting point → your level → test date → weekly schedule), then
// AI generation with a short feedback preview before saving. Mirrors the
// Practice Rush wizard patterns: vivid selectable cards, per-step tints,
// step dots, pinned footer.

struct StudyPlanSetupView: View {
    /// Called after the plan is saved so Home can swap this screen for the plan.
    var onDone: () -> Void = {}

    private enum Phase: Equatable {
        case setup
        case generating
        case preview
        case error(String)
    }

    @State private var step = 1
    @State private var phase: Phase = .setup
    @State private var intake = StudyPlanIntake()
    @State private var draftPlan: StudyPlan?

    // Step 2 state
    @State private var mathScore = 500
    @State private var englishScore = 500
    @State private var pickedScreenshot: PhotosPickerItem?
    @State private var screenshotImage: UIImage?
    @State private var analyzingScreenshot = false
    @State private var screenshotNote: String?

    // Step 3 state
    @State private var customDate = false

    var body: some View {
        ZStack {
            Color.kBackground.ignoresSafeArea()

            switch phase {
            case .setup:
                wizard
            case .generating:
                generatingView
            case .preview:
                if let draftPlan { previewView(draftPlan) }
            case .error(let message):
                errorView(message)
            }
        }
        .navigationTitle("Study planner")
        .navigationBarTitleDisplayMode(.inline)
        .animation(KAnimation.standard, value: phase)
    }

    // MARK: - Wizard shell

    private var wizard: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { s in
                    Capsule()
                        .fill(s == step ? stepTint : Color.kBorder)
                        .frame(width: s == step ? 24 : 8, height: 8)
                }
            }
            .padding(.top, Spacing.md)
            .animation(KAnimation.quick, value: step)

            ScrollView {
                VStack(spacing: Spacing.md) {
                    switch step {
                    case 1: startingPointStep
                    case 2: levelStep
                    case 3: dateStep
                    default: scheduleStep
                    }
                }
                .padding(Spacing.md)
            }

            footer
        }
        .animation(KAnimation.standard, value: step)
    }

    private var footer: some View {
        HStack(spacing: Spacing.sm) {
            if step > 1 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.kSecondary)
                    .frame(width: 100)
            }
            Button {
                if step < 4 {
                    step += 1
                } else {
                    generate()
                }
                Haptics.medium()
            } label: {
                Text(step == 4 ? "Build my plan" : "Next")
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
        switch step {
        case 1: return !intake.source.isEmpty
        case 2: return intake.source == "self" || (screenshotImage != nil && !analyzingScreenshot)
        case 3: return intake.testDate > Date()
        default: return !intake.studyDays.isEmpty
        }
    }

    private var stepTint: Color {
        switch step {
        case 1: return Self.indigo
        case 2: return Color(red: 0.20, green: 0.68, blue: 0.55)   // teal-green
        case 3: return Color(red: 0.95, green: 0.62, blue: 0.20)   // amber
        default: return .pink
        }
    }

    // MARK: - Step 1: starting point

    private var startingPointStep: some View {
        VStack(spacing: Spacing.md) {
            Text("Where are you starting from?")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)

            startCard(key: "sat", icon: "doc.text.fill",
                      title: "I've taken the SAT",
                      blurb: "Upload your score report and Korah plans from your results",
                      tint: Self.indigo)
            startCard(key: "practice", icon: "camera.viewfinder",
                      title: "I've taken a practice test",
                      blurb: "Share a screenshot of your report and Korah reads the scores",
                      tint: Color(red: 0.20, green: 0.68, blue: 0.55))
            startCard(key: "self", icon: "sparkles",
                      title: "I'm starting fresh",
                      blurb: "Rate your confidence and tell Korah what you want out of it",
                      tint: Color(red: 0.95, green: 0.45, blue: 0.35))
        }
    }

    private func startCard(key: String, icon: String, title: String, blurb: String,
                           tint: Color) -> some View {
        let selected = intake.source == key
        return Button {
            intake.source = key
            Haptics.selection()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.22))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.kHeadline)
                        .foregroundStyle(.white)
                    Text(blurb)
                        .font(.kCaption)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(selected ? 1 : 0.6))
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [tint, tint.lightened(by: 0.18)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .stroke(.white.opacity(selected ? 0.9 : 0), lineWidth: 2)
            )
            .scaleEffect(selected ? 1.01 : 1)
            .animation(KAnimation.quick, value: selected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: your level

    @ViewBuilder
    private var levelStep: some View {
        switch intake.source {
        case "sat", "practice":
            VStack(spacing: Spacing.md) {
                screenshotPickerCard
                scoresStep(title: screenshotImage == nil ? "What did you score?" : "Confirm your scores")
            }
        default:
            confidenceStep
        }
    }

    private func scoresStep(title: String) -> some View {
        VStack(spacing: Spacing.md) {
            Text(title)
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)

            ScoreSlider(title: "Math", value: $mathScore, tint: Self.mathTint)
            ScoreSlider(title: "Reading & Writing", value: $englishScore, tint: Self.englishTint)
        }
    }

    private var screenshotPickerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(intake.source == "sat" ? "Upload your score report" : "Share a screenshot of your report")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Text("Korah reads the scores and fills them in for you.")
                .font(.kCaption)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            PhotosPicker(selection: $pickedScreenshot, matching: .images) {
                VStack(spacing: Spacing.sm) {
                    if let screenshotImage {
                        Image(uiImage: screenshotImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
                    }
                    HStack(spacing: 8) {
                        Image(systemName: analyzingScreenshot ? "sparkles" : "photo.on.rectangle.angled")
                        Text(screenshotLabel)
                    }
                    .font(.kSubheadline.weight(.semibold))
                    .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .fill(
                            LinearGradient(colors: [Self.indigo, Self.indigo.lightened(by: 0.18)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                )
            }
            .opacity(analyzingScreenshot ? 0.6 : 1)
            .disabled(analyzingScreenshot)
            .onChange(of: pickedScreenshot) { _, item in
                guard let item else { return }
                analyzeScreenshot(item)
            }

            if let screenshotNote {
                Text(screenshotNote)
                    .font(.kCaption)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var screenshotLabel: String {
        if analyzingScreenshot { return "Reading your report..." }
        if screenshotImage != nil { return "Pick a different screenshot" }
        return "Pick a screenshot"
    }

    private func analyzeScreenshot(_ item: PhotosPickerItem) {
        analyzingScreenshot = true
        screenshotNote = nil
        Task { @MainActor in
            defer { analyzingScreenshot = false }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                screenshotNote = "Couldn't read that image. Try another screenshot."
                return
            }
            withAnimation(KAnimation.quick) { screenshotImage = image }
            do {
                let scores = try await StudyPlanGenerationService.shared.extractScores(from: image)
                withAnimation(KAnimation.bouncy) {
                    if let m = scores.mathScore { mathScore = m }
                    if let e = scores.englishScore { englishScore = e }
                }
                if scores.mathScore == nil && scores.englishScore == nil {
                    screenshotNote = "Couldn't spot scores in that one. Set them below instead."
                } else {
                    screenshotNote = "Found your scores! Double-check them below."
                    Haptics.success()
                }
            } catch {
                screenshotNote = "Couldn't read the report. Set your scores below instead."
            }
        }
    }

    // MARK: - Step 2 (fresh start): confidence + focus

    private var confidenceStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("How confident do you feel?")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            confidenceGroup(label: "MATH", domains: SATCatalog.math.domains, offset: 0)
            confidenceGroup(label: "READING & WRITING", domains: SATCatalog.english.domains, offset: 4)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Anything specific you want out of this plan?")
                    .font(.kHeadline)
                    .foregroundStyle(Color.kTextPrimary)
                TextField("e.g. I run out of time on reading passages", text: $intake.focusRequest, axis: .vertical)
                    .font(.kBody)
                    .foregroundStyle(Color.kTextPrimary)
                    .lineLimit(2...4)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(Color.kSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .stroke(Color.kBorder, lineWidth: 1)
                    )
            }
            .padding(.top, Spacing.xs)
        }
        .onAppear {
            // Default every domain to "okay" so nothing is left unrated.
            for domain in SATCatalog.math.domains + SATCatalog.english.domains
            where intake.confidence[domain.code] == nil {
                intake.confidence[domain.code] = 2
            }
        }
    }

    private func confidenceGroup(label: String, domains: [SATDomainInfo], offset: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label)
                .font(.kCaption.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(.white)

            ForEach(Array(domains.enumerated()), id: \.element.id) { index, domain in
                confidenceRow(domain, tint: Self.chipPalette[(offset + index) % Self.chipPalette.count])
            }
        }
    }

    private func confidenceRow(_ domain: SATDomainInfo, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(domain.name)
                .font(.kSubheadline.weight(.semibold))
                .foregroundStyle(Color.kTextPrimary)

            HStack(spacing: Spacing.xs) {
                ForEach(Array(zip(1..., ["Shaky", "Okay", "Strong"])), id: \.0) { level, title in
                    let selected = intake.confidence[domain.code] == level
                    Button {
                        withAnimation(KAnimation.quick) { intake.confidence[domain.code] = level }
                        Haptics.light()
                    } label: {
                        Text(title)
                            .font(.kCaption.weight(.bold))
                            .foregroundStyle(selected ? .white : tint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selected ? tint : tint.opacity(0.12))
                            )
                            .overlay(
                                Capsule().stroke(tint.opacity(selected ? 0 : 0.28), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Color.kSurface)
        )
    }

    // MARK: - Step 3: test date

    private var dateStep: some View {
        VStack(spacing: Spacing.md) {
            Text("When are you taking the SAT?")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)

            ForEach(Self.upcomingExamDates, id: \.self) { date in
                let selected = !customDate && Calendar.current.isDate(intake.testDate, inSameDayAs: date)
                Button {
                    customDate = false
                    intake.testDate = date
                    Haptics.selection()
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.headline)
                            .foregroundStyle(selected ? .white : stepTint)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected ? Color.white.opacity(0.22) : stepTint.opacity(0.15))
                            )
                        Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
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
                                  ? AnyShapeStyle(LinearGradient(colors: [stepTint, stepTint.lightened(by: 0.18)],
                                                                 startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.kSurface))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .stroke(selected ? .clear : stepTint.opacity(0.4), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation(KAnimation.quick) { customDate = true }
                Haptics.selection()
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.headline)
                        .foregroundStyle(customDate ? .white : stepTint)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(customDate ? Color.white.opacity(0.22) : stepTint.opacity(0.15))
                        )
                    Text("A different date")
                        .font(.kHeadline)
                        .foregroundStyle(customDate ? .white : Color.kTextPrimary)
                    Spacer()
                    Image(systemName: customDate ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(customDate ? .white : Color.kTextTertiary)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .fill(customDate
                              ? AnyShapeStyle(LinearGradient(colors: [stepTint, stepTint.lightened(by: 0.18)],
                                                             startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color.kSurface))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .stroke(customDate ? .clear : stepTint.opacity(0.4), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            if customDate {
                DatePicker("Test date",
                           selection: $intake.testDate,
                           in: Calendar.current.date(byAdding: .day, value: 7, to: Date())!...,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(stepTint)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .fill(Color.kSurface)
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .onAppear {
            if intake.testDate <= Date(), let first = Self.upcomingExamDates.first {
                intake.testDate = first
            }
        }
    }

    // MARK: - Step 4: weekly schedule

    private var scheduleStep: some View {
        VStack(spacing: Spacing.md) {
            Text("When can you study?")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Pick your study days")
                    .font(.kHeadline)
                    .foregroundStyle(Color.kTextPrimary)

                HStack(spacing: Spacing.xs) {
                    ForEach(Array(zip(StudyPlanDates.dayKeys, StudyPlanDates.dayLabels)), id: \.0) { key, label in
                        let selected = intake.studyDays.contains(key)
                        Button {
                            withAnimation(KAnimation.quick) {
                                if selected { intake.studyDays.removeAll { $0 == key } }
                                else { intake.studyDays.append(key) }
                            }
                            Haptics.light()
                        } label: {
                            Text(label)
                                .font(.kCaption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                        .fill(selected ? AnyShapeStyle(Color.pink) : AnyShapeStyle(Color.kSurface))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                        .stroke(selected ? .clear : Color.kBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            SnapSlider(title: "Hours per week",
                       options: Self.hourOptions,
                       value: intake.hoursPerWeek,
                       tint: .pink,
                       format: { "\($0)h" }) { intake.hoursPerWeek = $0 }
                .padding(.top, Spacing.xs)

            if !intake.studyDays.isEmpty {
                Text(scheduleSummary)
                    .font(.kSubheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xs)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.25), value: scheduleSummary)
            }
        }
    }

    private var scheduleSummary: String {
        let days = intake.studyDays.count
        let minutes = intake.hoursPerWeek * 60 / max(days, 1)
        return "That's about \(minutes) minutes per session, \(days) day\(days == 1 ? "" : "s") a week."
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image("korahcheer")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(color: Color.kGlow, radius: 12)
                .modifier(FloatingModifier())

            Text("Building your plan...")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)
            Text("Korah is mapping your weeks around \(examDateLabel).")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            VStack(spacing: Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBox(cornerRadius: CornerRadius.md, height: 56)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            Spacer()
            Spacer()
        }
    }

    private var examDateLabel: String {
        intake.testDate.formatted(.dateTime.month(.wide).day())
    }

    // MARK: - Preview

    private func previewView(_ plan: StudyPlan) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Your plan is ready!")
                        .font(.kLargeTitle)
                        .foregroundStyle(Color.kTextPrimary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.md)

                    StudyPlanFeedbackCard(feedback: plan.feedback)

                    HStack(spacing: Spacing.sm) {
                        previewStat(value: "\(plan.sessions.count)", label: "SESSIONS", tint: Self.indigo)
                        previewStat(value: "\(plan.hoursPerWeek)h", label: "PER WEEK", tint: .pink)
                        previewStat(value: "\(weeksUntilTest(plan))", label: "WEEKS", tint: Color(red: 0.95, green: 0.62, blue: 0.20))
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("YOUR FIRST WEEK")
                            .font(.kCaption.weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(Color.kTextTertiary)
                        ForEach(firstWeek(plan)) { session in
                            StudyPlanSessionRow(session: session, showsDate: true)
                        }
                    }
                }
                .padding(Spacing.md)
            }

            VStack(spacing: Spacing.sm) {
                Button {
                    savePlan(plan)
                } label: {
                    Text("Save my plan")
                        .font(.kBodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: [Self.indigo, Self.indigo.lightened(by: 0.18)],
                                                     startPoint: .leading, endPoint: .trailing))
                        )
                }
                .buttonStyle(.plain)

                Button("Rebuild it") {
                    generate()
                    Haptics.light()
                }
                .buttonStyle(.kSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
    }

    private func previewStat(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.jakarta(26, relativeTo: .title).weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.kCaption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.kTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
    }

    private func weeksUntilTest(_ plan: StudyPlan) -> Int {
        guard let first = plan.sessions.first?.date, let start = StudyPlanDates.date(from: first),
              let test = StudyPlanDates.date(from: plan.testDate) else { return 0 }
        return max(1, Calendar.current.dateComponents([.weekOfYear], from: start, to: test).weekOfYear ?? 1)
    }

    private func firstWeek(_ plan: StudyPlan) -> [StudyPlanSession] {
        guard let firstDate = plan.sessions.first?.date,
              let start = StudyPlanDates.date(from: firstDate) else { return [] }
        let cutoff = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        return plan.sessions.filter {
            guard let d = StudyPlanDates.date(from: $0.date) else { return false }
            return d < cutoff
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.kTextTertiary)
            Text("That didn't work")
                .font(.kTitle2)
                .foregroundStyle(Color.kTextPrimary)
            Text(message)
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Button("Retry") { generate() }
                .buttonStyle(.kPrimary)
                .padding(.horizontal, Spacing.xl)
            Button("Back to setup") { phase = .setup }
                .buttonStyle(.kSecondary)
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
    }

    // MARK: - Actions

    private func generate() {
        if intake.source == "sat" || intake.source == "practice" {
            intake.mathScore = mathScore
            intake.englishScore = englishScore
        } else {
            intake.mathScore = nil
            intake.englishScore = nil
        }
        phase = .generating
        Task { @MainActor in
            do {
                let plan = try await StudyPlanGenerationService.shared.generatePlan(intake: intake)
                draftPlan = plan
                phase = .preview
                Haptics.success()
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func savePlan(_ plan: StudyPlan) {
        do {
            try StudyPlanService.shared.save(plan)
            Haptics.success()
            onDone()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: - Constants

    static let indigo = Color(red: 0.36, green: 0.42, blue: 0.95)
    private static let mathTint = Color(red: 0.22, green: 0.65, blue: 0.45)
    private static let englishTint = Color(red: 0.30, green: 0.51, blue: 0.94)

    private static let chipPalette: [Color] = [
        Color(red: 0.36, green: 0.42, blue: 0.95),  // indigo
        Color(red: 0.95, green: 0.45, blue: 0.35),  // coral
        Color(red: 0.20, green: 0.68, blue: 0.55),  // teal-green
        Color(red: 0.85, green: 0.35, blue: 0.62),  // magenta
        Color(red: 0.95, green: 0.62, blue: 0.20),  // amber
        Color(red: 0.30, green: 0.70, blue: 0.78),  // cyan
        Color(red: 0.55, green: 0.40, blue: 0.88),  // purple
        Color(red: 0.20, green: 0.55, blue: 0.90),  // blue
    ]

    private static let hourOptions = [2, 3, 4, 5, 6, 8, 10, 12]

    /// The next few official SAT dates. See `SATExamDates` for the list.
    private static var upcomingExamDates: [Date] { SATExamDates.upcoming(limit: 3) }
}

// MARK: - Section score slider (200-800, step 10)
// SnapSlider labels every option under the track, which turns 61 score stops
// into soup. Same header + tinted read-out look, endpoint labels only.

private struct ScoreSlider: View {
    let title: String
    @Binding var value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(title)
                    .font(.kHeadline)
                    .foregroundStyle(Color.kTextPrimary)
                Spacer()
                Text("\(value)")
                    .font(.kTitle2.weight(.bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { newValue in
                        let snapped = Int((newValue / 10).rounded()) * 10
                        guard snapped != value else { return }
                        withAnimation(.snappy(duration: 0.2)) { value = snapped }
                        Haptics.selection()
                    }
                ),
                in: 200...800,
                step: 10
            )
            .tint(tint)

            HStack {
                Text("200")
                Spacer()
                Text("800")
            }
            .font(.kCaption)
            .foregroundStyle(.white)
        }
    }
}

// MARK: - Gentle ambient float for the generating mascot

private struct FloatingModifier: ViewModifier {
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -8 : 8)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: up)
            .onAppear { up = true }
    }
}
