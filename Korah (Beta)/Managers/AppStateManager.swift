import SwiftUI

@MainActor
@Observable
final class AppStateManager {
    @ObservationIgnored
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    var shouldShowLaunchAnimation: Bool = false
    
    init() {
        // Show launch animation only on fresh app launch (not from background)
        shouldShowLaunchAnimation = true
    }
    
    func dismissLaunchAnimation() {
        withAnimation {
            shouldShowLaunchAnimation = false
        }
    }
}
