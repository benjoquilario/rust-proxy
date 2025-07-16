# Digital Ocean Deployment Guide

This guide helps you deploy the Rust Proxy application to your Digital Ocean droplet with CI/CD on the subdomain `cors.animehi.live`.

## 🚀 Quick Start

### 1. Run Setup Script on Your Droplet

```bash
# SSH into your droplet
ssh your-user@your-droplet-ip

# Clone the repository
git clone https://github.com/benjoquilario/rust-proxy.git
cd rust-proxy

# Make setup script executable and run it
chmod +x setup-droplet.sh
./setup-droplet.sh
```

### 2. Configure DNS

Point `cors.animehi.live` to your droplet's IP address in your DNS provider:

- Type: A Record
- Name: cors (or whatever subdomain you prefer)
- Value: Your droplet's IP address

### 3. Set Up GitHub Secrets

In your GitHub repository, go to Settings → Secrets and variables → Actions, then add:

- `DROPLET_HOST`: Your droplet's IP address
- `DROPLET_USER`: Your username on the droplet (usually `root` or your user)
- `DROPLET_SSH_KEY`: Your private SSH key content

### 4. Enable HTTPS (Optional but Recommended)

```bash
sudo certbot --nginx -d cors.animehi.live
```

## 🔧 Manual Deployment

To deploy manually without CI/CD:

```bash
cd /opt/rust-proxy
./deploy.sh
```

## 📋 Architecture

```
Internet → cors.animehi.live → Nginx (Port 80/443) → Rust Proxy (Port 8080)
```

- **Nginx**: Reverse proxy handling the subdomain and SSL
- **Docker**: Isolated container for the Rust application
- **Port 8080**: Internal application port (not exposed directly)

## 🛡️ Security & Isolation

This deployment is designed to:

- ✅ Not affect other Docker containers on your droplet
- ✅ Use isolated Docker networks
- ✅ Run on a specific subdomain only
- ✅ Include proper CORS headers
- ✅ Auto-restart on failures

## 🔍 Monitoring & Logs

### Check Container Status

```bash
cd /opt/rust-proxy
docker-compose ps
```

### View Logs

```bash
cd /opt/rust-proxy
docker-compose logs rust-proxy
```

### Check Nginx Status

```bash
sudo systemctl status nginx
sudo nginx -t  # Test configuration
```

### Service Management

```bash
# Start service
sudo systemctl start rust-proxy

# Stop service
sudo systemctl stop rust-proxy

# Check status
sudo systemctl status rust-proxy
```

## 🔄 CI/CD Workflow

The GitHub Actions workflow:

1. Runs tests on every push/PR
2. Builds and pushes Docker image to GitHub Container Registry
3. On `main` branch: SSHs to droplet and updates only the `rust-proxy` container
4. Cleans up old Docker images

## 🌐 Endpoints

After deployment, your service will be available at:

- `http://cors.animehi.live` (or `https://` if SSL is configured)
- Direct access: `http://your-droplet-ip:8080` (for testing)

## 🚨 Troubleshooting

### Container Won't Start

```bash
cd /opt/rust-proxy
docker-compose logs rust-proxy
```

### Nginx Issues

```bash
sudo nginx -t
sudo systemctl status nginx
sudo journalctl -u nginx -f
```

### DNS Not Resolving

- Check DNS propagation: `nslookup cors.animehi.live`
- Verify A record points to correct IP

### Permission Issues

```bash
sudo chown -R $USER:$USER /opt/rust-proxy
```

## 📞 Support

If you encounter issues:

1. Check the logs as shown above
2. Verify DNS settings
3. Ensure firewall allows necessary ports
4. Check that other services aren't using port 8080

## 🔧 Configuration Files

- `docker-compose.yml`: Container configuration
- `nginx-cors-animehi.conf`: Nginx reverse proxy config
- `.github/workflows/deploy.yml`: CI/CD pipeline
- `setup-droplet.sh`: Initial server setup script
