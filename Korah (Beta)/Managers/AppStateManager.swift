import SwiftUI
import Combine

class AppStateManager: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @Published var shouldShowLaunchAnimation: Bool = false
    
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
