#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# autostart/linux/uninstall.sh — Remove systemd user service
# ═══════════════════════════════════════════════════════════════
#
# Usage: bash autostart/linux/uninstall.sh
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SERVICE_DEST="$HOME/.config/systemd/user/ollama-tunnel.service"

if [ ! -f "$SERVICE_DEST" ]; then
    echo "ℹ️  Service not found (already uninstalled?)"
    exit 0
fi

echo "🛑 Stopping service..."
systemctl --user stop ollama-tunnel.service 2>/dev/null || true

echo "🔌 Disabling service..."
systemctl --user disable ollama-tunnel.service 2>/dev/null || true

echo "🗑️  Removing service file..."
rm -f "$SERVICE_DEST"

echo "🔄 Reloading daemon..."
systemctl --user daemon-reload

echo ""
echo "✅ Auto-start removed. The tunnel will no longer start on login."
echo ""
echo "   To start manually: bash autostart/linux/start-tunnel.sh"
