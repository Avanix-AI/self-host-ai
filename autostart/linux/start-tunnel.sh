#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# autostart/linux/start-tunnel.sh — Start Nginx + Cloudflare Tunnel
# ═══════════════════════════════════════════════════════════════
#
# Called by systemd service on boot.
# Starts nginx (if not running) then launches cloudflared tunnel.
#
# Usage (manual): bash autostart/linux/start-tunnel.sh
# Auto-start:     bash autostart/linux/install.sh
# ═══════════════════════════════════════════════════════════════

set -uo pipefail  # No -e: allow individual steps to fail gracefully

TUNNEL_NAME="mac-ollama"
NGINX_PORT=8080
LOG_DIR="$HOME/.local/log/ollama-tunnel"
LOG_FILE="$LOG_DIR/tunnel.log"

# ── Setup log directory ────────────────────────────────────────
mkdir -p "$LOG_DIR"
echo "" >> "$LOG_FILE"
echo "══════════════════════════════════════" >> "$LOG_FILE"
echo "[$(date)] 🚀 Starting Ollama tunnel stack (Linux)" >> "$LOG_FILE"

# ── Step 1: Ensure nginx is running via systemd ────────────────
echo "[$(date)] 🔍 Checking nginx..." >> "$LOG_FILE"

if systemctl is-active --quiet nginx; then
    echo "[$(date)] ✅ nginx already running" >> "$LOG_FILE"
else
    echo "[$(date)] 📦 Starting nginx via systemd..." >> "$LOG_FILE"
    systemctl start nginx >> "$LOG_FILE" 2>&1 || {
        echo "[$(date)] ❌ Failed to start nginx. Try: sudo systemctl start nginx" >> "$LOG_FILE"
    }
fi

# ── Step 2: Wait for nginx to be ready ────────────────────────
MAX_WAIT=15
COUNT=0
while ! curl -sf http://localhost:$NGINX_PORT/health &>/dev/null; do
    sleep 1
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_WAIT ]; then
        echo "[$(date)] ⚠️  nginx health check timeout — continuing anyway" >> "$LOG_FILE"
        break
    fi
done

# ── Step 3: Find cloudflared binary ───────────────────────────
if command -v cloudflared &>/dev/null; then
    CF_BIN="$(command -v cloudflared)"
elif [ -x /usr/local/bin/cloudflared ]; then
    CF_BIN="/usr/local/bin/cloudflared"
elif [ -x /usr/bin/cloudflared ]; then
    CF_BIN="/usr/bin/cloudflared"
else
    echo "[$(date)] ❌ cloudflared not found. Install: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/" >> "$LOG_FILE"
    exit 1
fi

# ── Step 4: Launch Cloudflare Tunnel ──────────────────────────
echo "[$(date)] 🌐 Starting cloudflared tunnel: $TUNNEL_NAME" >> "$LOG_FILE"
echo "[$(date)]    Binary: $CF_BIN" >> "$LOG_FILE"

exec "$CF_BIN" tunnel run "$TUNNEL_NAME" >> "$LOG_FILE" 2>&1
