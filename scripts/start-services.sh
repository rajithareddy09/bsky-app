#!/bin/bash

# =============================================================================
# Bluesky Services Startup Script
# =============================================================================
# This script starts all Bluesky services in the correct order
# and monitors their migration progress

set -e

echo "🚀 Starting Bluesky services in sequence..."
echo "=============================================="

# Function to wait for service to be ready
wait_for_service() {
    local service_name=$1
    local max_attempts=30
    local attempt=1
    
    echo "⏳ Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if systemctl is-active --quiet $service_name; then
            # Check if service is responding (not just running)
            if [ "$service_name" = "bluesky-pds" ]; then
                # Test PDS health endpoint
                if curl -s -f "http://localhost:2583/xrpc/_health" > /dev/null 2>&1; then
                    echo "✅ $service_name is ready and responding"
                    return 0
                fi
            elif [ "$service_name" = "bluesky-appview" ]; then
                # Test AppView health endpoint
                if curl -s -f "http://localhost:2584/xrpc/_health" > /dev/null 2>&1; then
                    echo "✅ $service_name is ready and responding"
                    return 0
                fi
            elif [ "$service_name" = "bluesky-ozone" ]; then
                # Test Ozone health endpoint
                if curl -s -f "http://localhost:3001/xrpc/_health" > /dev/null 2>&1; then
                    echo "✅ $service_name is ready and responding"
                    return 0
                fi
            elif [ "$service_name" = "bluesky-bsync" ]; then
                # Test Bsync health endpoint
                if curl -s -f "http://localhost:3002/xrpc/_health" > /dev/null 2>&1; then
                    echo "✅ $service_name is ready and responding"
                    return 0
                fi
            else
                echo "✅ $service_name is running"
                return 0
            fi
        fi
        
        echo "⏳ Attempt $attempt/$max_attempts - waiting for $service_name..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo "❌ $service_name failed to become ready after $max_attempts attempts"
    return 1
}

# Function to check service logs for migration progress
check_migration_logs() {
    local service_name=$1
    echo ""
    echo "📋 Checking $service_name logs for migration progress..."
    echo "=================================================="
    
    # Show recent logs
    sudo journalctl -u $service_name --no-pager -n 20 | grep -E "(migration|table|schema|database|error|fail)" || echo "No migration-related logs found"
}

# Step 1: Start PDS first (creates core database schema)
echo ""
echo "🔧 Step 1: Starting PDS service..."
sudo systemctl start bluesky-pds
wait_for_service bluesky-pds
check_migration_logs bluesky-pds

# Step 2: Start AppView (depends on PDS)
echo ""
echo "🔧 Step 2: Starting AppView service..."
sudo systemctl start bluesky-appview
wait_for_service bluesky-appview
check_migration_logs bluesky-appview

# Step 3: Start Ozone (depends on both PDS and AppView)
echo ""
echo "🔧 Step 3: Starting Ozone service..."
sudo systemctl start bluesky-ozone
wait_for_service bluesky-ozone
check_migration_logs bluesky-ozone

# Step 4: Start Bsync (depends on PDS and AppView)
echo ""
echo "🔧 Step 4: Starting Bsync service..."
sudo systemctl start bluesky-bsync
wait_for_service bluesky-bsync
check_migration_logs bluesky-bsync

# Step 5: Start Web Frontend (depends on all backend services)
echo ""
echo "🔧 Step 5: Starting Web Frontend..."
sudo systemctl start bluesky-web
wait_for_service bluesky-web

echo ""
echo "🎉 All services started successfully!"
echo "====================================="

# Final status check
echo ""
echo "📊 Final service status:"
sudo systemctl status bluesky-* --no-pager

echo ""
echo "🔍 To monitor specific service logs:"
echo "   sudo journalctl -u bluesky-pds -f"
echo "   sudo journalctl -u bluesky-appview -f"
echo "   sudo journalctl -u bluesky-ozone -f"
echo "   sudo journalctl -u bluesky-bsync -f"
echo "   sudo journalctl -u bluesky-web -f"

echo ""
echo "🌐 Test your services:"
echo "   PDS: http://localhost:2583/xrpc/_health"
echo "   AppView: http://localhost:3000/xrpc/_health"
echo "   Ozone: http://localhost:3001/xrpc/_health"
echo "   Bsync: http://localhost:3002/xrpc/_health"
echo "   Web: http://localhost:8100"
