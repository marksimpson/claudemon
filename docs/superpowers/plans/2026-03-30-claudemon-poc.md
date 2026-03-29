# claudemon PoC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a CLI tool that shows which Claude Code sessions are waiting for user input, including their iTerm2 tab.

**Architecture:** Hooks log session state transitions to a shared JSON file. A CLI script reads that file, joins it with Claude's session metadata, checks PID liveness, and prints a colour-coded table.

**Tech Stack:** Bash, jq

**Spec:** `docs/superpowers/specs/2026-03-30-claudemon-poc-design.md`

---

### Task 1: Initialise the repository

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Initialise git**

```bash
cd /Users/mark/claudemon
git init
```

- [ ] **Step 2: Create .gitignore**

```gitignore
state.json
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore docs/
git commit -m "feat: initial commit with spec and plan"
```

---

### Task 2: Write the hook script

**Files:**
- Create: `hook.sh`

The hook handles three events: `SessionStart`, `Notification`, and `UserPromptSubmit`. It reads JSON from stdin, branches on `hook_event_name`, and updates `~/.claude/claudemon/state.json`.

- [ ] **Step 1: Create hook.sh**

```bash
#!/usr/bin/env bash
# claudemon hook — tracks Claude Code session state for the session monitor.
# Handles: SessionStart, Notification, UserPromptSubmit
# Requires: jq

set -euo pipefail

STATE_DIR="$HOME/.claude/claudemon"
STATE_FILE="$STATE_DIR/state.json"

mkdir -p "$STATE_DIR"

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')

if [ -z "$SESSION_ID" ] || [ -z "$EVENT" ]; then
  exit 0
fi

# Read existing state or start fresh
if [ -f "$STATE_FILE" ]; then
  STATE=$(cat "$STATE_FILE")
else
  STATE='{"sessions":{}}'
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

case "$EVENT" in
  SessionStart)
    ITERM_ID="${ITERM_SESSION_ID:-}"
    STATE=$(echo "$STATE" | jq \
      --arg sid "$SESSION_ID" \
      --arg iterm "$ITERM_ID" \
      --arg ts "$NOW" \
      '.sessions[$sid] = (.sessions[$sid] // {}) + {
        iterm_session_id: $iterm,
        last_event: "session_start",
        last_event_time: $ts,
        message: ""
      }')
    ;;

  Notification)
    NTYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')
    MSG=$(echo "$INPUT" | jq -r '.message // empty')
    STATE=$(echo "$STATE" | jq \
      --arg sid "$SESSION_ID" \
      --arg ntype "$NTYPE" \
      --arg msg "$MSG" \
      --arg ts "$NOW" \
      '.sessions[$sid] = (.sessions[$sid] // {}) + {
        last_event: $ntype,
        last_event_time: $ts,
        message: $msg
      }')
    ;;

  UserPromptSubmit)
    STATE=$(echo "$STATE" | jq \
      --arg sid "$SESSION_ID" \
      --arg ts "$NOW" \
      '.sessions[$sid] = (.sessions[$sid] // {}) + {
        last_event: "user_prompt",
        last_event_time: $ts,
        message: ""
      }')
    ;;

  *)
    exit 0
    ;;
esac

echo "$STATE" | jq . > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

exit 0
```

Note: the atomic write (write to `.tmp` then `mv`) reduces the chance of a concurrent read seeing a partial file.

- [ ] **Step 2: Make it executable**

```bash
chmod +x hook.sh
```

- [ ] **Step 3: Test SessionStart locally**

Pipe a fake SessionStart event into the hook and check the output:

```bash
echo '{"session_id":"test-001","hook_event_name":"SessionStart","cwd":"/tmp"}' | ITERM_SESSION_ID="w1t2p0:FAKE-UUID" ./hook.sh
cat ~/.claude/claudemon/state.json
```

Expected: state.json contains `test-001` with `last_event: "session_start"` and `iterm_session_id: "w1t2p0:FAKE-UUID"`.

- [ ] **Step 4: Test Notification locally**

```bash
echo '{"session_id":"test-001","hook_event_name":"Notification","notification_type":"idle_prompt","message":"Waiting for input","cwd":"/tmp"}' | ./hook.sh
cat ~/.claude/claudemon/state.json
```

Expected: `test-001` now has `last_event: "idle_prompt"` and `message: "Waiting for input"`. The `iterm_session_id` from the previous step is preserved.

- [ ] **Step 5: Test UserPromptSubmit locally**

```bash
echo '{"session_id":"test-001","hook_event_name":"UserPromptSubmit","prompt":"hello","cwd":"/tmp"}' | ./hook.sh
cat ~/.claude/claudemon/state.json
```

Expected: `test-001` now has `last_event: "user_prompt"` and `message: ""`.

- [ ] **Step 6: Clean up test data**

```bash
rm ~/.claude/claudemon/state.json
```

- [ ] **Step 7: Commit**

```bash
git add hook.sh
git commit -m "feat: hook script for tracking session state"
```

---

### Task 3: Write the CLI script

**Files:**
- Create: `claudemon`

The CLI reads state.json and Claude's session files, joins them, checks PID liveness, cleans up dead sessions, and prints a formatted table.

- [ ] **Step 1: Create the claudemon script**

```bash
#!/usr/bin/env bash
# claudemon — show active Claude Code sessions and their status.
# Requires: jq

set -euo pipefail

STATE_FILE="$HOME/.claude/claudemon/state.json"
SESSIONS_DIR="$HOME/.claude/sessions"

# Colour codes
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RESET='\033[0m'

# Load state file
if [ ! -f "$STATE_FILE" ]; then
  echo "No active sessions."
  exit 0
fi

STATE=$(cat "$STATE_FILE")

# Build a map of session_id -> session metadata from Claude's session files
# Each file is {pid}.json containing {pid, sessionId, cwd, name?, ...}
declare -A SESSION_PID
declare -A SESSION_NAME
declare -A SESSION_CWD

for f in "$SESSIONS_DIR"/*.json; do
  [ -f "$f" ] || continue
  SID=$(jq -r '.sessionId // empty' "$f")
  [ -z "$SID" ] && continue
  SESSION_PID[$SID]=$(jq -r '.pid' "$f")
  SESSION_NAME[$SID]=$(jq -r '.name // empty' "$f")
  SESSION_CWD[$SID]=$(jq -r '.cwd // empty' "$f")
done

# Collect rows and track dead sessions
ROWS=()
DEAD_SIDS=()

for SID in $(echo "$STATE" | jq -r '.sessions | keys[]'); do
  PID="${SESSION_PID[$SID]:-}"

  # No session file or PID not running → dead
  if [ -z "$PID" ] || ! ps -p "$PID" > /dev/null 2>&1; then
    DEAD_SIDS+=("$SID")
    continue
  fi

  # Session name: use name field if set, otherwise last component of cwd
  NAME="${SESSION_NAME[$SID]:-}"
  if [ -z "$NAME" ]; then
    CWD="${SESSION_CWD[$SID]:-}"
    NAME="${CWD##*/}"
  fi
  [ -z "$NAME" ] && NAME="unknown"

  LAST_EVENT=$(echo "$STATE" | jq -r ".sessions[\"$SID\"].last_event // empty")
  MESSAGE=$(echo "$STATE" | jq -r ".sessions[\"$SID\"].message // empty")

  # Extract iTerm tab number from iterm_session_id (wXtYpZ format)
  ITERM_ID=$(echo "$STATE" | jq -r ".sessions[\"$SID\"].iterm_session_id // empty")
  TAB=""
  if [ -n "$ITERM_ID" ]; then
    TAB=$(echo "$ITERM_ID" | sed -n 's/^w[0-9]*t\([0-9]*\)p.*/\1/p')
  fi

  case "$LAST_EVENT" in
    permission_prompt)
      STATUS="${RED}PERMISSION${RESET}"
      STATUS_PLAIN="PERMISSION"
      ;;
    idle_prompt)
      STATUS="${YELLOW}IDLE${RESET}"
      STATUS_PLAIN="IDLE"
      ;;
    *)
      STATUS="${GREEN}WORKING${RESET}"
      STATUS_PLAIN="WORKING"
      ;;
  esac

  # Sort key: PERMISSION first, then IDLE, then WORKING
  case "$STATUS_PLAIN" in
    PERMISSION) SORT_KEY="0" ;;
    IDLE)       SORT_KEY="1" ;;
    *)          SORT_KEY="2" ;;
  esac

  ROWS+=("${SORT_KEY}|${NAME}|${STATUS}|${STATUS_PLAIN}|${TAB}|${MESSAGE}")
done

# Clean up dead sessions from state file
if [ ${#DEAD_SIDS[@]} -gt 0 ]; then
  for SID in "${DEAD_SIDS[@]}"; do
    STATE=$(echo "$STATE" | jq --arg sid "$SID" 'del(.sessions[$sid])')
  done
  echo "$STATE" | jq . > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

if [ ${#ROWS[@]} -eq 0 ]; then
  echo "No active sessions."
  exit 0
fi

# Sort rows (PERMISSION first, then IDLE, then WORKING)
IFS=$'\n' SORTED=($(printf '%s\n' "${ROWS[@]}" | sort)); unset IFS

# Print header
printf "%-30s  %-12s  %-4s  %s\n" "SESSION" "STATUS" "TAB" "MESSAGE"

for ROW in "${SORTED[@]}"; do
  IFS='|' read -r _SORT NAME STATUS STATUS_PLAIN TAB MESSAGE <<< "$ROW"
  printf "%-30s  %-12b  %-4s  %s\n" "$NAME" "$STATUS" "$TAB" "$MESSAGE"
done
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x claudemon
```

- [ ] **Step 3: Test with synthetic data**

Create a fake state.json and session file to verify output formatting:

```bash
# Create a fake session file
mkdir -p ~/.claude/sessions
echo '{"pid":'"$$"',"sessionId":"test-cli-001","cwd":"/Users/mark/claudemon","name":"test-session","startedAt":1774745852727,"kind":"interactive","entrypoint":"cli"}' > ~/.claude/sessions/$$.json

# Create matching state
mkdir -p ~/.claude/claudemon
cat > ~/.claude/claudemon/state.json << 'STATEEOF'
{
  "sessions": {
    "test-cli-001": {
      "iterm_session_id": "w1t3p0:FAKE-UUID",
      "last_event": "idle_prompt",
      "last_event_time": "2026-03-30T01:00:00Z",
      "message": "Waiting for input"
    }
  }
}
STATEEOF

./claudemon
```

Expected output:
```
SESSION                         STATUS        TAB   MESSAGE
test-session                    IDLE          3     Waiting for input
```

- [ ] **Step 4: Clean up test data**

```bash
rm ~/.claude/sessions/$$.json
rm ~/.claude/claudemon/state.json
```

- [ ] **Step 5: Commit**

```bash
git add claudemon
git commit -m "feat: CLI script for displaying session status"
```

---

### Task 4: Configure hooks in settings.json

**Files:**
- Modify: `~/.claude/settings.json`

- [ ] **Step 1: Read the current settings.json**

Read `/Users/mark/.claude/settings.json` and verify it has no existing `hooks` key.

- [ ] **Step 2: Add hooks configuration**

Add the following `hooks` key to the top-level object in `~/.claude/settings.json`:

```json
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
      "matcher": "idle_prompt|permission_prompt",
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
  ]
}
```

---

### Task 5: Install and end-to-end test

**Files:**
- Symlink: `~/.local/bin/claudemon` → `/Users/mark/claudemon/claudemon`
- Symlink: `~/.claude/claudemon/hook.sh` → `/Users/mark/claudemon/hook.sh`

- [ ] **Step 1: Create symlinks**

The hook config points at `~/.claude/claudemon/hook.sh`, so symlink from there to the repo. Similarly, symlink the CLI into PATH.

```bash
ln -sf /Users/mark/claudemon/hook.sh ~/.claude/claudemon/hook.sh
ln -sf /Users/mark/claudemon/claudemon ~/.local/bin/claudemon
```

- [ ] **Step 2: Verify hook fires on this session**

The hooks are now configured. The `SessionStart` hook won't fire for this session (already started), but the `Notification` and `UserPromptSubmit` hooks will fire going forward. To verify:

1. Type a message in this Claude session — `UserPromptSubmit` should fire
2. Check `~/.claude/claudemon/state.json` for an entry with this session's ID
3. When Claude finishes responding, `Notification(idle_prompt)` should fire
4. Check state.json again — should now show `idle_prompt`

- [ ] **Step 3: Run claudemon**

```bash
claudemon
```

Expected: at least this session appears in the output.

- [ ] **Step 4: Test with a second session**

Open a new iTerm tab, start `claude`, then run `claudemon` from a third tab. Both sessions should appear.

- [ ] **Step 5: Verify end-to-end test passes, then done**

No commit needed for this task — it's installation and manual verification only.
