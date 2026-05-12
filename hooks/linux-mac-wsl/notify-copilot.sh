#!/bin/bash
# GitHub Copilot CLI hook — fires on agentStop, notification, permissionRequest, and errorOccurred.
# Install to ~/.copilot/hooks/ on macOS, Linux, or WSL (non-tmux terminals).
# Reads JSON from stdin, sends an OS notification, posts to the tmux-alerts server.
# HOOK_EVENT is injected by hooks.json via the env field.

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId // .session_id // ""')
SESSION_ID=${SESSION_ID:-unknown}
CWD=$(echo "$INPUT"        | jq -r '.cwd                      // ""')
PROJECT=$(basename "$CWD")
PROJECT=${PROJECT:-unknown}
HOOK_TYPE=${HOOK_EVENT:-unknown}

case "$HOOK_TYPE" in
    agentStop)         MESSAGE="Copilot finished" ;;
    notification)      MESSAGE=$(echo "$INPUT" | jq -r '.message // "Copilot notification"') ;;
    permissionRequest) MESSAGE="Permission requested: $(echo "$INPUT" | jq -r '.toolName // "unknown tool"')" ;;
    errorOccurred)     MESSAGE="Copilot error: $(echo "$INPUT" | jq -r '.error // "unknown error"')" ;;
    *)                 MESSAGE="Copilot hook fired" ;;
esac

# Detect client environment.
# TERM_PROGRAM=vscode is set in the integrated terminal; VSCODE_* vars are set
# in VS Code's process environment and inherited by Copilot hook subprocesses.
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
  -d "{\"sessionId\":\"$SESSION_ID\",\"message\":\"$MESSAGE\",\"hookType\":\"$HOOK_TYPE\",\"project\":\"$PROJECT\",\"tmuxTarget\":\"\",\"agent\":\"copilot\",\"client\":\"$CLIENT\"}" \
  > /dev/null || true
