#!/bin/bash

# =============================================================================
# Bluesky Database Setup Script
# =============================================================================
# This script sets up the PostgreSQL database and user
# The services will handle their own migrations on startup

set -e

echo "🗄️ Setting up Bluesky database..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
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
DB_PASSWORD="bluesky"

echo "🌐 Using domain: $DOMAIN"
echo "🗄️ Database: $DB_NAME"
echo "👤 Database user: $DB_USER"

# Create database and user if they don't exist
echo "📝 Creating database and user..."
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || echo "Database already exists"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';" 2>/dev/null || echo "User already exists"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null || echo "Privileges already granted"
sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;" 2>/dev/null || echo "User already has CREATEDB privilege"

# Grant additional permissions needed for migrations
sudo -u postgres psql -c "GRANT CREATE ON SCHEMA public TO $DB_USER;" 2>/dev/null || echo "Schema permissions already granted"
sudo -u postgres psql -c "GRANT USAGE ON SCHEMA public TO $DB_USER;" 2>/dev/null || echo "Schema usage permissions already granted"

echo "✅ Database setup complete"

echo ""
echo "📋 Important Notes:"
echo "=================================="
echo "• Database and user created successfully"
echo "• The services will automatically run their migrations on first startup"
echo "• No manual migration commands needed"
echo ""
echo "🚀 Next steps:"
echo "1. Start the services in this order:"
echo "   sudo systemctl start bluesky-pds"
echo "   sudo systemctl start bluesky-appview"
echo "   sudo systemctl start bluesky-ozone"
echo "   sudo systemctl start bluesky-bsync"
echo ""
echo "2. Check service status:"
echo "   sudo systemctl status bluesky-*"
echo ""
echo "3. View logs to see migration progress:"
echo "   sudo journalctl -u bluesky-pds -f"
echo "   sudo journalctl -u bluesky-appview -f"
echo "   sudo journalctl -u bluesky-ozone -f"
echo "   sudo journalctl -u bluesky-bsync -f"
echo ""
echo "⚠️  Note: First startup may take longer as services create their tables"
echo "   This is normal and expected behavior"
