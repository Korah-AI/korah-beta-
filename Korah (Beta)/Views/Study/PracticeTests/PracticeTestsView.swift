import SwiftUI
import Combine

final class PracticeTestsStore: ObservableObject {
    @Published var practiceTests: [PracticeTest] = [] {
        didSet { save() }
    }
    private let key = "PracticeTests"

    init() { load() }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([PracticeTest].self, from: data) {
            practiceTests = decoded
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(practiceTests) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}

struct PracticeTestsView: View {
    let openAICreationOnAppear: Bool

    init(openAICreationOnAppear: Bool = false) {
        self.openAICreationOnAppear = openAICreationOnAppear
    }

    @StateObject private var store = PracticeTestsStore()
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var newTestTitle = ""
    @State private var showingAdd = false
    @State private var showDeleteAlert = false
    @State private var pendingDeleteTest: PracticeTest? = nil

    @State private var flashcardSets: [FlashcardSet] = []
    @State private var selectedSetIndex: Int = 0

    @State private var studyGuides: [StudyGuide] = []
    @State private var selectedGuideIndex: Int = 0
    @State private var selectedTestForNavigation: PracticeTest? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.korahGradientBackground()
                    .ignoresSafeArea()
                List {
                    Section(header: Text("Create from Flashcards")) {
                        Picker("Flashcard Set", selection: $selectedSetIndex) {
                            ForEach(flashcardSets.indices, id: \.self) { idx in
                                Text(flashcardSets[idx].title).tag(idx)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())

                        TextField("Test Title (optional)", text: $newTestTitle)
                            .textInputAutocapitalization(.words)

                        Button(action: createTestFromSelectedSet) {
                            Label("Create Practice Test", systemImage: "doc.text.magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(flashcardSets.isEmpty)
                    }
                    .listRowBackground(Color.clear)
                    Section(header: Text("Create from Study Guide")) {
                        Picker("Study Guide", selection: $selectedGuideIndex) {
                            ForEach(studyGuides.indices, id: \.self) { idx in
                                Text(studyGuides[idx].title.isEmpty ? "Untitled Guide" : studyGuides[idx].title).tag(idx)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())

                        TextField("Test Title (optional)", text: $newTestTitle)
                            .textInputAutocapitalization(.words)

                        Button(action: createTestFromSelectedStudyGuide) {
                            Label("Create Practice Test", systemImage: "doc.text.magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(studyGuides.isEmpty)
                    }
                    .listRowBackground(Color.clear)
                    Section(header: Text("Recents")) {
                        let recent = store.practiceTests.sorted(by: { $0.createdAt > $1.createdAt })
                        if recent.isEmpty {
                            Text("No recent tests yet.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(recent.prefix(3))) { test in
                                NavigationLink(destination: PracticeTestDetailView(practiceTest: binding(for: test))) {
                                    VStack(alignment: .leading) {
                                        Text(test.title)
                                            .foregroundColor(.white)
                                        Text(test.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    Section(header: Text("All Practice Tests")) {
                        ForEach(store.practiceTests) { test in
                            NavigationLink(destination: PracticeTestDetailView(practiceTest: binding(for: test))) {
                                VStack(alignment: .leading) {
                                    Text(test.title)
                                        .foregroundColor(.white)
                                    Text(test.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    pendingDeleteTest = test
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    pendingDeleteTest = test
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteTests)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Practice Tests")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton().tint(.purple)
                    }
                }
            }
            .navigationDestination(item: $selectedTestForNavigation) { test in
                PracticeTestDetailView(practiceTest: binding(for: test))
            }
        }
        .accentColor(.purple)
        .preferredColorScheme(.dark)
        .alert("Delete Test?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let test = pendingDeleteTest { delete(test: test) }
                pendingDeleteTest = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteTest = nil }
        } message: {
            Text("Are you sure you want to delete this practice test?")
        }
        .onAppear {
            loadFlashcardSets()
            loadStudyGuides()
            if openAICreationOnAppear {
            }
        }
    }

    private func binding(for test: PracticeTest) -> Binding<PracticeTest> {
        guard let index = store.practiceTests.firstIndex(where: { $0.id == test.id }) else {
            // Return a temporary binding if test not found (shouldn't happen, but prevents crash)
            return .constant(test)
        }
        return $store.practiceTests[index]
    }

    private func addTest() {
        let title = newTestTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let new = PracticeTest(title: title, questions: [])
        store.practiceTests.append(new)
        newTestTitle = ""
    }

    private func deleteTests(at offsets: IndexSet) {
        store.practiceTests.remove(atOffsets: offsets)
    }

    private func delete(test: PracticeTest) {
        if let index = store.practiceTests.firstIndex(where: { $0.id == test.id }) {
            store.practiceTests.remove(at: index)
        }
    }

    private func loadFlashcardSets() {
        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let decoded = try? JSONDecoder().decode([FlashcardSet].self, from: data) {
            flashcardSets = decoded
            selectedSetIndex = min(selectedSetIndex, max(0, flashcardSets.count - 1))
        } else {
            flashcardSets = []
        }
    }

    private func loadStudyGuides() {
        if let data = UserDefaults.standard.data(forKey: "StudyGuides"),
           let decoded = try? JSONDecoder().decode([StudyGuide].self, from: data) {
            studyGuides = decoded
            selectedGuideIndex = min(selectedGuideIndex, max(0, studyGuides.count - 1))
        } else {
            studyGuides = []
        }
    }

    private func createTestFromSelectedSet() {
        guard !flashcardSets.isEmpty else { return }
        let set = flashcardSets[selectedSetIndex]
        
        // Use shared utility for test generation
        let result = StudyUtilities.generatePracticeTestQuestions(from: set.cards)
        
        switch result {
        case .success(let questions):
            let title = StudyUtilities.generateTestTitle(
                from: set.title,
                customTitle: newTestTitle
            )
            let test = PracticeTest(title: title, questions: questions)
            store.practiceTests.append(test)
            newTestTitle = ""
            
            DispatchQueue.main.async {
                selectedTestForNavigation = store.practiceTests.last
            }
            
        case .failure(let error):
            // Show error to user (you can add an @State var showError and errorMessage)
            print("Failed to create test: \(error.localizedDescription)")
        }
    }

    private func createTestFromSelectedStudyGuide() {
        guard !studyGuides.isEmpty else { return }
        let guide = studyGuides[selectedGuideIndex]

        let lines = guide.content.components(separatedBy: "\n")
        var questions: [PracticeTestQuestion] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-") else { continue }
            let payload = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            var term: String? = nil
            var definition: String? = nil
            if let range = payload.range(of: ":") {
                term = String(payload[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                definition = String(payload[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else if let range = payload.range(of: " — ") {
                term = String(payload[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                definition = String(payload[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            if let t = term, let d = definition, !t.isEmpty, !d.isEmpty {
                let allDefs: [String] = lines.compactMap { l in
                    let tr = l.trimmingCharacters(in: .whitespaces)
                    guard tr.hasPrefix("-") else { return nil }
                    let p = tr.dropFirst().trimmingCharacters(in: .whitespaces)
                    if let r = p.range(of: ":") { return String(p[r.upperBound...]).trimmingCharacters(in: .whitespaces) }
                    if let r2 = p.range(of: " — ") { return String(p[r2.upperBound...]).trimmingCharacters(in: .whitespaces) }
                    return nil
                }
                var options = [d]
                var distractors = allDefs.filter { $0 != d }.shuffled()
                options.append(contentsOf: distractors.prefix(3))
                while options.count < 4 { options.append(allDefs.randomElement() ?? "—") }
                options.shuffle()
                let correctIndex = options.firstIndex(of: d) ?? 0
                questions.append(PracticeTestQuestion(prompt: t, options: options, correctIndex: correctIndex))
            }
            if questions.count >= 20 { break }
        }

        if questions.isEmpty {
            questions.append(PracticeTestQuestion(prompt: "What is one key idea from the guide?", options: ["Idea A", "Idea B", "Idea C", "Idea D"], correctIndex: 0))
        }

        let title = newTestTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let testTitle = title.isEmpty ? "Practice Test from \(guide.title.isEmpty ? "Study Guide" : guide.title)" : title
        let test = PracticeTest(title: testTitle, questions: questions)
        store.practiceTests.append(test)
        newTestTitle = ""

        DispatchQueue.main.async {
            selectedTestForNavigation = store.practiceTests.last
        }
    }
}

struct PracticeTestDetailView: View {
    @Binding var practiceTest: PracticeTest
    @State private var showingAddQuestionSheet = false
    @State private var editingQuestion: PracticeTestQuestion? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteTestAlert = false

    var body: some View {
        VStack {
            if practiceTest.questions.isEmpty {
                Text("No questions added yet.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(practiceTest.questions) { q in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(q.prompt)
                                .font(.headline)
                                .foregroundColor(.white)
                            ForEach(q.options.indices, id: \.self) { idx in
                                let option = q.options[idx]
                                HStack {
                                    if idx == q.correctIndex {
                                        Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                                    }
                                    Text(option)
                                        .foregroundColor(.white)
                                }
                                .font(.subheadline)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingQuestion = q }
                    }
                    .onDelete(perform: deleteQuestions)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .background(Color.clear)
            }
            Spacer()
            NavigationLink(destination: TakePracticeTestView(practiceTest: $practiceTest)) {
                Text("Start Test")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(practiceTest.questions.isEmpty ? Color.gray.opacity(0.5) : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .disabled(practiceTest.questions.isEmpty)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddQuestionSheet = true }) { Image(systemName: "plus") }
                .tint(.purple)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) { showDeleteTestAlert = true } label: { Image(systemName: "trash") }
            }
        }
        .sheet(item: $editingQuestion) { question in
            QuestionEditView(question: question) { edited in
                if let idx = practiceTest.questions.firstIndex(where: { $0.id == edited.id }) {
                    practiceTest.questions[idx] = edited
                }
                editingQuestion = nil
            } onCancel: {
                editingQuestion = nil
            }
            .accentColor(.purple)
        }
        .sheet(isPresented: $showingAddQuestionSheet) {
            QuestionEditView(question: PracticeTestQuestion(prompt: "", options: ["", "", "", ""], correctIndex: 0)) { newQ in
                practiceTest.questions.append(newQ)
                showingAddQuestionSheet = false
            } onCancel: {
                showingAddQuestionSheet = false
            }
            .accentColor(.purple)
        }
        .alert("Delete Practice Test?", isPresented: $showDeleteTestAlert) {
            Button("Delete", role: .destructive) { deleteThisPracticeTest() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove this practice test from your library.")
        }
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(practiceTest.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deleteQuestions(at offsets: IndexSet) {
        practiceTest.questions.remove(atOffsets: offsets)
    }

    private func deleteThisPracticeTest() {
        var tests: [PracticeTest] = []
        if let data = UserDefaults.standard.data(forKey: "PracticeTests"),
           let decoded = try? JSONDecoder().decode([PracticeTest].self, from: data) {
            tests = decoded
        }
        tests.removeAll { $0.id == practiceTest.id }
        if let encoded = try? JSONEncoder().encode(tests) {
            UserDefaults.standard.set(encoded, forKey: "PracticeTests")
        }
        dismiss()
    }
}

struct QuestionEditView: View {
    @State var question: PracticeTestQuestion
    let onSave: (PracticeTestQuestion) -> Void
    let onCancel: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Question")) {
                    TextField("Question text", text: $question.prompt)
                        .textInputAutocapitalization(.sentences)
                }
                Section(header: Text("Options (exactly 4)")) {
                    ForEach(0..<question.options.count, id: \.self) { i in
                        TextField("Option \(i+1)", text: Binding(
                            get: { question.options[i] },
                            set: { question.options[i] = $0 }
                        ))
                        .textInputAutocapitalization(.sentences)
                    }
                }
                Section(header: Text("Correct Answer")) {
                    Picker("Correct option", selection: $question.correctIndex) {
                        ForEach(0..<question.options.count, id: \.self) { i in
                            Text(question.options[i].isEmpty ? "Option \(i+1)" : question.options[i]).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if let errorMessage = errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red) }
                }
            }
            .navigationTitle("Question")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!canSave) }
            }
        }
    }

    private var canSave: Bool {
        !question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        question.options.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        (0..<question.options.count).contains(question.correctIndex)
    }

    private func save() {
        guard canSave else {
            errorMessage = "Please ensure question and all options are filled, and correct answer is selected."
            return
        }
        onSave(question)
    }
}

struct TakePracticeTestView: View {
    @Binding var practiceTest: PracticeTest

    @State private var currentQuestionIndex = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var score = 0
    @State private var showResult = false
    @State private var userAnswers: [Int] = []
    @State private var showReview = false

    var body: some View {
        VStack {
            if showReview {
                reviewView
            } else if showResult {
                VStack(spacing: 20) {
                    Text("Test Completed!")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.purple)
                    
                    let percentage = Double(score) / Double(practiceTest.questions.count) * 100
                    Text("Score: \(score) / \(practiceTest.questions.count)")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text(String(format: "%.0f%%", percentage))
                        .font(.title)
                        .bold()
                        .foregroundColor(percentage >= 70 ? .green : percentage >= 50 ? .orange : .red)
                    
                    HStack(spacing: 12) {
                        Button("Review Answers") {
                            showReview = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        
                        Button("Retake Test") { resetTest() }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                    }
                }
                .padding()
                Spacer()
            } else {
                if currentQuestionIndex < practiceTest.questions.count {
                    let question = practiceTest.questions[currentQuestionIndex]
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Question \(currentQuestionIndex + 1) of \(practiceTest.questions.count)")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Text(question.prompt)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        ForEach(question.options.indices, id: \.self) { idx in
                            let option = question.options[idx]
                            Button(action: { selectedOptionIndex = idx }) {
                                HStack {
                                    Image(systemName: selectedOptionIndex == idx ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(selectedOptionIndex == idx ? .purple : .secondary)
                                    Text(option)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedOptionIndex == idx ? Color.purple : Color.secondary.opacity(0.5), lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Button(action: submitAnswer) {
                            Text("Submit Answer")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedOptionIndex == nil ? Color.gray.opacity(0.5) : Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(selectedOptionIndex == nil)
                    }
                    .padding()
                } else {
                    Spacer()
                }
            }
        }
        .background(Color.clear)
        .korahGradientBackground()
        .preferredColorScheme(.dark)
        .accentColor(.purple)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(practiceTest.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submitAnswer() {
        guard let selected = selectedOptionIndex, currentQuestionIndex < practiceTest.questions.count else { return }
        let correct = practiceTest.questions[currentQuestionIndex].correctIndex
        
        userAnswers.append(selected)
        if selected == correct { score += 1 }
        selectedOptionIndex = nil
        
        if currentQuestionIndex + 1 == practiceTest.questions.count { 
            showResult = true 
        } else { 
            currentQuestionIndex += 1 
        }
    }

    private func resetTest() {
        score = 0
        currentQuestionIndex = 0
        selectedOptionIndex = nil
        showResult = false
        showReview = false
        userAnswers = []
    }
    
    private var reviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                backButton
                
                ForEach(Array(practiceTest.questions.enumerated()), id: \.element.id) { index, question in
                    ReviewQuestionCard(
                        questionNumber: index + 1,
                        question: question,
                        userAnswer: index < userAnswers.count ? userAnswers[index] : -1
                    )
                }
                
                Spacer(minLength: 20)
            }
        }
        .background(Color.clear)
    }
    
    private var backButton: some View {
        HStack {
            Button(action: { showReview = false }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back to Results")
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
}

struct ReviewQuestionCard: View {
    let questionNumber: Int
    let question: PracticeTestQuestion
    let userAnswer: Int
    
    private var isCorrect: Bool {
        userAnswer == question.correctIndex
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            questionHeader
            questionPrompt
            optionsList
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var questionHeader: some View {
        HStack {
            Text("Question \(questionNumber)")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isCorrect ? .green : .red)
                .font(.title3)
        }
    }
    
    private var questionPrompt: some View {
        Text(question.prompt)
            .font(.body)
            .foregroundColor(.white)
            .padding(.bottom, 4)
    }
    
    private var optionsList: some View {
        ForEach(question.options.indices, id: \.self) { optionIndex in
            ReviewOptionRow(
                option: question.options[optionIndex],
                isUserAnswer: optionIndex == userAnswer,
                isCorrectAnswer: optionIndex == question.correctIndex
            )
        }
    }
}

struct ReviewOptionRow: View {
    let option: String
    let isUserAnswer: Bool
    let isCorrectAnswer: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            optionIcon
            
            Text(option)
                .foregroundColor(.white)
                .fontWeight(isCorrectAnswer || isUserAnswer ? .semibold : .regular)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(backgroundColor)
        .overlay(borderOverlay)
    }
    
    @ViewBuilder
    private var optionIcon: some View {
        if isCorrectAnswer {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if isUserAnswer {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        } else {
            Image(systemName: "circle")
                .foregroundColor(.gray)
        }
    }
    
    private var backgroundColor: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundFillColor)
    }
    
    private var backgroundFillColor: Color {
        if isCorrectAnswer {
            return Color.green.opacity(0.15)
        } else if isUserAnswer {
            return Color.red.opacity(0.15)
        } else {
            return Color.clear
        }
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: 1)
    }
    
    private var borderColor: Color {
        if isCorrectAnswer {
            return Color.green
        } else if isUserAnswer {
            return Color.red
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

#Preview {
    NavigationStack { PracticeTestsView() }
}
