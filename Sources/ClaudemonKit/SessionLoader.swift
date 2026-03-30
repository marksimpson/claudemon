import Foundation

public struct StateFile: Codable {
    public var sessions: [String: SessionState]
}

public struct SessionState: Codable {
    public let itermSessionId: String?
    public let lastEvent: String
    public let lastEventTime: String
    public let message: String

    enum CodingKeys: String, CodingKey {
        case itermSessionId = "iterm_session_id"
        case lastEvent = "last_event"
        case lastEventTime = "last_event_time"
        case message
    }
}

struct ClaudeSessionFile: Codable {
    let sessionId: String?
    let pid: Int?
    let name: String?
    let cwd: String?
}

public struct SessionLoader {
    public var isProcessRunning: (Int32) -> Bool

    public init(isProcessRunning: @escaping (Int32) -> Bool = { pid in kill(pid, 0) == 0 }) {
        self.isProcessRunning = isProcessRunning
    }

    /// Loads sessions by joining state.json with Claude's session files.
    /// Filters out dead sessions and removes them from state.json.
    /// Returns sessions sorted by tab index.
    public func load(stateDirectory: URL, sessionsDirectory: URL) -> [Session] {
        let stateFileURL = stateDirectory.appendingPathComponent("state.json")

        guard let stateData = try? Data(contentsOf: stateFileURL),
              var stateFile = try? JSONDecoder().decode(StateFile.self, from: stateData) else {
            return []
        }

        let claudeSessions = loadClaudeSessions(from: sessionsDirectory)
        var sessions: [Session] = []
        var deadSessionIds: [String] = []

        for (sessionId, state) in stateFile.sessions {
            guard let claudeSession = claudeSessions[sessionId] else {
                deadSessionIds.append(sessionId)
                continue
            }

            guard let pid = claudeSession.pid,
                  isProcessRunning(Int32(pid)) else {
                deadSessionIds.append(sessionId)
                continue
            }

            let name: String
            if let sessionName = claudeSession.name, !sessionName.isEmpty {
                name = sessionName
            } else if let cwd = claudeSession.cwd {
                name = URL(fileURLWithPath: cwd).lastPathComponent
            } else {
                name = "unknown"
            }

            let isoFormatter = ISO8601DateFormatter()
            let eventTime = isoFormatter.date(from: state.lastEventTime) ?? Date()

            let itermId = state.itermSessionId ?? ""

            sessions.append(Session(
                id: sessionId,
                name: name,
                status: SessionStatus(lastEvent: state.lastEvent),
                tabIndex: Session.parseTabIndex(from: itermId),
                itermSessionId: itermId,
                message: state.message,
                lastEventTime: eventTime
            ))
        }

        if !deadSessionIds.isEmpty {
            for id in deadSessionIds {
                stateFile.sessions.removeValue(forKey: id)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let encoded = try? encoder.encode(stateFile) {
                try? encoded.write(to: stateFileURL, options: .atomic)
            }
        }

        return sessions.sorted { $0.tabIndex < $1.tabIndex }
    }

    private func loadClaudeSessions(from directory: URL) -> [String: ClaudeSessionFile] {
        var result: [String: ClaudeSessionFile] = [:]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return result
        }
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let session = try? JSONDecoder().decode(ClaudeSessionFile.self, from: data),
                  let sessionId = session.sessionId else {
                continue
            }
            result[sessionId] = session
        }
        return result
    }
}
