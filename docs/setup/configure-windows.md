# Configure — Windows (PowerShell)

Sends a Windows balloon tip notification.

## Claude

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\hooks"
Copy-Item hooks\windows\notify-claude.ps1 "$env:USERPROFILE\.claude\hooks\notify-claude.ps1"
```

Merge the hooks from `hooks\windows\claude-hooks.json` into `%USERPROFILE%\.claude\settings.json`. Note the `"shell": "powershell"` field required on each entry:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify-claude.ps1", "shell": "powershell" }]
      }
    ],
    "PermissionRequest": [
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

## Copilot

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.copilot\hooks"
Copy-Item hooks\windows\notify-copilot.ps1 "$env:USERPROFILE\.copilot\hooks\notify-copilot.ps1"
Copy-Item hooks\windows\copilot-hooks.json "$env:USERPROFILE\.copilot\hooks\hooks.json"
```

Fires on `agentStop`, `notification`, `permissionRequest`, and `errorOccurred`.

If you share a `hooks.json` across platforms, add both `bash` and `powershell` fields to each entry and install both scripts — Copilot picks the one that applies.
