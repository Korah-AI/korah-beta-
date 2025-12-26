import SwiftUI

struct LauncherView: View {
    @AppStorage("IsLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("SavedUsername") private var savedUsername: String = ""
    
    var body: some View {
        NavigationStack {
            if isLoggedIn {
                HomePageView()
            } else {
                OpeningView()
            }
        }
    }
}

struct LauncherView_Previews: PreviewProvider {
    static var previews: some View {
        LauncherView()
    }
}

