#!/bin/bash

# =============================================================================
# Bluesky Database Setup and Migration Script
# =============================================================================
# This script sets up the PostgreSQL database and runs migrations for all services

set -e

echo "🗄️ Setting up Bluesky database..."

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

# Database configuration
DB_NAME="bluesky"
DB_USER="bluesky"
DB_PASSWORD="${POSTGRES_PASSWORD:-bluesky_password}"

echo "🌐 Using domain: $DOMAIN"
echo "🗄️ Database: $DB_NAME"
echo "👤 Database user: $DB_USER"

# Create database and user if they don't exist
echo "📝 Creating database and user..."
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || echo "Database already exists"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';" 2>/dev/null || echo "User already exists"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null || echo "Privileges already granted"
sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;" 2>/dev/null || echo "User already has CREATEDB privilege"

echo "✅ Database setup complete"

# Run PDS migrations
echo "🔄 Running PDS database migrations..."
cd /home/bluesky/atproto/services/pds
sudo -u bluesky bash -c 'source ~/.bashrc && nvm use 18 && npm run db:migrate' || {
    echo "⚠️ PDS migrations failed, trying alternative method..."
    sudo -u bluesky bash -c 'source ~/.bashrc && nvm use 18 && node --require ts-node/register ../../packages/pds/src/db/migrate.ts'
}
echo "✅ PDS migrations complete"

# Run AppView migrations
echo "🔄 Running AppView database migrations..."
cd /home/bluesky/atproto/services/bsky
sudo -u bluesky bash -c 'source ~/.bashrc && nvm use 18 && npm run db:migrate' || {
    echo "⚠️ AppView migrations failed, trying alternative method..."
    sudo -u bluesky bash -c 'source ~/.bashrc && nvm use 18 && node --require ts-node/register ../../packages/bsky/src/db/migrate.ts'
}
echo "✅ AppView migrations complete"

# Run Ozone migrations
echo "🔄 Running Ozone database migrations..."
cd /home/bluesky/atproto/services/ozone
sudo -u bluesky bash -c 'source ~/.bashrc && nvm use 18 && npm run db:migrate' || {
    echo "⚠️ Ozone migrations failed, trying alternative method..."
    sudo -u bluesky bash -c 'source ~/.bashrc && nvm use 18 && node --require ts-node/register ../../packages/ozone/src/db/migrate.ts'
}
echo "✅ Ozone migrations complete"

# Run Bsync migrations
echo "🔄 Running Bsync database migrations..."
cd /home/bluesky/atproto/services/bsync
sudo -u bluesky bash -c 'source ~/.bashrc && nvm use 18 && npm run db:migrate' || {
    echo "⚠️ Bsync migrations failed, trying alternative method..."
    sudo -u bluesky bash -c 'source ~/.bashrc && nvm use 18 && node --require ts-node/register ../../packages/bsync/src/db/migrate.ts'
}
echo "✅ Bsync migrations complete"

# Verify database tables
echo "🔍 Verifying database tables..."
cd /home/bluesky
sudo -u postgres psql -d bluesky -c "\dt" | grep -E "(signing_key|label|moderation_event|repo_push_event)" || echo "⚠️ Some expected tables not found"

echo ""
echo "🎉 Database setup and migrations complete!"
echo ""
echo "📋 Next steps:"
echo "1. Restart all services:"
echo "   sudo systemctl restart bluesky-pds"
echo "   sudo systemctl restart bluesky-appview"
echo "   sudo systemctl restart bluesky-ozone"
echo "   sudo systemctl restart bluesky-bsync"
echo ""
echo "2. Check service status:"
echo "   sudo systemctl status bluesky-*"
echo ""
echo "3. View logs if any issues:"
echo "   sudo journalctl -u bluesky-* -f"
