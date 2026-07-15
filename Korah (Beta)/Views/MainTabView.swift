import SwiftUI

// MARK: - Main tab shell (SAT-first)
// Replaces the old HomePageView TabView. Tabs: SAT (default) · Practice ·
// Ask Korah · Profile. The Question Bank is reached from within SAT/Practice
// rather than its own tab. The progress dashboard now lives on the Profile
// tab. The Tasks/To-Do and Focus Timer surfaces are deferred from v1
// navigation — see BETA_V1_DEFERRED.md.

struct MainTabView: View {
    @State private var selectedTab: Tab = .sat

    enum Tab: Hashable {
        case sat, practice, chat, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SATHomeView(onOpenProfile: { selectedTab = .profile },
                        onOpenChat: { selectedTab = .chat })
                .tabItem { Label("Home", systemImage: "graduationcap.fill") }
                .tag(Tab.sat)

            SATPracticeView()
                .tabItem { Label("Practice", systemImage: "bolt.fill") }
                .tag(Tab.practice)

            ChatView(onBack: { selectedTab = .sat })
                .tabItem { Label("Ask Korah", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(Tab.chat)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
        // NOTE: The selected-tab tint is set via the UITabBar appearance proxy
        // in KorahApp.init(). Do NOT add `.tint(Color.kAccent)` here — a SwiftUI
        // `.tint()` on the TabView overrides the appearance proxy and only takes
        // effect after a view rebuild (backgrounding/foregrounding), which is the
        // exact cold-launch bug where the tab bar shows untinted on first open.
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager.shared)
        .environment(FirestoreStudyService.shared)
        .environment(FirestoreConversationService.shared)
}
