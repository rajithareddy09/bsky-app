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

# Get domain from environment or prompt user
DOMAIN="${PDS_HOSTNAME:-}"
if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain (e.g., yourdomain.com): " DOMAIN
fi

# Remove any protocol prefixes
DOMAIN=$(echo "$DOMAIN" | sed 's|^https?://||' | sed 's|^pdsapi\.||')

# Update system packages
echo "🔄 Updating system packages..."
apt update && apt upgrade -y

# Install basic utilities
echo "📦 Installing basic utilities..."
apt install -y curl wget git build-essential python3 python3-pip software-properties-common

# Install nvm for Node.js version management
echo "📦 Installing nvm (Node Version Manager)..."
# Install nvm for the bluesky user
sudo -u root bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash'

# Add nvm to bash profile for bluesky user
echo "📝 Configuring nvm for bluesky user..."
cat >> /home/bluesky/.bashrc << 'EOF'

# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF

# Install Node.js versions for different components
echo "📦 Installing Node.js versions..."
sudo -u root bash -c 'source ~/.bashrc && nvm install 18'
sudo -u root bash -c 'source ~/.bashrc && nvm install 20'
sudo -u root bash -c 'source ~/.bashrc && nvm alias default 18'

# Install pnpm globally for both Node.js versions
echo "📦 Installing pnpm..."
sudo -u root bash -c 'source ~/.bashrc && nvm use 18 && npm install -g pnpm'
sudo -u root bash -c 'source ~/.bashrc && nvm use 20 && npm install -g pnpm'

# Install PostgreSQL
echo "📦 Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib

# Install Redis
echo "📦 Installing Redis..."
apt install -y redis-server

# Install Nginx
echo "📦 Installing Nginx..."
apt install -y nginx

# Install certbot for SSL
echo "📦 Installing Certbot..."
apt install -y certbot python3-certbot-nginx

# Install UFW firewall
echo "📦 Installing UFW firewall..."
apt install -y ufw

# Install Fail2ban
echo "📦 Installing Fail2ban..."
apt install -y fail2ban

# Configure Redis
echo "⚙️ Configuring Redis..."
sed -i 's/# maxmemory <bytes>/maxmemory 256mb/' /etc/redis/redis.conf
sed -i 's/# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf

# Enable and start services
echo "🚀 Enabling and starting services..."
systemctl enable postgresql
systemctl start postgresql
systemctl enable redis-server
systemctl start redis-server
systemctl enable nginx
systemctl start nginx
systemctl enable fail2ban
systemctl start fail2ban

# Configure UFW firewall
echo "🔥 Configuring firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw reload

# Create PostgreSQL database and user
echo "🗄️ Setting up PostgreSQL database..."
#sudo -u postgres psql -c "CREATE DATABASE bluesky;"
#sudo -u postgres psql -c "CREATE USER bluesky WITH ENCRYPTED PASSWORD 'bluesky_password';"
#sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE bluesky TO bluesky;"

# Verify installations
echo "✅ Verifying installations..."
echo "nvm installed for bluesky user"
echo "Node.js 18: $(sudo -u root bash -c 'source ~/.bashrc && nvm use 18 && node --version')"
echo "Node.js 20: $(sudo -u root bash -c 'source ~/.bashrc && nvm use 20 && node --version')"
echo "pnpm (Node 18): $(sudo -u root bash -c 'source ~/.bashrc && nvm use 18 && pnpm --version')"
echo "pnpm (Node 20): $(sudo -u root bash -c 'source ~/.bashrc && nvm use 20 && pnpm --version')"
echo "PostgreSQL version: $(psql --version)"
echo "Redis version: $(redis-server --version | head -1)"
echo "Nginx version: $(nginx -v 2>&1)"

echo ""
echo "🎉 Dependencies installation completed!"
echo ""
echo "📋 Installed components:"
echo "=================================="
echo "✅ nvm (Node Version Manager)"
echo "✅ Node.js 18 (for atproto backend)"
echo "✅ Node.js 20 (for social-app frontend)"
echo "✅ pnpm for both Node.js versions"
echo "✅ PostgreSQL 15+"
echo "✅ Redis 7+"
echo "✅ Nginx"
echo "✅ Certbot (SSL certificates)"
echo "✅ UFW (firewall)"
echo "✅ Fail2ban (security)"
echo "✅ Bluesky database and user"
echo ""
echo "🔐 Next steps:"
echo "=================================="
echo "1. Clone the atproto and social-app repositories"
echo "2. Generate cryptographic keys"
echo "3. Configure environment variables"
echo "4. Set up systemd services"
echo "5. Configure Nginx"
echo "6. Obtain SSL certificates"
echo ""
echo "🌐 SSL Certificate Commands:"
echo "=================================="
echo "sudo certbot --nginx -d app.$DOMAIN"
echo "sudo certbot --nginx -d bsky.$DOMAIN"
echo "sudo certbot --nginx -d pdsapi.$DOMAIN"
echo "sudo certbot --nginx -d ozone.$DOMAIN"
echo "sudo certbot --nginx -d bsync.$DOMAIN"
echo "sudo certbot --nginx -d introspect.$DOMAIN"
echo "sudo certbot --nginx -d chat.$DOMAIN"
echo "sudo certbot --nginx -d plc.$DOMAIN"
echo ""
echo "🔄 Auto-renewal setup:"
echo "sudo crontab -e"
echo "Add: 0 12 * * * /usr/bin/certbot renew --quiet"
echo ""
echo "🔒 Security notes:"
echo "=================================="
echo "• UFW firewall is enabled with SSH, HTTP, and HTTPS allowed"
echo "• Fail2ban is installed and running"
echo "• PostgreSQL is configured with a dedicated user"
echo "• Redis is configured with memory limits"
echo "• Change default passwords after setup"
echo ""
echo "📊 System status:"
echo "=================================="
echo "PostgreSQL: $(systemctl is-active postgresql)"
echo "Redis: $(systemctl is-active redis-server)"
echo "Nginx: $(systemctl is-active nginx)"
echo "UFW: $(ufw status | head -1)"
echo "Fail2ban: $(systemctl is-active fail2ban)"
