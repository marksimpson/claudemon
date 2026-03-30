import SwiftUI

public struct MenuBarLabel: View {
    public let sessions: [Session]

    public init(sessions: [Session]) {
        self.sessions = sessions
    }

    public var body: some View {
        if sessions.isEmpty {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundColor(.gray)
        } else {
            HStack(spacing: 2) {
                ForEach(sessions) { session in
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundColor(session.status.color)
                }
            }
        }
    }
}
