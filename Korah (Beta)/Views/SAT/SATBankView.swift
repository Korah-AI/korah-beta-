import SwiftUI

// MARK: - SAT Question Bank browser
// Mobile take on sat/index.html: pick topics (sections → domains → skills)
// with live question counts + your progress/accuracy, set difficulty /
// limit / randomize, then start a player session.

struct SATBankView: View {
    @State private var bank = SATBankStore.shared
    @State private var startQuery: SATQuery?
    /// Which section dropdown is currently expanded, if any. Only one can be
    /// open at a time (accordion); both start closed.
    @State private var expandedSection: String?
    /// Whether the Question set / Difficulty / Time Spent / Saved / Completed
    /// / Result chip row is showing.
    @State private var filtersExpanded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let error = bank.statsError {
                        errorBanner(error)
                    }

                    filterBar

                    sectionDropdown(SATCatalog.english, icon: "book.fill", gradient: Self.englishGradient)
                    sectionDropdown(SATCatalog.math, icon: "x.squareroot", gradient: Self.mathGradient)

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
            }

            startPill
        }
        .kBackground(withStars: true)
        .navigationTitle("Questionbank")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $startQuery) { query in
            SATPlayerView(query: query)
        }
        .task { await bank.loadIfNeeded() }
        .refreshable {
            await bank.loadStats(force: true)
            await bank.loadProgress()
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(Color.kError)
            Text(message)
                .font(.kCaption)
                .foregroundStyle(Color.kTextSecondary)
            Spacer()
            Button("Retry") { Task { await bank.loadStats(force: true) } }
                .font(.kCaption.bold())
                .foregroundStyle(Color.kAccent)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Color.kError.opacity(0.08))
        )
    }

    // MARK: - Filter bar
    // Question Limit dropdown + a "Filters" toggle that reveals a chip row
    // (Question set / Difficulty / Time Spent / Saved / Completed / Result).
    // Mirrors sat/index.html's filter bar.

    @ViewBuilder
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                questionLimitMenu
                filtersToggleButton
                Spacer(minLength: 0)
            }

            if filtersExpanded {
                FlexibleChipLayout(spacing: Spacing.xs) {
                    questionSetChip
                    difficultyChip
                    timeSpentChip
                    savedChip
                    completedChip
                    resultChip

                    if bank.hasActiveFilters {
                        Button {
                            bank.resetFilters()
                            Haptics.light()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                Text("Reset filters")
                                    .font(.kCaption.weight(.semibold))
                            }
                            .foregroundStyle(Color.kTextTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var questionLimitMenu: some View {
        Menu {
            Button("All questions") { bank.limit = nil }
            ForEach([10, 25, 50, 100], id: \.self) { value in
                Button("\(value) questions") { bank.limit = value }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.caption.weight(.semibold))
                Text(bank.limit.map { "\($0) questions" } ?? "Question Limit")
                    .font(.kSubheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(bank.limit != nil ? Self.filterActive : Color.kTextPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(Capsule().fill(bank.limit != nil ? Self.filterActive.opacity(0.12) : Color.kSurface))
            .overlay(Capsule().stroke(bank.limit != nil ? Self.filterActive.opacity(0.6) : Color.kBorder.opacity(0.6), lineWidth: 1))
        }
    }

    private var filtersToggleButton: some View {
        Button {
            withAnimation(KAnimation.smooth) { filtersExpanded.toggle() }
            Haptics.light()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                Text("Filters")
                    .font(.kSubheadline.weight(.semibold))
                Image(systemName: filtersExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(filtersExpanded || bank.hasActiveFilters ? Self.filterActive : Color.kTextPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(Capsule().fill(filtersExpanded || bank.hasActiveFilters ? Self.filterActive.opacity(0.12) : Color.kSurface))
            .overlay(Capsule().stroke(filtersExpanded || bank.hasActiveFilters ? Self.filterActive.opacity(0.6) : Color.kBorder.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// A single dropdown chip in the filter row.
    private func filterChip<Content: View>(icon: String, label: String, isActive: Bool,
                                            @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(label)
                    .font(.kCaption.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(isActive ? Self.filterActive : Color.kTextSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(Capsule().fill(isActive ? Self.filterActive.opacity(0.12) : Color.kSurface))
            .overlay(Capsule().stroke(isActive ? Self.filterActive.opacity(0.6) : Color.kBorder.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var questionSetChip: some View {
        filterChip(icon: "square.stack.3d.up",
                   label: bank.assessment == "SAT" ? "Question set" : bank.assessment,
                   isActive: bank.assessment != "SAT") {
            ForEach(SATCatalog.assessments, id: \.self) { option in
                Button {
                    bank.assessment = option
                    Haptics.selection()
                } label: {
                    if bank.assessment == option {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        }
    }

    private var difficultyChip: some View {
        let label = bank.selectedDifficulties.isEmpty
            ? "Difficulty"
            : SATCatalog.difficulties
                .filter { bank.selectedDifficulties.contains($0.code) }
                .map(\.label)
                .joined(separator: ", ")
        return filterChip(icon: "chart.bar.fill", label: label, isActive: !bank.selectedDifficulties.isEmpty) {
            ForEach(SATCatalog.difficulties, id: \.code) { entry in
                Button {
                    if bank.selectedDifficulties.contains(entry.code) {
                        bank.selectedDifficulties.remove(entry.code)
                    } else {
                        bank.selectedDifficulties.insert(entry.code)
                    }
                    Haptics.selection()
                } label: {
                    if bank.selectedDifficulties.contains(entry.code) {
                        Label(entry.label, systemImage: "checkmark")
                    } else {
                        Text(entry.label)
                    }
                }
            }
        }
    }

    private var timeSpentChip: some View {
        filterChip(icon: "clock",
                   label: bank.timeSpentFilter == .any ? "Time Spent" : bank.timeSpentFilter.rawValue,
                   isActive: bank.timeSpentFilter != .any) {
            ForEach(SATTimeSpentFilter.allCases) { option in
                Button {
                    bank.timeSpentFilter = option
                    Haptics.selection()
                } label: {
                    if bank.timeSpentFilter == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        }
    }

    private var savedChip: some View {
        filterChip(icon: "bookmark.fill", label: "Saved", isActive: bank.savedOnly) {
            Button {
                bank.savedOnly.toggle()
                Haptics.selection()
            } label: {
                if bank.savedOnly {
                    Label("Saved only", systemImage: "checkmark")
                } else {
                    Text("Saved only")
                }
            }
        }
    }

    private var completedChip: some View {
        filterChip(icon: "checkmark.circle.fill",
                   label: bank.completionFilter == .any ? "Completed" : bank.completionFilter.rawValue,
                   isActive: bank.completionFilter != .any) {
            ForEach(SATCompletionFilter.allCases) { option in
                Button {
                    bank.completionFilter = option
                    Haptics.selection()
                } label: {
                    if bank.completionFilter == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        }
    }

    private var resultChip: some View {
        filterChip(icon: "circle.lefthalf.filled",
                   label: bank.resultFilter == .any ? "Result" : bank.resultFilter.rawValue,
                   isActive: bank.resultFilter != .any) {
            ForEach(SATResultFilter.allCases) { option in
                Button {
                    bank.resultFilter = option
                    Haptics.selection()
                } label: {
                    if bank.resultFilter == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        }
    }

    // MARK: - Section dropdown

    /// A collapsible dropdown for a whole SAT section (English or Math). The
    /// leading checkbox toggles selecting every topic in the section; the rest
    /// of the header expands/collapses the domain + skill list.
    private func sectionDropdown(_ section: SATSectionInfo, icon: String, gradient: LinearGradient) -> some View {
        let isExpanded = expandedSection == section.key
        let count = bank.questionCount(forSection: section)

        return VStack(spacing: 0) {
            // Gradient header — matches the section cards on the Practice tab.
            HStack(spacing: Spacing.sm) {
                Button {
                    withAnimation(KAnimation.quick) { bank.toggleSection(section) }
                    Haptics.selection()
                } label: {
                    checkbox(isOn: bank.isSectionSelected(section), activeTint: .white, inactiveTint: Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(KAnimation.smooth) {
                        expandedSection = isExpanded ? nil : section.key
                    }
                    Haptics.light()
                } label: {
                    HStack(spacing: Spacing.lg) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(SATCatalog.sectionLabels[section.key] ?? section.label)
                                .font(.kTitle.weight(.bold))
                                .foregroundStyle(.white)
                            Text(count > 0 ? "\(count) questions" : "\(section.domains.count) domains")
                                .font(.kHeadline)
                                .foregroundStyle(Color.white.opacity(0.85))
                        }
                        Spacer()
                        Image(systemName: icon)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.2))
                            )
                        Image(systemName: "chevron.down")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xxl)
            .background(gradient)

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(section.domains) { domain in
                        domainGroup(section: section, domain: domain)
                    }
                }
                .padding(Spacing.md)
                .background(Color.kSurface)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(Color.kBorder.opacity(0.6), lineWidth: 1)
        )
    }

    private func domainGroup(section: SATSectionInfo, domain: SATDomainInfo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Button {
                withAnimation(KAnimation.quick) { bank.toggleDomain(domain) }
                Haptics.selection()
            } label: {
                HStack(spacing: Spacing.sm) {
                    checkbox(isOn: bank.isDomainSelected(domain))
                    Text(domain.name)
                        .font(.kHeadline)
                        .foregroundStyle(Color.kTextPrimary)
                    Spacer()
                    let count = bank.questionCount(forDomain: domain.code)
                    if count > 0 {
                        Text("\(count)")
                            .font(.kCaption)
                            .foregroundStyle(Color.kTextTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)

            ForEach(domain.skills) { skill in
                skillRow(skill)
            }
        }
    }

    private func skillRow(_ skill: SATSkillInfo) -> some View {
        let total = bank.questionCount(forSkill: skill.code)
        let progress = bank.progress(forSkill: skill.code)
        let accuracy: Int? = progress.attempts > 0
            ? Int((Double(progress.correct) / Double(progress.attempts) * 100).rounded())
            : nil

        return Button {
            withAnimation(KAnimation.quick) { bank.toggleSkill(skill.code) }
            Haptics.selection()
        } label: {
            HStack(spacing: Spacing.sm) {
                checkbox(isOn: bank.isSkillSelected(skill.code), small: true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(skill.name)
                        .font(.kSubheadline)
                        .foregroundStyle(Color.kTextSecondary)
                        .multilineTextAlignment(.leading)

                    if total > 0 {
                        HStack(spacing: Spacing.xs) {
                            // Progress bar: attempts vs bank size
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.kBorder.opacity(0.5))
                                    Capsule()
                                        .fill(Color.kAccent)
                                        .frame(width: geo.size.width * min(1, CGFloat(progress.attempts) / CGFloat(total)))
                                }
                            }
                            .frame(width: 70, height: 4)

                            Text("\(progress.attempts)/\(total)")
                                .font(.kCaption2)
                                .foregroundStyle(Color.kTextTertiary)

                            if let accuracy {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(accuracyColor(accuracy))
                                        .frame(width: 6, height: 6)
                                    Text("\(accuracy)%")
                                        .font(.kCaption2)
                                        .foregroundStyle(Color.kTextTertiary)
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.leading, Spacing.xl)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func accuracyColor(_ percent: Int) -> Color {
        percent >= 60 ? .kSuccess : percent >= 35 ? .kGold : .kError
    }

    private func checkbox(isOn: Bool, small: Bool = false,
                          activeTint: Color = .kAccent, inactiveTint: Color = .kTextTertiary) -> some View {
        Image(systemName: isOn ? "checkmark.square.fill" : "square")
            .font(small ? .subheadline : .title3)
            .foregroundStyle(isOn ? activeTint : inactiveTint)
    }

    // MARK: - Bottom start pill

    @ViewBuilder
    private var startPill: some View {
        if bank.selectedTopicCount > 0 {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(bank.selectedTopicCount) topic\(bank.selectedTopicCount == 1 ? "" : "s") selected")
                        .font(.kSubheadline)
                        .foregroundStyle(Color.kTextPrimary)
                    if let limit = bank.limit {
                        Text("Limit \(limit)\(bank.randomize ? " · random" : "")")
                            .font(.kCaption2)
                            .foregroundStyle(Color.kTextTertiary)
                    } else if bank.randomize {
                        Text("Random order")
                            .font(.kCaption2)
                            .foregroundStyle(Color.kTextTertiary)
                    }
                }
                Spacer()

                Button {
                    bank.randomize.toggle()
                    Haptics.light()
                } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(bank.randomize ? Color.kAccent : Color.kTextTertiary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.kAccent.opacity(bank.randomize ? 0.15 : 0.06)))
                }

                Button {
                    startQuery = bank.buildQuery
                    Haptics.medium()
                } label: {
                    HStack(spacing: 6) {
                        Text("Start")
                            .font(.kHeadline)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .frame(height: 44)
                    .background(Capsule().fill(LinearGradient.kPurpleGradient))
                    .kShadowGlow()
                }
            }
            .padding(Spacing.sm)
            .kGlassEffect(cornerRadius: CornerRadius.xxl)
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xs)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - SATQuery needs Hashable for navigationDestination(item:)

extension SATQuery: Hashable {
    static func == (lhs: SATQuery, rhs: SATQuery) -> Bool {
        lhs.sections == rhs.sections && lhs.domains == rhs.domains
            && lhs.skills == rhs.skills && lhs.difficulties == rhs.difficulties
            && lhs.assessment == rhs.assessment && lhs.limit == rhs.limit
            && lhs.random == rhs.random && lhs.questionIds == rhs.questionIds
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(skills)
        hasher.combine(assessment)
        hasher.combine(questionIds)
    }
}

// MARK: - Bank palette
// Same color-blocking as the section cards on the Practice tab.

private extension SATBankView {
    /// Light blue used for selected/active filter buttons (instead of the purple accent).
    static let filterActive = Color(red: 0.31, green: 0.62, blue: 0.94)

    static let englishGradient = LinearGradient(
        colors: [Color(red: 0.30, green: 0.51, blue: 0.94), Color(red: 0.30, green: 0.71, blue: 0.91)],
        startPoint: .leading, endPoint: .trailing)

    static let mathGradient = LinearGradient(
        colors: [Color(red: 0.22, green: 0.65, blue: 0.45), Color(red: 0.36, green: 0.78, blue: 0.55)],
        startPoint: .leading, endPoint: .trailing)
}
