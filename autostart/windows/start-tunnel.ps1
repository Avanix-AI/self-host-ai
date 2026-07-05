# ═══════════════════════════════════════════════════════════════
# autostart\windows\start-tunnel.ps1 — Start Nginx + Cloudflare Tunnel
# ═══════════════════════════════════════════════════════════════
#
# Starts nginx (if not running) then launches cloudflared tunnel.
# Called by Windows Task Scheduler on login.
#
# Usage (manual):  .\start-tunnel.ps1
# Auto-start:      .\install.ps1
# ═══════════════════════════════════════════════════════════════

param(
    [string]$TunnelName = "mac-ollama",
    [int]   $NginxPort  = 8080
)

$ErrorActionPreference = "Continue"   # Don't stop on non-critical errors

# ── Paths ──────────────────────────────────────────────────────
$LogDir  = "$env:USERPROFILE\.local\log\ollama-tunnel"
$LogFile = "$LogDir\tunnel.log"

# Find nginx
$NginxPaths = @(
    "C:\nginx\nginx.exe",
    "C:\tools\nginx\nginx.exe",
    "$env:ProgramFiles\nginx\nginx.exe",
    (Get-Command nginx -ErrorAction SilentlyContinue)?.Source
) | Where-Object { $_ -and (Test-Path $_) }
$NginxBin = $NginxPaths | Select-Object -First 1

# Find cloudflared
$CfPaths = @(
    "$env:ProgramFiles\cloudflared\cloudflared.exe",
    "$env:LOCALAPPDATA\cloudflared\cloudflared.exe",
    "C:\cloudflared\cloudflared.exe",
    (Get-Command cloudflared -ErrorAction SilentlyContinue)?.Source
) | Where-Object { $_ -and (Test-Path $_) }
$CfBin = $CfPaths | Select-Object -First 1

# ── Setup log directory ────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log {
    param([string]$Message)
    $Line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $LogFile -Value $Line
    Write-Host $Line
}

Write-Log ""
Write-Log "══════════════════════════════════════"
Write-Log "🚀 Starting Ollama tunnel stack (Windows)"

# ── Step 1: Start nginx ────────────────────────────────────────
Write-Log "🔍 Checking nginx..."

$NginxProcess = Get-Process -Name "nginx" -ErrorAction SilentlyContinue

if ($NginxProcess) {
    Write-Log "✅ nginx already running (PID: $($NginxProcess.Id))"
} elseif ($NginxBin) {
    Write-Log "📦 Starting nginx from: $NginxBin"
    $NginxDir = Split-Path $NginxBin
    Start-Process -FilePath $NginxBin -WorkingDirectory $NginxDir -WindowStyle Hidden
    Start-Sleep -Seconds 2

    if (Get-Process -Name "nginx" -ErrorAction SilentlyContinue) {
        Write-Log "✅ nginx started on port $NginxPort"
    } else {
        Write-Log "❌ nginx failed to start. Check logs in: $NginxDir\logs\"
    }
} else {
    Write-Log "⚠️  nginx not found. Download: https://nginx.org/en/download.html"
    Write-Log "   Expected path: C:\nginx\nginx.exe"
}

# ── Step 2: Wait for nginx to be ready ────────────────────────
$MaxWait = 15
$Count   = 0
Write-Log "⏳ Waiting for nginx on port $NginxPort..."
while ($Count -lt $MaxWait) {
    try {
        $Response = Invoke-WebRequest -Uri "http://localhost:$NginxPort/health" -UseBasicParsing -TimeoutSec 1 -ErrorAction Stop
        Write-Log "✅ nginx is ready (HTTP $($Response.StatusCode))"
        break
    } catch {
        Start-Sleep -Seconds 1
        $Count++
    }
}
if ($Count -ge $MaxWait) {
    Write-Log "⚠️  nginx health check timeout — continuing anyway"
}

# ── Step 3: Launch cloudflared ─────────────────────────────────
if (-not $CfBin) {
    Write-Log "❌ cloudflared not found. Download: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
    exit 1
}

Write-Log "🌐 Starting cloudflared tunnel: $TunnelName"
Write-Log "   Binary: $CfBin"

# Run cloudflared and pipe output to log
& $CfBin tunnel run $TunnelName 2>&1 | ForEach-Object {
    $Line = "[$(Get-Date -Format 'HH:mm:ss')] $_"
    Add-Content -Path $LogFile -Value $Line
    Write-Host $Line
}
