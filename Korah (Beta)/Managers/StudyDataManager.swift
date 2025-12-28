import Foundation

/// Centralized manager for study data persistence with error handling
final class StudyDataManager {
    static let shared = StudyDataManager()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {}
    
    // MARK: - Keys
    private enum StorageKey: String {
        case flashcardSets = "FlashcardSets"
        case studyGuides = "StudyGuides"
        case practiceTests = "PracticeTests"
    }
    
    // MARK: - Flashcard Sets
    func loadFlashcardSets() -> [FlashcardSet] {
        return load(key: .flashcardSets) ?? []
    }
    
    @discardableResult
    func saveFlashcardSets(_ sets: [FlashcardSet]) -> Bool {
        return save(sets, key: .flashcardSets)
    }
    
    func addFlashcardSet(_ set: FlashcardSet) -> Bool {
        var sets = loadFlashcardSets()
        sets.append(set)
        return saveFlashcardSets(sets)
    }
    
    func updateFlashcardSet(_ set: FlashcardSet) -> Bool {
        var sets = loadFlashcardSets()
        guard let index = sets.firstIndex(where: { $0.id == set.id }) else { return false }
        sets[index] = set
        return saveFlashcardSets(sets)
    }
    
    func deleteFlashcardSet(id: UUID) -> Bool {
        var sets = loadFlashcardSets()
        sets.removeAll { $0.id == id }
        return saveFlashcardSets(sets)
    }
    
    // MARK: - Study Guides
    func loadStudyGuides() -> [StudyGuide] {
        return load(key: .studyGuides) ?? []
    }
    
    @discardableResult
    func saveStudyGuides(_ guides: [StudyGuide]) -> Bool {
        return save(guides, key: .studyGuides)
    }
    
    func addStudyGuide(_ guide: StudyGuide) -> Bool {
        var guides = loadStudyGuides()
        guides.append(guide)
        return saveStudyGuides(guides)
    }
    
    func updateStudyGuide(_ guide: StudyGuide) -> Bool {
        var guides = loadStudyGuides()
        guard let index = guides.firstIndex(where: { $0.id == guide.id }) else { return false }
        guides[index] = guide
        return saveStudyGuides(guides)
    }
    
    func deleteStudyGuide(id: UUID) -> Bool {
        var guides = loadStudyGuides()
        guides.removeAll { $0.id == id }
        return saveStudyGuides(guides)
    }
    
    // MARK: - Practice Tests
    func loadPracticeTests() -> [PracticeTest] {
        return load(key: .practiceTests) ?? []
    }
    
    @discardableResult
    func savePracticeTests(_ tests: [PracticeTest]) -> Bool {
        return save(tests, key: .practiceTests)
    }
    
    func addPracticeTest(_ test: PracticeTest) -> Bool {
        var tests = loadPracticeTests()
        tests.append(test)
        return savePracticeTests(tests)
    }
    
    func updatePracticeTest(_ test: PracticeTest) -> Bool {
        var tests = loadPracticeTests()
        guard let index = tests.firstIndex(where: { $0.id == test.id }) else { return false }
        tests[index] = test
        return savePracticeTests(tests)
    }
    
    func deletePracticeTest(id: UUID) -> Bool {
        var tests = loadPracticeTests()
        tests.removeAll { $0.id == id }
        return savePracticeTests(tests)
    }
    
    // MARK: - Generic Save/Load with Error Handling
    private func save<T: Encodable>(_ data: T, key: StorageKey) -> Bool {
        do {
            let encoded = try encoder.encode(data)
            UserDefaults.standard.set(encoded, forKey: key.rawValue)
            return true
        } catch {
            print("❌ StudyDataManager: Failed to save \(key.rawValue): \(error.localizedDescription)")
            return false
        }
    }
    
    private func load<T: Decodable>(key: StorageKey) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key.rawValue) else {
            return nil
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("❌ StudyDataManager: Failed to load \(key.rawValue): \(error.localizedDescription)")
            return nil
        }
    }
}
