#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# autostart/linux/install.sh — Register systemd user service
# ═══════════════════════════════════════════════════════════════
#
# Installs ollama-tunnel as a systemd user service that starts
# on login and restarts on failure.
#
# Does NOT require sudo (uses --user systemd scope).
#
# Usage: bash autostart/linux/install.sh
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/start-tunnel.sh"
SERVICE_TEMPLATE="$SCRIPT_DIR/ollama-tunnel.service"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_DEST="$SYSTEMD_USER_DIR/ollama-tunnel.service"
LOG_DIR="$HOME/.local/log/ollama-tunnel"

# ── Validation ─────────────────────────────────────────────────
if [ ! -f "$START_SCRIPT" ]; then
    echo "❌ start-tunnel.sh not found at: $START_SCRIPT"
    exit 1
fi

if ! command -v cloudflared &>/dev/null; then
    echo "⚠️  cloudflared not found. Install from:"
    echo "   https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
    echo "   Continuing setup anyway..."
fi

if ! command -v systemctl &>/dev/null; then
    echo "❌ systemctl not found. This script requires systemd (Ubuntu/Debian/Arch/Fedora)."
    exit 1
fi

# ── Prepare ────────────────────────────────────────────────────
chmod +x "$START_SCRIPT"
mkdir -p "$SYSTEMD_USER_DIR"
mkdir -p "$LOG_DIR"
echo "✅ Log directory: $LOG_DIR"

# ── Install service file with correct paths ────────────────────
echo "📝 Installing systemd service..."

sed \
    -e "s|SERVICE_USER_PLACEHOLDER|$(whoami)|g" \
    -e "s|SERVICE_SCRIPT_PLACEHOLDER|$START_SCRIPT|g" \
    "$SERVICE_TEMPLATE" > "$SERVICE_DEST"

echo "   ✅ Service installed: $SERVICE_DEST"

# ── Enable lingering (so service runs even without active login) ──
# Required for servers where you SSH in, not for desktops
# loginctl enable-linger "$(whoami)" 2>/dev/null || true

# ── Reload daemon and enable service ──────────────────────────
echo "🔄 Reloading systemd daemon..."
systemctl --user daemon-reload

echo "🔌 Enabling service (auto-start on login)..."
systemctl --user enable ollama-tunnel.service

echo "🚀 Starting service now..."
systemctl --user start ollama-tunnel.service

sleep 2

# ── Status ─────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════"
echo "  ✅ Auto-start installed successfully!"
echo "══════════════════════════════════════════════════════════"
echo ""

STATUS=$(systemctl --user is-active ollama-tunnel.service 2>/dev/null || echo "unknown")
echo "  Service status: $STATUS"
echo ""
echo "  📋 Useful commands:"
echo ""
echo "  Check status:   systemctl --user status ollama-tunnel"
echo "  View logs:      journalctl --user -u ollama-tunnel -f"
echo "  File logs:      tail -f $LOG_DIR/tunnel.log"
echo "  Stop:           systemctl --user stop ollama-tunnel"
echo "  Start:          systemctl --user start ollama-tunnel"
echo "  Remove:         bash $SCRIPT_DIR/uninstall.sh"
echo ""
echo "  ⚠️  Note: On a headless server, run this to start without login:"
echo "    sudo loginctl enable-linger $(whoami)"
echo ""
