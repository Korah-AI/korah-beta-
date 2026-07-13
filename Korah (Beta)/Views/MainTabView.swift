import SwiftUI

// MARK: - Main tab shell (SAT-first)
// Replaces the old HomePageView TabView. Tabs: SAT (default) · Ask Korah ·
// Study · Profile. The Tasks/To-Do and Focus Timer surfaces are deferred
// from v1 navigation — see BETA_V1_DEFERRED.md.

struct MainTabView: View {
    @State private var selectedTab: Tab = .sat

    enum Tab: Hashable {
        case sat, chat, study, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SATHomeView()
                .tabItem { Label("SAT", systemImage: "graduationcap.fill") }
                .tag(Tab.sat)

            ChatView()
                .tabItem { Label("Ask Korah", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(Tab.chat)

            StudyHomeView()
                .tabItem { Label("Study", systemImage: "book.closed.fill") }
                .tag(Tab.study)

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
