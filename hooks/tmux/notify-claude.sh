#!/bin/bash
# Claude Code hook — fires on Stop and Notification events.
# Install to ~/.claude/hooks/ when running inside tmux.
# Reads JSON from stdin, flashes the tmux pane, posts to the tmux-alerts server.

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

# Find the tmux pane whose current directory matches the project cwd.
# This works even when Claude runs via VS Code (where $TMUX_PANE is unreliable).
if [ "$TERM_PROGRAM" = "vscode" ] || [ -n "${VSCODE_GIT_ASKPASS_NODE:-}" ] || [ -n "${VSCODE_PID:-}" ]; then
    CLIENT="vscode"
    TMUX_TARGET=""
else
    TMUX_TARGET=$(tmux list-panes -a -F '#{pane_id} #{pane_current_path}' 2>/dev/null | \
        awk -v cwd="$CWD" '$2 == cwd {print $1; exit}')
    TMUX_TARGET="${TMUX_TARGET:-${TMUX_PANE:-}}"

    if [ -n "$TMUX_TARGET" ]; then
        CLIENT="tmux"
        for i in 1 2 3; do
            tmux select-pane -t "$TMUX_TARGET" -P 'bg=red'
            sleep 0.15
            tmux select-pane -t "$TMUX_TARGET" -P 'bg=default'
            sleep 0.15
        done
    elif [ -n "${TMUX:-}" ]; then
        CLIENT="tmux"
    elif [ -z "${TERM:-}" ] && [ -z "${TERM_PROGRAM:-}" ]; then
        CLIENT="claude-desktop"
    else
        CLIENT="terminal"
    fi
fi

curl -s --max-time 2 -X POST http://localhost:7777/notify \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_ID\",\"message\":\"$MESSAGE\",\"hookType\":\"$HOOK_TYPE\",\"project\":\"$PROJECT\",\"tmuxTarget\":\"$TMUX_TARGET\",\"agent\":\"claude\",\"client\":\"$CLIENT\"}" \
  > /dev/null || true
