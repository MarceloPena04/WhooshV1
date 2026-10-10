import SwiftUI

@main
struct WhooshApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Whoosh lives in the menu bar (§2.1), and AppDelegate owns that menu.
        // SwiftUI needs at least one scene; Settings opens no window at launch.
        Settings {
            EmptyView()
        }
    }
}
