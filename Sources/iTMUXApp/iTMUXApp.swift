import SwiftUI
import iTMUX

@main
struct iTMUXApp: App {
    var body: some Scene {
        WindowGroup {
            SessionListView()
                .preferredColorScheme(.dark)
        }
    }
}
