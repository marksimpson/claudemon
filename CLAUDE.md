# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Claudemon is a macOS menubar app that monitors Claude Code sessions. It shows a row of coloured dots (one per session) and lets the user click to switch iTerm2 tabs. It works via Claude Code hooks that write session state to a shared JSON file.

## Build and test

```bash
swift build              # debug build
swift build -c release   # release build
swift test               # run all tests
make bundle              # release build + .app bundle with codesign
make install             # copy .app to /Applications
```

Run a single test:
```bash
swift test --filter ClaudemonKitTests.SessionStatusTests/permissionPromptMapsToPermission
```

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.

## Architecture

Two data flows meet in the app:

**Hook → state file:** `hook.sh` is called by Claude Code hooks (configured in `~/.claude/settings.json`). It reads JSON from stdin, acquires a file lock (`mkdir`-based), updates `~/.claude/claudemon/state.json`, and releases the lock. Hooks: `SessionStart`, `SessionEnd`, `Notification(permission_prompt)`, `UserPromptSubmit`, `Stop`, `PostToolUse`.

**State file → app:** `SessionStore` watches the `~/.claude/claudemon/` directory via `DispatchSource` and also polls every 5 seconds (to catch dead PIDs). On change, `SessionLoader` reads `state.json`, joins it with Claude's own session files (`~/.claude/sessions/*.json`) on session ID, checks PID liveness, cleans dead entries, and returns sorted sessions.

### SPM targets

- **ClaudemonKit** (library) — all logic: `Session`, `SessionStatus`, `SessionLoader`, `SessionStore`, `ITerm`, `DotStrip`, `SessionMenuBuilder`. Testable.
- **Claudemon** (executable) — thin `@main` entry point with `AppDelegate` managing `NSStatusItem`. Not directly testable.

### State model

| Status | Event | Colour |
|--------|-------|--------|
| WORKING | `user_prompt`, `tool_use` | Green |
| PERMISSION | `permission_prompt` | Red |
| IDLE | `idle`, `session_start` | Yellow |

`SessionLoader` has a 10-second grace period before cleaning sessions — prevents a race condition during `/resume` where `SessionStart` fires before Claude updates its session file.

### Key design decisions

- **NSStatusItem, not MenuBarExtra** — `MenuBarExtra` doesn't support click interception or dynamic label updates reliably. Left click cycles through sessions by urgency; right click/Option-click shows the menu.
- **Directory watching, not file watching** — the hook writes atomically via `mv`, which changes the inode. Watching the directory catches this.
- **File locking in hook.sh** — `mkdir`-based lock prevents concurrent hooks (especially `Notification` + `PostToolUse`) from clobbering each other's writes.
- **`PostToolUse` clears PERMISSION state** — without this, PERMISSION stays red for the entire turn after approval, which is especially bad with subagents.

## Installation

The hook script is symlinked from `~/.claude/claudemon/hook.sh` to the repo's `hook.sh`. Hooks are configured in `~/.claude/settings.json` (not in this repo). After changing `hook.sh`, copy it to the installed location:

```bash
cp hook.sh ~/.claude/claudemon/hook.sh
```

The legacy `claudemon` shell script (CLI) is still in the repo but superseded by the menubar app.
