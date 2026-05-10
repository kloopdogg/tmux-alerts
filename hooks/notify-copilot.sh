#!/bin/bash
# GitHub Copilot CLI hook — fires on agentStop, notification, permissionRequest, and errorOccurred.
# Install to ~/.copilot/hooks/notify-copilot.sh
# Reads JSON from stdin, posts to the tmux-alerts server.
# HOOK_EVENT is injected by hooks.json via the env field.

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT=$(basename "$CWD" 2>/dev/null)
PROJECT=${PROJECT:-unknown}
HOOK_TYPE=${HOOK_EVENT:-unknown}

case "$HOOK_TYPE" in
    agentStop)         MESSAGE="Copilot finished" ;;
    notification)      MESSAGE=$(echo "$INPUT" | jq -r '.message // "Copilot notification"') ;;
    permissionRequest) MESSAGE="Permission requested: $(echo "$INPUT" | jq -r '.toolName // "unknown tool"')" ;;
    errorOccurred)     MESSAGE="Copilot error: $(echo "$INPUT" | jq -r '.error // "unknown error"')" ;;
    *)                 MESSAGE="Copilot hook fired" ;;
esac

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
