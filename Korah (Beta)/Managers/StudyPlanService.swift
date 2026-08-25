import Foundation
import FirebaseFirestore
import Observation

/// Firestore-backed store for the user's active study plan.
/// Schema shared with the web app: users/{uid}/studyPlans/current.
///
/// Lifecycle mirrors FirestoreStudyService: `startListening()` after auth
/// (safe to call repeatedly), `stopListening()` on logout.
@MainActor
@Observable
final class StudyPlanService {

    static let shared = StudyPlanService()

    /// The active plan, kept live by a snapshot listener. nil = no plan yet.
    var plan: StudyPlan?
    private(set) var loaded = false

    private var db: Firestore { Firestore.firestore() }
    private var listener: ListenerRegistration?
    private(set) var currentUID: String?

    private init() {}

    private func planRef(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
            .collection("studyPlans").document("current")
    }

    private func isoNow() -> String {
        ISO8601DateFormatter.satShared.string(from: Date())
    }

    // MARK: - Lifecycle

    func startListening() {
        guard let uid = AuthManager.shared.currentUser?.id else { return }
        guard currentUID != uid else { return }
        stopListening()
        currentUID = uid
        listener = planRef(uid).addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let snapshot else { return }
            self.plan = snapshot.exists ? (try? snapshot.data(as: StudyPlan.self)) : nil
            self.loaded = true
            // Study day reminders follow whatever the plan currently says.
            NotificationManager.shared.scheduleStudyPlanNotifications(for: self.plan)
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        plan = nil
        loaded = false
        currentUID = nil
    }

    // MARK: - Writes

    func save(_ plan: StudyPlan) throws {
        guard let uid = currentUID ?? AuthManager.shared.currentUser?.id else { return }
        var payload = plan
        let now = isoNow()
        payload.createdAt = plan.createdAt ?? now
        payload.updatedAt = now
        try planRef(uid).setData(from: payload)
        self.plan = payload
    }

    func setCompleted(sessionId: String, completed: Bool) {
        guard var updated = plan,
              let index = updated.sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        updated.sessions[index].completed = completed
        try? save(updated)
    }

    func deletePlan() async throws {
        guard let uid = currentUID ?? AuthManager.shared.currentUser?.id else { return }
        try await planRef(uid).delete()
        plan = nil
    }
}
