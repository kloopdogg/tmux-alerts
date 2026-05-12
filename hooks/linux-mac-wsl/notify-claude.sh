#!/bin/bash
# Claude Code hook — fires on Stop and Notification events.
# Install to ~/.claude/hooks/ on macOS, Linux, or WSL (non-tmux terminals).
# Reads JSON from stdin, sends an OS notification, posts to the tmux-alerts server.

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id      // ""')
SESSION_ID=${SESSION_ID:-unknown}
MESSAGE=$(echo "$INPUT"    | jq -r '.message         // ""')
MESSAGE=${MESSAGE:-"Claude stopped"}
HOOK_TYPE=$(echo "$INPUT"  | jq -r '.hook_event_name // ""')
HOOK_TYPE=${HOOK_TYPE:-unknown}
CWD=$(echo "$INPUT"        | jq -r '.cwd             // ""')
PROJECT=$(basename "$CWD")
PROJECT=${PROJECT:-unknown}

# Detect client environment.
# TERM_PROGRAM=vscode is set in the integrated terminal; VSCODE_* vars are set
# in VS Code's process environment and inherited by hook subprocesses.
# Claude Desktop launches hooks without a terminal, so TERM and TERM_PROGRAM are unset.
if [ "$TERM_PROGRAM" = "vscode" ] || [ -n "${VSCODE_GIT_ASKPASS_NODE:-}" ] || [ -n "${VSCODE_PID:-}" ]; then
    CLIENT="vscode"
elif [ -z "${TERM:-}" ] && [ -z "${TERM_PROGRAM:-}" ]; then
    CLIENT="claude-desktop"
else
    CLIENT="terminal"
fi

# OS notification (best-effort).
case "$(uname -s)" in
    Darwin)
        osascript -e "display notification \"$MESSAGE\" with title \"tmux-alerts\" subtitle \"$PROJECT\"" 2>/dev/null || true
        ;;
    Linux)
        notify-send -a "tmux-alerts" "$PROJECT" "$MESSAGE" 2>/dev/null || true
        ;;
esac

curl -s --max-time 2 -X POST http://localhost:7777/notify \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_ID\",\"message\":\"$MESSAGE\",\"hookType\":\"$HOOK_TYPE\",\"project\":\"$PROJECT\",\"tmuxTarget\":\"\",\"agent\":\"claude\",\"client\":\"$CLIENT\"}" \
  > /dev/null || true
