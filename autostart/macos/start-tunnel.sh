#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# start-tunnel.sh — Auto-start Nginx + Cloudflare Tunnel
# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════
#
# Called by LaunchAgent on macOS login.
# Starts nginx (if not running) then launches cloudflared tunnel.
#
# Usage (manual): bash start-tunnel.sh
# Auto-start:     install-autostart.sh (sets up LaunchAgent)
# Auto-start:     install-autostart.sh (sets up LaunchAgent)
# ═══════════════════════════════════════════════════════════════

set -uo pipefail  # No -e: allow individual steps to fail without killing the script

TUNNEL_NAME="mac-ollama"
NGINX_PORT=8080
LOG_DIR="$HOME/.local/log/ollama-tunnel"
LOG_FILE="$LOG_DIR/tunnel.log"
NGINX_LOG="$LOG_DIR/nginx.log"

# ── Paths (Homebrew on Apple Silicon / Intel / Linux) ──────────
# Find nginx
if command -v nginx &>/dev/null; then
    NGINX_BIN="$(command -v nginx)"
elif [ -x /opt/homebrew/bin/nginx ]; then
    NGINX_BIN="/opt/homebrew/bin/nginx"
elif [ -x /usr/local/bin/nginx ]; then
    NGINX_BIN="/usr/local/bin/nginx"
else
    echo "[$(date)] ❌ nginx not found" >> "$LOG_FILE"
    exit 1
fi

# Find cloudflared
if command -v cloudflared &>/dev/null; then
    CF_BIN="$(command -v cloudflared)"
elif [ -x /opt/homebrew/bin/cloudflared ]; then
    CF_BIN="/opt/homebrew/bin/cloudflared"
elif [ -x /usr/local/bin/cloudflared ]; then
    CF_BIN="/usr/local/bin/cloudflared"
else
    echo "[$(date)] ❌ cloudflared not found" >> "$LOG_FILE"
    exit 1
fi

# ── Setup log directory ────────────────────────────────────────
mkdir -p "$LOG_DIR"
echo "" >> "$LOG_FILE"
echo "══════════════════════════════════════" >> "$LOG_FILE"
echo "[$(date)] 🚀 Starting Ollama tunnel stack" >> "$LOG_FILE"

# ── Step 1: Start / ensure nginx is running ────────────────────
echo "[$(date)] 🔍 Checking nginx..." >> "$LOG_FILE"

if pgrep -x nginx &>/dev/null; then
    echo "[$(date)] ✅ nginx already running" >> "$LOG_FILE"
else
    echo "[$(date)] 📦 Starting nginx..." >> "$LOG_FILE"
    # macOS Homebrew nginx runs as current user, no sudo needed
    "$NGINX_BIN" >> "$NGINX_LOG" 2>&1 &
    sleep 2

    # Verify nginx started
    if pgrep -x nginx &>/dev/null; then
        echo "[$(date)] ✅ nginx started on port $NGINX_PORT" >> "$LOG_FILE"
    else
        echo "[$(date)] ❌ nginx failed to start — check $NGINX_LOG" >> "$LOG_FILE"
        exit 1
    fi
fi

# ── Step 2: Wait for nginx to be ready ────────────────────────
MAX_WAIT=10
COUNT=0
while ! curl -sf http://localhost:$NGINX_PORT/health &>/dev/null; do
    sleep 1
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_WAIT ]; then
        echo "[$(date)] ⚠️  nginx health check timeout — continuing anyway" >> "$LOG_FILE"
        break
    fi
done

# ── Step 3: Launch Cloudflare Tunnel ──────────────────────────
echo "[$(date)] 🌐 Starting cloudflared tunnel: $TUNNEL_NAME" >> "$LOG_FILE"
echo "[$(date)]    Binary: $CF_BIN" >> "$LOG_FILE"

exec "$CF_BIN" tunnel run "$TUNNEL_NAME" >> "$LOG_FILE" 2>&1
