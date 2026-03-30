import SwiftUI

public struct SessionMenuItem: View {
    public let session: Session

    public init(session: Session) {
        self.session = session
    }

    public var body: some View {
        Button {
            ITerm.activateSession(itermSessionId: session.itermSessionId)
        } label: {
            let statusLabel = switch session.status {
            case .permission: "PERMISSION"
            case .idle: "IDLE"
            case .working: "WORKING"
            }
            let detail = session.message.isEmpty
                ? "\(statusLabel) · tab \(session.tabIndex)"
                : "\(statusLabel) · tab \(session.tabIndex) · \(session.message)"
            Text("\(session.name) — \(detail)")
        }
    }
}
