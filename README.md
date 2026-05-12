# tmux-alerts

Notification system for parallel AI coding sessions. Plays a sound and shows an alert when the agent needs your attention.

## Requirements

- .NET 8 SDK
- jq (bash hook scripts only)
- curl (bash hook scripts only)

## Hook types

Three hook variants are provided. Install the one that matches your environment.

| Folder | Platform | Attention signal |
|---|---|---|
| `hooks/tmux/` | Any OS running tmux | Flashes the tmux pane red + OS notification |
| `hooks/linux-mac-wsl/` | macOS, Linux, WSL (non-tmux) | OS notification via `osascript` / `notify-send` |
| `hooks/windows/` | Windows native PowerShell | Windows balloon tip notification |

---

## Configuration — tmux

### Claude (tmux)

```bash
mkdir -p ~/.claude/hooks
cp hooks/tmux/notify-claude.sh ~/.claude/hooks/notify-claude.sh
chmod +x ~/.claude/hooks/notify-claude.sh
```

Add to `~/.claude/settings.json`:

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

### Copilot (tmux)

```bash
mkdir -p ~/.copilot/hooks
cp hooks/tmux/notify-copilot.sh ~/.copilot/hooks/notify-copilot.sh
chmod +x ~/.copilot/hooks/notify-copilot.sh
cp .github/hooks/hooks.json ~/.copilot/hooks/hooks.json
```

Fires on `agentStop`, `notification`, `permissionRequest`, and `errorOccurred`.

---

## Configuration — macOS / Linux / WSL (non-tmux)

### Claude

```bash
mkdir -p ~/.claude/hooks
cp hooks/linux-mac-wsl/notify-claude.sh ~/.claude/hooks/notify-claude.sh
chmod +x ~/.claude/hooks/notify-claude.sh
```

Add the same `~/.claude/settings.json` block shown in the tmux section above.

### Copilot

```bash
mkdir -p ~/.copilot/hooks
cp hooks/linux-mac-wsl/notify-copilot.sh ~/.copilot/hooks/notify-copilot.sh
chmod +x ~/.copilot/hooks/notify-copilot.sh
cp .github/hooks/hooks.json ~/.copilot/hooks/hooks.json
```

**WSL note:** `notify-send` works if a desktop notification daemon is running. Install `wsl-notify-send` for native Windows toast notifications from WSL.

---

## Configuration — Windows (PowerShell)

### Claude

Copy the script and configure Claude Code to invoke it with PowerShell:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\hooks"
Copy-Item hooks\windows\notify-claude.ps1 "$env:USERPROFILE\.claude\hooks\notify-claude.ps1"
```

Add to `%USERPROFILE%\.claude\settings.json` — note the `"shell": "powershell"` field:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.ps1", "shell": "powershell" }]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.ps1", "shell": "powershell" }]
      }
    ]
  }
}
```

### Copilot (Windows)

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.copilot\hooks"
Copy-Item hooks\windows\notify-copilot.ps1 "$env:USERPROFILE\.copilot\hooks\notify-copilot.ps1"
```

Copilot's `hooks.json` supports `bash` and `powershell` fields — the right one fires based on OS. On Windows you only need `powershell`:

```json
{
  "version": 1,
  "hooks": {
    "agentStop": [
      {
        "type": "command",
        "powershell": "~/.copilot/hooks/notify-copilot.ps1",
        "timeoutSec": 5,
        "env": { "HOOK_EVENT": "agentStop" }
      }
    ]
  }
}
```

Add the same entry for `notification`, `permissionRequest`, and `errorOccurred`. Copy the result to `%USERPROFILE%\.copilot\hooks\hooks.json`.

If you share a `hooks.json` across platforms, add both fields to each entry and install both scripts — Copilot picks the one that applies.

---

## Quick Start

### 1. Start the server

```bash
cd src/TmuxAlerts
dotnet run
```

Open http://localhost:7777 in a browser and leave the tab open.

### 2. Install a hook (pick your platform above) and start a session

Agent stops → chime plays → dashboard lights up → check which project needs attention.

### Dashboard icons

The dashboard shows an agent icon (Claude or Copilot) and a client icon (tmux, terminal, VS Code, Claude Desktop) next to each notification. The placeholder icons in `src/TmuxAlerts/wwwroot/icons/` are transparent 1×1 PNGs — replace them with your own 24×32px PNGs and reload the page.

---

## Run with Docker / Podman

```bash
podman compose up --build
```

Or detached:

```bash
podman compose up -d --build
```

Stop:

```bash
podman compose down
```

Works with `docker compose` as well.

## Build self-contained binary

```bash
cd src/TmuxAlerts

# macOS (Apple Silicon)
dotnet publish -r osx-arm64 --self-contained -o ./publish

# WSL / Linux
dotnet publish -r linux-x64 --self-contained -o ./publish

./publish/TmuxAlerts
```
