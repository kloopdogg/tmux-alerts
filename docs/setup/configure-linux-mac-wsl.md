# Configure — macOS / Linux / WSL (non-tmux)

Sends an OS notification via `osascript` (macOS) or `notify-send` (Linux/WSL).

**WSL note:** `notify-send` works if a desktop notification daemon is running. Install `wsl-notify-send` for native Windows toast notifications from WSL.

## Claude

```bash
mkdir -p ~/.claude/hooks
cp hooks/linux-mac-wsl/notify-claude.sh ~/.claude/hooks/notify-claude.sh
chmod +x ~/.claude/hooks/notify-claude.sh
```

Merge the hooks from `hooks/linux-mac-wsl/claude-hooks.json` into `~/.claude/settings.json`. The full block to add:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.sh" }]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.sh" }]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.sh" }]
      }
    ]
  }
}
```

## Copilot

```bash
mkdir -p ~/.copilot/hooks
cp hooks/linux-mac-wsl/notify-copilot.sh ~/.copilot/hooks/notify-copilot.sh
chmod +x ~/.copilot/hooks/notify-copilot.sh
cp hooks/linux-mac-wsl/copilot-hooks.json ~/.copilot/hooks/hooks.json
```

Fires on `agentStop`, `notification`, `permissionRequest`, and `errorOccurred`.

## Test the hook scripts directly

**Claude:**

```bash
echo '{
  "session_id": "hook-test",
  "message": "Fired from the actual hook script",
  "hook_event_name": "Notification",
  "cwd": "/Users/scott/Projects/my-api"
}' | bash hooks/linux-mac-wsl/notify-claude.sh
```

**Copilot:**

```bash
echo '{
  "sessionId": "copilot-abc123",
  "cwd": "/Users/scott/Projects/my-api"
}' | HOOK_EVENT=agentStop bash ~/.copilot/hooks/notify-copilot.sh
```

Expected: OS notification fires, notification appears in the dashboard.
