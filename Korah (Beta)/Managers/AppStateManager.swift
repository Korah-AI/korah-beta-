import SwiftUI

/// Test date / score goals collected during onboarding, before the user has
/// signed in. There's no `uid` yet to write these to Firestore, so they're
/// held here and flushed to `SATAnalyticsService` once auth succeeds.
struct PendingOnboardingProfile: Codable {
    var mathScore: Int?
    var englishScore: Int?
    var mathGoal: Int
    var englishGoal: Int
    var testDate: Date?
}

@MainActor
@Observable
final class AppStateManager {
    // NOTE: This is deliberately NOT `@ObservationIgnored @AppStorage`.
    // That combination persisted the value but never notified SwiftUI, so
    // tapping "Get Started" on the last onboarding slide did nothing until
    // a backgrounding forced a re-render. A plain observable property with
    // a manual UserDefaults mirror both persists and updates the UI.
    //
    // Key is V2 so existing users see the new SAT onboarding once (it
    // collects the goal scores / test date the home screen now uses).
    var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding,
                                      forKey: Self.onboardingKey)
        }
    }

    var pendingOnboardingProfile: PendingOnboardingProfile? {
        didSet {
            if let pendingOnboardingProfile,
               let data = try? JSONEncoder().encode(pendingOnboardingProfile) {
                UserDefaults.standard.set(data, forKey: Self.pendingProfileKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.pendingProfileKey)
            }
        }
    }

    private static let onboardingKey = "hasCompletedOnboardingV2"
    private static let pendingProfileKey = "pendingOnboardingProfileV1"

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        if let data = UserDefaults.standard.data(forKey: Self.pendingProfileKey) {
            pendingOnboardingProfile = try? JSONDecoder().decode(PendingOnboardingProfile.self, from: data)
        } else {
            pendingOnboardingProfile = nil
        }
    }
}
