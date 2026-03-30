import SwiftUI
import ClaudemonKit

@main
struct ClaudemonApp: App {
    var body: some Scene {
        MenuBarExtra {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundColor(.gray)
        }
    }
}
