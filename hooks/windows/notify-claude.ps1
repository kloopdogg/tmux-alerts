# Claude Code hook — fires on Stop and Notification events.
# Install to %USERPROFILE%\.claude\hooks\ on Windows.
# Configure hooks.json with "shell": "powershell" to invoke this script.
# Reads JSON from stdin, sends a Windows notification, posts to the tmux-alerts server.

$raw = [Console]::In.ReadToEnd()
$input_json = if ($raw.Trim()) { $raw | ConvertFrom-Json } else { [PSCustomObject]@{} }

$sessionId = if ($input_json.session_id) { $input_json.session_id } else { "unknown" }
$message   = if ($input_json.message)    { $input_json.message }    else { "Claude stopped" }
$hookType  = if ($input_json.hook_event_name) { $input_json.hook_event_name } else { "unknown" }
$cwd       = if ($input_json.cwd)        { $input_json.cwd }        else { "" }
$project   = if ($cwd) { Split-Path -Leaf $cwd } else { "unknown" }

$client = if ($env:TERM_PROGRAM -eq "vscode" -or $env:VSCODE_PPID -or $env:VSCODE_INJECTION_UUID) { "vscode" } else { "terminal" }

# Windows balloon tip notification (no external dependencies).
try {
    Add-Type -AssemblyName System.Windows.Forms
    $n = New-Object System.Windows.Forms.NotifyIcon
    $n.Icon = [System.Drawing.SystemIcons]::Application
    $n.BalloonTipTitle = "tmux-alerts - $project"
    $n.BalloonTipText  = $message
    $n.Visible = $true
    $n.ShowBalloonTip(3000)
    Start-Sleep -Milliseconds 200
    $n.Dispose()
} catch { }

$body = @{
    sessionId  = $sessionId
    message    = $message
    hookType   = $hookType
    project    = $project
    tmuxTarget = ""
    agent      = "claude"
    client     = $client
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "http://localhost:7777/notify" -Method Post `
        -ContentType "application/json" -Body $body -TimeoutSec 2 | Out-Null
} catch { }
