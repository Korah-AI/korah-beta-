import Foundation

/// Performs a one-time migration of locally stored study data and conversations into Firestore.
///
/// Run `migrateIfNeeded(uid:)` once, right after authentication succeeds and the Firestore
/// services have started listening. Subsequent launches skip migration via the
/// `"firestoreMigrationComplete"` flag in `UserDefaults`.
@MainActor
final class DataMigrationManager {

    static let shared = DataMigrationManager()

    private let migrationKey = "firestoreMigrationComplete"

    private init() {}

    var needsMigration: Bool {
        !UserDefaults.standard.bool(forKey: migrationKey)
    }

    /// Migrates all locally stored data to Firestore (no-op if already migrated).
    func migrateIfNeeded(uid: String) async {
        guard needsMigration else { return }

        let studyService = FirestoreStudyService.shared
        let conversationService = FirestoreConversationService.shared
        let decoder = JSONDecoder()

        // --- Flashcard Sets ---
        if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
           let sets = try? decoder.decode([FlashcardSet].self, from: data) {
            for set in sets {
                try? studyService.addFlashcardSet(set)
            }
        }

        // --- Study Guides ---
        if let data = UserDefaults.standard.data(forKey: "StudyGuides"),
           let guides = try? decoder.decode([StudyGuide].self, from: data) {
            for guide in guides {
                try? studyService.addStudyGuide(guide)
            }
        }

        // --- Practice Tests ---
        if let data = UserDefaults.standard.data(forKey: "PracticeTests"),
           let tests = try? decoder.decode([PracticeTest].self, from: data) {
            for test in tests {
                try? studyService.addPracticeTest(test)
            }
        }

        // --- Conversations (chat + scan) ---
        let chatConversations = ConversationManager.shared.listConversations(type: .chat)
        let scanConversations = ConversationManager.shared.listConversations(type: .scan)
        for conversation in chatConversations + scanConversations {
            try? conversationService.saveConversation(conversation)
        }

        // Mark migration as done (local data kept as fallback cache).
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ DataMigrationManager: Firestore migration complete for uid \(uid)")
    }
}
