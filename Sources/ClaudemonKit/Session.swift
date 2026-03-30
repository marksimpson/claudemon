import Foundation

public enum SessionStatus {
    case working
    case permission
    case idle
}

extension SessionStatus: Equatable {
    public init(lastEvent: String) {
        switch lastEvent {
        case "permission_prompt":
            self = .permission
        case "idle", "session_start":
            self = .idle
        default:
            self = .working
        }
    }
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

extension Session {
    /// Extracts the tab index from an iTerm session ID string.
    /// Format: wXtYpZ:GUID — returns Y.
    public static func parseTabIndex(from itermSessionId: String) -> Int {
        guard let tIdx = itermSessionId.firstIndex(of: "t") else { return 0 }
        let afterT = itermSessionId.index(after: tIdx)
        guard afterT < itermSessionId.endIndex else { return 0 }
        guard let pIdx = itermSessionId[afterT...].firstIndex(of: "p") else { return 0 }
        return Int(itermSessionId[afterT..<pIdx]) ?? 0
    }
}

