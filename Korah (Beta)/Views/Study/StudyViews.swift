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
    
    // State arrays to trigger view updates
    @State private var allFlashcards: [StudyItemRow] = []
    @State private var allStudyGuides: [StudyItemRow] = []
    @State private var allPracticeTests: [StudyItemRow] = []
    @State private var refreshTrigger = false

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
    @State private var showFlashcardGenerationOptions = false
    @State private var showAIFlashcardPromptGenerator = false
    @State private var showStudyGuideGenerationOptions = false
    @State private var showAIStudyGuidePromptGenerator = false
    @State private var showPracticeTestGenerationOptions = false
    @State private var showAIPracticeTestPromptGenerator = false
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
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 60))
                                        .foregroundColor(.purple)
                                        .shadow(color: .purple.opacity(0.3), radius: 10)
                                    
                                    Text("Start Your Study Journey")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("Create flashcards, study guides, or practice tests to begin learning")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                    
                                    HStack(spacing: 12) {
                                        Button(action: { pendingCreationType = .flashcards; showCreationTemplate = true }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "rectangle.stack")
                                                    .font(.system(size: 24))
                                                Text("Flashcards")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .foregroundColor(.white)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                        
                                        Button(action: { pendingCreationType = .studyGuides; showCreationTemplate = true }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "book.closed")
                                                    .font(.system(size: 24))
                                                Text("Guide")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .foregroundColor(.white)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                        
                                        Button(action: { pendingCreationType = .practiceTests; showCreationTemplate = true }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "doc.text.magnifyingglass")
                                                    .font(.system(size: 24))
                                                Text("Test")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .foregroundColor(.white)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 24)
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
                                            subtitle: item.createdAt.formattedCreatedAt(),
                                            icon: icon(for: item.kind)
                                        )
                                    }
                                    .contextMenu {
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
                                        .contextMenu {
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
                                        .contextMenu {
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
                                        .contextMenu {
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
                                        .contextMenu {
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
                .refreshable {
                    loadRecentStudy()
                }

                Spacer(minLength: 0)
            }
            .sheet(isPresented: $showManualFlashcardsView, onDismiss: { loadRecentStudy() }) {
                NavigationStack { ManualFlashcardSetCreateView() }
            }
            .sheet(isPresented: $showManualStudyGuideCreate, onDismiss: { loadRecentStudy() }) {
                NavigationStack { ManualStudyGuideCreateView() }
            }
            .sheet(isPresented: $showManualPracticeTestCreate, onDismiss: { loadRecentStudy() }) {
                NavigationStack { ManualPracticeTestCreateView() }
            }
            .sheet(isPresented: $showFlashcardGenerationOptions) {
                FlashcardGenerationOptionsSheet(
                    onPromptGeneration: {
                        showFlashcardGenerationOptions = false
                        showAIFlashcardPromptGenerator = true
                    },
                    onStudyGuideGeneration: {
                        showFlashcardGenerationOptions = false
                        showAIGenerateFlashcardsFromGuide = true
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAIFlashcardPromptGenerator, onDismiss: { loadRecentStudy() }) {
                NavigationStack { AIFlashcardPromptGeneratorView() }
            }
            .sheet(isPresented: $showAIGenerateFlashcardsFromGuide, onDismiss: { loadRecentStudy() }) {
                NavigationStack { AIGenerateFlashcardsFromGuideView() }
            }
            .sheet(isPresented: $showStudyGuideGenerationOptions) {
                StudyGuideGenerationOptionsSheet(
                    onPromptGeneration: {
                        showStudyGuideGenerationOptions = false
                        showAIStudyGuidePromptGenerator = true
                    },
                    onFlashcardsGeneration: {
                        showStudyGuideGenerationOptions = false
                        showAIGenerateStudyGuideFromFlashcards = true
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAIStudyGuidePromptGenerator, onDismiss: { loadRecentStudy() }) {
                NavigationStack { AIStudyGuidePromptGeneratorView() }
            }
            .sheet(isPresented: $showAIGenerateStudyGuideFromFlashcards, onDismiss: { loadRecentStudy() }) {
                NavigationStack { AIGenerateStudyGuideFromFlashcardsView() }
            }
            .sheet(isPresented: $showPracticeTestGenerationOptions) {
                PracticeTestGenerationOptionsSheet(
                    onPromptGeneration: {
                        showPracticeTestGenerationOptions = false
                        showAIPracticeTestPromptGenerator = true
                    },
                    onStudyGuideGeneration: {
                        showPracticeTestGenerationOptions = false
                        showAIGeneratePracticeTestFromGuide = true
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAIPracticeTestPromptGenerator, onDismiss: { loadRecentStudy() }) {
                NavigationStack { AIPracticeTestPromptGeneratorView() }
            }
            .sheet(isPresented: $showAIGeneratePracticeTestFromGuide, onDismiss: { loadRecentStudy() }) {
                NavigationStack { AIGeneratePracticeTestFromGuideView() }
            }
            .sheet(isPresented: $showScanFlashcards, onDismiss: { loadRecentStudy() }) {
                NavigationStack { ScanFlashcardsView() }
            }
            .sheet(isPresented: $showScanStudyGuide, onDismiss: { loadRecentStudy() }) {
                NavigationStack { ScanStudyGuideView() }
            }
            .sheet(isPresented: $showScanPracticeTest, onDismiss: { loadRecentStudy() }) {
                NavigationStack { ScanPracticeTestView() }
            }
            .sheet(isPresented: $navigateToFlashcards, onDismiss: { loadRecentStudy() }) {
                NavigationStack { FlashcardsView(openAddSetOnAppear: startFlashcardsCreation) }
            }
            .sheet(isPresented: $navigateToStudyGuides, onDismiss: { loadRecentStudy() }) {
                NavigationStack { StudyGuidesView(openGeneratorOnAppear: startStudyGuidesCreation) }
            }
            .sheet(isPresented: $navigateToPracticeTests, onDismiss: { loadRecentStudy() }) {
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
                    .presentationDetents([.large])
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
        date.formattedLastOpened()
    }

    struct StudyItemRow: Identifiable { let id: UUID; let title: String; let kind: String; let lastOpenedAt: Date? }

    private func allItemsSortedByOpened() -> [StudyItemRow] {
        (flashcardItemsSorted() + studyGuideItemsSorted() + practiceTestItemsSorted()).sorted { (a, b) in
            (a.lastOpenedAt ?? .distantPast) > (b.lastOpenedAt ?? .distantPast)
        }
    }

    private func flashcardItemsSorted() -> [StudyItemRow] {
        return allFlashcards
    }

    private func studyGuideItemsSorted() -> [StudyItemRow] {
        return allStudyGuides
    }

    private func practiceTestItemsSorted() -> [StudyItemRow] {
        return allPracticeTests
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
                showFlashcardGenerationOptions = true
            } else {
                startFlashcardsCreation = true
                navigateToFlashcards = true
            }
        case .studyGuides:
            if mode == .manual {
                showManualStudyGuideCreate = true
            } else if mode == .generateFromCrossType {
                showStudyGuideGenerationOptions = true
            } else {
                startStudyGuidesCreation = true
                navigateToStudyGuides = true
            }
        case .practiceTests:
            if mode == .manual {
                showManualPracticeTestCreate = true
            } else if mode == .generateFromCrossType {
                showPracticeTestGenerationOptions = true
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

        // Load flashcards
        if let flashcardData = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let flashcardSets = try? decoder.decode([FlashcardSet].self, from: flashcardData) {
            let flashcardsItems = flashcardSets.map {
                RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.flashcardsKind, createdAt: $0.createdAt)
            }
            allItems.append(contentsOf: flashcardsItems)
            allFlashcards = flashcardSets.map { 
                StudyItemRow(id: $0.id, title: $0.title, kind: RecentStudyItem.flashcardsKind, lastOpenedAt: $0.lastOpenedAt) 
            }.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
        } else {
            allFlashcards = []
        }

        // Load study guides
        if let guidesData = UserDefaults.standard.data(forKey: "StudyGuides"),
           let studyGuides = try? decoder.decode([StudyGuide].self, from: guidesData) {
            let guideItems = studyGuides.map {
                RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.studyGuideKind, createdAt: $0.createdAt)
            }
            allItems.append(contentsOf: guideItems)
            allStudyGuides = studyGuides.map { 
                StudyItemRow(id: $0.id, title: $0.title, kind: RecentStudyItem.studyGuideKind, lastOpenedAt: $0.lastOpenedAt) 
            }.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
        } else {
            allStudyGuides = []
        }

        // Load practice tests
        if let testsData = UserDefaults.standard.data(forKey: "PracticeTests"),
           let practiceTests = try? decoder.decode([PracticeTest].self, from: testsData) {
            let testItems = practiceTests.map {
                RecentStudyItem(id: $0.id, title: $0.title, kind: RecentStudyItem.practiceTestKind, createdAt: $0.createdAt)
            }
            allItems.append(contentsOf: testItems)
            allPracticeTests = practiceTests.map { 
                StudyItemRow(id: $0.id, title: $0.title, kind: RecentStudyItem.practiceTestKind, lastOpenedAt: $0.lastOpenedAt) 
            }.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
        } else {
            allPracticeTests = []
        }

        flashcardsCount = allItems.filter { $0.kind == RecentStudyItem.flashcardsKind }.count
        guidesCount = allItems.filter { $0.kind == RecentStudyItem.studyGuideKind }.count
        testsCount = allItems.filter { $0.kind == RecentStudyItem.practiceTestKind }.count

        recentStudyItems = allItems.sorted(by: { $0.createdAt > $1.createdAt })
        
        // Toggle refresh trigger to force view update
        refreshTrigger.toggle()
        
        HomeDataManager.shared.loadRecentStudyItems()
    }
}

private struct CreationTemplateSheet: View {
    let pendingCreationType: StudyHomeView.CreationType?
    let onScanImages: () -> Void
    let onCreateManual: () -> Void
    let onGenerateFromCrossType: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image(systemName: iconForType)
                        .font(.system(size: 60))
                        .foregroundColor(colorForType)
                        .shadow(color: colorForType.opacity(0.3), radius: 10)
                    
                    Text(titleText)
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("Choose your creation method")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.bottom, 32)
                
                VStack(spacing: 16) {
                    CreationOptionCard(
                        icon: "doc.viewfinder",
                        title: "Scan Images",
                        description: "Upload images to extract content",
                        buttonText: "Scan",
                        color: .blue,
                        action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onScanImages()
                            }
                        }
                    )
                    
                    CreationOptionCard(
                        icon: "pencil.line",
                        title: "Create Manually",
                        description: "Build from scratch with manual input",
                        buttonText: "Create",
                        color: .purple,
                        action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onCreateManual()
                            }
                        }
                    )
                    
                    CreationOptionCard(
                        icon: "sparkles",
                        title: crossTypeTitle,
                        description: crossTypeDescription,
                        buttonText: "Generate",
                        color: .green,
                        action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onGenerateFromCrossType()
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(colorForType)
                }
            }
            .korahGradientBackground()
        }
    }

    private var titleText: String {
        switch pendingCreationType {
        case .flashcards: return "Create Flashcards"
        case .studyGuides: return "Create Study Guide"
        case .practiceTests: return "Create Practice Test"
        case .none: return "Create"
        }
    }
    
    private var iconForType: String {
        switch pendingCreationType {
        case .flashcards: return "rectangle.stack"
        case .studyGuides: return "book.closed"
        case .practiceTests: return "doc.text.magnifyingglass"
        case .none: return "sparkles"
        }
    }
    
    private var colorForType: Color {
        switch pendingCreationType {
        case .flashcards: return .purple
        case .studyGuides: return .blue
        case .practiceTests: return .green
        case .none: return .purple
        }
    }
    
    private var crossTypeTitle: String {
        return "Autogenerate with A.I."
    }
    
    private var crossTypeDescription: String {
        switch pendingCreationType {
        case .flashcards: return "Generate flashcards using AI from a study guide"
        case .studyGuides: return "Generate a study guide using AI from flashcards"
        case .practiceTests: return "Generate a practice test using AI from a study guide"
        case .none: return "Generate content with AI"
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

private struct FlashcardGenerationOptionsSheet: View {
    let onPromptGeneration: () -> Void
    let onStudyGuideGeneration: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                        .shadow(color: .purple.opacity(0.3), radius: 10)
                    
                    Text("Generate Flashcards")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("Choose your generation method")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.bottom, 32)
                
                VStack(spacing: 16) {
                    GenerationOptionCard(
                        icon: "brain",
                        title: "AI Prompt",
                        description: "Use an AI prompt to generate flashcards",
                        buttonText: "Generate With A.I.",
                        color: .purple,
                        action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onPromptGeneration()
                            }
                        }
                    )
                    
                    GenerationOptionCard(
                        icon: "book.closed",
                        title: "From Study Guide",
                        description: "Use an existing study guide",
                        buttonText: "Generate",
                        color: .green,
                        action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onStudyGuideGeneration()
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.purple)
                }
            }
            .korahGradientBackground()
        }
    }
}

private struct StudyGuideGenerationOptionsSheet: View {
    let onPromptGeneration: () -> Void
    let onFlashcardsGeneration: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 10)
                    
                    Text("Generate Study Guide")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("Choose your generation method")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.bottom, 32)
                
                VStack(spacing: 16) {
                    GenerationOptionCard(
                        icon: "brain",
                        title: "AI Prompt",
                        description: "Describe the topic you want to study",
                        buttonText: "Generate With A.I.",
                        color: .blue,
                        action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onPromptGeneration()
                            }
                        }
                    )
                    
                    GenerationOptionCard(
                        icon: "rectangle.stack",
                        title: "From Flashcards",
                        description: "Use existing flashcard sets",
                        buttonText: "Generate",
                        color: .orange,
                        action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onFlashcardsGeneration()
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
            .korahGradientBackground()
        }
    }
}

private struct PracticeTestGenerationOptionsSheet: View {
    let onPromptGeneration: () -> Void
    let onStudyGuideGeneration: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.3), radius: 10)
                    
                    Text("Generate Practice Test")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("Choose your generation method")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.bottom, 32)
                
                VStack(spacing: 16) {
                    GenerationOptionCard(
                        icon: "brain",
                        title: "AI Prompt",
                        description: "Describe the topic you want to test",
                        buttonText: "Generate With A.I.",
                        color: .green,
                        action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onPromptGeneration()
                            }
                        }
                    )
                    
                    GenerationOptionCard(
                        icon: "book.closed",
                        title: "From Study Guide",
                        description: "Use an existing study guide",
                        buttonText: "Generate",
                        color: .blue,
                        action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onStudyGuideGeneration()
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.green)
                }
            }
            .korahGradientBackground()
        }
    }
}

private struct GenerationOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(20)
            
            Button(action: action) {
                Text(buttonText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(color)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1.5)
        )
    }
}

private struct CreationOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(20)
            
            Button(action: action) {
                Text(buttonText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(color)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1.5)
        )
    }
}

#Preview {
    StudyHomeView()
}
