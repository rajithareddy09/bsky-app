#!/bin/bash

# =============================================================================
# Bluesky Cryptographic Keys Generation Script
# =============================================================================
# This script generates all required cryptographic keys and secrets

set -e

echo "🔑 Generating cryptographic keys for Bluesky instance..."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Create keys directory
echo "📁 Creating keys directory..."
mkdir -p keys
chmod 700 keys

# Function to generate random hex string
generate_hex() {
    local length=$1
    openssl rand -hex $length
}

# Function to generate random base64 string
generate_base64() {
    local length=$1
    openssl rand -base64 $length
}

# Function to generate random password
generate_password() {
    local length=$1
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

echo "🔐 Generating PDS keys..."
# PDS Repo Signing Key (K256)
PDS_REPO_SIGNING_KEY_K256_PRIVATE_KEY_HEX=$(generate_hex 32)
echo "✅ PDS Repo Signing Key (K256) generated"

# PDS PLC Rotation Key (K256)
PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=$(generate_hex 32)
echo "✅ PDS PLC Rotation Key (K256) generated"

echo "🔐 Generating AppView keys..."
# AppView Service Signing Key (must be hex/base16)
BSKY_SERVICE_SIGNING_KEY=$(generate_hex 32)
echo "✅ AppView Service Signing Key generated (hex)"

echo "🔐 Generating Ozone keys..."
# Ozone Signing Key
OZONE_SIGNING_KEY_HEX=$(generate_hex 32)
echo "✅ Ozone Signing Key generated"

echo "🔐 Generating secrets..."
# Generate DPOP secret (must be exactly 64 characters)
echo "🔐 Generating DPOP secret..."
DPOP_SECRET=$(openssl rand -hex 32)
echo "✅ DPOP secret generated (64 chars): ${DPOP_SECRET:0:10}..."

# JWT Secret
PDS_JWT_SECRET=$(generate_base64 32)
echo "✅ JWT Secret generated"

# Bsync API Keys
BSYNC_API_KEYS=$(generate_base64 32)
echo "✅ Bsync API Keys generated"

# Courier API Key
BSKY_COURIER_API_KEY=$(generate_base64 32)
echo "✅ Courier API Key generated"

echo "🔐 Generating admin passwords..."
# Admin passwords
PDS_ADMIN_PASSWORD=$(generate_password 16)
OZONE_ADMIN_PASSWORD=$(generate_password 16)
BSKY_ADMIN_PASSWORDS=$(generate_password 16)
echo "✅ Admin passwords generated"

echo "🔐 Generating database password..."
# Database password
POSTGRES_PASSWORD=$(generate_password 16)
echo "✅ Database password generated"

# Save individual key files
echo "💾 Saving individual key files..."
echo "$PDS_REPO_SIGNING_KEY_K256_PRIVATE_KEY_HEX" > keys/pds_repo_signing_key_k256_private_key_hex.txt
echo "$PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX" > keys/pds_plc_rotation_key_k256_private_key_hex.txt
echo "$BSKY_SERVICE_SIGNING_KEY" > keys/bsky_service_signing_key.txt
echo "$OZONE_SIGNING_KEY_HEX" > keys/ozone_signing_key_hex.txt
echo "$DPOP_SECRET" > keys/pds_dpop_secret.txt
echo "$PDS_JWT_SECRET" > keys/pds_jwt_secret.txt
echo "$BSYNC_API_KEYS" > keys/bsync_api_keys.txt
echo "$BSKY_COURIER_API_KEY" > keys/bsky_courier_api_key.txt
echo "$PDS_ADMIN_PASSWORD" > keys/pds_admin_password.txt
echo "$OZONE_ADMIN_PASSWORD" > keys/ozone_admin_password.txt
echo "$BSKY_ADMIN_PASSWORDS" > keys/bsky_admin_passwords.txt
echo "$POSTGRES_PASSWORD" > keys/postgres_password.txt

# Set proper permissions
chmod 600 keys/*.txt
echo "✅ Key files saved with proper permissions"

# Create .env file
echo "📝 Creating .env file..."
cat > .env << EOF
# =============================================================================
# Bluesky Environment Configuration
# =============================================================================

# Domain Configuration
PDS_HOSTNAME=pdsapi.yourdomain.com
BSKY_HOSTNAME=bsky.yourdomain.com
OZONE_HOSTNAME=ozone.yourdomain.com
PLC_HOSTNAME=plc.yourdomain.com
BSYNC_HOSTNAME=bsync.yourdomain.com
INTROSPECT_HOSTNAME=introspect.yourdomain.com
CHAT_HOSTNAME=chat.yourdomain.com

# URLs
PDS_PUBLIC_URL=https://pdsapi.yourdomain.com
BSKY_PUBLIC_URL=https://bsky.yourdomain.com
OZONE_PUBLIC_URL=https://ozone.yourdomain.com
PLC_PUBLIC_URL=https://plc.yourdomain.com
BSYNC_PUBLIC_URL=https://bsync.yourdomain.com
INTROSPECT_PUBLIC_URL=https://introspect.yourdomain.com
CHAT_PUBLIC_URL=https://chat.yourdomain.com

# AppView Configuration
BSKY_PUBLIC_URL=https://bsky.yourdomain.com
BSKY_SERVER_DID=did:web:bsky.yourdomain.com
BSKY_DID_PLC_URL=https://plc.yourdomain.com
BSKY_DATAPLANE_URLS=https://pdsapi.yourdomain.com
BSKY_PORT=3000
BSKY_VERSION=1.0.0
BSKY_IMG_URI_ENDPOINT=https://bsky.yourdomain.com/img
BSKY_COURIER_URL=https://chat.yourdomain.com
BSKY_COURIER_API_KEY=$COURIER_API_KEY
BSKY_BSYNC_URL=https://bsync.yourdomain.com
BSKY_BSYNC_API_KEY=$BSYNC_API_KEY
BSKY_BLOB_CACHE_LOC=/home/bluesky/data/cache

# Ozone Configuration
OZONE_PUBLIC_URL=https://ozone.yourdomain.com
OZONE_SERVER_DID=did:web:ozone.yourdomain.com
OZONE_APPVIEW_URL=https://bsky.yourdomain.com
OZONE_APPVIEW_DID=did:web:bsky.yourdomain.com
OZONE_PDS_URL=https://pdsapi.yourdomain.com
OZONE_PDS_DID=did:web:pdsapi.yourdomain.com
OZONE_DID_PLC_URL=https://plc.yourdomain.com
OZONE_ADMIN_PASSWORD=$OZONE_ADMIN_PASSWORD
OZONE_SIGNING_KEY_HEX=$OZONE_SIGNING_KEY_HEX
MOD_SERVICE_DID=did:web:ozone.yourdomain.com
OZONE_PORT=3001

# Database Configuration
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DB_POSTGRES_URL=postgresql://bluesky:$POSTGRES_PASSWORD@localhost:5432/bluesky

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379

# PDS Keys and Secrets
PDS_REPO_SIGNING_KEY_K256_PRIVATE_KEY_HEX=$PDS_REPO_SIGNING_KEY_K256_PRIVATE_KEY_HEX
PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=$PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX
PDS_DPOP_SECRET=$DPOP_SECRET
PDS_JWT_SECRET=$PDS_JWT_SECRET
PDS_ADMIN_PASSWORD=$PDS_ADMIN_PASSWORD

# AppView Keys and Secrets
BSKY_SERVICE_SIGNING_KEY=$BSKY_SERVICE_SIGNING_KEY
BSKY_ADMIN_PASSWORDS=$BSKY_ADMIN_PASSWORDS
BSKY_COURIER_API_KEY=$BSKY_COURIER_API_KEY

# Ozone Keys and Secrets
OZONE_SIGNING_KEY_HEX=$OZONE_SIGNING_KEY_HEX
OZONE_ADMIN_PASSWORD=$OZONE_ADMIN_PASSWORD

# Bsync Keys and Secrets
BSYNC_API_KEYS=$BSYNC_API_KEYS

# Service Configuration
NODE_ENV=production
LOG_LEVEL=info

# Ports
PDS_PORT=2583
BSKY_PORT=3000
OZONE_PORT=3001
BSYNC_PORT=3002
WEB_PORT=8100
WEB_ATP_APPVIEW_HOST=https://pdsapi.yourdomain.com
WEB_ATP_PDS_HOST=https://pdsapi.yourdomain.com
WEB_HTTP_ADDRESS=:8100

# Data Directories
PDS_DATA_DIRECTORY=/home/bluesky/data/pds
PDS_BLOBSTORE_DISK_LOCATION=/home/bluesky/data/blobs
PDS_BLOBSTORE_DISK_ENABLED=true
PDS_BLOBSTORE_DISK_TEMP_LOCATION=/home/bluesky/data/blobs/temp
PDS_BLOBSTORE_DISK_MAX_FILE_SIZE=104857600
PDS_BLOBSTORE_DISK_MAX_FILE_SIZE_KB=102400
PDS_BLOBSTORE_DISK_MAX_FILE_SIZE_MB=100
PDS_BLOBSTORE_DISK_MAX_FILE_SIZE_GB=0.1
BSKY_BLOB_CACHE_LOC=/home/bluesky/data/cache

# OAuth Configuration
PDS_OAUTH_PROVIDER_NAME=Your Bluesky Instance
PDS_OAUTH_PROVIDER_PRIMARY_COLOR=#0085ff

# Version Information
BSKY_VERSION=1.0.0
EOF

chmod 600 .env
echo "✅ .env file created"

echo ""
echo "🎉 Cryptographic keys generation completed!"
echo ""
echo "📋 Generated keys and secrets:"
echo "=================================="
echo "✅ PDS Repo Signing Key (K256)"
echo "✅ PDS PLC Rotation Key (K256)"
echo "✅ AppView Service Signing Key"
echo "✅ Ozone Signing Key"
echo "✅ DPOP Secret"
echo "✅ JWT Secret"
echo "✅ Bsync API Keys"
echo "✅ Courier API Key"
echo "✅ Admin Passwords"
echo "✅ Database Password"
echo ""
echo "📁 Files created:"
echo "=================================="
echo "• keys/ - Directory containing individual key files"
echo "• .env - Environment configuration file"
echo ""
echo "🔒 Security notes:"
echo "=================================="
echo "• All key files have restricted permissions (600)"
echo "• Keys directory has restricted permissions (700)"
echo "• .env file has restricted permissions (600)"
echo "• Keep these files secure and backup safely"
echo "• Never commit keys to version control"
echo ""
echo "📝 Next steps:"
echo "=================================="
echo "1. Edit the .env file to update domain names:"
echo "   nano .env"
echo ""
echo "2. Update the domain configuration in .env:"
echo "   Replace 'yourdomain.com' with your actual domain"
echo ""
echo "3. Continue with the setup process"
echo ""
echo "⚠️  Important: Keep your keys secure!"
echo "=================================="
echo "• Backup the keys/ directory securely"
echo "• Store keys in a password manager"
echo "• Use different keys for production vs development"
echo "• Rotate keys periodically for security"
