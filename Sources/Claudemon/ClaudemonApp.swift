import SwiftUI
import ClaudemonKit

@main
struct ClaudemonApp: App {
    @StateObject private var store = SessionStore()

    var body: some Scene {
        MenuBarExtra {
            ForEach(store.sessions) { session in
                SessionMenuItem(session: session)
            }
            if !store.sessions.isEmpty {
                Divider()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            MenuBarLabel(sessions: store.sessions)
        }
    }
}
