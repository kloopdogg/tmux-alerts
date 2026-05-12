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

## Phase 4 — Install hooks and wire up a real session

See the guide for your environment:

| Environment | Guide |
|---|---|
| tmux (any OS) | [docs/setup/configure-tmux.md](configure-tmux.md) |
| macOS / Linux / WSL (non-tmux) | [docs/setup/configure-linux-mac-wsl.md](configure-linux-mac-wsl.md) |
| Windows native PowerShell | [docs/setup/configure-windows.md](configure-windows.md) |

Each guide includes copy commands for both Claude and Copilot, the hook config files to use, and commands to test the hook script directly before wiring it to a live session.
