#!/bin/bash

# Quick setup script for Digital Ocean droplet
# Run this ONCE on your droplet before using CI/CD

set -e

echo "🚀 Setting up environment for Rust Proxy CI/CD deployment..."

# Update system
sudo apt update

# Install Docker and Docker Compose if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt install -y docker.io docker-compose
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
fi

# Install other required packages
sudo apt install -y git nginx curl

# Create application directory
sudo mkdir -p /opt/rust-proxy
sudo chown $USER:$USER /opt/rust-proxy

# Set up Nginx for subdomain (cors.animehi.live)
echo "Setting up Nginx configuration..."
sudo tee /etc/nginx/sites-available/rust-proxy << 'EOF'
server {
    listen 80;
    server_name cors.animehi.live;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS headers
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization, Range, X-Requested-With";
        add_header Access-Control-Expose-Headers "Content-Length, Content-Range, Accept-Ranges";
        
        if ($request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization, Range, X-Requested-With";
            add_header Access-Control-Max-Age 86400;
            add_header Content-Length 0;
            add_header Content-Type text/plain;
            return 204;
        }
    }
}
EOF

# Enable the Nginx site
sudo ln -sf /etc/nginx/sites-available/rust-proxy /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Configure firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw allow 8080
sudo ufw --force enable

echo "✅ Setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Point cors.animehi.live DNS to this server's IP: $(hostname -I | awk '{print $1}')"
echo "2. Set up GitHub secrets:"
echo "   - DROPLET_HOST: $(hostname -I | awk '{print $1}')"
echo "   - DROPLET_USER: $USER"
echo "   - DROPLET_SSH_KEY: (your private SSH key content)"
echo "3. For HTTPS: sudo certbot --nginx -d cors.animehi.live"
echo ""
echo "🎉 Ready for CI/CD deployment!"
