import SwiftUI

// MARK: - Onboarding (first launch, runs once, before login/signup)
// Slideshow of near-full-screen cards: each card has a solid two-tone tinted
// hero (same language as SATGradientCard headers — no fade-to-clear washes)
// with a Korah logo watermarked in the corner (a different logo per page)
// and a white "mini UI" demo panel animating in the middle. The card body
// holds the title, description, inline inputs, and a solid tint button.
// Pages slide horizontally like a phone onboarding slideshow. Collects
// the planned test date and current/goal section scores; since there's no
// signed-in user yet, they're handed to `onFinish` and saved to
// users/{uid}/satProfile/main (via SATAnalyticsService) once auth succeeds.
//
// Page order (urgency first, aspiration last):
//   1. Welcome  2. Test date  3. Current scores  4. Goal scores
//   5. Practice Rush demo  6. Question Bank demo  7. Ask Korah demo
//   8. "It's all free" → Get Started

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    /// Onboarding now runs before login/signup, so there's no `uid` yet to
    /// save the collected profile to Firestore — hand it back to the caller
    /// to hold until auth succeeds.
    var onFinish: (PendingOnboardingProfile) -> Void

    @State private var page = 0
    /// +1 when advancing, -1 when going back — drives the slide direction.
    @State private var direction = 1
    private let pageCount = 8

    /// One color per slide, matching each page's tint, so the progress dots
    /// read as a little rainbow rather than a row of identical pills.
    private let pageTints: [Color] = [
        .kAccent, .teal, .orange, .kSuccess, .pink, .blue, .kAccentLight, .kGold
    ]

    // Collected data
    /// Index into `examDates`; `examDates.count` means "Not sure yet".
    @State private var dateChoice: Int? = nil
    @State private var hasTakenTest = true
    @State private var currentMath: Double = 500
    @State private var currentRW: Double = 500
    @State private var goalMath: Double = 650
    @State private var goalRW: Double = 650
    @State private var goalsSeeded = false

    /// Upcoming official SAT dates (mirrors SATHomeView.examDates).
    private static let examDates: [Date] = {
        let cal = Calendar.current
        let components = [
            DateComponents(year: 2026, month: 8, day: 22),
            DateComponents(year: 2026, month: 10, day: 3),
            DateComponents(year: 2026, month: 11, day: 7),
            DateComponents(year: 2026, month: 12, day: 5),
            DateComponents(year: 2027, month: 3, day: 13),
        ]
        return components.compactMap { cal.date(from: $0) }.filter { $0 > Date() }
    }()

    var body: some View {
        ZStack {
            Color.kBackground.ignoresSafeArea()

            VStack(spacing: Spacing.sm) {
                header

                ZStack {
                    switch page {
                    case 0: welcomePage.transition(pageTransition)
                    case 1: datePage.transition(pageTransition)
                    case 2: currentScorePage.transition(pageTransition)
                    case 3: goalScorePage.transition(pageTransition)
                    case 4: rushPage.transition(pageTransition)
                    case 5: bankPage.transition(pageTransition)
                    case 6: chatPage.transition(pageTransition)
                    default: freePage.transition(pageTransition)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
            }
        }
    }

    // MARK: - Chrome

    private var header: some View {
        ZStack {
            HStack {
                if page > 0 {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.kTextSecondary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.kSurface))
                            .overlay(Circle().stroke(Color.kBorder, lineWidth: 1))
                    }
                    .transition(.opacity)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(pageTints[i].opacity(i == page ? 1 : 0.3))
                        .frame(width: i == page ? 22 : 7, height: 7)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: page)
    }

    /// Pure horizontal slide, direction-aware: forward slides in from the
    /// right, back slides in from the left — no fades. Uses full screen-width
    /// offsets (not .move, which only travels the view's own width and left
    /// a sliver of the inset card popping out at the screen edge).
    private var pageTransition: AnyTransition {
        let w = UIScreen.main.bounds.width
        return direction >= 0
            ? .asymmetric(insertion: .offset(x: w), removal: .offset(x: -w))
            : .asymmetric(insertion: .offset(x: -w), removal: .offset(x: w))
    }

    private func next() {
        // Seed goal sliders just above the user's current score, once.
        if page == 2, hasTakenTest, !goalsSeeded {
            goalMath = min(800, currentMath + 100)
            goalRW = min(800, currentRW + 100)
            goalsSeeded = true
        }
        direction = 1
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            page = min(page + 1, pageCount - 1)
        }
    }

    private func back() {
        direction = -1
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            page = max(page - 1, 0)
        }
    }

    private func finish() {
        let profile = PendingOnboardingProfile(
            mathScore: hasTakenTest ? Int(currentMath) : nil,
            englishScore: hasTakenTest ? Int(currentRW) : nil,
            mathGoal: Int(goalMath),
            englishGoal: Int(goalRW),
            testDate: dateChoice.flatMap { $0 < Self.examDates.count ? Self.examDates[$0] : nil }
        )
        onFinish(profile)
        withAnimation(.easeInOut(duration: 0.4)) {
            isOnboardingComplete = true
        }
    }

    // MARK: - Derived values

    private var currentTotal: Int? {
        hasTakenTest ? Int(currentMath + currentRW) : nil
    }

    private var goalTotal: Int { Int(goalMath + goalRW) }

    private var selectedDaysAway: Int? {
        guard let idx = dateChoice, idx < Self.examDates.count else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(),
                                                   to: Self.examDates[idx]).day ?? 0
        return max(0, days)
    }

    private var selectedDateLabel: String? {
        guard let idx = dateChoice, idx < Self.examDates.count else { return nil }
        return Self.examDates[idx]
            .formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    // MARK: - Pages

    private var welcomePage: some View {
        WelcomeHeroCard(onContinue: next)
    }

    private var datePage: some View {
        OnboardingPage(
            tint: .teal, logo: "newlogo2",
            title: "When are you taking the SAT?",
            description: "We'll count down with you and pace your practice around it.",
            primaryTitle: "Continue",
            primaryDisabled: dateChoice == nil,
            primaryAction: next,
            demo: {
                CountdownDemo(days: selectedDaysAway, dateLabel: selectedDateLabel)
            },
            controls: {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 10) {
                    ForEach(0...Self.examDates.count, id: \.self) { idx in
                        let label = idx < Self.examDates.count
                            ? Self.examDates[idx].formatted(.dateTime.month(.abbreviated).day().year())
                            : "Not sure yet"
                        SelectableChip(label: label, selected: dateChoice == idx, tint: .teal) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dateChoice = idx
                            }
                        }
                    }
                }
            }
        )
    }

    private var currentScorePage: some View {
        OnboardingPage(
            tint: .orange, logo: "newlogo3",
            title: "Where are you starting from?",
            description: "Your latest real or practice test score. Rough guesses are fine.",
            primaryTitle: "Continue", primaryAction: next,
            demo: {
                ScoreMeterDemo(eyebrow: "YOUR STARTING SCORE", total: currentTotal,
                               tint: .orange)
            },
            controls: {
                VStack(spacing: Spacing.sm) {
                    Toggle(isOn: $hasTakenTest.animation(.easeInOut(duration: 0.25))) {
                        Text("I've taken the SAT or a practice test")
                            .font(.kSubheadline)
                            .foregroundStyle(Color.kTextPrimary)
                    }
                    .tint(.orange)

                    if hasTakenTest {
                        ScoreSliderRow(label: "Math", tint: .orange, value: $currentMath)
                        ScoreSliderRow(label: "Reading & Writing", tint: .orange,
                                       value: $currentRW)
                    }
                }
            }
        )
    }

    private var goalScorePage: some View {
        OnboardingPage(
            tint: Color.kSuccess, logo: "newlogo5",
            title: "Where do you want to be?",
            description: "Pick a target for each section. You can change it anytime.",
            primaryTitle: "Continue", primaryAction: next,
            demo: {
                GoalDemo(current: currentTotal, goal: goalTotal)
            },
            controls: {
                VStack(spacing: Spacing.sm) {
                    ScoreSliderRow(label: "Math goal", tint: Color.kSuccess,
                                   value: $goalMath)
                    ScoreSliderRow(label: "Reading & Writing goal", tint: Color.kSuccess,
                                   value: $goalRW)
                }
            }
        )
    }

    private var rushPage: some View {
        OnboardingPage(
            tint: .pink, logo: "newlogo10",
            title: "Race the clock in Practice Rush",
            description: "Quick-fire rounds of real SAT questions. Beat the timer, build streaks, and earn XP.",
            primaryTitle: "Continue", primaryAction: next
        ) {
            RushDemo()
        }
    }

    private var bankPage: some View {
        OnboardingPage(
            tint: .blue, logo: "newlogo11",
            title: "Every question, one bank",
            description: "Thousands of real SAT questions, filterable by section, skill, and difficulty, with your saved and missed lists.",
            primaryTitle: "Continue", primaryAction: next
        ) {
            BankDemo()
        }
    }

    private var chatPage: some View {
        OnboardingPage(
            tint: Color.kAccentLight, logo: "newlogo12",
            title: "Stuck? Ask Korah",
            description: "Your AI tutor breaks down any question step by step, whenever you need it.",
            primaryTitle: "Continue", primaryAction: next
        ) {
            ChatDemo()
        }
    }

    private var freePage: some View {
        OnboardingPage(
            tint: Color.kGold, logo: "newlogo2",
            title: "And it's all 100% free",
            description: "No subscription, no paywall, no catch. Everything you just saw is free, forever.",
            primaryTitle: "Get Started",
            primaryAction: finish
        ) {
            FreeDemo()
        }
    }
}

// MARK: - Welcome hero card
// The first slide sits on the plain app background with a single liquid-glass
// card floating in the center: the pulsing icon, the welcome copy, and the
// "Let's go" button all grouped together rather than pinned to the edges.

private struct WelcomeHeroCard: View {
    let onContinue: () -> Void

    var body: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(spacing: Spacing.lg) {
                WelcomeDemo()
                    .frame(width: 260, height: 200)

                VStack(spacing: Spacing.sm) {
                    Text("Welcome to Korah")
                        .font(.kLargeTitle)
                        .foregroundStyle(Color.kTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Yeah, we're the most goated SAT app. You set a goal, we help you get there.")
                        .font(.kCallout)
                        .foregroundStyle(Color.kTextSecondary)
                        .multilineTextAlignment(.center)
                        .kLineSpacing()
                        .padding(.horizontal, Spacing.sm)
                }

                Button(action: onContinue) {
                    Text("Let's go")
                        .font(.kBodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.kAccent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xs)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity)
            .kGlassEffect(cornerRadius: 32)
            .kShadowMedium()

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Slideshow card scaffold

private struct OnboardingPage<Demo: View, Controls: View>: View {
    let tint: Color
    let logo: String
    let title: String
    let description: String
    let primaryTitle: String
    var primaryDisabled: Bool = false
    let primaryAction: () -> Void
    @ViewBuilder let demo: Demo
    @ViewBuilder let controls: Controls

    init(tint: Color, logo: String, title: String, description: String,
         primaryTitle: String, primaryDisabled: Bool = false,
         primaryAction: @escaping () -> Void,
         @ViewBuilder demo: () -> Demo,
         @ViewBuilder controls: () -> Controls) {
        self.tint = tint
        self.logo = logo
        self.title = title
        self.description = description
        self.primaryTitle = primaryTitle
        self.primaryDisabled = primaryDisabled
        self.primaryAction = primaryAction
        self.demo = demo()
        self.controls = controls()
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 0) {
                // Tinted hero (two-tone, like SATGradientCard headers), now
                // sized to the demo so the card floats in the center instead of
                // stretching to fill the whole screen. This page's Korah logo
                // sits behind it as a faint watermark.
                demo
                    .frame(maxWidth: 340)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            LinearGradient(colors: [tint, tint.lightened(by: 0.18)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)

                            Image(logo)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .rotationEffect(.degrees(-12))
                                .offset(x: 38, y: 30)
                                .opacity(0.08)
                                .frame(maxWidth: .infinity, maxHeight: .infinity,
                                       alignment: .bottomTrailing)
                        }
                    )

                // Solid card body: copy + inputs + button.
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(title)
                        .font(.kTitle)
                        .foregroundStyle(Color.kTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(description)
                        .font(.kCallout)
                        .foregroundStyle(Color.kTextSecondary)
                        .kLineSpacing()
                        .fixedSize(horizontal: false, vertical: true)

                    controls
                        .padding(.top, Spacing.xxs)

                    Button(action: primaryAction) {
                        Text(primaryTitle)
                            .font(.kBodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(tint)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(primaryDisabled)
                    .opacity(primaryDisabled ? 0.4 : 1)
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.kSurface)
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
            .kShadowMedium()

            Spacer(minLength: 0)
        }
    }
}

extension OnboardingPage where Controls == EmptyView {
    init(tint: Color, logo: String, title: String, description: String,
         primaryTitle: String, primaryDisabled: Bool = false,
         primaryAction: @escaping () -> Void,
         @ViewBuilder demo: () -> Demo) {
        self.init(tint: tint, logo: logo, title: title, description: description,
                  primaryTitle: primaryTitle, primaryDisabled: primaryDisabled,
                  primaryAction: primaryAction, demo: demo,
                  controls: { EmptyView() })
    }
}

// MARK: - Shared input controls (bottom panel, app-themed)

private struct SelectableChip: View {
    let label: String
    let selected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.kSubheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.kTextPrimary : Color.kTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? tint.opacity(0.22) : Color.kSurfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? tint : Color.kBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ScoreSliderRow: View {
    let label: String
    let tint: Color
    @Binding var value: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.kSubheadline)
                    .foregroundStyle(Color.kTextPrimary)
                Spacer()
                Text("\(Int(value))")
                    .font(.kHeadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: value)
            }
            Slider(value: $value, in: 200...800, step: 10)
                .tint(tint)
        }
    }
}

// MARK: - Demo palette & surfaces
// Demos render on solid WHITE panels sitting on the bright tinted hero,
// regardless of app theme — so they use fixed light-mode ink colors.

private extension Color {
    static let demoInk = Color(red: 0.10, green: 0.04, blue: 0.24)      // dark purple text
    static let demoInkSoft = Color(red: 0.35, green: 0.29, blue: 0.48)  // muted text
    static let demoRow = Color(red: 0.96, green: 0.95, blue: 0.99)      // light row fill
    static let demoTrack = Color(red: 0.91, green: 0.90, blue: 0.95)    // bar tracks
    static let demoGreen = Color(red: 0.024, green: 0.588, blue: 0.412) // #059669
    static let demoGold = Color(red: 0.851, green: 0.541, blue: 0.024)  // #d97706
    static let demoPurple = Color(red: 0.486, green: 0.227, blue: 0.929) // #7c3aed
}

private extension View {
    /// The solid white "mini UI" panel that sits on the tinted hero.
    func demoSurface() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }

    func demoEyebrow(_ tint: Color) -> some View {
        self
            .font(.kCaption.weight(.semibold))
            .foregroundStyle(tint)
    }
}

// MARK: - Page demos

/// App icon with twinkling sparkles and a soft pulse, straight on the hero.
private struct WelcomeDemo: View {
    @State private var pulse = false
    @State private var twinkle = false

    private let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (-88, -56, 16), (94, -36, 20), (-106, 34, 13),
        (76, 62, 15), (-6, -88, 18), (110, 26, 12)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(sparkles.enumerated()), id: \.offset) { i, s in
                Image(systemName: "sparkle")
                    .font(.system(size: s.size))
                    .foregroundStyle(Color.kGold)
                    .offset(x: s.x, y: s.y)
                    .opacity(twinkle ? 1 : 0.2)
                    .scaleEffect(twinkle ? 1 : 0.6)
                    .animation(
                        .easeInOut(duration: 0.9)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.22),
                        value: twinkle
                    )
            }

            Image("AppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 116, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
                .scaleEffect(pulse ? 1.06 : 1)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                           value: pulse)
        }
        .onAppear {
            pulse = true
            twinkle = true
        }
    }
}

/// Mini countdown widget that live-updates as the user picks a date.
private struct CountdownDemo: View {
    let days: Int?
    let dateLabel: String?

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .bold))
                Text("TEST DAY COUNTDOWN")
            }
            .demoEyebrow(.teal)

            Text(days.map(String.init) ?? "—")
                .font(.jakarta(48).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.demoInk)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.3), value: days)

            Text("days to go")
                .font(.kSubheadline)
                .foregroundStyle(Color.demoInkSoft)

            if let dateLabel {
                Text(dateLabel)
                    .font(.kCaption)
                    .foregroundStyle(.teal)
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
        .demoSurface()
    }
}

/// Big total score readout with a fill bar, live-updating with the sliders.
private struct ScoreMeterDemo: View {
    let eyebrow: String
    let total: Int?
    let tint: Color

    private var fraction: CGFloat {
        guard let total else { return 0 }
        return CGFloat(max(0, min(1, Double(total - 400) / 1200.0)))
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(eyebrow)
                .demoEyebrow(tint)

            Text(total.map(String.init) ?? "—")
                .font(.jakarta(48).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.demoInk)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.25), value: total)

            Text("out of 1600")
                .font(.kSubheadline)
                .foregroundStyle(Color.demoInkSoft)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.demoTrack)
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * fraction)
                        .animation(.snappy(duration: 0.3), value: fraction)
                }
            }
            .frame(width: 180, height: 8)
            .padding(.top, 6)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
        .demoSurface()
    }
}

/// Target score readout with the "+N points" delta chip.
private struct GoalDemo: View {
    let current: Int?
    let goal: Int

    private var fraction: CGFloat {
        CGFloat(max(0, min(1, Double(goal - 400) / 1200.0)))
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("YOUR TARGET")
                .demoEyebrow(Color.demoGreen)

            Text("\(goal)")
                .font(.jakarta(48).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.demoInk)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.25), value: goal)

            if let current, goal > current {
                Text("that's +\(goal - current) points")
                    .font(.kCaption.weight(.bold))
                    .foregroundStyle(Color.demoGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.demoGreen.opacity(0.12)))
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.25), value: goal)
            } else {
                Text("out of 1600")
                    .font(.kSubheadline)
                    .foregroundStyle(Color.demoInkSoft)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.demoTrack)
                    Capsule()
                        .fill(Color.demoGreen)
                        .frame(width: geo.size.width * fraction)
                        .animation(.snappy(duration: 0.3), value: fraction)
                }
            }
            .frame(width: 180, height: 8)
            .padding(.top, 6)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
        .demoSurface()
    }
}

/// Looping Practice Rush round: timer drains, an answer locks in green,
/// XP pops.
private struct RushDemo: View {
    @State private var timeLeft: CGFloat = 1
    @State private var picked = false
    @State private var showXP = false

    private let choices = ["3", "5", "15", "25"]
    private let correctIndex = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("PRACTICE RUSH")
                }
                .demoEyebrow(.pink)
                Spacer()
                Text("0:12")
                    .font(.kCaption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.demoInkSoft)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.demoTrack)
                    Capsule()
                        .fill(Color.pink)
                        .frame(width: geo.size.width * timeLeft)
                }
            }
            .frame(height: 6)

            Text("If 3x + 5 = 20, what is the value of x?")
                .font(.kSubheadline.weight(.semibold))
                .foregroundStyle(Color.demoInk)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 8) {
                ForEach(choices.indices, id: \.self) { i in
                    let isCorrectPick = picked && i == correctIndex
                    HStack(spacing: 5) {
                        Text(choices[i])
                            .font(.kCaption.weight(.semibold))
                        if isCorrectPick {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundStyle(isCorrectPick ? Color.demoGreen : Color.demoInkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isCorrectPick ? Color.demoGreen.opacity(0.12)
                                                : Color.demoRow)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isCorrectPick ? Color.demoGreen : Color.demoTrack,
                                    lineWidth: 1)
                    )
                    .scaleEffect(isCorrectPick ? 1.04 : 1)
                }
            }
        }
        .padding(Spacing.md)
        .demoSurface()
        .overlay(alignment: .topTrailing) {
            if showXP {
                Text("+15 XP")
                    .font(.kCaption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.demoGreen))
                    .offset(x: 6, y: -14)
                    .transition(.scale.combined(with: .opacity)
                        .combined(with: .offset(y: 10)))
            }
        }
        .task { await loop() }
    }

    private func loop() async {
        while !Task.isCancelled {
            timeLeft = 1
            picked = false
            withAnimation(.linear(duration: 2.6)) { timeLeft = 0.12 }
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { picked = true }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showXP = true }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.25)) { showXP = false }
            try? await Task.sleep(nanoseconds: 350_000_000)
        }
    }
}

/// Looping Question Bank browse: filter chips pop in, rows slide in,
/// a bookmark flips gold.
private struct BankDemo: View {
    @State private var chipsShown = 0
    @State private var rowsShown = 0
    @State private var bookmarked = false

    private let chips = ["Algebra", "Geometry", "Hard"]
    private let rows: [(skill: String, meta: String, dot: Color)] = [
        ("Central Ideas and Details", "Reading · Easy", .demoGreen),
        ("Linear equations in two variables", "Algebra · Medium", .demoGold),
        ("Ratios, rates, and proportions", "Math · Hard", .red)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("QUESTION BANK")
            }
            .demoEyebrow(.blue)

            HStack(spacing: 6) {
                ForEach(chips.indices, id: \.self) { i in
                    Text(chips[i])
                        .font(.kCaption2.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.blue.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.blue.opacity(0.35), lineWidth: 1))
                        .scaleEffect(chipsShown > i ? 1 : 0.5)
                        .opacity(chipsShown > i ? 1 : 0)
                }
                Spacer()
            }

            VStack(spacing: 7) {
                ForEach(rows.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(rows[i].dot)
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rows[i].skill)
                                .font(.kCaption.weight(.semibold))
                                .foregroundStyle(Color.demoInk)
                                .lineLimit(1)
                            Text(rows[i].meta)
                                .font(.kCaption2)
                                .foregroundStyle(Color.demoInkSoft)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: i == 1 && bookmarked
                              ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 11))
                            .foregroundStyle(i == 1 && bookmarked
                                             ? Color.demoGold : Color.demoInkSoft)
                            .scaleEffect(i == 1 && bookmarked ? 1.2 : 1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.demoRow)
                    )
                    .offset(x: rowsShown > i ? 0 : 40)
                    .opacity(rowsShown > i ? 1 : 0)
                }
            }
        }
        .padding(Spacing.md)
        .demoSurface()
        .task { await loop() }
    }

    private func loop() async {
        while !Task.isCancelled {
            chipsShown = 0
            rowsShown = 0
            bookmarked = false
            for i in 1...chips.count {
                try? await Task.sleep(nanoseconds: 220_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    chipsShown = i
                }
            }
            for i in 1...rows.count {
                try? await Task.sleep(nanoseconds: 240_000_000)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    rowsShown = i
                }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                bookmarked = true
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
}

/// Looping Ask Korah exchange: question bubble, thinking shimmer, answer bubble.
private struct ChatDemo: View {
    @State private var stage = 0   // 0 empty · 1 user · 2 typing · 3 answer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("ASK KORAH")
            }
            .demoEyebrow(Color.demoPurple)

            VStack(spacing: 8) {
                if stage >= 1 {
                    Text("How do I solve x² − 5x + 6 = 0?")
                        .font(.kCaption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.demoPurple)
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                if stage == 2 {
                    HStack(spacing: 7) {
                        Image("newlogo2")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)

                        ThinkingShimmer(text: "Korah is thinking")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.demoRow)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }

                if stage >= 3 {
                    Text("Factor it: (x − 2)(x − 3) = 0, so x = 2 or x = 3. Want the step-by-step?")
                        .font(.kCaption)
                        .foregroundStyle(Color.demoInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.demoRow)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .top)
        }
        .padding(Spacing.md)
        .demoSurface()
        .task { await loop() }
    }

    private func loop() async {
        while !Task.isCancelled {
            withAnimation(.easeOut(duration: 0.2)) { stage = 0 }
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { stage = 1 }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.easeInOut(duration: 0.2)) { stage = 2 }
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { stage = 3 }
            try? await Task.sleep(nanoseconds: 2_600_000_000)
        }
    }
}

/// A bright band sweeping across faint text, masked to the glyphs — the same
/// "Korah is thinking" treatment the real chat uses instead of bouncing dots.
/// The base sits dim so the sweeping purple highlight clearly pops as it moves.
private struct ThinkingShimmer: View {
    let text: String
    @State private var phase: CGFloat = -1

    private let font = Font.kCaption.weight(.bold)

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Color.demoInkSoft.opacity(0.25))
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.demoPurple, Color.demoInk, Color.demoPurple, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.85)
                    .offset(x: phase * geo.size.width * 1.5)
                    .mask(
                        Text(text)
                            .font(font)
                            .frame(width: geo.size.width, alignment: .leading)
                    )
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

/// "$0 forever" with the feature checklist popping in.
private struct FreeDemo: View {
    @State private var shown = 0
    @State private var priceIn = false

    private let features = ["Practice Rush", "Question Bank", "Ask Korah AI tutor"]

    var body: some View {
        VStack(spacing: 10) {
            Text("$0")
                .font(.jakarta(52).weight(.bold))
                .foregroundStyle(Color.demoGold)
                .scaleEffect(priceIn ? 1 : 0.5)
                .opacity(priceIn ? 1 : 0)

            VStack(spacing: 6) {
                ForEach(features.indices, id: \.self) { i in
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.demoGreen)
                        Text(features[i])
                            .font(.kCaption.weight(.semibold))
                            .foregroundStyle(Color.demoInk)
                        Spacer()
                        Text("FREE")
                            .font(.kCaption2.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(Color.demoGold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.demoRow)
                    )
                    .offset(y: shown > i ? 0 : 14)
                    .opacity(shown > i ? 1 : 0)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .demoSurface()
        .task {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { priceIn = true }
            for i in 1...features.count {
                try? await Task.sleep(nanoseconds: 260_000_000)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    shown = i
                }
            }
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false), onFinish: { _ in })
}
