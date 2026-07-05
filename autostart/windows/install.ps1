# ═══════════════════════════════════════════════════════════════
# autostart\windows\install.ps1 — Register Task Scheduler task
# ═══════════════════════════════════════════════════════════════
#
# Registers a Windows Task Scheduler task that runs start-tunnel.ps1
# at user logon and keeps it running.
#
# Run once in PowerShell (as Administrator for Task Scheduler access):
#   .\install.ps1
#
# Or without admin (user-only task, less reliable):
#   .\install.ps1 -UserOnly
# ═══════════════════════════════════════════════════════════════

param(
    [switch]$UserOnly  # Register as current-user task (no admin needed)
)

$ErrorActionPreference = "Stop"

$TaskName   = "OllamaTunnel"
$TaskPath   = "\Kalix\"
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptPath = Join-Path $ScriptDir "start-tunnel.ps1"
$LogDir     = "$env:USERPROFILE\.local\log\ollama-tunnel"

# ── Validation ─────────────────────────────────────────────────
if (-not (Test-Path $ScriptPath)) {
    Write-Error "❌ start-tunnel.ps1 not found at: $ScriptPath"
    exit 1
}

# ── Ensure ExecutionPolicy allows running scripts ──────────────
$CurrentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($CurrentPolicy -eq "Restricted") {
    Write-Host "🔧 Setting ExecutionPolicy to RemoteSigned for current user..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "✅ ExecutionPolicy updated"
}

# ── Create log directory ───────────────────────────────────────
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Write-Host "✅ Log directory: $LogDir"

# ── Remove existing task if present ───────────────────────────
$ExistingTask = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Write-Host "🔄 Removing existing task..."
    Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false
}

# ── Build the task action ─────────────────────────────────────
# Hidden PowerShell window so it doesn't pop up on login
$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

# ── Trigger: run at logon of current user ─────────────────────
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# ── Settings ─────────────────────────────────────────────────
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0) `   # No time limit
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

# ── Principal (run as current user) ───────────────────────────
$Principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited      # No elevation needed

# ── Register the task ─────────────────────────────────────────
Write-Host "📝 Registering Task Scheduler task..."

Register-ScheduledTask `
    -TaskName  $TaskName `
    -TaskPath  $TaskPath `
    -Action    $Action `
    -Trigger   $Trigger `
    -Settings  $Settings `
    -Principal $Principal `
    -Force | Out-Null

Write-Host "   ✅ Task registered: $TaskPath$TaskName"

# ── Start the task now ────────────────────────────────────────
Write-Host "🚀 Starting task now..."
Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
Start-Sleep -Seconds 2

$Status = (Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName).State
Write-Host "   Task state: $Status"

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════"
Write-Host "  ✅ Auto-start installed successfully!"
Write-Host "══════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "  The tunnel will start automatically at every logon."
Write-Host ""
Write-Host "  📋 Useful commands (run in PowerShell):"
Write-Host ""
Write-Host "  Check status:"
Write-Host "    Get-ScheduledTask -TaskPath '\Kalix\' -TaskName 'OllamaTunnel'"
Write-Host ""
Write-Host "  View logs:"
Write-Host "    Get-Content $LogDir\tunnel.log -Tail 50 -Wait"
Write-Host ""
Write-Host "  Stop tunnel:"
Write-Host "    Stop-ScheduledTask -TaskPath '\Kalix\' -TaskName 'OllamaTunnel'"
Write-Host ""
Write-Host "  Start tunnel:"
Write-Host "    Start-ScheduledTask -TaskPath '\Kalix\' -TaskName 'OllamaTunnel'"
Write-Host ""
Write-Host "  Remove auto-start:"
Write-Host "    .\uninstall.ps1"
Write-Host ""
