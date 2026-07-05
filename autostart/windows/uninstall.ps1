# ═══════════════════════════════════════════════════════════════
# autostart\windows\uninstall.ps1 — Remove Task Scheduler task
# ═══════════════════════════════════════════════════════════════
#
# Usage: .\uninstall.ps1
# ═══════════════════════════════════════════════════════════════

$TaskName = "OllamaTunnel"
$TaskPath = "\Kalix\"

$Task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $Task) {
    Write-Host "ℹ️  Task not found (already uninstalled?)"
    exit 0
}

Write-Host "🛑 Stopping task..."
Stop-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue

Write-Host "🗑️  Removing task..."
Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false

# Remove the \Kalix\ folder if empty
$RemainingTasks = Get-ScheduledTask -TaskPath $TaskPath -ErrorAction SilentlyContinue
if (-not $RemainingTasks) {
    # Can't delete task folders directly via PowerShell, use schtasks
    schtasks /delete /tn "\Kalix" /f 2>$null | Out-Null
}

Write-Host ""
Write-Host "✅ Auto-start removed. The tunnel will no longer start on login."
Write-Host ""
Write-Host "   To start manually: .\start-tunnel.ps1"
