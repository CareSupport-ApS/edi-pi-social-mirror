#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# 🖥️ SOCIAL MIRROR - DISPLAY INITIALIZATION SCRIPT
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

LOG_FILE="/var/log/social-mirror-display.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

log "🖥️ Starting X server as root..."

# Check if X server is already running
if pgrep -x "Xorg" > /dev/null; then
    log "✅ X server already running"
    exit 0
fi

# Create minimal .xinitrc
if [[ ! -f "/root/.xinitrc" ]]; then
    echo "exec openbox-session" > "/root/.xinitrc"
    chmod +x "/root/.xinitrc"
fi

# Start X server as root
export DISPLAY=:0
startx &

# Wait for X server
for i in {1..30}; do
    if DISPLAY=:0 xset q >/dev/null 2>&1; then
        log "✅ X server ready"
        exit 0
    fi
    sleep 1
done

log "❌ X server failed to start"
exit 1