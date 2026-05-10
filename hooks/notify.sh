#!/bin/bash
# Claude Code hook — fires on Stop and Notification events.
# Reads JSON from stdin, posts to the tmux-alerts server.

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id     // "unknown"')
MESSAGE=$(echo "$INPUT"    | jq -r '.message         // "Claude stopped"')
HOOK_TYPE=$(echo "$INPUT"  | jq -r '.hook_event_name // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT=$(basename "$CWD" 2>/dev/null)
PROJECT=${PROJECT:-unknown}

# Find the tmux pane whose current directory matches the project cwd.
# This works even when Claude runs via VS Code (where $TMUX_PANE is unreliable).
TMUX_TARGET=$(tmux list-panes -a -F '#{pane_id} #{pane_current_path}' 2>/dev/null | \
    awk -v cwd="$CWD" '$2 == cwd {print $1; exit}')
TMUX_TARGET="${TMUX_TARGET:-${TMUX_PANE:-}}"

if [ -n "$TMUX_TARGET" ]; then
    for i in 1 2 3; do
        tmux select-pane -t "$TMUX_TARGET" -P 'bg=red'
        sleep 0.15
        tmux select-pane -t "$TMUX_TARGET" -P 'bg=default'
        sleep 0.15
    done
fi

curl -s --max-time 2 -X POST http://localhost:7777/notify \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_ID\",\"message\":\"$MESSAGE\",\"hookType\":\"$HOOK_TYPE\",\"project\":\"$PROJECT\",\"tmuxTarget\":\"$TMUX_TARGET\"}" \
  > /dev/null || true
