# Self-Hosted Bluesky Deployment Guide (Non-Docker)

This guide will help you deploy a complete Bluesky instance on your server using your configured subdomains without Docker.

## Prerequisites

- Ubuntu 20.04+ or Debian 11+ server
- Node.js 18+ and npm/pnpm
- PostgreSQL 15+
- Redis 7+
- Nginx
- SSL certificates (Let's Encrypt recommended)
- Domain with the following subdomains configured:
  - `app.sfproject.net` - Web frontend
  - `bsky.sfproject.net` - AppView API
  - `pdsapi.sfproject.net` - Personal Data Server
  - `ozone.sfproject.net` - Moderation interface
  - `plc.sfproject.net` - DID resolution
  - `bsync.sfproject.net` - Background sync
  - `introspect.sfproject.net` - API introspection
  - `chat.sfproject.net` - Chat service

## System Requirements

- **CPU**: 2+ cores
- **RAM**: 4GB+ (8GB recommended)
- **Storage**: 50GB+ SSD
- **Network**: Stable internet connection

## Installation Steps

### 1. System Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git build-essential python3 python3-pip

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install pnpm
npm install -g pnpm

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Install Redis
sudo apt install -y redis-server

# Install Nginx
sudo apt install -y nginx

# Install certbot for SSL
sudo apt install -y certbot python3-certbot-nginx
```

### 2. Database Setup

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE bluesky;
CREATE USER bluesky WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE bluesky TO bluesky;
\q

# Enable PostgreSQL to start on boot
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

### 3. Redis Setup

```bash
# Configure Redis
sudo sed -i 's/# maxmemory <bytes>/maxmemory 256mb/' /etc/redis/redis.conf
sudo sed -i 's/# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf

# Enable Redis to start on boot
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

### 4. Clone and Build atproto

```bash
# Clone atproto repository
git clone https://github.com/bluesky-social/atproto.git
cd atproto

# Install dependencies
pnpm install

# Build all packages
pnpm build
```

### 5. Clone and Build social-app

```bash
# Clone social-app repository
cd ..
git clone https://github.com/bluesky-social/social-app.git
cd social-app

# Install dependencies
yarn install

# Build web version
yarn build-web
```

### 6. Generate Cryptographic Keys

```bash
# Run the key generation script
cd ..
chmod +x scripts/generate-keys.sh
./scripts/generate-keys.sh
```

### 7. Configure Environment Variables

```bash
# Copy the example environment file
cp env.example .env

# Edit the .env file with your domain configuration
nano .env
```

Update the `.env` file with your domain configuration:

```env
# Domain Configuration
PDS_HOSTNAME=pdsapi.sfproject.net
BSKY_HOSTNAME=bsky.sfproject.net
OZONE_HOSTNAME=ozone.sfproject.net
PLC_HOSTNAME=plc.sfproject.net
BSYNC_HOSTNAME=bsync.sfproject.net
INTROSPECT_HOSTNAME=introspect.sfproject.net
CHAT_HOSTNAME=chat.sfproject.net

# URLs
PDS_PUBLIC_URL=https://pdsapi.sfproject.net
BSKY_PUBLIC_URL=https://bsky.sfproject.net
OZONE_PUBLIC_URL=https://ozone.sfproject.net
PLC_PUBLIC_URL=https://plc.sfproject.net
BSYNC_PUBLIC_URL=https://bsync.sfproject.net
INTROSPECT_PUBLIC_URL=https://introspect.sfproject.net
CHAT_PUBLIC_URL=https://chat.sfproject.net

# Database
POSTGRES_PASSWORD=your_secure_postgres_password
DB_POSTGRES_URL=postgresql://bluesky:your_secure_postgres_password@localhost:5432/bluesky

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
```

### 8. Create Systemd Services

Create service files for each component:

#### PDS Service
```bash
sudo nano /etc/systemd/system/bluesky-pds.service
```

```ini
[Unit]
Description=Bluesky Personal Data Server
After=network.target postgresql.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/pds
Environment=NODE_ENV=production
Environment=PDS_HOSTNAME=pdsapi.sfproject.net
Environment=PDS_PORT=2583
Environment=PDS_SERVICE_DID=did:web:pdsapi.sfproject.net
Environment=PDS_DATA_DIRECTORY=/home/bluesky/data/pds
Environment=PDS_BLOBSTORE_DISK_LOCATION=/home/bluesky/data/blobs
Environment=PDS_REPO_SIGNING_KEY_K256_PRIVATE_KEY_HEX=${PDS_REPO_SIGNING_KEY_K256_PRIVATE_KEY_HEX}
Environment=PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=${PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX}
Environment=PDS_DPOP_SECRET=${PDS_DPOP_SECRET}
Environment=PDS_JWT_SECRET=${PDS_JWT_SECRET}
Environment=PDS_ADMIN_PASSWORD=${PDS_ADMIN_PASSWORD}
Environment=PDS_DID_PLC_URL=https://plc.sfproject.net
Environment=PDS_BSKY_APP_VIEW_URL=https://bsky.sfproject.net
Environment=PDS_BSKY_APP_VIEW_DID=did:web:bsky.sfproject.net
Environment=PDS_OAUTH_PROVIDER_NAME=SF Project Bluesky
Environment=PDS_OAUTH_PROVIDER_PRIMARY_COLOR=#0085ff
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### AppView Service
```bash
sudo nano /etc/systemd/system/bluesky-appview.service
```

```ini
[Unit]
Description=Bluesky AppView
After=network.target postgresql.service redis-server.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/bsky
Environment=NODE_ENV=production
Environment=BSKY_PUBLIC_URL=https://bsky.sfproject.net
Environment=BSKY_SERVER_DID=did:web:bsky.sfproject.net
Environment=BSKY_DID_PLC_URL=https://plc.sfproject.net
Environment=BSKY_DATAPLANE_URL=https://pdsapi.sfproject.net
Environment=BSKY_SERVICE_SIGNING_KEY=${BSKY_SERVICE_SIGNING_KEY}
Environment=BSKY_ADMIN_PASSWORDS=${BSKY_ADMIN_PASSWORDS}
Environment=BSKY_PORT=3000
Environment=BSKY_VERSION=1.0.0
Environment=BSKY_IMG_URI_ENDPOINT=https://bsky.sfproject.net/img
Environment=BSKY_BLOB_CACHE_LOC=/home/bluesky/data/cache
Environment=BSKY_COURIER_URL=https://chat.sfproject.net
Environment=BSKY_COURIER_API_KEY=${BSKY_COURIER_API_KEY}
Environment=BSKY_BSYNC_URL=https://bsync.sfproject.net
Environment=BSKY_BSYNC_API_KEY=${BSKY_BSYNC_API_KEY}
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps api.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### Ozone Service
```bash
sudo nano /etc/systemd/system/bluesky-ozone.service
```

```ini
[Unit]
Description=Bluesky Ozone Moderation
After=network.target postgresql.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/ozone
Environment=NODE_ENV=production
Environment=OZONE_PUBLIC_URL=https://ozone.sfproject.net
Environment=OZONE_SERVER_DID=did:web:ozone.sfproject.net
Environment=OZONE_APPVIEW_URL=https://bsky.sfproject.net
Environment=OZONE_APPVIEW_DID=did:web:bsky.sfproject.net
Environment=OZONE_PDS_URL=https://pdsapi.sfproject.net
Environment=OZONE_PDS_DID=did:web:pdsapi.sfproject.net
Environment=OZONE_DB_POSTGRES_URL=postgresql://bluesky:your_secure_postgres_password@localhost:5432/bluesky
Environment=OZONE_DID_PLC_URL=https://plc.sfproject.net
Environment=OZONE_ADMIN_PASSWORD=${OZONE_ADMIN_PASSWORD}
Environment=OZONE_SIGNING_KEY_HEX=${OZONE_SIGNING_KEY_HEX}
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps api.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### Bsync Service
```bash
sudo nano /etc/systemd/system/bluesky-bsync.service
```

```ini
[Unit]
Description=Bluesky Background Sync
After=network.target postgresql.service

[Service]
Type=simple
User=bluesky
WorkingDirectory=/home/bluesky/atproto/services/bsync
Environment=NODE_ENV=production
Environment=BSYNC_PORT=3000
Environment=BSYNC_DB_POSTGRES_URL=postgresql://bluesky:your_secure_postgres_password@localhost:5432/bluesky
Environment=BSYNC_API_KEYS=${BSYNC_API_KEYS}
Environment=LOG_LEVEL=info
ExecStart=/usr/bin/node --enable-source-maps index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 9. Create User and Directories

```bash
# Create bluesky user
sudo useradd -m -s /bin/bash bluesky
sudo usermod -aG sudo bluesky

# Create data directories
sudo mkdir -p /home/bluesky/data/{pds,blobs,cache}
sudo chown -R bluesky:bluesky /home/bluesky/data

# Copy source code
sudo cp -r atproto /home/bluesky/
sudo cp -r social-app /home/bluesky/
sudo chown -R bluesky:bluesky /home/bluesky/atproto
sudo chown -R bluesky:bluesky /home/bluesky/social-app
```

### 10. Configure Nginx

Create Nginx configuration files for each subdomain:

#### Main Nginx Configuration
```bash
sudo nano /etc/nginx/sites-available/bluesky
```

```nginx
# App frontend
server {
    listen 80;
    server_name app.sfproject.net;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name app.sfproject.net;
    
    ssl_certificate /etc/letsencrypt/live/app.sfproject.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.sfproject.net/privkey.pem;
    
    location / {
        proxy_pass http://localhost:8100;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# AppView API
server {
    listen 80;
    server_name bsky.sfproject.net;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name bsky.sfproject.net;
    
    ssl_certificate /etc/letsencrypt/live/bsky.sfproject.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/bsky.sfproject.net/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS headers
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization";
    }
}

# PDS API
server {
    listen 80;
    server_name pdsapi.sfproject.net;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name pdsapi.sfproject.net;
    
    ssl_certificate /etc/letsencrypt/live/pdsapi.sfproject.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pdsapi.sfproject.net/privkey.pem;
    
    location / {
        proxy_pass http://localhost:2583;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS headers
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization";
    }
}

# Ozone Moderation
server {
    listen 80;
    server_name ozone.sfproject.net;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ozone.sfproject.net;
    
    ssl_certificate /etc/letsencrypt/live/ozone.sfproject.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ozone.sfproject.net/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Bsync
server {
    listen 80;
    server_name bsync.sfproject.net;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name bsync.sfproject.net;
    
    ssl_certificate /etc/letsencrypt/live/bsync.sfproject.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/bsync.sfproject.net/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/bluesky /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 11. SSL Certificates

```bash
# Obtain SSL certificates for all subdomains
sudo certbot --nginx -d app.sfproject.net
sudo certbot --nginx -d bsky.sfproject.net
sudo certbot --nginx -d pdsapi.sfproject.net
sudo certbot --nginx -d ozone.sfproject.net
sudo certbot --nginx -d bsync.sfproject.net

# Set up auto-renewal
sudo crontab -e
# Add this line:
0 12 * * * /usr/bin/certbot renew --quiet
```

### 12. Start Services

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable and start services
sudo systemctl enable bluesky-pds
sudo systemctl enable bluesky-appview
sudo systemctl enable bluesky-ozone
sudo systemctl enable bluesky-bsync

sudo systemctl start bluesky-pds
sudo systemctl start bluesky-appview
sudo systemctl start bluesky-ozone
sudo systemctl start bluesky-bsync

# Check service status
sudo systemctl status bluesky-pds
sudo systemctl status bluesky-appview
sudo systemctl status bluesky-ozone
sudo systemctl status bluesky-bsync
```

### 13. Start Web Frontend

```bash
# Switch to bluesky user
sudo su - bluesky

# Navigate to social-app directory
cd social-app

# Start the web server
yarn start-web
```

### 14. Verification

Test your deployment:

1. **Web App**: https://app.sfproject.net
2. **AppView API**: https://bsky.sfproject.net
3. **PDS API**: https://pdsapi.sfproject.net
4. **Ozone**: https://ozone.sfproject.net
5. **Bsync**: https://bsync.sfproject.net

### 15. Create Admin Account

```bash
# Create your first admin account
curl -X POST https://pdsapi.sfproject.net/xrpc/com.atproto.server.createAccount \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@sfproject.net",
    "handle": "admin.sfproject.net",
    "password": "your_secure_password"
  }'
```

## Maintenance

### Logs
```bash
# View service logs
sudo journalctl -u bluesky-pds -f
sudo journalctl -u bluesky-appview -f
sudo journalctl -u bluesky-ozone -f
sudo journalctl -u bluesky-bsync -f
```

### Updates
```bash
# Update atproto
cd /home/bluesky/atproto
git pull
pnpm install
pnpm build

# Update social-app
cd /home/bluesky/social-app
git pull
yarn install
yarn build-web

# Restart services
sudo systemctl restart bluesky-pds
sudo systemctl restart bluesky-appview
sudo systemctl restart bluesky-ozone
sudo systemctl restart bluesky-bsync
```

### Backup
```bash
# Backup database
pg_dump -U bluesky bluesky > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup data directories
tar -czf data_backup_$(date +%Y%m%d_%H%M%S).tar.gz /home/bluesky/data/
```

## Troubleshooting

### Common Issues

1. **Service won't start**: Check logs with `sudo journalctl -u service-name -f`
2. **Database connection issues**: Verify PostgreSQL is running and credentials are correct
3. **SSL certificate issues**: Check certbot logs and ensure DNS is properly configured
4. **Port conflicts**: Ensure no other services are using the required ports

### Health Checks

```bash
# Check if services are responding
curl https://bsky.sfproject.net/xrpc/com.atproto.server.describeServer
curl https://pdsapi.sfproject.net/xrpc/com.atproto.server.describeServer
curl https://ozone.sfproject.net/health
```

## Security Considerations

1. **Firewall**: Configure UFW to only allow necessary ports
2. **Regular updates**: Keep system and dependencies updated
3. **Monitoring**: Set up monitoring for service health
4. **Backups**: Regular database and data backups
5. **SSL**: Ensure all subdomains have valid SSL certificates

Your Bluesky instance should now be fully operational with all services running on their respective subdomains!
