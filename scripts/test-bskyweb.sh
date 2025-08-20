#!/bin/bash

# Test script to verify bskyweb configuration

echo "🔍 Testing bskyweb configuration..."

# Check if the binary exists
if [ -f "/home/bluesky/social-app/bskyweb/bskyweb" ]; then
    echo "✅ bskyweb binary found"
    ls -la /home/bluesky/social-app/bskyweb/bskyweb
else
    echo "❌ bskyweb binary not found"
    exit 1
fi

# Check the service configuration
echo ""
echo "📋 Service configuration:"
sudo systemctl show bluesky-web -p Environment

# Test the bskyweb command with our configuration
echo ""
echo "🧪 Testing bskyweb command..."
cd /home/bluesky/social-app/bskyweb

# Test with explicit parameters
echo "Testing: ./bskyweb serve --appview-host=https://pdsapi.sfproject.net --debug"
timeout 5s ./bskyweb serve --appview-host=https://pdsapi.sfproject.net --debug &
BSKYWEB_PID=$!
sleep 2

# Check if it's running
if ps -p $BSKYWEB_PID > /dev/null; then
    echo "✅ bskyweb started successfully"
    
    # Test connectivity to PDS
    echo ""
    echo "🌐 Testing connectivity to PDS..."
    if curl -s -o /dev/null -w "%{http_code}" "https://pdsapi.sfproject.net/xrpc/com.atproto.server.describeServer" | grep -q "200"; then
        echo "✅ PDS server is reachable"
    else
        echo "❌ PDS server is not reachable"
    fi
    
    # Kill the test process
    kill $BSKYWEB_PID 2>/dev/null
else
    echo "❌ bskyweb failed to start"
fi

echo ""
echo "📊 Current service status:"
sudo systemctl status bluesky-web --no-pager -l

echo ""
echo "📝 Recent service logs:"
sudo journalctl -u bluesky-web --no-pager -n 20
