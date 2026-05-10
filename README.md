# tmux-alerts

Notification system for parallel Claude Code sessions. Plays a sound and shows an alert when Claude needs your attention. One click jumps your terminal to the right pane.

## Quick Start

### 1. Start the server

```bash
cd src/TmuxAlerts
dotnet run
```

Open http://localhost:7777 in a browser and leave the tab open.

### 2. Install the hook script

```bash
mkdir -p ~/.claude/hooks
cp hooks/notify.sh ~/.claude/hooks/notify.sh
chmod +x ~/.claude/hooks/notify.sh
```

### 3. Wire up Claude Code hooks

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh" }]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh" }]
      }
    ]
  }
}
```

### 4. Open Claude sessions in tmux

```bash
tmux new-session -s work
# Split into panes, start claude in each
```

That's it. Claude stops → chime plays → dashboard lights up → click Jump → terminal switches pane.

---

## GitHub Copilot CLI

```bash
mkdir -p ~/.copilot/hooks
cp hooks/notify-copilot.sh ~/.copilot/hooks/notify-copilot.sh
chmod +x ~/.copilot/hooks/notify-copilot.sh
cp .github/hooks/hooks.json ~/.copilot/hooks/hooks.json
```

Fires on `agentStop`, `notification`, `permissionRequest`, and `errorOccurred`.

## Build self-contained binary

```bash
cd src/TmuxAlerts
dotnet publish -r osx-arm64 --self-contained -o ./publish
./publish/TmuxAlerts
```

## Requirements

- .NET 8 SDK
- tmux
- jq (for the hook script)
- curl
