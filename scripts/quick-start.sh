#!/bin/bash

# =============================================================================
# Bluesky Quick Start Script
# =============================================================================
# This script automates the entire setup process for a self-hosted Bluesky instance

set -e

echo "🚀 Bluesky Self-Hosted Quick Start"
echo "=================================="
echo ""
echo "This script will set up a complete Bluesky instance on your server."
echo "Make sure you have:"
echo "1. A fresh Ubuntu/Debian server"
echo "2. Root access"
echo "3. Your domain configured with the required subdomains"
echo ""
echo "Required subdomains:"
echo "- app.sfproject.net"
echo "- bsky.sfproject.net"
echo "- pdsapi.sfproject.net"
echo "- ozone.sfproject.net"
echo "- plc.sfproject.net"
echo "- bsync.sfproject.net"
echo "- introspect.sfproject.net"
echo "- chat.sfproject.net"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Confirm installation
read -p "Do you want to proceed with the installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

echo ""
echo "🔧 Starting installation process..."
echo ""

# Step 1: Install system dependencies
echo "📦 Step 1: Installing system dependencies..."
./scripts/install-dependencies.sh

# Step 2: Clone repositories
echo ""
echo "📥 Step 2: Cloning repositories..."
if [ ! -d "atproto" ]; then
    echo "Cloning atproto repository..."
    git clone https://github.com/bluesky-social/atproto.git
else
    echo "atproto repository already exists"
fi

if [ ! -d "social-app" ]; then
    echo "Cloning social-app repository..."
    git clone https://github.com/bluesky-social/social-app.git
else
    echo "social-app repository already exists"
fi

# Step 3: Build atproto
echo ""
echo "🔨 Step 3: Building atproto..."
cd atproto
pnpm install
pnpm build
cd ..

# Step 4: Build social-app
echo ""
echo "🔨 Step 4: Building social-app..."
cd social-app
yarn install
yarn build-web
cd ..

# Step 5: Generate cryptographic keys
echo ""
echo "🔑 Step 5: Generating cryptographic keys..."
./scripts/generate-keys.sh

# Step 6: Configure environment
echo ""
echo "⚙️ Step 6: Configuring environment..."
if [ ! -f ".env" ]; then
    cp env.example .env
    echo "✅ Environment file created from template"
    echo "⚠️  Please edit .env file with your domain configuration before continuing"
    echo ""
    read -p "Press Enter after you have configured the .env file..."
else
    echo "✅ Environment file already exists"
fi

# Step 7: Set up systemd services
echo ""
echo "🔧 Step 7: Setting up systemd services..."
./scripts/setup-systemd.sh

# Step 8: Configure Nginx
echo ""
echo "🌐 Step 8: Configuring Nginx..."
./scripts/setup-nginx.sh

# Step 9: Copy source code to bluesky user
echo ""
echo "📁 Step 9: Setting up file permissions..."
cp -r atproto /home/bluesky/
cp -r social-app /home/bluesky/
chown -R bluesky:bluesky /home/bluesky/atproto
chown -R bluesky:bluesky /home/bluesky/social-app

# Step 10: Start services
echo ""
echo "🚀 Step 10: Starting services..."
systemctl start bluesky-pds
systemctl start bluesky-appview
systemctl start bluesky-ozone
systemctl start bluesky-bsync
systemctl start bluesky-web

# Step 11: Wait for services to start
echo ""
echo "⏳ Step 11: Waiting for services to start..."
sleep 10

# Step 12: Check service status
echo ""
echo "📊 Step 12: Checking service status..."
echo ""

services=("bluesky-pds" "bluesky-appview" "bluesky-ozone" "bluesky-bsync" "bluesky-web")
all_running=true

for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "✅ $service: Running"
    else
        echo "❌ $service: Not running"
        all_running=false
    fi
done

echo ""
if [ "$all_running" = true ]; then
    echo "🎉 All services are running successfully!"
else
    echo "⚠️  Some services failed to start. Check logs with:"
    echo "   sudo journalctl -u service-name -f"
fi

echo ""
echo "🔐 Step 13: SSL Certificate Setup"
echo "=================================="
echo "You need to obtain SSL certificates for all subdomains."
echo "Run the following commands:"
echo ""
echo "sudo certbot --nginx -d app.sfproject.net"
echo "sudo certbot --nginx -d bsky.sfproject.net"
echo "sudo certbot --nginx -d pdsapi.sfproject.net"
echo "sudo certbot --nginx -d ozone.sfproject.net"
echo "sudo certbot --nginx -d bsync.sfproject.net"
echo "sudo certbot --nginx -d introspect.sfproject.net"
echo "sudo certbot --nginx -d chat.sfproject.net"
echo "sudo certbot --nginx -d plc.sfproject.net"
echo ""
echo "Set up auto-renewal:"
echo "sudo crontab -e"
echo "Add: 0 12 * * * /usr/bin/certbot renew --quiet"
echo ""

echo "🎉 Installation completed!"
echo ""
echo "📋 Your Bluesky instance is now running on:"
echo "=================================="
echo "Web App:           https://app.sfproject.net"
echo "AppView API:       https://bsky.sfproject.net"
echo "PDS API:           https://pdsapi.sfproject.net"
echo "Ozone Moderation:  https://ozone.sfproject.net"
echo "Bsync:             https://bsync.sfproject.net"
echo "Introspect:        https://introspect.sfproject.net"
echo "Chat:              https://chat.sfproject.net"
echo "PLC:               https://plc.sfproject.net"
echo ""
echo "🔧 Management Commands:"
echo "=================================="
echo "Check service status:"
echo "  sudo systemctl status bluesky-pds"
echo "  sudo systemctl status bluesky-appview"
echo "  sudo systemctl status bluesky-ozone"
echo "  sudo systemctl status bluesky-bsync"
echo "  sudo systemctl status bluesky-web"
echo ""
echo "View logs:"
echo "  sudo journalctl -u bluesky-pds -f"
echo "  sudo journalctl -u bluesky-appview -f"
echo "  sudo journalctl -u bluesky-ozone -f"
echo "  sudo journalctl -u bluesky-bsync -f"
echo "  sudo journalctl -u bluesky-web -f"
echo ""
echo "Restart services:"
echo "  sudo systemctl restart bluesky-pds"
echo "  sudo systemctl restart bluesky-appview"
echo "  sudo systemctl restart bluesky-ozone"
echo "  sudo systemctl restart bluesky-bsync"
echo "  sudo systemctl restart bluesky-web"
echo ""
echo "🔐 Create your first admin account:"
echo "=================================="
echo "curl -X POST https://pdsapi.sfproject.net/xrpc/com.atproto.server.createAccount \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{"
echo "    \"email\": \"admin@sfproject.net\","
echo "    \"handle\": \"admin.sfproject.net\","
echo "    \"password\": \"your_secure_password\""
echo "  }'"
echo ""
echo "📚 Documentation:"
echo "=================================="
echo "For detailed information, see DEPLOYMENT-GUIDE.md"
echo ""
echo "🎊 Congratulations! Your self-hosted Bluesky instance is ready!"
