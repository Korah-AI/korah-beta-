import SwiftUI

// MARK: - Main tab shell (SAT-first)
// Replaces the old HomePageView TabView. Tabs: SAT (default) · Practice ·
// Question Bank · Ask Korah · Profile. The progress dashboard now lives on the
// Profile tab. The Tasks/To-Do and Focus Timer surfaces are deferred from v1
// navigation — see BETA_V1_DEFERRED.md.

struct MainTabView: View {
    @State private var selectedTab: Tab = .sat

    enum Tab: Hashable {
        case sat, practice, bank, chat, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SATHomeView(onOpenProfile: { selectedTab = .profile })
                .tabItem { Label("SAT", systemImage: "graduationcap.fill") }
                .tag(Tab.sat)

            SATPracticeView()
                .tabItem { Label("Practice", systemImage: "bolt.fill") }
                .tag(Tab.practice)

            NavigationStack {
                SATBankView()
            }
            .tabItem { Label("Question Bank", systemImage: "square.grid.2x2.fill") }
            .tag(Tab.bank)

            ChatView(onBack: { selectedTab = .sat })
                .tabItem { Label("Ask Korah", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(Tab.chat)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
        .tint(Color.kAccent)
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager.shared)
        .environment(FirestoreStudyService.shared)
        .environment(FirestoreConversationService.shared)
}
