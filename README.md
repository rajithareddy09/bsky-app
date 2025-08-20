# Self-Hosted Bluesky Instance

This repository contains everything you need to deploy your own complete Bluesky instance without Docker, using your own subdomains.

## 🌟 Features

- **Complete Bluesky Stack**: PDS, AppView, Ozone, Bsync, and Web Frontend
- **Multi-Domain Setup**: Separate subdomains for each service
- **Production Ready**: Systemd services, Nginx reverse proxy, SSL certificates
- **Security Focused**: Firewall, fail2ban, rate limiting, security headers
- **Easy Deployment**: Automated scripts for quick setup
- **No Docker Required**: Native installation on Ubuntu/Debian

## 📋 Prerequisites

- Ubuntu 20.04+ or Debian 11+ server
- Root access
- Domain with the following subdomains configured:
  - `app.sfproject.net` - Web frontend
  - `bsky.sfproject.net` - AppView API
  - `pdsapi.sfproject.net` - Personal Data Server
  - `ozone.sfproject.net` - Moderation interface
  - `plc.sfproject.net` - DID resolution
  - `bsync.sfproject.net` - Background sync
  - `introspect.sfproject.net` - API introspection
  - `chat.sfproject.net` - Chat service

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# Clone this repository
git clone <your-repo-url>
cd Bsky-app

# Make scripts executable
chmod +x scripts/*.sh

# Run the automated setup
sudo ./scripts/quick-start.sh
```

### Option 2: Manual Setup

Follow the detailed step-by-step guide in [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md)

## 📁 Project Structure

```
Bsky-app/
├── scripts/
│   ├── quick-start.sh          # Complete automated setup
│   ├── install-dependencies.sh # System dependencies
│   ├── generate-keys.sh        # Cryptographic key generation
│   ├── setup-systemd.sh        # Systemd service configuration
│   └── setup-nginx.sh          # Nginx configuration
├── docker-compose.yml          # Docker setup (alternative)
├── nginx.conf                  # Nginx configuration
├── env.example                 # Environment variables template
├── DEPLOYMENT-GUIDE.md         # Detailed manual setup guide
└── README.md                   # This file
```

## 🔧 Services Overview

| Service | Subdomain | Port | Description |
|---------|-----------|------|-------------|
| **Web Frontend** | `app.sfproject.net` | 8100 | Bluesky web application |
| **AppView** | `bsky.sfproject.net` | 3000 | Main API for client interactions |
| **PDS** | `pdsapi.sfproject.net` | 2583 | Personal Data Server |
| **Ozone** | `ozone.sfproject.net` | 3001 | Moderation interface |
| **Bsync** | `bsync.sfproject.net` | 3002 | Background synchronization |
| **Introspect** | `introspect.sfproject.net` | 3003 | API documentation |
| **Chat** | `chat.sfproject.net` | 3004 | Chat service |
| **PLC** | `plc.sfproject.net` | 3005 | DID resolution |

## 🔐 Security Features

- **SSL/TLS**: Automatic HTTPS with Let's Encrypt
- **Firewall**: UFW configured with minimal open ports
- **Rate Limiting**: Nginx rate limiting for API endpoints
- **Fail2ban**: Protection against brute force attacks
- **Security Headers**: XSS protection, content type sniffing prevention
- **CORS**: Properly configured for cross-origin requests
- **Isolated Services**: Each service runs on its own subdomain

## 📊 System Requirements

- **CPU**: 2+ cores
- **RAM**: 4GB+ (8GB recommended)
- **Storage**: 50GB+ SSD
- **Network**: Stable internet connection

## 🛠️ Management Commands

### Service Management

```bash
# Check service status
sudo systemctl status bluesky-pds
sudo systemctl status bluesky-appview
sudo systemctl status bluesky-ozone
sudo systemctl status bluesky-bsync
sudo systemctl status bluesky-web

# View logs
sudo journalctl -u bluesky-pds -f
sudo journalctl -u bluesky-appview -f
sudo journalctl -u bluesky-ozone -f
sudo journalctl -u bluesky-bsync -f
sudo journalctl -u bluesky-web -f

# Restart services
sudo systemctl restart bluesky-pds
sudo systemctl restart bluesky-appview
sudo systemctl restart bluesky-ozone
sudo systemctl restart bluesky-bsync
sudo systemctl restart bluesky-web
```

### Database Management

```bash
# Backup database
pg_dump -U bluesky bluesky > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore database
psql -U bluesky bluesky < backup_file.sql
```

### SSL Certificate Management

```bash
# Renew certificates
sudo certbot renew

# Check certificate status
sudo certbot certificates
```

## 🔍 Troubleshooting

### Common Issues

1. **Service won't start**
   ```bash
   sudo journalctl -u service-name -f
   ```

2. **Database connection issues**
   ```bash
   sudo systemctl status postgresql
   sudo -u postgres psql -c "SELECT 1;"
   ```

3. **SSL certificate issues**
   ```bash
   sudo certbot certificates
   sudo nginx -t
   ```

4. **Port conflicts**
   ```bash
   sudo netstat -tlnp | grep :3000
   ```

### Health Checks

```bash
# Test API endpoints
curl https://bsky.sfproject.net/xrpc/com.atproto.server.describeServer
curl https://pdsapi.sfproject.net/xrpc/com.atproto.server.describeServer
curl https://ozone.sfproject.net/health
```

## 📚 Documentation

- [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md) - Detailed manual setup guide
- [Bluesky Documentation](https://atproto.com/guides/overview) - Official AT Protocol docs
- [atproto Repository](https://github.com/bluesky-social/atproto) - Backend source code
- [social-app Repository](https://github.com/bluesky-social/social-app) - Frontend source code

## 🔄 Updates

### Updating atproto

```bash
cd /home/bluesky/atproto
git pull
pnpm install
pnpm build
sudo systemctl restart bluesky-pds
sudo systemctl restart bluesky-appview
sudo systemctl restart bluesky-ozone
sudo systemctl restart bluesky-bsync
```

### Updating social-app

```bash
cd /home/bluesky/social-app
git pull
yarn install
yarn build-web
sudo systemctl restart bluesky-web
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This is an unofficial deployment guide for self-hosting Bluesky. It is not affiliated with or endorsed by Bluesky Social PBC. Use at your own risk.

## 🆘 Support

For issues related to this deployment guide:
- Check the troubleshooting section above
- Review the logs for error messages
- Consult the official Bluesky documentation
- Open an issue in this repository

For Bluesky protocol questions:
- [AT Protocol Documentation](https://atproto.com/guides/overview)
- [Bluesky Community](https://github.com/bluesky-social/atproto/discussions)

---

**Happy self-hosting! 🎉**
