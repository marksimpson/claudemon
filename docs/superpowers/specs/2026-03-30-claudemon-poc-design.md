# claudemon PoC — Session Monitor for Claude Code

## Purpose

Monitor all active Claude Code sessions and show which ones are waiting for user input (permission prompts or idle), including which iTerm2 tab they're in.

This is the PoC phase. Phase 2 will be a SwiftUI menubar app reusing the same state model.

## State model

Each Claude session has one of four states:

| State | Meaning | Trigger |
|-------|---------|---------|
| WORKING | Claude is thinking/acting | `SessionStart` or `UserPromptSubmit` hook |
| PERMISSION | Waiting for tool approval | `Notification` hook with `permission_prompt` |
| IDLE | Waiting for user input | `Stop` hook |
| DEAD | Session PID no longer running | PID check at display time |

State transitions:

```
SessionStart → WORKING
UserPromptSubmit → WORKING
Stop → IDLE
Notification(permission_prompt) → PERMISSION
PID dead → DEAD (entry removed from state file)
```

Note: the `idle_prompt` notification type was originally planned for IDLE detection but doesn't fire reliably. The `Stop` hook fires when Claude finishes a turn, which is the correct signal.

## Data storage

Single file: `~/.claude/claudemon/state.json`

```json
{
  "sessions": {
    "<session-id>": {
      "iterm_session_id": "w4t7p0:6390C52A-B81C-4048-9302-3CCB94C34612",
      "last_event": "idle_prompt",
      "last_event_time": "2026-03-30T01:23:45Z",
      "message": "Waiting for input"
    }
  }
}
```

Session metadata (name, cwd, pid) comes from Claude's own session files at `~/.claude/sessions/{pid}.json`, not duplicated in our state file. This means names stay up-to-date if the user renames a session mid-conversation.

## Hooks

Four hooks, all handled by a single script (`~/.claude/claudemon/hook.sh`):

### SessionStart

- Reads `session_id` from stdin JSON
- Reads `ITERM_SESSION_ID` from environment
- Writes `iterm_session_id` and `last_event="session_start"` into state.json for this session

### Notification (matcher: `permission_prompt`)

- Reads `session_id`, `notification_type`, `message` from stdin JSON
- Writes `last_event`, `last_event_time`, `message` into state.json

### UserPromptSubmit

- Reads `session_id` from stdin JSON
- Sets `last_event="user_prompt"`, clearing the waiting state

### Stop

- Reads `session_id` from stdin JSON
- Sets `last_event="idle"` — Claude finished its turn and is waiting for the user

### Hook input format

All hooks receive JSON on stdin with at least:

```json
{
  "session_id": "718bc7c3-...",
  "hook_event_name": "SessionStart|Notification|UserPromptSubmit|Stop",
  "cwd": "/path/to/project"
}
```

Notification events additionally include:

```json
{
  "notification_type": "permission_prompt",
  "message": "human-readable description"
}
```

### Hook script design

One script handles all events, branching on `hook_event_name`:

1. Read JSON from stdin
2. Extract `session_id` and `hook_event_name`
3. Read existing state.json (or create empty)
4. Update the session entry based on event type
5. Write state.json back

Race condition: concurrent hook invocations from different sessions could clobber state.json. Acceptable risk for PoC with ≤5 sessions; phase 2 can use proper locking or a different storage mechanism.

Dependencies: `jq` (already installed on Mark's system).

## CLI

A shell script (`claudemon`) that:

1. Reads `~/.claude/claudemon/state.json` for event state
2. Reads `~/.claude/sessions/*.json` for session metadata (pid, name, cwd)
3. Joins on session ID
4. Checks PID liveness via `ps`; removes dead sessions from state file
5. Prints a formatted table

### Output format

```
SESSION                      STATUS      TAB   MESSAGE
00121-sell-transactions       PERMISSION  3    Allow Bash: npm test?
00146-price-history-viewer    IDLE        5    Waiting for input
00134-dolt-migration          WORKING     2
claudemon                     IDLE        7    Waiting for input
```

- **SESSION**: session name if set, otherwise last path component of cwd
- **STATUS**: colour-coded (red=PERMISSION, yellow=IDLE, green=WORKING)
- **TAB**: iTerm2 tab number extracted from `ITERM_SESSION_ID` (the `t` component of `wXtYpZ`)
- **MESSAGE**: notification message for waiting sessions, blank otherwise

If no active sessions, prints "No active sessions."

Dead sessions are silently cleaned from state.json rather than displayed.

## Hook configuration

Added to `~/.claude/settings.json` under the `hooks` key:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/claudemon/hook.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/claudemon/hook.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/claudemon/hook.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/claudemon/hook.sh"
          }
        ]
      }
    ]
  }
}
```

## File layout

```
~/.claude/claudemon/
├── hook.sh          # Single hook script for all events
└── state.json       # Session state (created automatically)

~/.local/bin/claudemon     # CLI script (symlink to repo)
```

## Constraints

- Shell script (bash) for speed to PoC
- ≤5 concurrent sessions — no performance concerns
- Dependencies: jq, ps, standard POSIX utilities
- macOS only (iTerm2 integration)
- Phase 2 (SwiftUI menubar app) will replace the CLI but reuse the state model and hooks
