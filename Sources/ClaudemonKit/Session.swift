import SwiftUI

public enum SessionStatus {
    case working
    case permission
    case idle
}

public struct Session: Identifiable {
    public let id: String
    public let name: String
    public let status: SessionStatus
    public let tabIndex: Int
    public let itermSessionId: String
    public let message: String
    public let lastEventTime: Date

    public init(
        id: String,
        name: String,
        status: SessionStatus,
        tabIndex: Int,
        itermSessionId: String,
        message: String,
        lastEventTime: Date
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.tabIndex = tabIndex
        self.itermSessionId = itermSessionId
        self.message = message
        self.lastEventTime = lastEventTime
    }
}
