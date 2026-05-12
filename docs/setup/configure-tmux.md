# Configure — tmux

Covers any OS running tmux. The hook flashes the active pane red and sends an OS notification.

## Claude

```bash
mkdir -p ~/.claude/hooks
cp hooks/tmux/notify-claude.sh ~/.claude/hooks/notify-claude.sh
chmod +x ~/.claude/hooks/notify-claude.sh
```

Merge the hooks from `hooks/tmux/claude-hooks.json` into `~/.claude/settings.json`. The full block to add:

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
cp hooks/tmux/notify-copilot.sh ~/.copilot/hooks/notify-copilot.sh
chmod +x ~/.copilot/hooks/notify-copilot.sh
cp hooks/tmux/copilot-hooks.json ~/.copilot/hooks/hooks.json
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
}' | bash hooks/tmux/notify-claude.sh
```

**Copilot:**

```bash
echo '{
  "sessionId": "copilot-abc123",
  "cwd": "/Users/scott/Projects/my-api"
}' | HOOK_EVENT=agentStop bash ~/.copilot/hooks/notify-copilot.sh
```

Expected: OS notification fires, notification appears in the dashboard.

## Useful tmux keystrokes

| Keys | Action |
|---|---|
| `tmux new -s work` | New named session |
| `Ctrl+b %` | Split pane vertically |
| `Ctrl+b "` | Split pane horizontally |
| `Ctrl+b →` `←` `↑` `↓` | Move between panes |
| `Ctrl+b z` | Zoom current pane (toggle fullscreen) |
| `Ctrl+b d` | Detach session |
