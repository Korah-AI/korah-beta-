import SwiftUI

struct RecentStudyItem: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let kind: String
    let createdAt: Date

    static let flashcardsKind = "Flashcards"
    static let studyGuideKind = "Study Guides"
    static let practiceTestKind = "Practice Tests"
}

struct StudyHomeView: View {
    @State private var recentStudyItems: [RecentStudyItem] = []
    @State private var startStudyGuidesCreation = false

    @State private var showAddSetSheet = false
    @State private var newSetTitle: String = ""
    @State private var showStudyGuidesCreator = false
    @State private var showPracticeTestsCreator = false
    @State private var showManualStudyGuideCreate = false
    @State private var showManualPracticeTestCreate = false

    @State private var flashcardsCount: Int = 0
    @State private var guidesCount: Int = 0
    @State private var testsCount: Int = 0

    @State private var navigateToFlashcards = false
    @State private var navigateToStudyGuides = false
    @State private var navigateToPracticeTests = false

    @State private var startFlashcardsCreation = false
    @State private var startPracticeTestsCreation = false

    @State private var showCreationTemplate = false
    @State private var showManualFlashcardsView = false
    @State private var showAIGenerateFlashcardsFromGuide = false
    @State private var showAIGenerateStudyGuideFromFlashcards = false
    @State private var showAIGeneratePracticeTestFromGuide = false
    @State private var showScanFlashcards = false
    @State private var showScanStudyGuide = false
    @State private var showScanPracticeTest = false
    enum CreationType { case flashcards, studyGuides, practiceTests }
    @State private var pendingCreationType: CreationType? = nil

    enum StudyFilter: String, CaseIterable { case all = "All", flashcards = "Flashcards", studyGuides = "Study Guides", practiceTests = "Practice Tests" }
    @State private var selectedFilter: StudyFilter = .all

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(StudyFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Menu {
                    Button("Flashcard Set") { pendingCreationType = .flashcards; showCreationTemplate = true }
                    Button("Study Guide") { pendingCreationType = .studyGuides; showCreationTemplate = true }
                    Button("Practice Test") { pendingCreationType = .practiceTests; showCreationTemplate = true }
                } label: {
                    HStack { Image(systemName: "plus.circle.fill"); Text("Create") }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            if recentStudyItems.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text("Your recent study items will be displayed here")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.5))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal)
                                .padding(.vertical, 32)
                            } else {
                                ForEach(Array(recentStudyItems.prefix(3))) { item in
                                    NavigationLink {
                                        destination(for: item.id, kind: item.kind)
                                    } label: {
                                        StudyItemCardView(
                                            title: item.title,
                                            subtitle: item.createdAt.formatted(date: .abbreviated, time: .shortened),
                                            icon: icon(for: item.kind)
                                        )
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteItem(id: item.id, kind: item.kind)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(selectedFilter.rawValue)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            switch selectedFilter {
                            case .all:
                                VStack(spacing: 10) {
                                    ForEach(allItemsSortedByOpened(), id: \.id) { item in
                                        NavigationLink { 
                                            destination(for: item.id, kind: item.kind) 
                                        } label: {
                                            StudyItemCardView(
                                                title: item.title,
                                                subtitle: openedText(item.lastOpenedAt),
                                                icon: icon(for: item.kind)
                                            )
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteItem(id: item.id, kind: item.kind)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            case .flashcards:
                                VStack(spacing: 10) {
                                    ForEach(flashcardItemsSorted(), id: \.id) { item in
                                        NavigationLink { 
                                            destination(for: item.id, kind: item.kind) 
                                        } label: {
                                            StudyItemCardView(
                                                title: item.title,
                                                subtitle: openedText(item.lastOpenedAt),
                                                icon: icon(for: item.kind)
                                            )
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteItem(id: item.id, kind: item.kind)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            case .studyGuides:
                                VStack(spacing: 10) {
                                    ForEach(studyGuideItemsSorted(), id: \.id) { item in
                                        NavigationLink { 
                                            destination(for: item.id, kind: item.kind) 
                                        } label: {
                                            StudyItemCardView(
                                                title: item.title,
                                                subtitle: openedText(item.lastOpenedAt),
                                                icon: icon(for: item.kind)
                                            )
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteItem(id: item.id, kind: item.kind)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            case .practiceTests:
                                VStack(spacing: 10) {
                                    ForEach(practiceTestItemsSorted(), id: \.id) { item in
                                        NavigationLink { 
                                            destination(for: item.id, kind: item.kind) 
                                        } label: {
                                            StudyItemCardView(
                                                title: item.title,
                                                subtitle: openedText(item.lastOpenedAt),
                                                icon: icon(for: item.kind)
                                            )
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteItem(id: item.id, kind: item.kind)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .background(Color.clear)

                Spacer(minLength: 0)
            }
            .sheet(isPresented: $showManualFlashcardsView) {
                NavigationStack { ManualFlashcardSetCreateView() }
            }
            .sheet(isPresented: $showManualStudyGuideCreate) {
                NavigationStack { ManualStudyGuideCreateView() }
            }
            .sheet(isPresented: $showManualPracticeTestCreate) {
                NavigationStack { ManualPracticeTestCreateView() }
            }
            .sheet(isPresented: $showAIGenerateFlashcardsFromGuide) {
                NavigationStack { AIGenerateFlashcardsFromGuideView() }
            }
            .sheet(isPresented: $showAIGenerateStudyGuideFromFlashcards) {
                NavigationStack { AIGenerateStudyGuideFromFlashcardsView() }
            }
            .sheet(isPresented: $showAIGeneratePracticeTestFromGuide) {
                NavigationStack { AIGeneratePracticeTestFromGuideView() }
            }
            .sheet(isPresented: $showScanFlashcards) {
                NavigationStack { ScanFlashcardsView() }
            }
            .sheet(isPresented: $showScanStudyGuide) {
                NavigationStack { ScanStudyGuideView() }
            }
            .sheet(isPresented: $showScanPracticeTest) {
                NavigationStack { ScanPracticeTestView() }
            }
            .sheet(isPresented: $navigateToFlashcards) {
                NavigationStack { FlashcardsView(openAddSetOnAppear: startFlashcardsCreation) }
            }
            .sheet(isPresented: $navigateToStudyGuides) {
                NavigationStack { StudyGuidesView(openGeneratorOnAppear: startStudyGuidesCreation) }
            }
            .sheet(isPresented: $navigateToPracticeTests) {
                NavigationStack { PracticeTestsView(openAICreationOnAppear: startPracticeTestsCreation) }
            }
            .sheet(isPresented: $showCreationTemplate) {
                CreationTemplateSheet(pendingCreationType: pendingCreationType,
                                      onScanImages: {
                                          guard let type = pendingCreationType else { return }
                                          handleScanImages(type: type)
                                      },
                                      onCreateManual: {
                                          guard let type = pendingCreationType else { return }
                                          handleCreationChoice(type: type, mode: .manual)
                                      },
                                      onGenerateFromCrossType: {
                                          guard let type = pendingCreationType else { return }
                                          handleCreationChoice(type: type, mode: .generateFromCrossType)
                                      })
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Study")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .korahGradientBackground()
        }
        .tint(.purple)
        .onAppear(perform: loadRecentStudy)
    }

    private func openedText(_ date: Date?) -> String {
        guard let date = date else { return "Never opened" }
        return "Opened " + date.formatted(.relative(presentation: .named))
    }

    struct StudyItemRow: Identifiable { let id: UUID; let title: String; let kind: String; let lastOpenedAt: Date? }

    private func allItemsSortedByOpened() -> [StudyItemRow] {
        (flashcardItemsSorted() + studyGuideItemsSorted() + practiceTestItemsSorted()).sorted { (a, b) in
            (a.lastOpenedAt ?? .distantPast) > (b.lastOpenedAt ?? .distantPast)
        }
    }

    private func flashcardItemsSorted() -> [StudyItemRow] {
        var rows: [StudyItemRow] = []
        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"), let sets = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
            rows = sets.map { StudyItemRow(id: $0.id, title: $0.title, kind: RecentStudyItem.flashcardsKind, lastOpenedAt: $0.lastOpenedAt) }
        }
        return rows.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    private func studyGuideItemsSorted() -> [StudyItemRow] {
        var rows: [StudyItemRow] = []
        if let data = UserDefaults.standard.data(forKey: "StudyGuides"), let guides = try? JSONDecoder().decode([StudyGuide].self, from: data) {
            rows = guides.map { StudyItemRow(id: $0.id, title: $0.title, kind: RecentStudyItem.studyGuideKind, lastOpenedAt: $0.lastOpenedAt) }
        }
        return rows.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    private func practiceTestItemsSorted() -> [StudyItemRow] {
        var rows: [StudyItemRow] = []
        if let data = UserDefaults.standard.data(forKey: "PracticeTests"), let tests = try? JSONDecoder().decode([PracticeTest].self, from: data) {
            rows = tests.map { StudyItemRow(id: $0.id, title: $0.title, kind: RecentStudyItem.practiceTestKind, lastOpenedAt: $0.lastOpenedAt) }
        }
        return rows.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    @ViewBuilder
    private func destination(for kind: String) -> some View {
        switch kind {
        case RecentStudyItem.flashcardsKind: FlashcardsView()
        case RecentStudyItem.studyGuideKind: StudyGuidesView()
        case RecentStudyItem.practiceTestKind: PracticeTestsView()
        default: FlashcardsView()
        }
    }

    @ViewBuilder
    private func destination(for id: UUID, kind: String) -> some View {
        switch kind {
        case RecentStudyItem.flashcardsKind:
            if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
               let sets = try? JSONDecoder().decode([FlashcardSet].self, from: data),
               let set = sets.first(where: { $0.id == id }) {
                FlashcardsView(selectedSetID: set.id)
            } else {
                FlashcardsView()
            }
        case RecentStudyItem.studyGuideKind:
            if let data = UserDefaults.standard.data(forKey: "StudyGuides"),
               let guides = try? JSONDecoder().decode([StudyGuide].self, from: data),
               let guide = guides.first(where: { $0.id == id }) {
                StudyGuideDetailView(guide: guide)
            } else {
                StudyGuidesView()
            }
        case RecentStudyItem.practiceTestKind:
            if let data = UserDefaults.standard.data(forKey: "PracticeTests"),
               let tests = try? JSONDecoder().decode([PracticeTest].self, from: data),
               let test = tests.first(where: { $0.id == id }) {
                PracticeTestDetailLoaderView(testID: test.id)
            } else {
                PracticeTestsView()
            }
        default:
            FlashcardsView()
        }
    }

    private enum CreationMode { case manual, generateFromCrossType }
    
    private func handleScanImages(type: CreationType) {
        showCreationTemplate = false
        switch type {
        case .flashcards:
            showScanFlashcards = true
        case .studyGuides:
            showScanStudyGuide = true
        case .practiceTests:
            showScanPracticeTest = true
        }
    }

    private func handleCreationChoice(type: CreationType, mode: CreationMode) {
        showCreationTemplate = false
        startFlashcardsCreation = false
        startStudyGuidesCreation = false
        startPracticeTestsCreation = false

        switch type {
        case .flashcards:
            if mode == .manual {
                showManualFlashcardsView = true
            } else if mode == .generateFromCrossType {
                showAIGenerateFlashcardsFromGuide = true
            } else {
                startFlashcardsCreation = true
                navigateToFlashcards = true
            }
        case .studyGuides:
            if mode == .manual {
                showManualStudyGuideCreate = true
            } else if mode == .generateFromCrossType {
                showAIGenerateStudyGuideFromFlashcards = true
            } else {
                startStudyGuidesCreation = true
                navigateToStudyGuides = true
            }
        case .practiceTests:
            if mode == .manual {
                showManualPracticeTestCreate = true
            } else if mode == .generateFromCrossType {
                showAIGeneratePracticeTestFromGuide = true
            } else {
                startPracticeTestsCreation = true
                navigateToPracticeTests = true
            }
        }
    }

    struct TypeRow: View {
        let title: String
        let systemImage: String
        let count: Int
        let onOpen: () -> Void
        let onCreate: () -> Void

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(.purple)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }
                Spacer()
                Button(action: onCreate) {
                    Label("Create", systemImage: "plus")
                        .fixedSize(horizontal: true, vertical: true)
                }
                .buttonStyle(.bordered)
                .tint(.purple)

                Button(action: onOpen) {
                    Label("Open", systemImage: "chevron.right")
                        .fixedSize(horizontal: true, vertical: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case RecentStudyItem.flashcardsKind: return "rectangle.stack"
        case RecentStudyItem.studyGuideKind: return "book.closed"
        case RecentStudyItem.practiceTestKind: return "doc.text.magnifyingglass"
        default: return "doc"
        }
    }

    private var addSetSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Set Title")) {
                    TextField("e.g. Biology - Cell Parts", text: $newSetTitle)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddSetSheet = false; newSetTitle = "" }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { addSet() }
                        .disabled(newSetTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .korahGradientBackground()
    }

    private func addSet() {
        let title = newSetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        var sets: [FlashcardSet] = []
        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let decoded = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
            sets = decoded
        }
        let new = FlashcardSet(title: title, cards: [])
        sets.append(new)
        if let encoded = try? JSONEncoder().encode(sets) {
            UserDefaults.standard.set(encoded, forKey: "FlashcardSets")
        }
        newSetTitle = ""
        showAddSetSheet = false
        loadRecentStudy()
    }

    private func deleteItem(id: UUID, kind: String) {
        switch kind {
        case RecentStudyItem.flashcardsKind:
            if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
               var sets = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
                sets.removeAll { $0.id == id }
                if let encoded = try? JSONEncoder().encode(sets) {
                    UserDefaults.standard.set(encoded, forKey: "FlashcardSets")
                }
            }
        case RecentStudyItem.studyGuideKind:
            if let data = UserDefaults.standard.data(forKey: "StudyGuides"),
               var guides = try? JSONDecoder().decode([StudyGuide].self, from: data) {
                guides.removeAll { $0.id == id }
                if let encoded = try? JSONEncoder().encode(guides) {
                    UserDefaults.standard.set(encoded, forKey: "StudyGuides")
                }
            }
        case RecentStudyItem.practiceTestKind:
            if let data = UserDefaults.standard.data(forKey: "PracticeTests"),
               var tests = try? JSONDecoder().decode([PracticeTest].self, from: data) {
                tests.removeAll { $0.id == id }
                if let encoded = try? JSONEncoder().encode(tests) {
                    UserDefaults.standard.set(encoded, forKey: "PracticeTests")
                }
            }
        default:
            break
        }
        loadRecentStudy()
        HomeDataManager.shared.loadRecentStudyItems()
    }
    
    private func loadRecentStudy() {
        var allItems: [RecentStudyItem] = []
        let decoder = JSONDecoder()

        if let flashcardData = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let flashcardSets = try? decoder.decode([FlashcardSet].self, from: flashcardData) {
            let flashcardsItems = flashcardSets.map {
                RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.flashcardsKind, createdAt: $0.createdAt)
            }
            allItems.append(contentsOf: flashcardsItems)
        }

        if let guidesData = UserDefaults.standard.data(forKey: "StudyGuides"),
           let studyGuides = try? decoder.decode([StudyGuide].self, from: guidesData) {
            let guideItems = studyGuides.map {
                RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.studyGuideKind, createdAt: $0.createdAt)
            }
            allItems.append(contentsOf: guideItems)
        }

        if let testsData = UserDefaults.standard.data(forKey: "PracticeTests"),
           let practiceTests = try? decoder.decode([PracticeTest].self, from: testsData) {
            let testItems = practiceTests.map {
                RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.practiceTestKind, createdAt: $0.createdAt)
            }
            allItems.append(contentsOf: testItems)
        }

        flashcardsCount = allItems.filter { $0.kind == RecentStudyItem.flashcardsKind }.count
        guidesCount = allItems.filter { $0.kind == RecentStudyItem.studyGuideKind }.count
        testsCount = allItems.filter { $0.kind == RecentStudyItem.practiceTestKind }.count

        recentStudyItems = allItems.sorted(by: { $0.createdAt > $1.createdAt })
        
        HomeDataManager.shared.loadRecentStudyItems()
    }
}

private struct CreationTemplateSheet: View {
    let pendingCreationType: StudyHomeView.CreationType?
    let onScanImages: () -> Void
    let onCreateManual: () -> Void
    let onGenerateFromCrossType: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(titleText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top)

                VStack(spacing: 12) {
                    Button(action: onScanImages) {
                        HStack { Image(systemName: "doc.viewfinder"); Text("Scan Images"); Spacer() }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple.opacity(0.3))
                            .cornerRadius(10)
                    }
                    Button(action: onCreateManual) {
                        HStack { Image(systemName: "pencil"); Text("Create Manually"); Spacer() }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple.opacity(0.3))
                            .cornerRadius(10)
                    }
                    Button(action: onGenerateFromCrossType) {
                        HStack { Image(systemName: "sparkles"); Text(crossTypeButtonLabel); Spacer() }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green.opacity(0.3))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("How would you like to create this item?")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            .korahGradientBackground()
        }
    }

    private var titleText: String {
        switch pendingCreationType {
        case .flashcards: return "Create Flashcard Set"
        case .studyGuides: return "Create Study Guide"
        case .practiceTests: return "Create Practice Test"
        case .none: return "Create"
        }
    }
    
    private var crossTypeButtonLabel: String {
        switch pendingCreationType {
        case .flashcards: return "Generate from Study Guide"
        case .studyGuides: return "Generate from Flashcards"
        case .practiceTests: return "Generate from Study Guide"
        case .none: return "Generate"
        }
    }
}

struct StudyCard<Destination: View>: View {
    let destination: Destination
    let title: String
    let systemImage: String

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundColor(.purple)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(.purple)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

struct PracticeTestDetailLoaderView: View {
    let testID: UUID
    @State private var store = PracticeTestsStore()

    var body: some View {
        if let index = store.practiceTests.firstIndex(where: { $0.id == testID }) {
            PracticeTestDetailView(practiceTest: Binding(
                get: { store.practiceTests[index] },
                set: { store.practiceTests[index] = $0 }
            ))
        } else {
            PracticeTestsView()
        }
    }
}

struct StudyItemCardView: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.purple)
                .frame(width: 50, height: 50)
                .background(Color.purple.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.purple.opacity(0.7))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    StudyHomeView()
}
