import SwiftUI
import iTMUX

@main
struct iTMUXiOSClientApp: App {
    var body: some Scene {
        WindowGroup {
            SessionListView()
                .preferredColorScheme(.dark)
        }
    }
}
