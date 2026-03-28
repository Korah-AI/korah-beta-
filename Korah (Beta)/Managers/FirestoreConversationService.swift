import Foundation
import FirebaseFirestore
import Observation

/// Centralized Firestore service for conversation history (scan and chat).
/// Replaces file-based `ConversationManager` for persistence.
/// Images remain stored locally; only the `imageFileName` reference is stored in Firestore.
///
/// Lifecycle:
/// - Call `startListening(uid:)` after the user authenticates.
/// - Call `stopListening()` on logout.
@MainActor
@Observable
final class FirestoreConversationService {

    static let shared = FirestoreConversationService()

    // MARK: - Live Data

    var conversations: [Conversation] = []

    // MARK: - Private State

    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    private(set) var currentUID: String?

    private init() {}

    // MARK: - Lifecycle

    func startListening(uid: String) {
        guard currentUID != uid else { return }
        stopListening()
        currentUID = uid

        listener = db.collection("users").document(uid)
            .collection("conversations")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                self.conversations = snapshot.documents
                    .compactMap { try? $0.data(as: Conversation.self) }
                    .sorted { $0.updatedAt > $1.updatedAt }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        conversations = []
        currentUID = nil
    }

    // MARK: - CRUD

    /// Saves (creates or overwrites) a conversation in Firestore.
    /// Images attached to scan messages remain on-device; only `imageFileName` is persisted.
    func saveConversation(_ conversation: Conversation) throws {
        guard let uid = currentUID else { return }
        try db.collection("users").document(uid)
            .collection("conversations").document(conversation.id.uuidString)
            .setData(from: conversation)
    }

    /// Convenience async-throwing variant for callers that prefer structured concurrency.
    func saveConversationAsync(_ conversation: Conversation) async throws {
        guard let uid = currentUID else { return }
        try db.collection("users").document(uid)
            .collection("conversations").document(conversation.id.uuidString)
            .setData(from: conversation)
    }

    func deleteConversation(id: UUID) async throws {
        guard let uid = currentUID else { return }
        try await db.collection("users").document(uid)
            .collection("conversations").document(id.uuidString)
            .delete()
    }

    /// Fetches a single conversation from Firestore by ID (one-shot read, not streamed).
    func loadConversation(id: UUID) async -> Conversation? {
        guard let uid = currentUID else { return nil }
        let snapshot = try? await db.collection("users").document(uid)
            .collection("conversations").document(id.uuidString)
            .getDocument()
        return try? snapshot?.data(as: Conversation.self)
    }

    // MARK: - Helpers

    /// Returns all conversations matching a given `ConversationType`, sorted newest first.
    func conversations(ofType type: ConversationType) -> [Conversation] {
        conversations.filter { $0.type == type }
    }
}
