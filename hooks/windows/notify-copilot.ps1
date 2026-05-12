# GitHub Copilot CLI hook — fires on agentStop, notification, permissionRequest, and errorOccurred.
# Install to %USERPROFILE%\.copilot\hooks\ on Windows.
# HOOK_EVENT must be set in the hooks.json env field.
# Reads JSON from stdin, sends a Windows notification, posts to the tmux-alerts server.

$input_json = $input | Out-String | ConvertFrom-Json

$sessionId = if ($input_json.sessionId) { $input_json.sessionId }
             elseif ($input_json.session_id) { $input_json.session_id }
             else { "unknown" }
$cwd       = if ($input_json.cwd) { $input_json.cwd } else { "" }
$project   = if ($cwd) { Split-Path -Leaf $cwd } else { "unknown" }
$hookType  = if ($env:HOOK_EVENT) { $env:HOOK_EVENT } else { "unknown" }

$message = switch ($hookType) {
    "agentStop"         { "Copilot finished" }
    "notification"      { if ($input_json.message) { $input_json.message } else { "Copilot notification" } }
    "permissionRequest" { "Permission requested: $(if ($input_json.toolName) { $input_json.toolName } else { 'unknown tool' })" }
    "errorOccurred"     { "Copilot error: $(if ($input_json.error) { $input_json.error } else { 'unknown error' })" }
    default             { "Copilot hook fired" }
}

$client = if ($env:TERM_PROGRAM -eq "vscode") { "vscode" } else { "terminal" }

# Windows balloon tip notification (no external dependencies).
try {
    Add-Type -AssemblyName System.Windows.Forms
    $n = New-Object System.Windows.Forms.NotifyIcon
    $n.Icon = [System.Drawing.SystemIcons]::Application
    $n.BalloonTipTitle = "tmux-alerts — $project"
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
    agent      = "copilot"
    client     = $client
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "http://localhost:7777/notify" -Method Post `
        -ContentType "application/json" -Body $body -TimeoutSec 2 | Out-Null
} catch { }
