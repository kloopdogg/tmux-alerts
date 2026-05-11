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
  -d '{"sessionId":"abc123","message":"Which S3 bucket should I write to?","hookType":"Notification","project":"data-pipeline","tmuxTarget":""}'
```

Expected: chime plays, session card appears, notification appears. Click **Dismiss** to clear it.

---

## Phase 3 — Test the Jump (requires tmux)

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
  -d '{"sessionId":"abc123","message":"Need your input!","hookType":"Stop","project":"my-api","tmuxTarget":"%2"}'
```

Click **Jump** in the dashboard — terminal should switch to pane `%2`.

---

## Phase 4 — Test the hook script directly

```bash
echo '{
  "session_id": "hook-test",
  "message": "Fired from the actual hook script",
  "hook_event_name": "Notification",
  "cwd": "/Users/scott/Projects/my-api"
}' | bash hooks/notify-claude.sh
```

Expected: notification appears in the dashboard.

---

## Phase 5 — Wire up real Claude Code hooks

```bash
mkdir -p ~/.claude/hooks
cp hooks/notify-claude.sh ~/.claude/hooks/notify-claude.sh
cp hooks/notify-copilot.sh ~/.copilot/hooks/notify-copilot.sh
chmod +x ~/.claude/hooks/notify-claude.sh ~/.copilot/hooks/notify-copilot.sh
```

Add to `~/.claude/settings.json` (merge with existing content):

```json
{
  "hooks": {
    "Notification": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.sh" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.sh" }] }
    ]
  }
}
```

Start Claude in a tmux pane. Any time it stops or sends a notification, the dashboard fires.

---

## Phase 6 — Wire up Copilot CLI hooks

Copy `hooks.json` to your home directory (user-level hooks) or to any project root:

```bash
cp .github/hooks/hooks.json ~/.copilot/hooks/hooks.json
```

Test the Copilot hook script directly by piping the JSON format Copilot sends:

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
