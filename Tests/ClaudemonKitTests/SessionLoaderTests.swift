import Foundation
import Testing
@testable import ClaudemonKit

/// Creates a temporary directory with a state.json file. Returns the directory URL.
func makeTempStateDir(stateJSON: String) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try stateJSON.write(
        to: dir.appendingPathComponent("state.json"),
        atomically: true,
        encoding: .utf8
    )
    return dir
}

/// Creates a temporary sessions directory with session files. Returns the directory URL.
func makeTempSessionsDir(files: [(filename: String, json: String)]) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for file in files {
        try file.json.write(
            to: dir.appendingPathComponent(file.filename),
            atomically: true,
            encoding: .utf8
        )
    }
    return dir
}

@Suite("SessionLoader")
struct SessionLoaderTests {
    @Test func loadsSessionFromStateAndSessionFiles() throws {
        let stateDir = try makeTempStateDir(stateJSON: """
            {
              "sessions": {
                "abc-123": {
                  "pid": 999,
                  "iterm_session_id": "w0t2p0:GUID-AAA",
                  "last_event": "permission_prompt",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": "Allow Bash: npm test?"
                }
              }
            }
            """)
        let sessionsDir = try makeTempSessionsDir(files: [
            ("999.json", """
                {"sessionId": "abc-123", "pid": 999, "name": "my-session", "cwd": "/Users/mark/project"}
            """),
        ])

        let loader = SessionLoader(isProcessRunning: { _ in true })
        let sessions = loader.load(
            stateDirectory: stateDir,
            sessionsDirectory: sessionsDir
        )

        #expect(sessions.count == 1)
        let s = sessions[0]
        #expect(s.id == "abc-123")
        #expect(s.name == "my-session")
        #expect(s.status == .permission)
        #expect(s.tabIndex == 2)
        #expect(s.message == "Allow Bash: npm test?")
    }

    @Test func fallsBackToCwdBasenameWhenNameIsEmpty() throws {
        let stateDir = try makeTempStateDir(stateJSON: """
            {
              "sessions": {
                "abc-456": {
                  "pid": 888,
                  "iterm_session_id": "w0t0p0:GUID-BBB",
                  "last_event": "idle",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                }
              }
            }
            """)
        let sessionsDir = try makeTempSessionsDir(files: [
            ("888.json", """
                {"sessionId": "abc-456", "pid": 888, "cwd": "/Users/mark/my-project"}
            """),
        ])

        let loader = SessionLoader(isProcessRunning: { _ in true })
        let sessions = loader.load(
            stateDirectory: stateDir,
            sessionsDirectory: sessionsDir
        )

        #expect(sessions.count == 1)
        #expect(sessions[0].name == "my-project")
    }

    @Test func filtersOutDeadProcesses() throws {
        let stateDir = try makeTempStateDir(stateJSON: """
            {
              "sessions": {
                "alive-1": {
                  "pid": 100,
                  "iterm_session_id": "w0t0p0:GUID-1",
                  "last_event": "session_start",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                },
                "dead-2": {
                  "pid": 200,
                  "iterm_session_id": "w0t1p0:GUID-2",
                  "last_event": "idle",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                }
              }
            }
            """)
        let sessionsDir = try makeTempSessionsDir(files: [
            ("100.json", """
                {"sessionId": "alive-1", "pid": 100, "cwd": "/a"}
            """),
            ("200.json", """
                {"sessionId": "dead-2", "pid": 200, "cwd": "/b"}
            """),
        ])

        let loader = SessionLoader(isProcessRunning: { pid in pid == 100 })
        let sessions = loader.load(
            stateDirectory: stateDir,
            sessionsDirectory: sessionsDir
        )

        #expect(sessions.count == 1)
        #expect(sessions[0].id == "alive-1")
    }

    @Test func removesDeadSessionsFromStateFile() throws {
        let stateDir = try makeTempStateDir(stateJSON: """
            {
              "sessions": {
                "dead-1": {
                  "pid": 300,
                  "iterm_session_id": "w0t0p0:GUID-1",
                  "last_event": "idle",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                }
              }
            }
            """)
        let sessionsDir = try makeTempSessionsDir(files: [
            ("300.json", """
                {"sessionId": "dead-1", "pid": 300, "cwd": "/c"}
            """),
        ])

        let loader = SessionLoader(isProcessRunning: { _ in false })
        _ = loader.load(stateDirectory: stateDir, sessionsDirectory: sessionsDir)

        let updatedData = try Data(contentsOf: stateDir.appendingPathComponent("state.json"))
        let updatedState = try JSONDecoder().decode(StateFile.self, from: updatedData)
        #expect(updatedState.sessions.isEmpty)
    }

    @Test func sortsSessionsByTabIndex() throws {
        let stateDir = try makeTempStateDir(stateJSON: """
            {
              "sessions": {
                "s1": {
                  "pid": 10,
                  "iterm_session_id": "w0t5p0:GUID-1",
                  "last_event": "idle",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                },
                "s2": {
                  "pid": 20,
                  "iterm_session_id": "w0t1p0:GUID-2",
                  "last_event": "session_start",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                }
              }
            }
            """)
        let sessionsDir = try makeTempSessionsDir(files: [
            ("10.json", """
                {"sessionId": "s1", "pid": 10, "cwd": "/a"}
            """),
            ("20.json", """
                {"sessionId": "s2", "pid": 20, "cwd": "/b"}
            """),
        ])

        let loader = SessionLoader(isProcessRunning: { _ in true })
        let sessions = loader.load(
            stateDirectory: stateDir,
            sessionsDirectory: sessionsDir
        )

        #expect(sessions.count == 2)
        #expect(sessions[0].id == "s2")  // tab 1
        #expect(sessions[1].id == "s1")  // tab 5
    }

    @Test func sortsSessionsByWindowThenTab() throws {
        // Two windows, tab indices overlap. Expected order: w0t0, w0t2, w1t0, w1t3.
        let stateDir = try makeTempStateDir(stateJSON: """
            {
              "sessions": {
                "w1-t3": {
                  "pid": 10,
                  "iterm_session_id": "w1t3p0:GUID-A",
                  "last_event": "idle",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                },
                "w0-t2": {
                  "pid": 20,
                  "iterm_session_id": "w0t2p0:GUID-B",
                  "last_event": "idle",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                },
                "w1-t0": {
                  "pid": 30,
                  "iterm_session_id": "w1t0p0:GUID-C",
                  "last_event": "idle",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                },
                "w0-t0": {
                  "pid": 40,
                  "iterm_session_id": "w0t0p0:GUID-D",
                  "last_event": "idle",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                }
              }
            }
            """)
        let sessionsDir = try makeTempSessionsDir(files: [
            ("10.json", #"{"sessionId": "w1-t3", "pid": 10, "cwd": "/a"}"#),
            ("20.json", #"{"sessionId": "w0-t2", "pid": 20, "cwd": "/b"}"#),
            ("30.json", #"{"sessionId": "w1-t0", "pid": 30, "cwd": "/c"}"#),
            ("40.json", #"{"sessionId": "w0-t0", "pid": 40, "cwd": "/d"}"#),
        ])

        let loader = SessionLoader(isProcessRunning: { _ in true })
        let sessions = loader.load(
            stateDirectory: stateDir,
            sessionsDirectory: sessionsDir
        )

        #expect(sessions.map(\.id) == ["w0-t0", "w0-t2", "w1-t0", "w1-t3"])
        #expect(sessions[0].windowIndex == 0)
        #expect(sessions[2].windowIndex == 1)
    }

    @Test func matchesByPidWhenClaudeSessionIdIsStale() throws {
        // Simulates the /clear race: SessionStart has fired with the new session ID
        // so state.json is up to date, but Claude has not yet rewritten
        // ~/.claude/sessions/{pid}.json, which still references the old session ID.
        let stateDir = try makeTempStateDir(stateJSON: """
            {
              "sessions": {
                "new-sid": {
                  "pid": 4242,
                  "iterm_session_id": "w0t3p0:GUID-X",
                  "last_event": "session_start",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                }
              }
            }
            """)
        let sessionsDir = try makeTempSessionsDir(files: [
            ("4242.json", """
                {"sessionId": "old-sid", "pid": 4242, "name": "still-here", "cwd": "/Users/mark/project"}
            """),
        ])

        let loader = SessionLoader(isProcessRunning: { $0 == 4242 })
        let sessions = loader.load(
            stateDirectory: stateDir,
            sessionsDirectory: sessionsDir
        )

        #expect(sessions.count == 1)
        #expect(sessions[0].id == "new-sid")
        #expect(sessions[0].name == "still-here")
        #expect(sessions[0].tabIndex == 3)
    }

    @Test func returnsEmptyWhenStateFileIsMissing() throws {
        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let loader = SessionLoader(isProcessRunning: { _ in true })
        let sessions = loader.load(
            stateDirectory: emptyDir,
            sessionsDirectory: emptyDir
        )

        #expect(sessions.isEmpty)
    }
}
