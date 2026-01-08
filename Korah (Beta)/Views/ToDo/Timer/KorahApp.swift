import SwiftUI
import Foundation

@main
struct KorahApp: App {
    init() {
        applyKorahAppearance()
    }
    var body: some Scene {
        WindowGroup {
            LauncherView()
                .preferredColorScheme(.dark)
        }
    }
}
