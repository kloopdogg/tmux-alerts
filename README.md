# tmux-alerts

Notification system for parallel AI coding sessions. Plays a sound and shows an alert when the agent needs your attention. One click jumps your terminal to the right pane.

## Requirements

- .NET 8 SDK
- tmux
- jq (for the hook scripts)
- curl

## Configuration

### Claude

```bash
mkdir -p ~/.claude/hooks
cp hooks/notify-claude.sh ~/.claude/hooks/notify-claude.sh
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

### Copilot

```bash
mkdir -p ~/.copilot/hooks
cp hooks/notify-copilot.sh ~/.copilot/hooks/notify-copilot.sh
chmod +x ~/.copilot/hooks/notify-copilot.sh
cp .github/hooks/hooks.json ~/.copilot/hooks/hooks.json
```

Fires on `agentStop`, `notification`, `permissionRequest`, and `errorOccurred`.

## Quick Start

### 1. Start the server

```bash
cd src/TmuxAlerts
dotnet run
```

Open http://localhost:7777 in a browser and leave the tab open.

### 2. Open sessions in tmux

```bash
tmux new-session -s work
# Split into panes, start claude or copilot in each
```

That's it. Agent stops → chime plays → dashboard lights up → click Jump → terminal switches pane.

## Run with Docker / Podman

```bash
podman compose up --build
```

Or detached:

```bash
podman compose up --build
```

Stop:

```bash
podman compose down
```

Works with `docker compose` as well - same commands.

## Build self-contained binary

```bash
cd src/TmuxAlerts

# macOS (Apple Silicon)
dotnet publish -r osx-arm64 --self-contained -o ./publish

# WSL / Linux
dotnet publish -r linux-x64 --self-contained -o ./publish

./publish/TmuxAlerts
```
