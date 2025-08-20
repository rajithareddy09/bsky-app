#!/bin/bash

# =============================================================================
# Bluesky Dependencies Installation Script
# =============================================================================
# This script installs all required system dependencies for Bluesky

set -e

echo "📦 Installing system dependencies for Bluesky..."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Update system
echo "🔄 Updating system packages..."
apt update && apt upgrade -y

# Install basic packages
echo "📦 Installing basic packages..."
apt install -y curl wget git build-essential python3 python3-pip software-properties-common

# Install Node.js 18
echo "📦 Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verify Node.js installation
echo "✅ Node.js version: $(node --version)"
echo "✅ npm version: $(npm --version)"

# Install pnpm
echo "📦 Installing pnpm..."
npm install -g pnpm

# Verify pnpm installation
echo "✅ pnpm version: $(pnpm --version)"

# Install PostgreSQL
echo "📦 Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib

# Configure PostgreSQL
echo "🔧 Configuring PostgreSQL..."
systemctl enable postgresql
systemctl start postgresql

# Install Redis
echo "📦 Installing Redis..."
apt install -y redis-server

# Configure Redis
echo "🔧 Configuring Redis..."
sed -i 's/# maxmemory <bytes>/maxmemory 256mb/' /etc/redis/redis.conf
sed -i 's/# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf

systemctl enable redis-server
systemctl start redis-server

# Install Nginx
echo "📦 Installing Nginx..."
apt install -y nginx

# Configure Nginx
echo "🔧 Configuring Nginx..."
systemctl enable nginx
systemctl start nginx

# Install certbot for SSL
echo "📦 Installing certbot..."
apt install -y certbot python3-certbot-nginx

# Install additional useful packages
echo "📦 Installing additional packages..."
apt install -y htop vim nano ufw fail2ban

# Configure firewall
echo "🔧 Configuring firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp

# Configure fail2ban
echo "🔧 Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Create database and user
echo "🗄️ Setting up PostgreSQL database..."
sudo -u postgres psql -c "CREATE DATABASE bluesky;" || echo "Database already exists"
sudo -u postgres psql -c "CREATE USER bluesky WITH ENCRYPTED PASSWORD 'bluesky_password';" || echo "User already exists"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE bluesky TO bluesky;" || echo "Privileges already granted"

# Test Redis connection
echo "🧪 Testing Redis connection..."
if redis-cli ping | grep -q "PONG"; then
    echo "✅ Redis is working correctly"
else
    echo "❌ Redis connection failed"
    exit 1
fi

# Test PostgreSQL connection
echo "🧪 Testing PostgreSQL connection..."
if sudo -u postgres psql -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ PostgreSQL is working correctly"
else
    echo "❌ PostgreSQL connection failed"
    exit 1
fi

# Test Nginx
echo "🧪 Testing Nginx..."
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx is running"
else
    echo "❌ Nginx is not running"
    exit 1
fi

echo ""
echo "🎉 All dependencies installed successfully!"
echo ""
echo "📋 Installation Summary:"
echo "=================================="
echo "✅ Node.js $(node --version)"
echo "✅ npm $(npm --version)"
echo "✅ pnpm $(pnpm --version)"
echo "✅ PostgreSQL $(psql --version | cut -d' ' -f3)"
echo "✅ Redis $(redis-server --version | cut -d' ' -f3)"
echo "✅ Nginx $(nginx -v 2>&1 | cut -d' ' -f3)"
echo "✅ Certbot $(certbot --version | cut -d' ' -f2)"
echo "✅ UFW Firewall"
echo "✅ Fail2ban"
echo ""
echo "📋 Service Status:"
echo "=================================="
echo "PostgreSQL: $(systemctl is-active postgresql)"
echo "Redis:      $(systemctl is-active redis-server)"
echo "Nginx:      $(systemctl is-active nginx)"
echo "Fail2ban:   $(systemctl is-active fail2ban)"
echo ""
echo "🔐 Database Information:"
echo "=================================="
echo "Database:   bluesky"
echo "User:       bluesky"
echo "Password:   bluesky_password"
echo "Host:       localhost"
echo "Port:       5432"
echo ""
echo "🌐 Firewall Status:"
echo "=================================="
echo "SSH:        Allowed (port 22)"
echo "HTTP:       Allowed (port 80)"
echo "HTTPS:      Allowed (port 443)"
echo ""
echo "📝 Next steps:"
echo "1. Clone the atproto repository:"
echo "   git clone https://github.com/bluesky-social/atproto.git"
echo ""
echo "2. Clone the social-app repository:"
echo "   git clone https://github.com/bluesky-social/social-app.git"
echo ""
echo "3. Generate cryptographic keys:"
echo "   ./scripts/generate-keys.sh"
echo ""
echo "4. Configure environment variables:"
echo "   cp env.example .env"
echo "   nano .env"
echo ""
echo "5. Set up systemd services:"
echo "   sudo ./scripts/setup-systemd.sh"
echo ""
echo "6. Configure Nginx:"
echo "   sudo ./scripts/setup-nginx.sh"
echo ""
echo "7. Obtain SSL certificates:"
echo "   sudo certbot --nginx -d app.sfproject.net"
echo "   sudo certbot --nginx -d bsky.sfproject.net"
echo "   sudo certbot --nginx -d pdsapi.sfproject.net"
echo "   sudo certbot --nginx -d ozone.sfproject.net"
echo "   sudo certbot --nginx -d bsync.sfproject.net"
echo "   sudo certbot --nginx -d introspect.sfproject.net"
echo "   sudo certbot --nginx -d chat.sfproject.net"
echo "   sudo certbot --nginx -d plc.sfproject.net"
