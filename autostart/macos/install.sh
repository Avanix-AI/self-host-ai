#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# install.sh — Register LaunchAgent for auto-start
# ═══════════════════════════════════════════════════════════════
#
# Run once to enable the tunnel to start automatically on login.
# Does NOT require sudo.
#
# Usage: bash autostart/macos/install.sh
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/start-tunnel.sh"
PLIST_TEMPLATE="$SCRIPT_DIR/com.kalix.ollama-tunnel.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_AGENTS_DIR/com.kalix.ollama-tunnel.plist"
LOG_DIR="$HOME/.local/log/ollama-tunnel"

# ── Validation ─────────────────────────────────────────────────
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ start-tunnel.sh not found at: $SCRIPT_PATH"
    exit 1
fi

if [ ! -f "$PLIST_TEMPLATE" ]; then
    echo "❌ plist template not found at: $PLIST_TEMPLATE"
    exit 1
fi

# ── Make start-tunnel.sh executable ───────────────────────────
chmod +x "$SCRIPT_PATH"
echo "✅ Made start-tunnel.sh executable"

# ── Create log directory ───────────────────────────────────────
mkdir -p "$LOG_DIR"
echo "✅ Log directory: $LOG_DIR"

# ── Create LaunchAgents dir (usually exists) ───────────────────
mkdir -p "$LAUNCH_AGENTS_DIR"

# ── Install plist with correct paths ──────────────────────────
echo "📝 Installing LaunchAgent plist..."

sed \
    -e "s|SCRIPT_PATH_PLACEHOLDER|$SCRIPT_PATH|g" \
    -e "s|LOG_DIR_PLACEHOLDER|$LOG_DIR|g" \
    -e "s|HOME_PLACEHOLDER|$HOME|g" \
    "$PLIST_TEMPLATE" > "$PLIST_DEST"

echo "   ✅ Plist installed: $PLIST_DEST"

# ── Unload existing agent (if any) before re-registering ──────
if launchctl list | grep -q "com.kalix.ollama-tunnel" 2>/dev/null; then
    echo "🔄 Unloading existing LaunchAgent..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# ── Load and start the agent ───────────────────────────────────
echo "🚀 Loading LaunchAgent..."
launchctl load "$PLIST_DEST"

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  ✅ Auto-start installed successfully!"
echo "══════════════════════════════════════════════════════════"
echo ""
echo "  The tunnel will now start automatically on every login."
echo ""
echo "  📋 Useful commands:"
echo ""
echo "  Check status:"
echo "    launchctl list | grep ollama-tunnel"
echo ""
echo "  View logs:"
echo "    tail -f $LOG_DIR/tunnel.log"
echo ""
echo "  Stop tunnel:"
echo "    launchctl stop com.kalix.ollama-tunnel"
echo ""
echo "  Start tunnel:"
echo "    launchctl start com.kalix.ollama-tunnel"
echo ""
echo "  Remove auto-start:"
echo "    bash $SCRIPT_DIR/uninstall.sh"
echo ""
