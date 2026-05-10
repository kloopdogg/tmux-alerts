# AGENTS.md — tmux-alerts

## What this is

A local notification system for parallel Claude Code sessions in tmux. When Claude stops or needs input, a hook script POSTs to a C# server, which pushes an alert to a browser dashboard via WebSocket. The user clicks Jump; the server runs `tmux select-pane` to switch panes.

## Coding rules

**No alignment rivers.** Do not pad `=`, `:`, or any operator to align columns across lines. Each line stands alone.

```csharp
// wrong
var sessions      = new ConcurrentDictionary<string, Session>();
var notifications = new ConcurrentDictionary<string, Notification>();
var wsLock        = new object();

// right
var sessions = new ConcurrentDictionary<string, Session>();
var notifications = new ConcurrentDictionary<string, Notification>();
var wsLock = new object();
```

**No comments that describe what the code does.** Only comment when the WHY is non-obvious — a hidden constraint, a workaround, a subtle invariant. Well-named identifiers carry the what.

**Simple over clever.** No patterns, abstractions, or structure beyond what the task requires. Three similar lines beats a premature abstraction.

**No error handling for impossible cases.** Trust the framework and internal guarantees. Validate only at boundaries (HTTP request bodies, hook stdin).

## Decided architecture — do not re-propose alternatives

| Decision | Choice | Reason |
|---|---|---|
| Transport | HTTP + WebSockets | gRPC requires proxy for browser; SSE/WS gives real-time push with no extra deps |
| Server | ASP.NET Core Minimal API, .NET 8 | C# is the owner's primary language; Minimal API keeps it in one file |
| State | In-memory only | Single user, local tool; restarts are acceptable |
| Frontend | Vanilla JS, no framework, no build step | Nothing to justify the overhead |
| Port | 7777 | Decided; don't suggest changing it |
| Platform | macOS first, WSL later | Same architecture; add WSL support when asked |

## File layout

```
hooks/notify.sh              ← install to ~/.claude/hooks/, fires on Stop + Notification
hooks/notify-copilot.sh      ← install to ~/.copilot/hooks/, fires on agentStop + notification + permissionRequest + errorOccurred
.github/hooks/hooks.json     ← template: copy to ~/.copilot/hooks/ for user-level Copilot hooks
src/TmuxAlerts/Program.cs    ← everything in one file: state, endpoints, broadcast, models
src/TmuxAlerts/wwwroot/index.html  ← full dashboard, single HTML file
```

## Key behaviors

- Sessions auto-register via `/notify` — no separate register step required
- `tmuxTarget` is `$TMUX_PANE` (e.g. `%3`) — unique global pane ID set by tmux
- Hook script uses `|| true` and `--max-time 2` — Claude must never fail due to server being down
- WebSocket broadcast is serialized via `SemaphoreSlim` to avoid interleaved sends
- Dashboard plays a two-tone Web Audio API chime on new notifications — no audio file needed
