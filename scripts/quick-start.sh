#!/bin/bash

# =============================================================================
# Bluesky Quick Start Script
# =============================================================================
# This script automates the complete setup of a self-hosted Bluesky instance

set -e

echo "🚀 Bluesky Self-Hosted Quick Start"
echo "=================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Get domain from user
read -p "Enter your domain (e.g., yourdomain.com): " DOMAIN

# Remove any protocol prefixes
DOMAIN=$(echo "$DOMAIN" | sed 's|^https?://||' | sed 's|^pdsapi\.||')

echo ""
echo "🌐 Using domain: $DOMAIN"
echo ""

# Step 1: Install dependencies
echo "📦 Step 1: Installing system dependencies..."
./scripts/install-dependencies.sh



# Step 3: Build atproto
echo ""
echo "🔨 Step 3: Building atproto..."
cd atproto
pnpm install
pnpm build
cd ..
echo "✅ atproto built successfully"

# Step 4: Build social-app
echo ""
echo "🔨 Step 4: Building social-app..."
cd social-app
yarn install
yarn build-web
cd ..
echo "✅ social-app built successfully"

# Step 5: Generate keys
echo ""
echo "🔑 Step 5: Generating cryptographic keys..."
./scripts/generate-keys.sh

# Step 6: Configure environment
echo ""
echo "⚙️ Step 6: Configuring environment..."
if [ ! -f ".env" ]; then
    cp env.example .env
    echo "✅ Environment file created from template"
else
    echo "✅ Environment file already exists"
fi

echo ""
echo "📝 Please edit the .env file with your domain configuration:"
echo "   nano .env"
echo ""
echo "Make sure to update these variables:"
echo "   PDS_HOSTNAME=pdsapi.$DOMAIN"
echo "   BSKY_HOSTNAME=bsky.$DOMAIN"
echo "   OZONE_HOSTNAME=ozone.$DOMAIN"
echo "   PLC_HOSTNAME=plc.$DOMAIN"
echo "   BSYNC_HOSTNAME=bsync.$DOMAIN"
echo "   INTROSPECT_HOSTNAME=introspect.$DOMAIN"
echo "   CHAT_HOSTNAME=chat.$DOMAIN"
echo ""
read -p "Press Enter after you've configured the .env file..."

# Step 7: Set up systemd services
echo ""
echo "⚙️ Step 7: Setting up systemd services..."
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
echo "✅ Source code copied to bluesky user"

# Step 10: Start services
echo ""
echo "🚀 Step 10: Starting services..."
systemctl start bluesky-pds
systemctl start bluesky-appview
systemctl start bluesky-ozone
systemctl start bluesky-bsync
systemctl start bluesky-web

# Step 11: Check service status
echo ""
echo "📊 Step 11: Checking service status..."
echo "PDS Service: $(systemctl is-active bluesky-pds)"
echo "AppView Service: $(systemctl is-active bluesky-appview)"
echo "Ozone Service: $(systemctl is-active bluesky-ozone)"
echo "Bsync Service: $(systemctl is-active bluesky-bsync)"
echo "Web Service: $(systemctl is-active bluesky-web)"

echo ""
echo "🎊 Congratulations! Your self-hosted Bluesky instance is ready!"
echo ""
echo "📋 Next Steps:"
echo "=================================="
echo "1. Get SSL certificates for all subdomains:"
echo "   sudo certbot --nginx -d app.$DOMAIN"
echo "   sudo certbot --nginx -d bsky.$DOMAIN"
echo "   sudo certbot --nginx -d pdsapi.$DOMAIN"
echo "   sudo certbot --nginx -d ozone.$DOMAIN"
echo "   sudo certbot --nginx -d bsync.$DOMAIN"
echo "   sudo certbot --nginx -d introspect.$DOMAIN"
echo "   sudo certbot --nginx -d chat.$DOMAIN"
echo "   sudo certbot --nginx -d plc.$DOMAIN"
echo ""
echo "2. Set up auto-renewal:"
echo "   sudo crontab -e"
echo "   Add: 0 12 * * * /usr/bin/certbot renew --quiet"
echo ""
echo "3. Create your first admin account:"
echo "   curl -X POST https://pdsapi.$DOMAIN/xrpc/com.atproto.server.createAccount \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{"
echo "       \"email\": \"admin@$DOMAIN\","
echo "       \"handle\": \"admin.$DOMAIN\","
echo "       \"password\": \"your_secure_password\""
echo "     }'"
echo ""
echo "4. Access your instance:"
echo "   Web App: https://app.$DOMAIN"
echo "   Moderation: https://ozone.$DOMAIN"
echo "   API Docs: https://introspect.$DOMAIN"
echo ""
echo "5. Run health check:"
echo "   ./scripts/health-check.sh"
echo ""
echo "6. Create users and seed database:"
echo "   ./scripts/create-users.sh"
echo "   ./scripts/seed-database.sh"
echo ""
echo "🔒 Security Reminders:"
echo "=================================="
echo "• Change default passwords"
echo "• Set up regular backups"
echo "• Monitor system logs"
echo "• Keep system updated"
echo "• Configure monitoring"
echo ""
echo "📚 Useful Commands:"
echo "=================================="
echo "Check service status: sudo systemctl status bluesky-*"
echo "View logs: sudo journalctl -u bluesky-* -f"
echo "Restart services: sudo systemctl restart bluesky-*"
echo "Backup database: ./scripts/backup-database.sh"
echo "Health check: ./scripts/health-check.sh"
echo ""
echo "🎉 Setup complete! Your Bluesky instance is ready to use!"
