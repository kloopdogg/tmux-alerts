# tmux-alerts

Notification system for parallel AI coding sessions. Plays a sound and shows an alert when the agent needs your attention.

## Requirements

- .NET 8 SDK
- jq (bash hook scripts only)
- curl (bash hook scripts only)

## Quick Start

### 1. Start the server

```bash
cd src/TmuxAlerts
dotnet run
```

Open http://localhost:7777 in a browser and leave the tab open.

### 2. Install hooks and start a session

Pick the guide for your environment:

| Environment | Guide |
|---|---|
| tmux (any OS) | [docs/setup/configure-tmux.md](docs/setup/configure-tmux.md) |
| macOS / Linux / WSL (non-tmux) | [docs/setup/configure-linux-mac-wsl.md](docs/setup/configure-linux-mac-wsl.md) |
| Windows native PowerShell | [docs/setup/configure-windows.md](docs/setup/configure-windows.md) |

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
