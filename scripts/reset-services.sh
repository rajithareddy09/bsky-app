#!/bin/bash

# =============================================================================
# Bluesky Services Reset Script
# =============================================================================
# This script resets all Bluesky services to a clean state

set -e

echo "🔄 Resetting Bluesky services to clean state..."
echo "================================================"

# Stop all services
echo "🛑 Stopping all services..."
sudo systemctl stop bluesky-web 2>/dev/null || echo "Web service already stopped"
sudo systemctl stop bluesky-bsync 2>/dev/null || echo "Bsync service already stopped"
sudo systemctl stop bluesky-ozone 2>/dev/null || echo "Ozone service already stopped"
sudo systemctl stop bluesky-appview 2>/dev/null || echo "AppView service already stopped"
sudo systemctl stop bluesky-pds 2>/dev/null || echo "PDS service already stopped"

# Wait a moment for services to fully stop
sleep 3

# Check if any services are still running
echo "🔍 Checking for any remaining running services..."
if systemctl is-active --quiet bluesky-*; then
    echo "⚠️  Some services are still running, forcing stop..."
    sudo systemctl stop bluesky-* || true
    sleep 2
fi

# Reset failed service states
echo "🔄 Resetting failed service states..."
sudo systemctl reset-failed bluesky-* 2>/dev/null || echo "No failed services to reset"

# Clear service logs (optional - comment out if you want to keep logs)
echo "🧹 Clearing service logs..."
sudo journalctl --vacuum-time=1s --unit=bluesky-* 2>/dev/null || echo "No logs to clear"

# Verify all services are stopped
echo "✅ Verifying all services are stopped..."
if systemctl is-active --quiet bluesky-*; then
    echo "❌ Some services are still running:"
    systemctl is-active bluesky-*
else
    echo "✅ All services are stopped"
fi

echo ""
echo "🎯 Services have been reset to clean state"
echo ""
echo "📋 Next steps:"
echo "1. Run the startup script:"
echo "   sudo ./scripts/start-services.sh"
echo ""
echo "2. Or start services manually in order:"
echo "   sudo systemctl start bluesky-pds"
echo "   sudo systemctl start bluesky-appview"
echo "   sudo systemctl start bluesky-ozone"
echo "   sudo systemctl start bluesky-bsync"
echo "   sudo systemctl start bluesky-web"
echo ""
echo "3. Monitor progress:"
echo "   sudo journalctl -u bluesky-pds -f"
