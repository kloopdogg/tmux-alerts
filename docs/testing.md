# Testing

## Phase 1 — Start the server

```bash
cd src/TmuxAlerts
dotnet run
```

Open **http://localhost:7777**. Confirm the dashboard shows "Waiting for Claude sessions..." and a green **● live** indicator in the header.

---

## Phase 2 — Smoke test with curl (no tmux needed)

```bash
curl -s -X POST http://localhost:7777/notify \
  -H "Content-Type: application/json" \
  -d '{"sessionId":"abc123","message":"Which S3 bucket should I write to?","hookType":"Notification","project":"data-pipeline","tmuxTarget":"","agent":"claude","client":"terminal"}'
```

Expected: chime plays, session pill appears with agent and client icons, notification appears. Hover the pill to reveal the **✕** remove button. Click **Dismiss** to clear the notification.

---

## Phase 3 — Test tmux pane flash (requires tmux)

```bash
tmux new-session -s work
tmux list-panes -a -F '#{pane_id}  #{session_name}:#{window_index}.#{pane_index}'
```

Output will look like:
```
%0  work:0.0
%1  work:0.1
%2  work:0.2
```

Fire a notification targeting a real pane ID:

```bash
curl -s -X POST http://localhost:7777/notify \
  -H "Content-Type: application/json" \
  -d '{"sessionId":"abc123","message":"Need your input!","hookType":"Stop","project":"my-api","tmuxTarget":"%2","agent":"claude","client":"tmux"}'
```

Expected: pane `%2` flashes red, notification appears in the dashboard labelled **TMUX %2**.

---

## Phase 4 — Test the hook script directly

### tmux

```bash
echo '{
  "session_id": "hook-test",
  "message": "Fired from the actual hook script",
  "hook_event_name": "Notification",
  "cwd": "/Users/scott/Projects/my-api"
}' | bash hooks/tmux/notify-claude.sh
```

### macOS / Linux / WSL (non-tmux)

```bash
echo '{
  "session_id": "hook-test",
  "message": "Fired from the actual hook script",
  "hook_event_name": "Notification",
  "cwd": "/Users/scott/Projects/my-api"
}' | bash hooks/linux-mac-wsl/notify-claude.sh
```

Expected: OS notification fires, notification appears in the dashboard.

---

## Phase 5 — Wire up real Claude Code hooks

Pick the subfolder that matches your environment:

```bash
mkdir -p ~/.claude/hooks

# tmux
cp hooks/tmux/notify-claude.sh ~/.claude/hooks/notify-claude.sh
chmod +x ~/.claude/hooks/notify-claude.sh

# macOS / Linux / WSL
cp hooks/linux-mac-wsl/notify-claude.sh ~/.claude/hooks/notify-claude.sh
chmod +x ~/.claude/hooks/notify-claude.sh
```

Add to `~/.claude/settings.json` (merge with existing content):

```json
{
  "hooks": {
    "PermissionRequest": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.sh" }] }
    ],
    "Notification": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.sh" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.sh" }] }
    ]
  }
}
```

Start Claude in your terminal. Any time it stops or sends a notification, the dashboard fires.

---

## Phase 6 — Wire up Copilot CLI hooks

```bash
mkdir -p ~/.copilot/hooks

# tmux
cp hooks/tmux/notify-copilot.sh ~/.copilot/hooks/notify-copilot.sh
chmod +x ~/.copilot/hooks/notify-copilot.sh

# macOS / Linux / WSL
cp hooks/linux-mac-wsl/notify-copilot.sh ~/.copilot/hooks/notify-copilot.sh
chmod +x ~/.copilot/hooks/notify-copilot.sh
```

Copy a `hooks.json` to your home directory:

```bash
cp .github/hooks/hooks.json ~/.copilot/hooks/hooks.json
```

Test the Copilot hook script directly:

```bash
echo '{
  "sessionId": "copilot-abc123",
  "cwd": "/Users/scott/Projects/my-api"
}' | HOOK_EVENT=agentStop bash ~/.copilot/hooks/notify-copilot.sh
```

Expected: notification appears in the dashboard with message "Copilot finished".

---

## Useful tmux keystrokes

| Keys | Action |
|---|---|
| `tmux new -s work` | New named session |
| `Ctrl+b %` | Split pane vertically |
| `Ctrl+b "` | Split pane horizontally |
| `Ctrl+b →` `←` `↑` `↓` | Move between panes |
| `Ctrl+b z` | Zoom current pane (toggle fullscreen) |
| `Ctrl+b d` | Detach session |
