# claudemon — SwiftUI Menubar App

## Purpose

Replace the `claudemon` CLI with a macOS menubar app that shows at-a-glance status of all active Claude Code sessions and lets the user switch to the relevant iTerm2 tab with a click.

Reuses the existing state model and hooks from the PoC. No changes to `hook.sh` or the state file format.

## Menubar icon

A row of small filled circles (dots), one per active session, coloured by status:

| Colour | Status |
|--------|--------|
| Red | PERMISSION — waiting for tool approval |
| Yellow | IDLE — waiting for user input |
| Green | WORKING — Claude is thinking/acting |

Dots are ordered by iTerm2 tab index. When no sessions are active, show a single grey dot.

The strip should be compact — small circles with minimal spacing so it doesn't eat into menubar real estate.

Rendered as a custom SwiftUI `View` used as the `MenuBarExtra` label.

## Menu content

Opening the menu shows one item per session, in tab order. Each item displays:

- Session name (from Claude's session file, falling back to last path component of `cwd`)
- Status (colour-coded text or indicator)
- Tab number
- Message (permission prompt text for PERMISSION sessions, blank otherwise)

A **Quit** item sits at the bottom of the menu.

Clicking a session item activates the corresponding iTerm2 tab.

## Data model

Two data sources, joined on session ID:

### State file (`~/.claude/claudemon/state.json`)

Written by hooks. Contains per-session:
- `iterm_session_id` — iTerm2 session identifier (`wXtYpZ:GUID`)
- `last_event` — the hook event that last fired
- `last_event_time` — ISO 8601 timestamp
- `message` — notification message (permission prompt text, etc.)

### Session files (`~/.claude/sessions/*.json`)

Written by Claude Code. Contains per-session:
- `sessionId` — matches state file key
- `pid` — process ID for liveness checking
- `name` — user-assigned session name (may be empty)
- `cwd` — working directory

### Merged session model

```swift
struct Session: Identifiable {
    let id: String              // session ID
    let name: String            // from session file, fallback to basename of cwd
    let status: Status          // derived from last_event
    let tabIndex: Int           // parsed from iterm_session_id
    let itermSessionId: String  // raw value for AppleScript
    let message: String         // notification message
    let lastEventTime: Date     // for potential "2m ago" display
}

enum Status {
    case working
    case permission
    case idle
}
```

Status derivation from `last_event`:
- `permission_prompt` → `.permission`
- `idle` → `.idle`
- `session_start`, `user_prompt`, anything else → `.working`

Dead sessions (PID not running) are filtered out of the display and cleaned from `state.json`.

## Architecture

Three components:

### SessionStore

An `ObservableObject` that owns the session data. Responsibilities:

- Watches the `~/.claude/claudemon/` directory for file system changes using `DispatchSource.makeFileSystemObjectSource` with `.write` events
- On change: reads `state.json`, scans `~/.claude/sessions/*.json`, joins on session ID, checks PID liveness, publishes a sorted `[Session]` array
- Cleans dead sessions from `state.json`
- Performs an initial load at app launch

Directory watching (not file watching) is necessary because the hook writes atomically via `mv` from a `.tmp` file, which changes the inode. Watching the directory catches this and also handles the case where `state.json` doesn't exist yet.

### MenuBarLabel

A SwiftUI `View` rendered as the `MenuBarExtra` label:
- Maps the session list to a horizontal row of filled circle SF Symbols
- Colour per dot matches session status
- Single grey dot when the session list is empty
- Compact layout — small symbols, tight spacing

### ITerm2 tab switching

An AppleScript executed via `NSAppleScript` that activates a specific iTerm2 session by GUID:

```applescript
tell application "iTerm2"
    activate
    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                if unique ID of s is "<GUID>" then
                    select t
                    return
                end if
            end repeat
        end repeat
    end repeat
end tell
```

The GUID is extracted from the `iterm_session_id` field (everything after the colon in `wXtYpZ:GUID`).

This requires the macOS Automation permission for iTerm2, which the system will prompt for on first use.

## Tab index parsing

The `ITERM_SESSION_ID` format is `wXtYpZ:GUID` where:
- `w` + digits = window index
- `t` + digits = tab index
- `p` + digits = pane index
- After the colon = session GUID

Tab index is extracted by parsing the `t` component. Used for ordering dots and menu items.

## Project structure

Swift Package Manager executable:

```
claudemon/
├── Package.swift
├── Sources/
│   └── Claudemon/
│       ├── ClaudemonApp.swift      # @main App, MenuBarExtra
│       ├── Session.swift            # Session model and Status enum
│       ├── SessionStore.swift       # Directory watching, data loading
│       ├── MenuBarLabel.swift       # Dot strip view
│       ├── SessionMenuItem.swift    # Individual menu item view
│       └── ITerm.swift              # AppleScript tab switching
├── hook.sh                          # Existing hook (unchanged)
├── claudemon                        # Existing CLI (kept for reference)
└── docs/
```

The app must set `LSUIElement = true` in its `Info.plist` to hide the dock icon. With SPM this requires embedding an `Info.plist` resource. If this proves awkward, fall back to a minimal Xcode project.

## Platform requirements

- macOS 13+ (for `MenuBarExtra`)
- Swift 5.9+
- Automation permission for iTerm2 (prompted by macOS on first use)

## What stays the same

- `hook.sh` — no changes
- `state.json` format — no changes
- Hook configuration in `~/.claude/settings.json` — no changes
- Session file format (owned by Claude Code) — read only

## Constraints

- Target ≤5 concurrent sessions (same as PoC)
- No network access
- No persistent storage beyond what the hooks already write
- macOS only
