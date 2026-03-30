import AppKit
import ClaudemonKit
import Combine

@main
enum ClaudemonApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var store: SessionStore!
    private var cancellable: AnyCancellable?
    private var cycleIndex = 0
    private var lastUrgentIds: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = SessionStore()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        cancellable = store.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                self?.updateStatusItem(sessions: sessions)
            }
    }

    private func updateStatusItem(sessions: [Session]) {
        statusItem.button?.image = DotStrip.renderDots(sessions: sessions)

        let urgentIds = sessions
            .filter { $0.status == .permission || $0.status == .idle }
            .map(\.id)
        if urgentIds != lastUrgentIds {
            cycleIndex = 0
            lastUrgentIds = urgentIds
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            showMenu()
        } else {
            let urgent = store.sessions.filter { $0.status == .permission || $0.status == .idle }
            if urgent.isEmpty {
                showMenu()
            } else {
                cycleToNext(urgent: urgent)
            }
        }
    }

    private func cycleToNext(urgent: [Session]) {
        if cycleIndex >= urgent.count { cycleIndex = 0 }
        let session = urgent[cycleIndex]
        ITerm.activateSession(itermSessionId: session.itermSessionId)
        cycleIndex = (cycleIndex + 1) % urgent.count
    }

    private func showMenu() {
        let menu = NSMenu()

        for session in store.sessions {
            let item = SessionMenuBuilder.menuItem(
                for: session,
                target: self,
                action: #selector(menuItemClicked(_:))
            )
            menu.addItem(item)
        }

        if !store.sessions.isEmpty {
            menu.addItem(.separator())
        }

        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuItemClicked(_ sender: NSMenuItem) {
        guard let itermSessionId = sender.representedObject as? String else { return }
        ITerm.activateSession(itermSessionId: itermSessionId)
    }
}
