# Spec: tmux-alerts

## Overview

Three moving parts:
1. **Hook scripts** — shell scripts Claude Code invokes on events, POST to the server
2. **C# server** — receives events, pushes to browser via WebSocket, executes tmux jumps
3. **Browser dashboard** — shows live session status, plays alerts, offers one-click jump

---

## Part 1: Claude Code Hooks

Claude Code fires hooks by writing a JSON payload to a script's stdin. Hooks are configured in `~/.claude/settings.json`.

### Hook Events Used

| Event | When It Fires | Why We Care |
|---|---|---|
| `Notification` | Claude wants the user's attention | Primary alert trigger |
| `Stop` | Claude has stopped (done, blocked, or waiting) | Catch anything Notification misses |
| `PreToolUse` | (optional) Before Claude uses a tool | Could filter for high-risk tools |

### Hook Payload (from Claude Code)

```json
{
  "session_id": "abc123",
  "hook_event_name": "Notification",
  "message": "I need clarification on the database schema",
  "transcript_path": "/path/to/transcript"
}
```

### Hook Script: `hooks/notify-claude.sh`

```bash
#!/bin/bash
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
MESSAGE=$(echo "$INPUT"   | jq -r '.message // "Claude stopped"')
HOOK_TYPE=$(echo "$INPUT" | jq -r '.hook_event_name // "unknown"')
PROJECT=$(echo "$INPUT"   | jq -r '.cwd // ""' | xargs basename 2>/dev/null || echo "unknown")

curl -s -X POST http://localhost:7777/notify \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_ID\",\"message\":\"$MESSAGE\",\"hookType\":\"$HOOK_TYPE\",\"project\":\"$PROJECT\"}" \
  || true
```

The `|| true` ensures the hook never fails Claude even if the server is down.

### Hook Script: `hooks/register.sh`

Fires on session start to register the tmux pane target (so the server knows where to jump).

```bash
#!/bin/bash
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
PROJECT=$(echo "$INPUT"   | jq -r '.cwd // ""' | xargs basename 2>/dev/null || echo "unknown")
TMUX_TARGET="${TMUX_PANE:-unknown}"

curl -s -X POST http://localhost:7777/register \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_ID\",\"tmuxTarget\":\"$TMUX_TARGET\",\"project\":\"$PROJECT\"}" \
  || true
```

`$TMUX_PANE` is an environment variable tmux sets automatically (e.g., `%3`). Combined with `tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}'` it gives us a full jump target.

### Settings Configuration: `~/.claude/settings.json`

```json
{
  "hooks": {
    "Notification": [
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

---

## Part 1b: GitHub Copilot CLI Hooks

Copilot CLI hooks are configured via `hooks.json`, placed at `~/.copilot/hooks/hooks.json` for user-level activation.

### Hook Events Used

| Event | When It Fires | Why We Care |
|---|---|---|
| `agentStop` | Agent finishes a turn | Primary alert trigger — equivalent to Claude's `Stop` |
| `notification` | CLI emits a system notification | Direct user-attention signal |
| `permissionRequest` | Before the permission service runs | Claude equivalent of a tool-use prompt |
| `errorOccurred` | An error occurs during execution | Catch failures |

### Hook Payload (from Copilot CLI)

```json
{
  "sessionId": "abc123",
  "timestamp": 1704614400000,
  "cwd": "/Users/scott/Projects/my-api",
  "message": "Needs your attention"
}
```

### Hook Script: `hooks/notify-copilot.sh`

Install to `~/.copilot/hooks/notify-copilot.sh`. Reads the same fields as `notify-claude.sh` where available; synthesizes the rest. `HOOK_EVENT` is injected via the `env` field in `hooks.json`.

### Configuration: `hooks.json`

```json
{
  "version": 1,
  "hooks": {
    "agentStop":        [{ "type": "command", "bash": "~/.copilot/hooks/notify-copilot.sh", "timeoutSec": 5, "env": { "HOOK_EVENT": "agentStop" } }],
    "notification":     [{ "type": "command", "bash": "~/.copilot/hooks/notify-copilot.sh", "timeoutSec": 5, "env": { "HOOK_EVENT": "notification" } }],
    "permissionRequest":[{ "type": "command", "bash": "~/.copilot/hooks/notify-copilot.sh", "timeoutSec": 5, "env": { "HOOK_EVENT": "permissionRequest" } }],
    "errorOccurred":    [{ "type": "command", "bash": "~/.copilot/hooks/notify-copilot.sh", "timeoutSec": 5, "env": { "HOOK_EVENT": "errorOccurred" } }]
  }
}
```

Copy to `~/.copilot/hooks/hooks.json` for user-level activation.

---

## Part 2: C# Server

### Tech Stack

- **ASP.NET Core Minimal API** — no controllers, just endpoints
- **WebSockets** — built-in to ASP.NET Core, no SignalR needed
- **Static file serving** — serves the dashboard HTML from `wwwroot/`
- **No database** — in-memory state only (sessions, notifications)
- **Target:** .NET 8, single executable (`dotnet publish -r osx-arm64 --self-contained`)

### Project Structure

```
src/TmuxAlerts/
├── TmuxAlerts.csproj
├── Program.cs           ← everything lives here (Minimal API)
├── Models.cs            ← simple record types
└── wwwroot/
    └── index.html       ← the entire dashboard
```

### In-Memory State

```csharp
// Sessions registered by Claude hooks
Dictionary<string, Session> Sessions;

// Pending notifications (cleared when user clicks dismiss/jump)
List<Notification> Notifications;

// Active WebSocket connections (browser tabs)
List<WebSocket> Connections;
```

```csharp
record Session(string SessionId, string TmuxTarget, string Project, DateTime RegisteredAt);
record Notification(string Id, string SessionId, string Message, string HookType, string Project, DateTime ReceivedAt, bool Dismissed);
```

### API Endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/register` | Hook registers a new Claude session with its tmux target |
| `POST` | `/notify` | Hook posts a notification event |
| `POST` | `/jump/{notificationId}` | Dashboard requests a pane jump |
| `POST` | `/dismiss/{notificationId}` | Dashboard dismisses a notification |
| `GET` | `/state` | Dashboard polls current state on load |
| `GET` | `/ws` | WebSocket upgrade — browser connects here |
| `GET` | `/` | Serves `index.html` |

### Jump Execution

```csharp
app.MapPost("/jump/{id}", (string id) => {
    var notification = notifications.FirstOrDefault(n => n.Id == id);
    if (notification is null) return Results.NotFound();

    var session = sessions.GetValueOrDefault(notification.SessionId);
    if (session is null) return Results.NotFound();

    // tmux select-pane -t %3  (or full target like mysession:1.2)
    Process.Start("tmux", $"select-pane -t {session.TmuxTarget}");

    // Mark dismissed
    DismissNotification(id);
    BroadcastState();

    return Results.Ok();
});
```

### WebSocket Broadcast

On any state change (new notification, dismiss, jump, new session), broadcast the full current state to all connected browser tabs:

```csharp
async Task BroadcastState() {
    var payload = JsonSerializer.Serialize(new {
        sessions = sessions.Values,
        notifications = notifications.Where(n => !n.Dismissed)
    });
    var bytes = Encoding.UTF8.GetBytes(payload);
    foreach (var ws in connections.ToList()) {
        if (ws.State == WebSocketState.Open)
            await ws.SendAsync(bytes, WebSocketMessageType.Text, true, CancellationToken.None);
    }
}
```

### Running the Server

```bash
cd src/TmuxAlerts
dotnet run
# → Listening on http://localhost:7777
```

---

## Part 3: Browser Dashboard

Single HTML file. No build step. No framework. Vanilla JS.

### Layout

```
┌──────────────────────────────────────────┐
│  tmux-alerts          ● 2 need attention │
├──────────────────────────────────────────┤
│ ACTIVE SESSIONS                          │
│  ● api-service      pane %1  [idle]      │
│  ● web-frontend     pane %2  [idle]      │
│  ▲ data-pipeline    pane %3  [waiting]   │
│  ● auth-service     pane %4  [idle]      │
├──────────────────────────────────────────┤
│ NOTIFICATIONS                            │
│  [!] data-pipeline — 2:14pm              │
│  "Which S3 bucket should I write to?"    │
│                    [Jump] [Dismiss]      │
│                                          │
│  [!] data-pipeline — 2:09pm              │
│  "Claude stopped"                        │
│                    [Jump] [Dismiss]      │
└──────────────────────────────────────────┘
```

### Behavior

- On load: fetch `/state`, connect WebSocket
- On WebSocket message: re-render the notification list
- On new notification: play a sound (short chime via Web Audio API — no audio file needed)
- **Jump** button: `fetch('POST /jump/{id}')` — server handles the tmux switch
- **Dismiss** button: `fetch('POST /dismiss/{id}')` — removes from list
- Page title shows unread count: `(2) tmux-alerts` — visible in browser tab

---

## File Layout

```
tmux-alerts/
├── .github/
│   └── hooks/
│       └── hooks.json
├── docs/
│   ├── vision.md
│   └── spec.md
├── hooks/
│   ├── notify-claude.sh
│   └── notify-copilot.sh
├── src/
│   └── TmuxAlerts/
│       ├── TmuxAlerts.csproj
│       ├── Program.cs
│       ├── Models.cs
│       └── wwwroot/
│           └── index.html
└── README.md
```

---

## Build & Run

```bash
# Run in dev
cd src/TmuxAlerts && dotnet run

# Build self-contained binary for Mac
dotnet publish -r osx-arm64 --self-contained -o ./publish

# Install claude hooks (one-time)
mkdir -p ~/.claude/hooks
cp hooks/notify-claude.sh ~/.claude/hooks/
cp hooks/register.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
# Then add hook config to ~/.claude/settings.json

# Install copilot hooks (one-time)
mkdir -p ~/.copilot/hooks
cp hooks/notify-copilot.sh ~/.copilot/hooks/
chmod +x ~/.copilot/hooks/notify-copilot.sh
cp .github/hooks/hooks.json ~/.copilot/hooks/
# hooks.json wires agentStop, notification, permissionRequest, and errorOccurred to notify-copilot.sh

```
