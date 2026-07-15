import SwiftUI

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

    private static let onboardingKey = "hasCompletedOnboardingV2"

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }
}
