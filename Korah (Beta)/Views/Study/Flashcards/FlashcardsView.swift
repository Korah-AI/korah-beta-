import SwiftUI

// Using shared utility from StudyUtilities.extractJSONObject

struct FlashcardsView: View {
    let selectedSetID: UUID?
    let openAddSetOnAppear: Bool

    init(openAddSetOnAppear: Bool = false, selectedSetID: UUID? = nil) {
        self.openAddSetOnAppear = openAddSetOnAppear
        self.selectedSetID = selectedSetID
    }
    @State private var sets: [FlashcardSet] = []
    @State private var selectedSet: FlashcardSet? = nil
    @State private var showingAddSet = false
    @State private var newSetTitle: String = ""
    @State private var setToEdit: FlashcardSet? = nil
    @State private var setToDelete: FlashcardSet? = nil

    @State private var showDeleteConfirm: Bool = false
    @State private var selectedSetForDeletion: FlashcardSet? = nil

    var body: some View {
        NavigationStack {
            content
                .korahGradientBackground()
        }
        .accentColor(.purple)
        .navigationTitle("Flashcards")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSet = true }) {
                    Label("Add Set", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .tint(.purple)
            }
        }
        .onAppear {
            loadSets()
            if openAddSetOnAppear { showingAddSet = true }
            if selectedSet == nil, let targetID = selectedSetID {
                selectedSet = sets.first(where: { $0.id == targetID })
            }
        }
        .sheet(isPresented: $showingAddSet) { addSetSheet }
        .sheet(item: $setToEdit) { editable in
            FlashcardSetDetailView(set: editable, onSave: { updated in
                updateSet(updated)
                setToEdit = nil
            }, onDelete: { deleted in
                deleteSet(deleted)
                setToEdit = nil
            })
        }
        .confirmationDialog(
            "Delete Set?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let set = selectedSetForDeletion {
                    deleteSet(set)
                }
                selectedSetForDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                selectedSetForDeletion = nil
            }
        } message: {
            Text("Are you sure you want to delete \"\(selectedSetForDeletion?.title ?? "this set")\"?")
        }
    }

    @ViewBuilder
    private var content: some View {
        if sets.isEmpty {
            VStack(spacing: 16) {
                Text("No flashcard sets yet.")
                    .foregroundColor(.gray)
                Button(action: { showingAddSet = true }) {
                    Text("Create your first set")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .tint(.purple)
            }
            .padding()
        } else if let set = selectedSet {
            FlashcardSetStudyView(set: set, onBack: { selectedSet = nil })
        } else {
            FlashcardSetListView(
                sets: sets,
                onSelect: { selectedSet = $0 },
                onEdit: { set in setToEdit = set },
                onDelete: { set in
                    selectedSetForDeletion = set
                    showDeleteConfirm = true
                }
            )
        }
    }

    struct FlashcardSetListView: View {
        let sets: [FlashcardSet]
        let onSelect: (FlashcardSet) -> Void
        let onEdit: (FlashcardSet) -> Void
        let onDelete: (FlashcardSet) -> Void

        var body: some View {
            List {
                ForEach(sets) { set in
                    Button(action: { onSelect(set) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(set.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("\(set.cards.count) cards")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { onEdit(set) }) {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .contextMenu {
                                Button {
                                    onEdit(set)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    onDelete(set)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.purple)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }

    private var addSetSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Set Title")) {
                    TextField("e.g. Biology - Cell Parts", text: $newSetTitle)
                }
            }
            .navigationTitle("New Set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddSet = false; newSetTitle = "" }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { addSet() }
                        .disabled(newSetTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .tint(.purple)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .korahGradientBackground()
    }

    private func addSet() {
        let title = newSetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let new = FlashcardSet(title: title, cards: [])
        sets.append(new)
        saveSets()
        newSetTitle = ""
        showingAddSet = false
    }

    private func delete(at offsets: IndexSet) {
        sets.remove(atOffsets: offsets)
        saveSets()
    }

    private func updateSet(_ updated: FlashcardSet) {
        if let idx = sets.firstIndex(where: { $0.id == updated.id }) {
            sets[idx] = updated
            saveSets()
        }
    }

    private func deleteSet(_ set: FlashcardSet) {
        sets.removeAll { $0.id == set.id }
        saveSets()
    }

    private func saveSets() {
        if let data = try? JSONEncoder().encode(sets) {
            UserDefaults.standard.set(data, forKey: "FlashcardSets")
        }
    }

    private func loadSets() {
        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let decoded = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
            sets = decoded
        } else {
            sets = []
        }
    }
}

struct FlashcardSetStudyView: View {
    let set: FlashcardSet
    let onBack: () -> Void
    
    @State private var currentCardIndex: Int = 0
    @State private var showBack: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var showStudySession: Bool = false
    @State private var showTestOptions: Bool = false
    @State private var isGeneratingGuide: Bool = false
    @State private var isGeneratingTest: Bool = false
    @State private var generatedTest: PracticeTest? = nil
    @State private var generatedGuide: StudyGuide? = nil
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    @State private var showGenerationAlert: Bool = false
    @State private var generationMessage: String = ""
    
    @State private var showDeleteConfirm: Bool = false
    

    @ViewBuilder
    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Set", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
        }
        .padding()
    }

    @ViewBuilder
    private var cardArea: some View {
        if !set.cards.isEmpty {
            let card = set.cards[currentCardIndex % set.cards.count]
            let rotation: Double = showBack ? 180.0 : 0.0
            LargeFlipCard(front: card.front, back: card.back, showBack: showBack)
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .padding(.horizontal)
                .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .offset(x: dragOffset)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation { showBack.toggle() } }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 80
                            if value.translation.width <= -threshold {
                                nextCard()
                            } else if value.translation.width >= threshold {
                                prevCard()
                            }
                            withAnimation(.spring()) { dragOffset = 0 }
                        }
                )
                .animation(.spring(), value: dragOffset)
            HStack(spacing: 6) {
                ForEach(0..<set.cards.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentCardIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6)
                }
            }
            .padding(.top, 16)
        } else {
            VStack {
                Text("No cards in this set")
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    @ViewBuilder
    private var studyButtons: some View {
        ScrollView {
            VStack(spacing: 12) {
                NavigationLink(destination: StudySessionView(set: set)) {
                    StudyModeButton(icon: "square.stack", title: "Flashcards", color: Color.purple)
                }
                Button(action: { isGeneratingGuide = true; generateStudyGuide() }) {
                    StudyModeButton(icon: "sparkles", title: "Study Guide", color: Color.purple.opacity(0.7))
                }
                Button(action: { showTestOptions = true }) {
                    StudyModeButton(icon: "doc.text.magnifyingglass", title: set.cards.count < 4 ? "Practice Test (minimum: 4 flashcards)" : "Practice Test", color: Color.purple.opacity(0.7), isDisabled: set.cards.count < 4)
                }
                .disabled(set.cards.count < 4)
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 16)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            cardArea
            Spacer()
            studyButtons
        }
        .background(Color.clear)
        .sheet(isPresented: $showTestOptions) {
            TestOptionsSheet(set: set, isGenerating: $isGeneratingTest, onMultipleChoice: createMultipleChoiceTest, onAIGenerated: generateAITest)
        }
        .sheet(isPresented: $showErrorAlert) {
            ErrorAlertView(isPresented: $showErrorAlert, message: errorMessage)
        }
        .alert("Created!", isPresented: $showGenerationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(generationMessage)
        }
        .navigationDestination(item: $generatedGuide) { guide in
            StudyGuideDetailView(guide: guide)
        }
        .navigationDestination(item: $generatedTest) { test in
            PracticeTestDetailLoaderView(testID: test.id)
        }
        .confirmationDialog(
            "Delete Set?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteCurrentSet()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(set.title)\"? This action cannot be undone.")
        }
    }
    
    private func deleteCurrentSet() {
        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
           var sets = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
            sets.removeAll { $0.id == set.id }
            if let encoded = try? JSONEncoder().encode(sets) {
                UserDefaults.standard.set(encoded, forKey: "FlashcardSets")
            }
        }
        onBack()
    }
    
    private func nextCard() {
        guard !set.cards.isEmpty else { return }
        if currentCardIndex < set.cards.count - 1 {
            currentCardIndex += 1
            showBack = false
        }
    }
    
    private func prevCard() {
        guard !set.cards.isEmpty else { return }
        if currentCardIndex > 0 {
            currentCardIndex -= 1
            showBack = false
        }
    }
    
    private func createMultipleChoiceTest() {
        let result = StudyUtilities.generatePracticeTestQuestions(from: set.cards)
        
        switch result {
        case .success(let questions):
            let test = PracticeTest(title: "Test: \(set.title)", questions: questions)
            
            if StudyDataManager.append(test, toKey: "PracticeTests") {
                showTestOptions = false
                generatedTest = test
            } else {
                errorMessage = "Failed to save practice test. Please try again."
                showErrorAlert = true
            }
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func generateAITest() {
        guard set.cards.count >= 4 else {
            errorMessage = "Need at least 4 flashcards to create a test."
            showErrorAlert = true
            return
        }
        
        isGeneratingTest = true
        showTestOptions = false
        
        struct LocalOpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let role: String?; let content: String? }
                let index: Int?
                let message: Message
                let finish_reason: String?
            }
            let id: String?
            let object: String?
            let created: Int?
            let model: String?
            let choices: [Choice]
        }
        
        let pairs: [[String: String]] = set.cards.map { ["term": $0.front, "definition": $0.back] }
        
        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            errorMessage = "Invalid URL"
            showErrorAlert = true
            isGeneratingTest = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
You are a test generator. Generate a multiple-choice test based on the provided flashcard content and broader knowledge of the concept. Output **PURE JSON** (no code fences) matching this schema:

{
  "questions": [
    {
      "prompt": string,
      "options": [string, string, string, string],
      "correctIndex": number (0-3)
    }
  ]
}

Create 5-10 questions mixing direct flashcard content with related conceptual questions.
"""
        
        struct ChatMessage: Codable {
            let role: String
            let content: String
        }
        struct ChatRequest: Codable {
            let model: String
            let temperature: Double
            let max_tokens: Int
            let messages: [ChatMessage]
        }
        
        let userPayload: [String: Any] = [
            "setTitle": set.title,
            "pairs": pairs as Any
        ]
        let userContentData = try? JSONSerialization.data(withJSONObject: userPayload, options: [.sortedKeys])
        let userContentString = String(data: userContentData ?? Data(), encoding: .utf8) ?? "{}"
        
        let messages: [ChatMessage] = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userContentString)
        ]
        
        let chatBody = ChatRequest(
            model: "gpt-4o-mini",
            temperature: 0.7,
            max_tokens: 2000,
            messages: messages
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        request.httpBody = try? encoder.encode(chatBody)
        
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            DispatchQueue.main.async {
                self.isGeneratingTest = false
                
                if let error = error {
                    self.errorMessage = StudyUtilities.errorMessage(for: error)
                    self.showErrorAlert = true
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data from server"
                    self.showErrorAlert = true
                    return
                }
                
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    self.errorMessage = StudyUtilities.errorMessage(for: http.statusCode, responseData: data)
                    self.showErrorAlert = true
                    return
                }
                
                do {
                    let decoded = try JSONDecoder().decode(LocalOpenAIResponse.self, from: data)
                    let raw = decoded.choices.first?.message.content ?? ""
                    let jsonString = StudyUtilities.extractJSONObject(from: raw) ?? raw
                    
                    if let jsonData = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let questionArray = json["questions"] as? [[String: Any]] {
                        var questions: [PracticeTestQuestion] = []
                        for item in questionArray {
                            if let prompt = item["prompt"] as? String,
                               let options = item["options"] as? [String],
                               let correctIndex = item["correctIndex"] as? Int,
                               options.count == 4,
                               correctIndex >= 0 && correctIndex < 4 {
                                let q = PracticeTestQuestion(prompt: prompt, options: options, correctIndex: correctIndex)
                                questions.append(q)
                            }
                        }
                        
                        if !questions.isEmpty {
                            let test = PracticeTest(title: "AI Test: \(self.set.title)", questions: questions)
                            var existing: [PracticeTest] = []
                            if let tdata = UserDefaults.standard.data(forKey: "PracticeTests"),
                               let decoded = try? JSONDecoder().decode([PracticeTest].self, from: tdata) {
                                existing = decoded
                            }
                            existing.append(test)
                            if let encoded = try? JSONEncoder().encode(existing) {
                                UserDefaults.standard.set(encoded, forKey: "PracticeTests")
                                self.generatedTest = test
                            }
                        } else {
                            self.errorMessage = "No valid questions generated."
                            self.showErrorAlert = true
                        }
                    }
                } catch {
                    self.errorMessage = StudyError.invalidJSON.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
        task.resume()
    }
    
    private func generateStudyGuide() {
        guard !set.cards.isEmpty else {
            generationMessage = "This set has no cards."
            showGenerationAlert = true
            isGeneratingGuide = false
            return
        }
        
        struct LocalOpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let role: String?; let content: String? }
                let index: Int?
                let message: Message
                let finish_reason: String?
            }
            let id: String?
            let object: String?
            let created: Int?
            let model: String?
            let choices: [Choice]
        }
        
        let pairs: [[String: String]] = set.cards.map { ["term": $0.front, "definition": $0.back] }
        
        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            generationMessage = "Invalid URL"
            showGenerationAlert = true
            isGeneratingGuide = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
You are a study coach. Output **PURE JSON** (no code fences, no markdown) that matches this schema exactly:

{
  "kind": "tutor",
  "title": string,
  "summary": string,
  "steps": [string],
  "hints": [string],
  "questions": [string],
  "footer": string
}

Rules:
- Use ONLY the provided flashcard term/definition pairs as content.
- Paraphrase; avoid copy-paste. Prefer clarity and precision.
- Create a study guide with 3–8 key steps/sections.
- Include 3–5 helpful hints.
- Generate 5–8 Socratic follow-up questions.
- Keep language unambiguous and audience-appropriate.
- Return valid JSON only. No trailing commas. No extra text.
"""
        
        struct ChatMessage: Codable {
            let role: String
            let content: String
        }
        struct ChatRequest: Codable {
            let model: String
            let temperature: Double
            let max_tokens: Int
            let messages: [ChatMessage]

            enum CodingKeys: String, CodingKey {
                case model
                case temperature
                case max_tokens
                case messages
            }
        }
        
        let userPayload: [String: Any] = [
            "setTitle": set.title,
            "pairs": pairs as Any
        ]
        let userContentData = try? JSONSerialization.data(withJSONObject: userPayload, options: [.sortedKeys])
        let userContentString = String(data: userContentData ?? Data(), encoding: .utf8) ?? "{}"
        
        let messages: [ChatMessage] = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userContentString)
        ]
        
        let chatBody = ChatRequest(
            model: "gpt-4o-mini",
            temperature: 0.2,
            max_tokens: 1600,
            messages: messages
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        request.httpBody = try? encoder.encode(chatBody)
        
        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            DispatchQueue.main.async {
                self.isGeneratingGuide = false
                
                if let error = error {
                    self.generationMessage = StudyUtilities.errorMessage(for: error)
                    self.showGenerationAlert = true
                    return
                }
                
                guard let data = data else {
                    self.generationMessage = "No data from server"
                    self.showGenerationAlert = true
                    return
                }
                
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    self.generationMessage = StudyUtilities.errorMessage(for: http.statusCode, responseData: data)
                    self.showGenerationAlert = true
                    return
                }
                
                do {
                    let decoded = try JSONDecoder().decode(LocalOpenAIResponse.self, from: data)
                    let raw = decoded.choices.first?.message.content ?? ""
                    let jsonString = StudyUtilities.extractJSONObject(from: raw) ?? raw
                    
                    if let _ = jsonString.data(using: .utf8) {
                        let title = "Study Guide: \(set.title)"
                        let guide = StudyGuide(title: title, content: jsonString)

                        var existing: [StudyGuide] = []
                        if let gdata = UserDefaults.standard.data(forKey: "StudyGuides"),
                           let decodedGuides = try? JSONDecoder().decode([StudyGuide].self, from: gdata) {
                            existing = decodedGuides
                        }
                        existing.append(guide)
                        if let encoded = try? JSONEncoder().encode(existing) {
                            UserDefaults.standard.set(encoded, forKey: "StudyGuides")
                            DispatchQueue.main.async {
                                self.generationMessage = "Saved to Study Guides."
                                self.showGenerationAlert = true
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.generationMessage = "Failed to save Study Guide."
                                self.showGenerationAlert = true
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.generationMessage = "AI did not return valid JSON."
                            self.showGenerationAlert = true
                        }
                    }
                } catch {
                    let responseString = String(data: data, encoding: .utf8) ?? "(unreadable)"
                    print("Decode error: \(error)\nRaw: \(responseString)")
                    DispatchQueue.main.async {
                        self.generationMessage = StudyError.invalidJSON.localizedDescription
                        self.showGenerationAlert = true
                    }
                }
            }
        }
        task.resume()
    }
}

struct StudyModeButton: View {
    let icon: String
    let title: String
    let color: Color
    var isDisabled: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .cornerRadius(10)
                .opacity(isDisabled ? 0.5 : 1)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .opacity(isDisabled ? 0.5 : 1)
            
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

struct FlashcardSetDetailView: View {
    @State var set: FlashcardSet
    var onSave: (FlashcardSet) -> Void
    var onDelete: (FlashcardSet) -> Void

    @State private var showingAddCard = false
    @State private var newFront = ""
    @State private var newBack = ""
    @State private var previewShowBack = false
    @State private var isEditing = false
    @State private var showGenerationAlert = false
    @State private var generationMessage: String? = nil

    @State private var showConfirmDeleteAllCards = false
    @State private var showConfirmDeleteAllTests = false
    @State private var showConfirmDeleteAllGuides = false
    @State private var showDeleteSetAlert = false
    
    @State private var isGeneratingGuide = false

    @ViewBuilder
    private var previewSection: some View {
        Section(header: Text("Preview")) {
            if set.cards.isEmpty {
                Text("No cards yet. Add one!")
                    .foregroundColor(.gray)
            } else {
                FlipCardView(
                    frontText: set.cards.first?.front ?? "",
                    backText: set.cards.first?.back ?? "",
                    showBack: $previewShowBack
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        isEditing.toggle()
                    } label: {
                        Label(isEditing ? "Done Editing" : "Edit Flashcards", systemImage: isEditing ? "checkmark.circle" : "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)

                    NavigationLink(destination: StudySessionView(set: set)) {
                        Label("Study Flashcards", systemImage: "rectangle.stack.person.crop")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }

                HStack(spacing: 12) {
                    Button(action: generatePracticeTestFromSet) {
                        Label("Test", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)

                    Button {
                        isGeneratingGuide = true
                        generateStudyGuideFromSet()
                    } label: {
                        Label("Study Guide", systemImage: "book.closed")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }
            }
            .tint(.purple)
        }
        .listRowBackground(Color.clear)
    }

    var body: some View {
        List {
            previewSection

            actionsSection

            Section(header: Text("Cards")) {
                if isEditing {
                    Button(action: { showingAddCard = true }) {
                        Label("Add Card", systemImage: "plus")
                    }
                    .tint(.purple)
                    .listRowBackground(Color.clear)
                }
                if set.cards.isEmpty {
                    Text("No cards yet. Add one!")
                        .foregroundColor(.gray)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(set.cards) { card in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.front)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(card.back)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteCards)
                }
            }
        }
        .environment(\.editMode, Binding.constant(isEditing ? .active : .inactive))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(set.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) { showDeleteSetAlert = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("Created!", isPresented: $showGenerationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(generationMessage ?? "")
        }
        .alert("Delete all cards?", isPresented: $showConfirmDeleteAllCards) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteAllCards() }
        } message: {
            Text("This will remove every card in this set.")
        }
        .alert("Delete all practice tests?", isPresented: $showConfirmDeleteAllTests) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteAllPracticeTests() }
        } message: {
            Text("This will remove all saved practice tests.")
        }
        .alert("Delete all study guides?", isPresented: $showConfirmDeleteAllGuides) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteAllStudyGuides() }
        } message: {
            Text("This will remove all saved study guides.")
        }
        .alert("Delete Set?", isPresented: $showDeleteSetAlert) {
            Button("Delete", role: .destructive) { onDelete(set) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(set.title)\"?")
        }
        .onDisappear { onSave(set) }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .korahGradientBackground()
        .overlay(loadingOverlay)
        .sheet(isPresented: $showingAddCard) { addCardSheet }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if isGeneratingGuide {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView("Generating study guide…")
                        .progressViewStyle(.circular)
                        .tint(.purple)
                    Text("This may take a few seconds")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }
        }
    }

    private var addCardSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Front")) {
                    TextField("Question / Prompt", text: $newFront)
                }
                Section(header: Text("Back")) {
                    TextField("Answer", text: $newBack)
                }
            }
            .navigationTitle("New Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddCard = false; newFront = ""; newBack = "" }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addCard() }
                        .disabled(newFront.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newBack.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .tint(.purple)
        }
        .korahGradientBackground()
    }

    private func addCard() {
        let f = newFront.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = newBack.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !f.isEmpty, !b.isEmpty else { return }
        set.cards.append(Flashcard(front: f, back: b))
        newFront = ""
        newBack = ""
        showingAddCard = false
    }

    private func deleteCards(at offsets: IndexSet) {
        set.cards.remove(atOffsets: offsets)
    }

    private func deleteAllCards() {
        set.cards.removeAll()
    }

    private func deleteAllPracticeTests() {
        UserDefaults.standard.removeObject(forKey: "PracticeTests")
    }

    private func deleteAllStudyGuides() {
        UserDefaults.standard.removeObject(forKey: "StudyGuides")
    }

    private func generatePracticeTestFromSet() {
        guard !set.cards.isEmpty else {
            generationMessage = "This set has no cards."
            showGenerationAlert = true
            return
        }
        
        let result = StudyUtilities.generatePracticeTestQuestions(from: set.cards, minCards: 1)
        
        switch result {
        case .success(let questions):
            let test = PracticeTest(title: "Practice Test from \(set.title)", questions: questions)
            
            if StudyDataManager.append(test, toKey: "PracticeTests") {
                generationMessage = "Saved to Practice Tests."
            } else {
                generationMessage = "Failed to save Practice Test."
            }
            
        case .failure(let error):
            generationMessage = error.localizedDescription
        }
        
        showGenerationAlert = true
    }

    private func generateStudyGuideFromSet() {
        guard !set.cards.isEmpty else {
            generationMessage = "This set has no cards."
            showGenerationAlert = true
            isGeneratingGuide = false
            return
        }

        struct LocalOpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let role: String?; let content: String? }
                let index: Int?
                let message: Message
                let finish_reason: String?
            }
            let id: String?
            let object: String?
            let created: Int?
            let model: String?
            let choices: [Choice]
        }

        let pairs: [[String: String]] = set.cards.map { ["term": $0.front, "definition": $0.back] }

        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            generationMessage = "Invalid URL"
            showGenerationAlert = true
            isGeneratingGuide = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemJSONSchema = """
You are a study coach. Output **PURE JSON** (no code fences, no markdown) that matches this schema exactly:

{
  "kind": "tutor",
  "title": string,              
  "summary": string,            
  "steps": [string],            
  "hints": [string],            
  "questions": [string],        
  "footer": string              
}

Rules:
- Use ONLY the provided flashcard term/definition pairs as content.
- Paraphrase; avoid copy-paste. Prefer clarity and precision.
- Create a study guide with 3–8 key steps/sections.
- Include 3–5 helpful hints.
- Generate 5–8 Socratic follow-up questions.
- Keep language unambiguous and audience-appropriate.
- Return valid JSON only. No trailing commas. No extra text.
"""

        struct ChatMessage: Codable {
            let role: String
            let content: String
        }
        struct ChatRequest: Codable {
            let model: String
            let temperature: Double
            let max_tokens: Int
            let messages: [ChatMessage]

            enum CodingKeys: String, CodingKey {
                case model
                case temperature
                case max_tokens
                case messages
            }
        }

        let userPayload: [String: Any] = [
            "setTitle": set.title,
            "pairs": pairs as Any
        ]
        let userContentData = try? JSONSerialization.data(withJSONObject: userPayload, options: [.sortedKeys])
        let userContentString = String(data: userContentData ?? Data(), encoding: .utf8) ?? "{}"

        let messages: [ChatMessage] = [
            ChatMessage(role: "system", content: systemJSONSchema),
            ChatMessage(role: "user", content: userContentString)
        ]

        let chatBody = ChatRequest(
            model: "gpt-4o-mini",
            temperature: 0.2,
            max_tokens: 1600,
            messages: messages
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        request.httpBody = try? encoder.encode(chatBody)

        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            DispatchQueue.main.async {
                self.isGeneratingGuide = false
                
                if let error = error {
                    self.generationMessage = StudyUtilities.errorMessage(for: error)
                    self.showGenerationAlert = true
                    return
                }
                
                guard let data = data else {
                    self.generationMessage = "No data from server"
                    self.showGenerationAlert = true
                    return
                }
                
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    self.generationMessage = StudyUtilities.errorMessage(for: http.statusCode, responseData: data)
                    self.showGenerationAlert = true
                    return
                }
                
                do {
                    let decoded = try JSONDecoder().decode(LocalOpenAIResponse.self, from: data)
                    let raw = decoded.choices.first?.message.content ?? ""
                    let jsonString = StudyUtilities.extractJSONObject(from: raw) ?? raw
                    
                    if let _ = jsonString.data(using: .utf8) {
                        let title = "Study Guide: \(set.title)"
                        let guide = StudyGuide(title: title, content: jsonString)

                        var existing: [StudyGuide] = []
                        if let gdata = UserDefaults.standard.data(forKey: "StudyGuides"),
                           let decodedGuides = try? JSONDecoder().decode([StudyGuide].self, from: gdata) {
                            existing = decodedGuides
                        }
                        existing.append(guide)
                        if let encoded = try? JSONEncoder().encode(existing) {
                            UserDefaults.standard.set(encoded, forKey: "StudyGuides")
                            DispatchQueue.main.async {
                                self.generationMessage = "Saved to Study Guides."
                                self.showGenerationAlert = true
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.generationMessage = "Failed to save Study Guide."
                                self.showGenerationAlert = true
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.generationMessage = "AI did not return valid JSON."
                            self.showGenerationAlert = true
                        }
                    }
                } catch {
                    let responseString = String(data: data, encoding: .utf8) ?? "(unreadable)"
                    print("Decode error: \(error)\nRaw: \(responseString)")
                    DispatchQueue.main.async {
                        self.generationMessage = StudyError.invalidJSON.localizedDescription
                        self.showGenerationAlert = true
                    }
                }
            }
        }
        task.resume()
    }
}

struct StudySessionView: View {
    let set: FlashcardSet
    @State private var index: Int = 0
    @State private var showBack: Bool = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 20) {
            if set.cards.isEmpty {
                Text("No cards to study.")
                    .foregroundColor(.gray)
            } else {
                Text("Card \(index + 1) of \(set.cards.count)")
                    .foregroundColor(.white)

                FlipCardView(
                    frontText: set.cards[index].front,
                    backText: set.cards[index].back,
                    showBack: $showBack
                )
                .padding(.horizontal)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 80
                            if value.translation.width <= -threshold {
                                next()
                            } else if value.translation.width >= threshold {
                                prev()
                            }
                            withAnimation(.spring()) { dragOffset = 0 }
                        }
                )
                .animation(.spring(), value: dragOffset)

                Text("Tap to flip. Swipe left/right to navigate.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .background(Color.clear)
        .korahGradientBackground()
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
    }

    private func next() {
        guard !set.cards.isEmpty else { return }
        if index < set.cards.count - 1 {
            index += 1
            showBack = false
        }
    }

    private func prev() {
        guard !set.cards.isEmpty else { return }
        if index > 0 {
            index -= 1
            showBack = false
        }
    }
}

struct FlipCardView: View {
    let frontText: String
    let backText: String
    @Binding var showBack: Bool

    var body: some View {
        let rotation = showBack ? 180.0 : 0.0

        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.korahCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            ZStack {
                VStack(spacing: 12) {
                    Text(frontText)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                    Text("Front")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(showBack ? 0 : 1)

                VStack(spacing: 12) {
                    Text(backText)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                    Text("Back")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .opacity(showBack ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: showBack)
        .onTapGesture { withAnimation { showBack.toggle() } }
    }
}

struct LargeFlipCard: View {
    let front: String
    let back: String
    let showBack: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))

            ZStack {
                VStack(spacing: 20) {
                    Spacer()
                    Text(front)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "rectangle.2.swap")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(12)
                }
                .opacity(showBack ? 0 : 1)

                VStack(spacing: 20) {
                    Spacer()
                    Text(back)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "rectangle.2.swap")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(12)
                }
                .opacity(showBack ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .padding()
        }
    }
}

struct TestOptionsSheet: View {
    let set: FlashcardSet
    @Binding var isGenerating: Bool
    let onMultipleChoice: () -> Void
    let onAIGenerated: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Choose Test Type")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top)
                
                Button(action: {
                    onMultipleChoice()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 20))
                        Text("Multiple Choice")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.purple.opacity(0.3))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    onAIGenerated()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                        Text("AI Generated")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.purple.opacity(0.3))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .korahGradientBackground()
    }
}

struct ErrorAlertView: View {
    @Binding var isPresented: Bool
    let message: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Button(action: { isPresented = false }) {
                    Text("OK")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
        }
        .korahGradientBackground()
    }
}

#Preview {
    NavigationStack { FlashcardsView() }
}

extension StudyGuide: Hashable {
    public static func == (lhs: StudyGuide, rhs: StudyGuide) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension PracticeTest: Hashable {
    public static func == (lhs: PracticeTest, rhs: PracticeTest) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
