#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# uninstall-autostart.sh — Remove LaunchAgent
# ═══════════════════════════════════════════════════════════════
#
# Usage: bash uninstall-autostart.sh
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

PLIST_DEST="$HOME/Library/LaunchAgents/com.kalix.ollama-tunnel.plist"

if [ ! -f "$PLIST_DEST" ]; then
    echo "ℹ️  LaunchAgent not found (already uninstalled?)"
    exit 0
fi

echo "🛑 Stopping tunnel..."
launchctl stop com.kalix.ollama-tunnel 2>/dev/null || true

echo "🔄 Unloading LaunchAgent..."
launchctl unload "$PLIST_DEST" 2>/dev/null || true

echo "🗑️  Removing plist..."
rm -f "$PLIST_DEST"

echo ""
echo "✅ Auto-start removed. The tunnel will no longer start on login."
echo ""
echo "   To start manually: bash start-tunnel.sh"
