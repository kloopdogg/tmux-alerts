# AGENTS.md — tmux-alerts

## What this is

A local notification system for parallel AI coding sessions. When Claude or Copilot stops or needs input, a hook script POSTs to a C# server, which pushes an alert to a browser dashboard via WebSocket. Three hook variants cover tmux (pane flash), macOS/Linux/WSL (OS notification), and Windows (PowerShell balloon tip).

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
| Platform | macOS, Linux, WSL, Windows | Same server; hook variant differs per platform |

## File layout

```
hooks/tmux/notify-claude.sh          ← tmux: pane flash + notify, fires on Stop + Notification
hooks/tmux/notify-copilot.sh         ← tmux: pane flash + notify, fires on agentStop + notification + permissionRequest + errorOccurred
hooks/linux-mac-wsl/notify-claude.sh ← non-tmux: OS notification + notify (macOS/Linux/WSL)
hooks/linux-mac-wsl/notify-copilot.sh ← non-tmux: OS notification + notify (macOS/Linux/WSL)
hooks/windows/notify-claude.ps1      ← Windows: balloon tip + notify (PowerShell)
hooks/windows/notify-copilot.ps1     ← Windows: balloon tip + notify (PowerShell)
.github/hooks/hooks.json             ← Copilot hooks template: copy to ~/.copilot/hooks/
src/TmuxAlerts/Program.cs            ← everything in one file: state, endpoints, broadcast, models
src/TmuxAlerts/wwwroot/index.html    ← full dashboard, single HTML file
src/TmuxAlerts/wwwroot/icons/        ← agent + client icon PNGs (replace placeholders with real assets)
```

## Key behaviors

- Sessions auto-register via `/notify` — no separate register step required
- `tmuxTarget` is the tmux pane ID (e.g. `%3`); empty for non-tmux clients
- Each notification and session carries `agent` (claude/copilot) and `client` (tmux/terminal/vscode/claude-desktop)
- Hook client detection: VS Code check runs before tmux lookup — VS Code launched from a tmux pane must not be reported as tmux
- Sessions can be manually removed via `DELETE /session/{id}` — they reappear on the next hook fire
- Hook script uses `|| true` and `--max-time 2` — Claude must never fail due to server being down
- WebSocket broadcast is serialized via `SemaphoreSlim` to avoid interleaved sends
- Dashboard plays a two-tone Web Audio API chime on new notifications — no audio file needed
