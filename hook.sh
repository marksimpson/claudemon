#!/usr/bin/env bash
# claudemon hook — tracks Claude Code session state for the session monitor.
# Handles: SessionStart, SessionEnd, Notification, UserPromptSubmit, Stop
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

  Stop)
    STATE=$(echo "$STATE" | jq \
      --arg sid "$SESSION_ID" \
      --arg ts "$NOW" \
      '.sessions[$sid] = (.sessions[$sid] // {}) + {
        last_event: "idle",
        last_event_time: $ts,
        message: ""
      }')
    ;;

  SessionEnd)
    STATE=$(echo "$STATE" | jq \
      --arg sid "$SESSION_ID" \
      'del(.sessions[$sid])')
    ;;

  *)
    exit 0
    ;;
esac

echo "$STATE" | jq . > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

exit 0
