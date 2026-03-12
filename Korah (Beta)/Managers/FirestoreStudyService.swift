import Foundation
import FirebaseFirestore
import Observation

/// Centralized Firestore service for all study data (flashcard sets, study guides, practice tests).
/// Replaces `StudyDataManager` and the inline `UserDefaults` calls scattered across views.
///
/// Lifecycle:
/// - Call `startListening(uid:)` after the user authenticates.
/// - Call `stopListening()` on logout.
@MainActor
@Observable
final class FirestoreStudyService {

    static let shared = FirestoreStudyService()

    // MARK: - Live Data

    var flashcardSets: [FlashcardSet] = []
    var studyGuides: [StudyGuide] = []
    var practiceTests: [PracticeTest] = []

    // MARK: - Private State

    private var db: Firestore { Firestore.firestore() }
    private var listeners: [ListenerRegistration] = []
    private(set) var currentUID: String?

    private init() {}

    // MARK: - Lifecycle

    func startListening(uid: String) {
        guard currentUID != uid else { return }
        stopListening()
        currentUID = uid
        attachListeners(uid: uid)
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        flashcardSets = []
        studyGuides = []
        practiceTests = []
        currentUID = nil
    }

    // MARK: - Snapshot Listeners

    private func attachListeners(uid: String) {
        let base = db.collection("users").document(uid)

        // Flashcard Sets
        let flashcardListener = base.collection("flashcardSets")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                self.flashcardSets = snapshot.documents
                    .compactMap { try? $0.data(as: FlashcardSet.self) }
                    .sorted { $0.createdAt > $1.createdAt }
            }
        listeners.append(flashcardListener)

        // Study Guides
        let guidesListener = base.collection("studyGuides")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                self.studyGuides = snapshot.documents
                    .compactMap { try? $0.data(as: StudyGuide.self) }
                    .sorted { $0.createdAt > $1.createdAt }
            }
        listeners.append(guidesListener)

        // Practice Tests
        let testsListener = base.collection("practiceTests")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                self.practiceTests = snapshot.documents
                    .compactMap { try? $0.data(as: PracticeTest.self) }
                    .sorted { $0.createdAt > $1.createdAt }
            }
        listeners.append(testsListener)
    }

    // MARK: - Flashcard Sets CRUD

    func addFlashcardSet(_ set: FlashcardSet) throws {
        guard let uid = currentUID else { return }
        try db.collection("users").document(uid)
            .collection("flashcardSets").document(set.id.uuidString)
            .setData(from: set)
    }

    func updateFlashcardSet(_ set: FlashcardSet) throws {
        guard let uid = currentUID else { return }
        var updated = set
        updated.updatedAt = Date()
        try db.collection("users").document(uid)
            .collection("flashcardSets").document(set.id.uuidString)
            .setData(from: updated)
    }

    func deleteFlashcardSet(id: UUID) async throws {
        guard let uid = currentUID else { return }
        try await db.collection("users").document(uid)
            .collection("flashcardSets").document(id.uuidString)
            .delete()
    }

    // MARK: - Study Guides CRUD

    func addStudyGuide(_ guide: StudyGuide) throws {
        guard let uid = currentUID else { return }
        try db.collection("users").document(uid)
            .collection("studyGuides").document(guide.id.uuidString)
            .setData(from: guide)
    }

    func updateStudyGuide(_ guide: StudyGuide) throws {
        guard let uid = currentUID else { return }
        try db.collection("users").document(uid)
            .collection("studyGuides").document(guide.id.uuidString)
            .setData(from: guide)
    }

    func deleteStudyGuide(id: UUID) async throws {
        guard let uid = currentUID else { return }
        try await db.collection("users").document(uid)
            .collection("studyGuides").document(id.uuidString)
            .delete()
    }

    // MARK: - Practice Tests CRUD

    func addPracticeTest(_ test: PracticeTest) throws {
        guard let uid = currentUID else { return }
        try db.collection("users").document(uid)
            .collection("practiceTests").document(test.id.uuidString)
            .setData(from: test)
    }

    func updatePracticeTest(_ test: PracticeTest) throws {
        guard let uid = currentUID else { return }
        try db.collection("users").document(uid)
            .collection("practiceTests").document(test.id.uuidString)
            .setData(from: test)
    }

    func deletePracticeTest(id: UUID) async throws {
        guard let uid = currentUID else { return }
        try await db.collection("users").document(uid)
            .collection("practiceTests").document(id.uuidString)
            .delete()
    }

    // MARK: - Bulk Delete Helpers

    func deleteAllPracticeTests() {
        let ids = practiceTests.map { $0.id }
        for id in ids {
            Task { try? await deletePracticeTest(id: id) }
        }
    }

    func deleteAllStudyGuides() {
        let ids = studyGuides.map { $0.id }
        for id in ids {
            Task { try? await deleteStudyGuide(id: id) }
        }
    }
}
