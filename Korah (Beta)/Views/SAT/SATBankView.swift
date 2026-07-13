import SwiftUI

// MARK: - SAT Question Bank browser
// Mobile take on sat/index.html: pick topics (sections → domains → skills)
// with live question counts + your progress/accuracy, set difficulty /
// limit / randomize, then start a player session.

struct SATBankView: View {
    @State private var bank = SATBankStore.shared
    @State private var startQuery: SATQuery?
    @State private var showFilters = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    header

                    if let error = bank.statsError {
                        errorBanner(error)
                    }

                    ForEach(SATCatalog.sections) { section in
                        sectionCard(section)
                    }

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, Spacing.md)
            }

            startPill
        }
        .background(Color.kBackground)
        .navigationTitle("Question Bank")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            SATBankFiltersSheet(bank: bank)
                .presentationDetents([.medium])
        }
        .navigationDestination(item: $startQuery) { query in
            SATPlayerView(query: query)
        }
        .task { await bank.loadIfNeeded() }
        .refreshable {
            await bank.loadStats(force: true)
            await bank.loadProgress()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Official College Board questions")
                .font(.kSubheadline)
                .foregroundStyle(Color.kTextSecondary)
            if let stats = bank.stats {
                Text("\(stats.totalQuestions) questions · \(bank.assessment)")
                    .font(.kCaption)
                    .foregroundStyle(Color.kTextTertiary)
            } else if bank.isLoadingStats {
                ProgressView().tint(Color.kAccent)
            }
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

    // MARK: - Section card

    private func sectionCard(_ section: SATSectionInfo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(KAnimation.quick) { bank.toggleSection(section) }
                Haptics.selection()
            } label: {
                HStack(spacing: Spacing.sm) {
                    checkbox(isOn: bank.isSectionSelected(section))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.label)
                            .font(.kTitle3)
                            .foregroundStyle(Color.kTextPrimary)
                        let count = bank.questionCount(forSection: section)
                        if count > 0 {
                            Text("\(count) questions")
                                .font(.kCaption)
                                .foregroundStyle(Color.kTextTertiary)
                        }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            ForEach(section.domains) { domain in
                domainGroup(section: section, domain: domain)
            }
        }
        .padding(Spacing.md)
        .kGlassEffect(cornerRadius: CornerRadius.xl)
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

    private func checkbox(isOn: Bool, small: Bool = false) -> some View {
        Image(systemName: isOn ? "checkmark.square.fill" : "square")
            .font(small ? .subheadline : .title3)
            .foregroundStyle(isOn ? Color.kAccent : Color.kTextTertiary)
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

// MARK: - Filters sheet (assessment / difficulty / limit)

struct SATBankFiltersSheet: View {
    @Bindable var bank: SATBankStore
    @Environment(\.dismiss) private var dismiss
    @State private var limitText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Question set") {
                    Picker("Assessment", selection: $bank.assessment) {
                        ForEach(SATCatalog.assessments, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Difficulty") {
                    HStack(spacing: Spacing.xs) {
                        ForEach(SATCatalog.difficulties, id: \.code) { difficulty in
                            let isOn = bank.selectedDifficulties.contains(difficulty.code)
                            Button {
                                if isOn { bank.selectedDifficulties.remove(difficulty.code) }
                                else { bank.selectedDifficulties.insert(difficulty.code) }
                                Haptics.selection()
                            } label: {
                                Text(difficulty.label)
                                    .font(.kSubheadline)
                                    .foregroundStyle(isOn ? .white : Color.kTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule().fill(isOn ? Color.kAccent : Color.kSurface)
                                    )
                                    .overlay(Capsule().stroke(Color.kBorder, lineWidth: isOn ? 0 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Question limit") {
                    TextField("No limit", text: $limitText)
                        .keyboardType(.numberPad)
                        .onChange(of: limitText) { _, newValue in
                            bank.limit = Int(newValue).flatMap { $0 > 0 ? $0 : nil }
                        }
                    Toggle("Randomize order", isOn: $bank.randomize)
                }

                Section {
                    Button("Reset all filters", role: .destructive) {
                        bank.resetFilters()
                        limitText = ""
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                limitText = bank.limit.map(String.init) ?? ""
            }
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
