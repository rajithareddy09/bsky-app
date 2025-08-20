#!/bin/bash

# =============================================================================
# Bluesky Systemd Service Setup Script
# =============================================================================
# This script creates systemd services for all Bluesky components

set -e

echo "⚙️ Setting up Bluesky systemd services..."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found. Please run the key generation script first."
    exit 1
fi

# Get domain from environment or prompt user
DOMAIN="${PDS_HOSTNAME:-}"
if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain (e.g., yourdomain.com): " DOMAIN
fi

# Remove any protocol prefixes
DOMAIN=$(echo "$DOMAIN" | sed 's|^https?://||' | sed 's|^pdsapi\.||')

# Create bluesky user if it doesn't exist
if ! id "bluesky" &>/dev/null; then
    echo "👤 Creating bluesky user..."
    useradd -m -s /bin/bash bluesky
    usermod -aG sudo bluesky
    echo "✅ Bluesky user created"
else
    echo "✅ Bluesky user already exists"
fi

# Create data directories
echo "📁 Creating data directories..."
mkdir -p /home/bluesky/data/{pds,blobs,cache}
chown -R bluesky:bluesky /home/bluesky/data
echo "✅ Data directories created"

# Create PDS service
echo "📝 Creating PDS service..."
cat > /etc/systemd/system/bluesky-pds.service << EOF
[Unit]
Description=Bluesky Personal Data Server
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/pds
Environment=NODE_ENV=production
Environment=PDS_HOSTNAME=pdsapi.$DOMAIN
Environment=PDS_PORT=2583
Environment=PDS_SERVICE_DID=did:web:pdsapi.$DOMAIN
Environment=PDS_DATA_DIRECTORY=/home/bluesky/data/pds
Environment=PDS_BLOBSTORE_DISK_LOCATION=/home/bluesky/data/blobs
Environment=PDS_REPO_SIGNING_KEY_K256_PRIVATE_KEY_HEX=\${PDS_REPO_SIGNING_KEY_K256_PRIVATE_KEY_HEX}
Environment=PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=\${PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX}
Environment=PDS_DPOP_SECRET=\${PDS_DPOP_SECRET}
Environment=PDS_JWT_SECRET=\${PDS_JWT_SECRET}
Environment=PDS_ADMIN_PASSWORD=\${PDS_ADMIN_PASSWORD}
Environment=PDS_DID_PLC_URL=https://plc.$DOMAIN
Environment=PDS_BSKY_APP_VIEW_URL=https://bsky.$DOMAIN
Environment=PDS_BSKY_APP_VIEW_DID=did:web:bsky.$DOMAIN
Environment=PDS_OAUTH_PROVIDER_NAME=Your Bluesky Instance
Environment=PDS_OAUTH_PROVIDER_PRIMARY_COLOR=#0085ff
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bluesky-pds

[Install]
WantedBy=multi-user.target
EOF

# Create AppView service
echo "📝 Creating AppView service..."
cat > /etc/systemd/system/bluesky-appview.service << EOF
[Unit]
Description=Bluesky AppView
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/bsky
Environment=NODE_ENV=production
Environment=BSKY_PUBLIC_URL=https://bsky.$DOMAIN
Environment=BSKY_SERVER_DID=did:web:bsky.$DOMAIN
Environment=BSKY_DID_PLC_URL=https://plc.$DOMAIN
Environment=BSKY_DATAPLANE_URL=https://pdsapi.$DOMAIN
Environment=BSKY_SERVICE_SIGNING_KEY=\${BSKY_SERVICE_SIGNING_KEY}
Environment=BSKY_ADMIN_PASSWORDS=\${BSKY_ADMIN_PASSWORDS}
Environment=BSKY_PORT=3000
Environment=BSKY_VERSION=1.0.0
Environment=BSKY_IMG_URI_ENDPOINT=https://bsky.$DOMAIN/img
Environment=BSKY_BLOB_CACHE_LOC=/home/bluesky/data/cache
Environment=BSKY_COURIER_URL=https://chat.$DOMAIN
Environment=BSKY_COURIER_API_KEY=\${BSKY_COURIER_API_KEY}
Environment=BSKY_BSYNC_URL=https://bsync.$DOMAIN
Environment=BSKY_BSYNC_API_KEY=\${BSKY_BSYNC_API_KEY}
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps api.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bluesky-appview

[Install]
WantedBy=multi-user.target
EOF

# Create Ozone service
echo "📝 Creating Ozone service..."
cat > /etc/systemd/system/bluesky-ozone.service << EOF
[Unit]
Description=Bluesky Ozone Moderation
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/ozone
Environment=NODE_ENV=production
Environment=OZONE_PUBLIC_URL=https://ozone.$DOMAIN
Environment=OZONE_SERVER_DID=did:web:ozone.$DOMAIN
Environment=OZONE_APPVIEW_URL=https://bsky.$DOMAIN
Environment=OZONE_APPVIEW_DID=did:web:bsky.$DOMAIN
Environment=OZONE_PDS_URL=https://pdsapi.$DOMAIN
Environment=OZONE_PDS_DID=did:web:pdsapi.$DOMAIN
Environment=OZONE_DB_POSTGRES_URL=postgresql://bluesky:\${POSTGRES_PASSWORD}@localhost:5432/bluesky
Environment=OZONE_DID_PLC_URL=https://plc.$DOMAIN
Environment=OZONE_ADMIN_PASSWORD=\${OZONE_ADMIN_PASSWORD}
Environment=OZONE_SIGNING_KEY_HEX=\${OZONE_SIGNING_KEY_HEX}
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps api.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bluesky-ozone

[Install]
WantedBy=multi-user.target
EOF

# Create Bsync service
echo "📝 Creating Bsync service..."
cat > /etc/systemd/system/bluesky-bsync.service << EOF
[Unit]
Description=Bluesky Background Sync
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/bsync
Environment=NODE_ENV=production
Environment=BSYNC_PORT=3002
Environment=BSYNC_DB_POSTGRES_URL=postgresql://bluesky:\${POSTGRES_PASSWORD}@localhost:5432/bluesky
Environment=BSYNC_API_KEYS=\${BSYNC_API_KEYS}
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bluesky-bsync

[Install]
WantedBy=multi-user.target
EOF

# Create Web Frontend service
echo "📝 Creating Web Frontend service..."
cat > /etc/systemd/system/bluesky-web.service << EOF
[Unit]
Description=Bluesky Web Frontend
After=network.target
Wants=network.target

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/social-app
Environment=NODE_ENV=production
Environment=PORT=8100
Environment=BSKY_SERVICE_URL=https://bsky.$DOMAIN
Environment=BSKY_PDS_URL=https://pdsapi.$DOMAIN
Environment=BSKY_OAUTH_REDIRECT_URL=https://app.$DOMAIN
ExecStart=/usr/bin/yarn start-web
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bluesky-web

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl daemon-reload

# Enable services
echo "🔧 Enabling services..."
systemctl enable bluesky-pds
systemctl enable bluesky-appview
systemctl enable bluesky-ozone
systemctl enable bluesky-bsync
systemctl enable bluesky-web

echo ""
echo "🎉 Systemd services created and enabled!"
echo ""
echo "📋 Created services:"
echo "=================================="
echo "• bluesky-pds      - Personal Data Server"
echo "• bluesky-appview  - AppView API"
echo "• bluesky-ozone    - Moderation interface"
echo "• bluesky-bsync    - Background sync"
echo "• bluesky-web      - Web frontend"
echo ""
echo "🚀 Management commands:"
echo "=================================="
echo "Start all services:"
echo "  sudo systemctl start bluesky-pds"
echo "  sudo systemctl start bluesky-appview"
echo "  sudo systemctl start bluesky-ozone"
echo "  sudo systemctl start bluesky-bsync"
echo "  sudo systemctl start bluesky-web"
echo ""
echo "Check service status:"
echo "  sudo systemctl status bluesky-pds"
echo "  sudo systemctl status bluesky-appview"
echo "  sudo systemctl status bluesky-ozone"
echo "  sudo systemctl status bluesky-bsync"
echo "  sudo systemctl status bluesky-web"
echo ""
echo "View service logs:"
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
echo "🌐 Service URLs:"
echo "=================================="
echo "Web App:           https://app.$DOMAIN"
echo "AppView API:       https://bsky.$DOMAIN"
echo "PDS API:           https://pdsapi.$DOMAIN"
echo "Ozone Moderation:  https://ozone.$DOMAIN"
echo "Bsync:             https://bsync.$DOMAIN"
echo ""
echo "⚠️  Note: Make sure to start the services after setting up SSL certificates!"
