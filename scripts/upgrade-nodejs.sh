#!/bin/bash

# =============================================================================
# Node.js Upgrade Script
# =============================================================================
# This script upgrades Node.js from version 18 to version 20

set -e

echo "🔄 Upgrading Node.js to version 20..."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Check current Node.js version
echo "📊 Current Node.js version:"
node --version
npm --version

# Remove old Node.js installation
echo "🗑️ Removing old Node.js installation..."
apt remove -y nodejs npm
apt autoremove -y

# Clean up NodeSource repository
echo "🧹 Cleaning up old NodeSource repository..."
rm -f /etc/apt/sources.list.d/nodesource.list*

# Update package list
echo "🔄 Updating package list..."
apt update

# Install Node.js 20
echo "📦 Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install pnpm globally
echo "📦 Installing pnpm..."
npm install -g pnpm

# Verify installation
echo "✅ Verifying new installation..."
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"
echo "pnpm version: $(pnpm --version)"

# Check if version is 20 or higher
NODE_VERSION=$(node --version | sed 's/v//')
MAJOR_VERSION=$(echo $NODE_VERSION | cut -d. -f1)

if [ "$MAJOR_VERSION" -ge 20 ]; then
    echo ""
    echo "🎉 Node.js upgrade completed successfully!"
    echo "✅ Node.js version: $(node --version)"
    echo "✅ npm version: $(npm --version)"
    echo "✅ pnpm version: $(pnpm --version)"
    echo ""
    echo "📝 You can now continue with the Bluesky installation."
else
    echo ""
    echo "❌ Node.js upgrade failed. Current version: $(node --version)"
    echo "Please check the installation and try again."
    exit 1
fi
