#!/bin/bash

# =============================================================================
# Bluesky Systemd Service Setup Script
# =============================================================================
# This script creates and configures systemd services for all Bluesky components

set -e

echo "🔧 Setting up systemd services for Bluesky components..."
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

# Create bluesky user if it doesn't exist
if ! id "bluesky" &>/dev/null; then
    echo "👤 Creating bluesky user..."
    useradd -m -s /bin/bash bluesky
    usermod -aG sudo bluesky
    echo "✅ bluesky user created"
else
    echo "✅ bluesky user already exists"
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

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/pds
Environment=NODE_ENV=production
Environment=PDS_HOSTNAME=${PDS_HOSTNAME:-pdsapi.sfproject.net}
Environment=PDS_PORT=2583
Environment=PDS_SERVICE_DID=did:web:${PDS_HOSTNAME:-pdsapi.sfproject.net}
Environment=PDS_DATA_DIRECTORY=/home/bluesky/data/pds
Environment=PDS_BLOBSTORE_DISK_LOCATION=/home/bluesky/data/blobs
Environment=PDS_REPO_SIGNING_KEY_K256_PRIVATE_KEY_HEX=${PDS_REPO_SIGNING_KEY_K256_PRIVATE_KEY_HEX}
Environment=PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=${PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX}
Environment=PDS_DPOP_SECRET=${PDS_DPOP_SECRET}
Environment=PDS_JWT_SECRET=${PDS_JWT_SECRET}
Environment=PDS_ADMIN_PASSWORD=${PDS_ADMIN_PASSWORD}
Environment=PDS_DID_PLC_URL=${PDS_DID_PLC_URL:-https://plc.sfproject.net}
Environment=PDS_BSKY_APP_VIEW_URL=${PDS_BSKY_APP_VIEW_URL:-https://bsky.sfproject.net}
Environment=PDS_BSKY_APP_VIEW_DID=did:web:${BSKY_HOSTNAME:-bsky.sfproject.net}
Environment=PDS_OAUTH_PROVIDER_NAME=${PDS_OAUTH_PROVIDER_NAME:-SF Project Bluesky}
Environment=PDS_OAUTH_PROVIDER_PRIMARY_COLOR=${PDS_OAUTH_PROVIDER_PRIMARY_COLOR:-#0085ff}
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create AppView service
echo "📝 Creating AppView service..."
cat > /etc/systemd/system/bluesky-appview.service << EOF
[Unit]
Description=Bluesky AppView
After=network.target postgresql.service redis-server.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/bsky
Environment=NODE_ENV=production
Environment=BSKY_PUBLIC_URL=${BSKY_PUBLIC_URL:-https://bsky.sfproject.net}
Environment=BSKY_SERVER_DID=did:web:${BSKY_HOSTNAME:-bsky.sfproject.net}
Environment=BSKY_DID_PLC_URL=${BSKY_DID_PLC_URL:-https://plc.sfproject.net}
Environment=BSKY_DATAPLANE_URL=${BSKY_DATAPLANE_URL:-https://pdsapi.sfproject.net}
Environment=BSKY_SERVICE_SIGNING_KEY=${BSKY_SERVICE_SIGNING_KEY}
Environment=BSKY_ADMIN_PASSWORDS=${BSKY_ADMIN_PASSWORDS}
Environment=BSKY_PORT=3000
Environment=BSKY_VERSION=1.0.0
Environment=BSKY_IMG_URI_ENDPOINT=${BSKY_IMG_URI_ENDPOINT:-https://bsky.sfproject.net/img}
Environment=BSKY_BLOB_CACHE_LOC=/home/bluesky/data/cache
Environment=BSKY_COURIER_URL=${BSKY_COURIER_URL:-https://chat.sfproject.net}
Environment=BSKY_COURIER_API_KEY=${BSKY_COURIER_API_KEY}
Environment=BSKY_BSYNC_URL=${BSKY_BSYNC_URL:-https://bsync.sfproject.net}
Environment=BSKY_BSYNC_API_KEY=${BSKY_BSYNC_API_KEY}
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps api.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Ozone service
echo "📝 Creating Ozone service..."
cat > /etc/systemd/system/bluesky-ozone.service << EOF
[Unit]
Description=Bluesky Ozone Moderation
After=network.target postgresql.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/ozone
Environment=NODE_ENV=production
Environment=OZONE_PUBLIC_URL=${OZONE_PUBLIC_URL:-https://ozone.sfproject.net}
Environment=OZONE_SERVER_DID=did:web:${OZONE_HOSTNAME:-ozone.sfproject.net}
Environment=OZONE_APPVIEW_URL=${OZONE_APPVIEW_URL:-https://bsky.sfproject.net}
Environment=OZONE_APPVIEW_DID=did:web:${BSKY_HOSTNAME:-bsky.sfproject.net}
Environment=OZONE_PDS_URL=${OZONE_PDS_URL:-https://pdsapi.sfproject.net}
Environment=OZONE_PDS_DID=did:web:${PDS_HOSTNAME:-pdsapi.sfproject.net}
Environment=OZONE_DB_POSTGRES_URL=postgresql://bluesky:${POSTGRES_PASSWORD:-bluesky_password}@localhost:5432/bluesky
Environment=OZONE_DID_PLC_URL=${OZONE_DID_PLC_URL:-https://plc.sfproject.net}
Environment=OZONE_ADMIN_PASSWORD=${OZONE_ADMIN_PASSWORD}
Environment=OZONE_SIGNING_KEY_HEX=${OZONE_SIGNING_KEY_HEX}
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps api.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Bsync service
echo "📝 Creating Bsync service..."
cat > /etc/systemd/system/bluesky-bsync.service << EOF
[Unit]
Description=Bluesky Background Sync
After=network.target postgresql.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/bsync
Environment=NODE_ENV=production
Environment=BSYNC_PORT=3000
Environment=BSYNC_DB_POSTGRES_URL=postgresql://bluesky:${POSTGRES_PASSWORD:-bluesky_password}@localhost:5432/bluesky
Environment=BSYNC_API_KEYS=${BSYNC_API_KEYS}
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Web Frontend service
echo "📝 Creating Web Frontend service..."
cat > /etc/systemd/system/bluesky-web.service << EOF
[Unit]
Description=Bluesky Web Frontend
After=network.target

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/social-app
Environment=NODE_ENV=production
Environment=EXPO_PUBLIC_ENV=production
Environment=EXPO_PUBLIC_RELEASE_VERSION=1.0.0
Environment=EXPO_PUBLIC_BUNDLE_IDENTIFIER=com.bluesky.selfhost
Environment=BSKY_PUBLIC_URL=${BSKY_PUBLIC_URL:-https://bsky.sfproject.net}
Environment=BSKY_SERVER_DID=did:web:${BSKY_HOSTNAME:-bsky.sfproject.net}
ExecStart=/usr/bin/yarn start-web
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl daemon-reload

# Enable services
echo "✅ Enabling services..."
systemctl enable bluesky-pds
systemctl enable bluesky-appview
systemctl enable bluesky-ozone
systemctl enable bluesky-bsync
systemctl enable bluesky-web

echo ""
echo "🎉 Systemd services created and enabled!"
echo ""
echo "📋 Service Status:"
echo "=================================="
echo "PDS Service:        bluesky-pds"
echo "AppView Service:    bluesky-appview"
echo "Ozone Service:      bluesky-ozone"
echo "Bsync Service:      bluesky-bsync"
echo "Web Frontend:       bluesky-web"
echo ""
echo "🚀 To start all services:"
echo "   sudo systemctl start bluesky-pds"
echo "   sudo systemctl start bluesky-appview"
echo "   sudo systemctl start bluesky-ozone"
echo "   sudo systemctl start bluesky-bsync"
echo "   sudo systemctl start bluesky-web"
echo ""
echo "📊 To check service status:"
echo "   sudo systemctl status bluesky-pds"
echo "   sudo systemctl status bluesky-appview"
echo "   sudo systemctl status bluesky-ozone"
echo "   sudo systemctl status bluesky-bsync"
echo "   sudo systemctl status bluesky-web"
echo ""
echo "📝 To view logs:"
echo "   sudo journalctl -u bluesky-pds -f"
echo "   sudo journalctl -u bluesky-appview -f"
echo "   sudo journalctl -u bluesky-ozone -f"
echo "   sudo journalctl -u bluesky-bsync -f"
echo "   sudo journalctl -u bluesky-web -f"
