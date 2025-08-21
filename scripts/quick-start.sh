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
#./scripts/install-dependencies.sh


# Step 3: Build atproto (using Node.js 18)
echo ""
echo "🔨 Step 3: Building atproto (Node.js 18)..."
cd atproto
bash -c 'source $HOME/.nvm/nvm.sh  && nvm use 18 && pnpm install'
bash -c 'source $HOME/.nvm/nvm.sh  && nvm use 18 && pnpm build'
cd ..
echo "✅ atproto built successfully"

# Step 4: Build social-app (using Node.js 20)
echo ""
echo "🔨 Step 4: Building social-app (Node.js 20)..."
cd social-app
# Set CI environment to skip husky git hooks
bash -c 'source $HOME/.nvm/nvm.sh  && nvm use 20 && CI=true yarn install'
bash -c 'source $HOME/.nvm/nvm.sh  && nvm use 20 && CI=true yarn build-web'
echo "✅ social-app built successfully"

# Step 4.5: Build Go-based bskyweb server
echo ""
echo "🔨 Step 4.5: Building Go-based bskyweb server..."
cd bskyweb
# Install Go if not present
if ! command -v go &> /dev/null; then
    echo "📦 Installing Go..."
    wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
fi

# Ensure Go modules are properly set up
echo "📦 Setting up Go modules..."
go mod download
go mod verify

# Clean any existing binary
rm -f bskyweb

# Build the bskyweb binary with proper template embedding
echo "🔨 Building bskyweb with embedded templates..."
go build -o bskyweb ./cmd/bskyweb

# Verify the binary was created
if [ -f "bskyweb" ]; then
    echo "✅ bskyweb Go server built successfully at $(pwd)/bskyweb"
    echo "📏 Binary size: $(ls -lh bskyweb | awk '{print $5}')"
    
    # Test if the binary can run and has templates
    echo "🧪 Testing binary..."
    if timeout 5s ./bskyweb serve --help > /dev/null 2>&1; then
        echo "✅ Binary is executable and responds to --help"
    else
        echo "❌ Binary failed to respond to --help"
    fi
else
    echo "❌ Failed to build bskyweb binary"
    exit 1
fi

# Ensure the binary is executable
chmod +x bskyweb

cd ..

# Step 5: Generate keys
echo ""
echo "🔑 Step 5: Generating cryptographic keys..."
#./scripts/generate-keys.sh

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
#./scripts/setup-systemd.sh


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
