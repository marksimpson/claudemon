# claudemon Menubar App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a SwiftUI menubar app that shows colour-coded dots for each Claude Code session and lets the user click to switch iTerm2 tabs.

**Architecture:** A `MenuBarExtra` app with a library target for testable logic. `SessionStore` watches the `~/.claude/claudemon/` directory via `DispatchSource` and publishes a sorted session list. The menubar label renders a compact dot strip. Menu items trigger AppleScript to switch iTerm2 tabs.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 13+, SPM (library + executable targets)

**Spec:** `docs/superpowers/specs/2026-03-30-claudemon-menubar-design.md`

---

## File structure

```
Package.swift
Sources/
├── ClaudemonKit/              # Library target (testable)
│   ├── Session.swift          # Session model, Status enum, tab index parsing
│   ├── SessionLoader.swift    # State file + session file decoding, joining, PID checks
│   ├── SessionStore.swift     # ObservableObject, DispatchSource directory watching
│   ├── MenuBarLabel.swift     # Dot strip view for menubar icon
│   ├── SessionMenuItem.swift  # Individual menu item view
│   └── ITerm.swift            # GUID parsing + AppleScript tab switching
└── Claudemon/
    └── ClaudemonApp.swift     # @main entry point only
Tests/
└── ClaudemonKitTests/
    ├── SessionTests.swift
    ├── SessionLoaderTests.swift
    └── ITermTests.swift
Info.plist                     # LSUIElement = true
Makefile                       # Build + bundle into .app
```

The library/executable split is necessary because `@main` prevents the test target from linking the executable directly.

---

### Task 1: SPM project scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/Claudemon/ClaudemonApp.swift`
- Create: `Sources/ClaudemonKit/Session.swift` (placeholder export)

Set up the SPM package with two targets: `ClaudemonKit` (library) and `Claudemon` (executable). Verify it builds and shows a grey dot in the menubar.

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Claudemon",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "ClaudemonKit",
            path: "Sources/ClaudemonKit"
        ),
        .executableTarget(
            name: "Claudemon",
            dependencies: ["ClaudemonKit"],
            path: "Sources/Claudemon"
        ),
        .testTarget(
            name: "ClaudemonKitTests",
            dependencies: ["ClaudemonKit"],
            path: "Tests/ClaudemonKitTests"
        ),
    ]
)
```

- [ ] **Step 2: Create the placeholder library file**

`Sources/ClaudemonKit/Session.swift`:

```swift
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
```

- [ ] **Step 3: Create the app entry point**

`Sources/Claudemon/ClaudemonApp.swift`:

```swift
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
```

- [ ] **Step 4: Create an empty test file so the test target compiles**

`Tests/ClaudemonKitTests/SessionTests.swift`:

```swift
import Testing
@testable import ClaudemonKit

@Test func placeholder() {
    // Will be replaced with real tests in Task 2
}
```

- [ ] **Step 5: Build and verify**

Run: `swift build`
Expected: builds without errors.

- [ ] **Step 6: Run and verify the grey dot appears**

Run: `swift run Claudemon`
Expected: a small grey dot appears in the menubar. Clicking it shows a menu with "Quit". No dock icon appears in the menu, though it may show in the dock without LSUIElement (that's fine for now — Task 8 fixes it).

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "feat: SPM scaffold with grey dot menubar app"
```

---

### Task 2: Session model — status derivation and tab index parsing

**Files:**
- Modify: `Sources/ClaudemonKit/Session.swift`
- Modify: `Tests/ClaudemonKitTests/SessionTests.swift`

Add `SessionStatus.init(lastEvent:)` for deriving status from the hook event string, and `Session.parseTabIndex(from:)` for extracting the tab number from an iTerm session ID. Both are pure functions — straightforward TDD.

- [ ] **Step 1: Write failing tests for status derivation**

`Tests/ClaudemonKitTests/SessionTests.swift`:

```swift
import Testing
@testable import ClaudemonKit

@Suite("SessionStatus")
struct SessionStatusTests {
    @Test func permissionPromptMapsToPermission() {
        #expect(SessionStatus(lastEvent: "permission_prompt") == .permission)
    }

    @Test func idleMapsToIdle() {
        #expect(SessionStatus(lastEvent: "idle") == .idle)
    }

    @Test func sessionStartMapsToWorking() {
        #expect(SessionStatus(lastEvent: "session_start") == .working)
    }

    @Test func userPromptMapsToWorking() {
        #expect(SessionStatus(lastEvent: "user_prompt") == .working)
    }

    @Test func unknownEventMapsToWorking() {
        #expect(SessionStatus(lastEvent: "something_else") == .working)
    }
}

@Suite("Tab index parsing")
struct TabIndexTests {
    @Test func parsesTabFromStandardFormat() {
        #expect(Session.parseTabIndex(from: "w0t3p0:6390C52A-B81C-4048-9302-3CCB94C34612") == 3)
    }

    @Test func parsesTabZero() {
        #expect(Session.parseTabIndex(from: "w1t0p0:SOME-GUID") == 0)
    }

    @Test func parsesMultiDigitTab() {
        #expect(Session.parseTabIndex(from: "w0t12p0:SOME-GUID") == 12)
    }

    @Test func returnsZeroForEmptyString() {
        #expect(Session.parseTabIndex(from: "") == 0)
    }

    @Test func returnsZeroForMalformedString() {
        #expect(Session.parseTabIndex(from: "garbage") == 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: compilation errors — `SessionStatus` has no `init(lastEvent:)` and `Session` has no `parseTabIndex(from:)`.

- [ ] **Step 3: Implement status derivation and tab parsing**

Add to `Sources/ClaudemonKit/Session.swift`:

```swift
extension SessionStatus: Equatable {
    public init(lastEvent: String) {
        switch lastEvent {
        case "permission_prompt":
            self = .permission
        case "idle":
            self = .idle
        default:
            self = .working
        }
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudemonKit/Session.swift Tests/ClaudemonKitTests/SessionTests.swift
git commit -m "feat: status derivation and tab index parsing"
```

---

### Task 3: State file and session file decoding

**Files:**
- Create: `Sources/ClaudemonKit/SessionLoader.swift`
- Create: `Tests/ClaudemonKitTests/SessionLoaderTests.swift`

Implement Codable structs for both JSON formats and a `SessionLoader` that reads, decodes, joins, and filters the data. Uses a closure for PID checking so tests can inject a fake.

- [ ] **Step 1: Write failing tests for state file decoding**

`Tests/ClaudemonKitTests/SessionLoaderTests.swift`:

```swift
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

/// Creates a temporary sessions directory with one session file. Returns the directory URL.
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
                  "iterm_session_id": "w0t0p0:GUID-1",
                  "last_event": "session_start",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                },
                "dead-2": {
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
                  "iterm_session_id": "w0t5p0:GUID-1",
                  "last_event": "idle",
                  "last_event_time": "2026-03-30T01:00:00Z",
                  "message": ""
                },
                "s2": {
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: compilation errors — `SessionLoader`, `StateFile` do not exist.

- [ ] **Step 3: Implement SessionLoader**

`Sources/ClaudemonKit/SessionLoader.swift`:

```swift
import Foundation

public struct StateFile: Codable {
    public var sessions: [String: SessionState]
}

public struct SessionState: Codable {
    public let itermSessionId: String
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

            sessions.append(Session(
                id: sessionId,
                name: name,
                status: SessionStatus(lastEvent: state.lastEvent),
                tabIndex: Session.parseTabIndex(from: state.itermSessionId),
                itermSessionId: state.itermSessionId,
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudemonKit/SessionLoader.swift Tests/ClaudemonKitTests/SessionLoaderTests.swift
git commit -m "feat: session loading with state file and session file joining"
```

---

### Task 4: iTerm2 GUID parsing and AppleScript switching

**Files:**
- Create: `Sources/ClaudemonKit/ITerm.swift`
- Create: `Tests/ClaudemonKitTests/ITermTests.swift`

TDD for the GUID parsing. The AppleScript execution itself can't be unit tested but the script generation can be verified.

- [ ] **Step 1: Write failing tests**

`Tests/ClaudemonKitTests/ITermTests.swift`:

```swift
import Testing
@testable import ClaudemonKit

@Suite("ITerm")
struct ITermTests {
    @Test func parsesGUIDFromStandardFormat() {
        let guid = ITerm.parseGUID(from: "w0t3p0:6390C52A-B81C-4048-9302-3CCB94C34612")
        #expect(guid == "6390C52A-B81C-4048-9302-3CCB94C34612")
    }

    @Test func returnsNilForMissingColon() {
        #expect(ITerm.parseGUID(from: "w0t3p0") == nil)
    }

    @Test func returnsNilForEmptyString() {
        #expect(ITerm.parseGUID(from: "") == nil)
    }

    @Test func preservesGUIDWithColons() {
        // Edge case: GUID itself won't contain colons, but verify we split on first only
        let guid = ITerm.parseGUID(from: "w0t0p0:ABC:DEF")
        #expect(guid == "ABC:DEF")
    }

    @Test func generatesValidAppleScript() {
        let script = ITerm.activationScript(for: "MY-GUID-123")
        #expect(script.contains("\"MY-GUID-123\""))
        #expect(script.contains("tell application \"iTerm2\""))
        #expect(script.contains("select t"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: compilation errors — `ITerm` does not exist.

- [ ] **Step 3: Implement ITerm**

`Sources/ClaudemonKit/ITerm.swift`:

```swift
import Foundation

public enum ITerm {
    public static func parseGUID(from itermSessionId: String) -> String? {
        guard let colonIndex = itermSessionId.firstIndex(of: ":") else { return nil }
        let afterColon = itermSessionId.index(after: colonIndex)
        guard afterColon < itermSessionId.endIndex else { return nil }
        return String(itermSessionId[afterColon...])
    }

    public static func activationScript(for guid: String) -> String {
        """
        tell application "iTerm2"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if unique ID of s is "\(guid)" then
                            select t
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
    }

    public static func activateSession(itermSessionId: String) {
        guard let guid = parseGUID(from: itermSessionId) else { return }
        let source = activationScript(for: guid)
        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudemonKit/ITerm.swift Tests/ClaudemonKitTests/ITermTests.swift
git commit -m "feat: iTerm2 GUID parsing and AppleScript tab switching"
```

---

### Task 5: SessionStore with directory watching

**Files:**
- Create: `Sources/ClaudemonKit/SessionStore.swift`

The `SessionStore` is an `ObservableObject` that watches `~/.claude/claudemon/` for changes using `DispatchSource` and republishes the session list. No unit tests for this component — it's a thin wrapper around `SessionLoader` (which is tested) and `DispatchSource` (which is an OS primitive). We'll verify it works by running the app.

- [ ] **Step 1: Implement SessionStore**

`Sources/ClaudemonKit/SessionStore.swift`:

```swift
import Foundation
import SwiftUI

public class SessionStore: ObservableObject {
    @Published public var sessions: [Session] = []

    private var directorySource: DispatchSourceFileSystemObject?
    private let stateDirectory: URL
    private let sessionsDirectory: URL
    private let loader: SessionLoader

    public init(
        stateDirectory: URL? = nil,
        sessionsDirectory: URL? = nil,
        loader: SessionLoader = SessionLoader()
    ) {
        self.stateDirectory = stateDirectory
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent(".claude/claudemon")
        self.sessionsDirectory = sessionsDirectory
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent(".claude/sessions")
        self.loader = loader
        reload()
        startWatching()
    }

    deinit {
        directorySource?.cancel()
    }

    public func reload() {
        sessions = loader.load(
            stateDirectory: stateDirectory,
            sessionsDirectory: sessionsDirectory
        )
    }

    private func startWatching() {
        let path = stateDirectory.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.reload()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        directorySource = source
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: builds without errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/ClaudemonKit/SessionStore.swift
git commit -m "feat: session store with directory watching"
```

---

### Task 6: MenuBarLabel — the dot strip

**Files:**
- Create: `Sources/ClaudemonKit/MenuBarLabel.swift`

The menubar icon: a compact row of coloured dots, one per session, ordered by tab index. Grey dot when empty. No unit tests — this is a pure display component. Verified visually.

- [ ] **Step 1: Add colour property to SessionStatus**

Add to `Sources/ClaudemonKit/Session.swift`:

```swift
extension SessionStatus {
    public var color: Color {
        switch self {
        case .permission: return .red
        case .idle: return .yellow
        case .working: return .green
        }
    }
}
```

- [ ] **Step 2: Create MenuBarLabel**

`Sources/ClaudemonKit/MenuBarLabel.swift`:

```swift
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
```

- [ ] **Step 3: Build to verify it compiles**

Run: `swift build`
Expected: builds without errors.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudemonKit/Session.swift Sources/ClaudemonKit/MenuBarLabel.swift
git commit -m "feat: menubar dot strip label"
```

---

### Task 7: Menu content and app wiring

**Files:**
- Create: `Sources/ClaudemonKit/SessionMenuItem.swift`
- Modify: `Sources/Claudemon/ClaudemonApp.swift`

Wire the `SessionStore`, `MenuBarLabel`, and menu items together in the app. Each menu item shows session details and triggers iTerm2 tab switching on click.

- [ ] **Step 1: Create SessionMenuItem**

`Sources/ClaudemonKit/SessionMenuItem.swift`:

```swift
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
```

- [ ] **Step 2: Wire up ClaudemonApp**

Replace `Sources/Claudemon/ClaudemonApp.swift` with:

```swift
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
```

- [ ] **Step 3: Build and verify**

Run: `swift build`
Expected: builds without errors.

- [ ] **Step 4: Run and verify end-to-end**

Run: `swift run Claudemon`

With active Claude Code sessions running (which are producing state.json via hooks):
- The menubar should show coloured dots for each session
- Clicking the icon should show a menu with session details
- Clicking a session item should switch to that iTerm2 tab
- The dots should update when session states change (e.g., when a permission prompt appears)

If no sessions are running, verify the grey dot appears and the menu shows only "Quit".

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudemonKit/SessionMenuItem.swift Sources/Claudemon/ClaudemonApp.swift
git commit -m "feat: menu content and app wiring"
```

---

### Task 8: App bundle with Info.plist and Makefile

**Files:**
- Create: `Info.plist`
- Create: `Makefile`
- Modify: `.gitignore`

Create the Info.plist for `LSUIElement` (no dock icon) and a Makefile that builds the app and wraps it in a `.app` bundle.

- [ ] **Step 1: Create Info.plist**

`Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Claudemon</string>
    <key>CFBundleIdentifier</key>
    <string>nz.co.claudemon</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>Claudemon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
```

- [ ] **Step 2: Create Makefile**

```makefile
.PHONY: build bundle install clean test

APP_NAME := Claudemon
BUILD_DIR := .build/release
BUNDLE_DIR := $(BUILD_DIR)/$(APP_NAME).app

build:
	swift build -c release

test:
	swift test

bundle: build
	mkdir -p $(BUNDLE_DIR)/Contents/MacOS
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE_DIR)/Contents/MacOS/
	cp Info.plist $(BUNDLE_DIR)/Contents/

install: bundle
	cp -r $(BUNDLE_DIR) /Applications/

clean:
	swift package clean
	rm -rf $(BUNDLE_DIR)
```

- [ ] **Step 3: Update .gitignore**

Add `.build` to `.gitignore`:

```
state.json
.claude/settings.local.json
.build
```

- [ ] **Step 4: Build the bundle and verify**

Run: `make bundle`
Expected: `.build/release/Claudemon.app` is created.

Run: `open .build/release/Claudemon.app`
Expected: the app launches with no dock icon. The menubar dot strip appears.

- [ ] **Step 5: Commit**

```bash
git add Info.plist Makefile .gitignore
git commit -m "feat: app bundle with Info.plist and Makefile"
```

---

### Task 9: Install and end-to-end test

No files to create — this is verification and installation.

- [ ] **Step 1: Install the app**

Run: `make install`
Expected: `Claudemon.app` is copied to `/Applications/`.

- [ ] **Step 2: Launch from Applications**

Run: `open /Applications/Claudemon.app`
Expected: grey dot in menubar (or coloured dots if sessions are active). No dock icon.

- [ ] **Step 3: Verify with active sessions**

With Claude Code sessions running:
1. Confirm dots appear in the menubar, coloured correctly
2. Open the menu — session names, status, and tab numbers display
3. Click a session item — iTerm2 activates and switches to the correct tab
4. Trigger a state change (e.g., approve a permission prompt) — the dot colour updates

- [ ] **Step 4: Verify empty state**

Kill all Claude Code sessions. Confirm the menubar shows a single grey dot. The menu shows only "Quit".

- [ ] **Step 5: Verify the hooks still work**

Start a new Claude Code session. Confirm:
- The grey dot changes to a green dot
- The menu shows the new session
- State transitions (WORKING → IDLE → PERMISSION) update the dot colour
