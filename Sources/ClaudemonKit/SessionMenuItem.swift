import AppKit

public enum SessionMenuBuilder {
    public static func menuItem(
        for session: Session,
        target: AnyObject,
        action: Selector
    ) -> NSMenuItem {
        let statusLabel = switch session.status {
        case .permission: "PERMISSION"
        case .idle: "IDLE"
        case .working: "WORKING"
        }
        let detail = session.message.isEmpty
            ? "\(statusLabel) · tab \(session.tabIndex + 1)"
            : "\(statusLabel) · tab \(session.tabIndex + 1) · \(session.message)"

        let item = NSMenuItem(
            title: "\(session.name) — \(detail)",
            action: action,
            keyEquivalent: ""
        )
        item.target = target
        item.representedObject = session.itermSessionId

        let dotSize: CGFloat = 8
        let image = NSImage(size: NSSize(width: dotSize, height: dotSize), flipped: false) { rect in
            session.status.nsColor.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        item.image = image

        return item
    }
}
