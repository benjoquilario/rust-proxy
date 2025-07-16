#!/bin/bash

# Rust Proxy Deployment Script for Digital Ocean Droplet
# This script sets up the environment without affecting other Docker containers

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Setting up Rust Proxy deployment on cors.animehi.live${NC}"

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update system packages
echo -e "${YELLOW}📦 Updating system packages...${NC}"
$SUDO apt update

# Install required packages if not present
echo -e "${YELLOW}🔧 Installing required packages...${NC}"
PACKAGES=("curl" "git" "docker.io" "docker-compose" "nginx")

for package in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package "; then
        echo "Installing $package..."
        $SUDO apt install -y $package
    else
        echo "$package is already installed"
    fi
done

# Start and enable Docker
echo -e "${YELLOW}🐳 Setting up Docker...${NC}"
$SUDO systemctl start docker
$SUDO systemctl enable docker

# Add current user to docker group if not already added
if ! groups $USER | grep -q '\bdocker\b'; then
    echo "Adding $USER to docker group..."
    $SUDO usermod -aG docker $USER
    echo -e "${RED}⚠️  You need to log out and log back in for docker group changes to take effect${NC}"
fi

# Create application directory
echo -e "${YELLOW}📁 Creating application directory...${NC}"
$SUDO mkdir -p /opt/rust-proxy
$SUDO chown $USER:$USER /opt/rust-proxy

# Clone or update repository
echo -e "${YELLOW}📥 Setting up repository...${NC}"
if [ -d "/opt/rust-proxy/.git" ]; then
    echo "Repository exists, pulling latest changes..."
    cd /opt/rust-proxy
    git pull origin main
else
    echo "Cloning repository..."
    git clone https://github.com/benjoquilario/rust-proxy.git /tmp/rust-proxy-clone
    cp -r /tmp/rust-proxy-clone/* /opt/rust-proxy/
    rm -rf /tmp/rust-proxy-clone
    cd /opt/rust-proxy
fi

# Create environment file
echo -e "${YELLOW}⚙️ Creating environment configuration...${NC}"
cat > /opt/rust-proxy/.env << EOF
ENABLE_CORS=true
RUST_LOG=info
EOF

# Set up Nginx configuration for subdomain
echo -e "${YELLOW}🌐 Setting up Nginx for cors.animehi.live...${NC}"

# Copy nginx config
$SUDO cp /opt/rust-proxy/nginx-cors-animehi.conf /etc/nginx/sites-available/rust-proxy

# Enable the site
$SUDO ln -sf /etc/nginx/sites-available/rust-proxy /etc/nginx/sites-enabled/

# Test nginx configuration
if $SUDO nginx -t; then
    echo -e "${GREEN}✅ Nginx configuration is valid${NC}"
    $SUDO systemctl reload nginx
else
    echo -e "${RED}❌ Nginx configuration error${NC}"
    exit 1
fi

# Create a deployment script
echo -e "${YELLOW}📝 Creating deployment script...${NC}"
cat > /opt/rust-proxy/deploy.sh << 'EOF'
#!/bin/bash

set -e

echo "🚀 Deploying Rust Proxy..."

# Navigate to app directory
cd /opt/rust-proxy

# Pull latest changes
echo "📥 Pulling latest changes..."
git pull origin main

# Login to GitHub Container Registry (if token is available)
if [ ! -z "$GITHUB_TOKEN" ]; then
    echo "🔐 Logging into GitHub Container Registry..."
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u $GITHUB_USER --password-stdin
fi

# Pull latest Docker image
echo "🐳 Pulling latest Docker image..."
docker-compose pull rust-proxy

# Stop only rust-proxy container (won't affect other containers)
echo "🛑 Stopping rust-proxy container..."
docker-compose stop rust-proxy || true
docker-compose rm -f rust-proxy || true

# Start rust-proxy container
echo "▶️ Starting rust-proxy container..."
docker-compose up -d rust-proxy

# Wait for container to be healthy
echo "⏳ Waiting for container to be ready..."
sleep 10

# Check if container is running
if docker-compose ps rust-proxy | grep -q "Up"; then
    echo "✅ rust-proxy container is running successfully!"
    
    # Test the service
    if curl -f http://localhost:8080 >/dev/null 2>&1; then
        echo "✅ Service is responding on port 8080"
    else
        echo "⚠️ Service might still be starting up"
    fi
else
    echo "❌ rust-proxy container failed to start"
    docker-compose logs rust-proxy
    exit 1
fi

# Clean up old images
echo "🧹 Cleaning up old images..."
docker image prune -f

echo "✅ Deployment completed successfully!"
echo "🌐 Service should be available at:"
echo "  - http://$(hostname -I | awk '{print $1}'):8080 (direct)"
echo "  - http://cors.animehi.live (via nginx)"
EOF

chmod +x /opt/rust-proxy/deploy.sh

# Set up firewall rules (only add if ufw is installed and not conflicting)
if command_exists ufw; then
    echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
    
    # Check if ufw is active
    if $SUDO ufw status | grep -q "Status: active"; then
        echo "UFW is active, adding rules..."
        $SUDO ufw allow 8080/tcp comment "Rust Proxy"
        $SUDO ufw allow 'Nginx Full'
    else
        echo "UFW is not active, skipping firewall configuration"
    fi
fi

# Create systemd service for auto-restart
echo -e "${YELLOW}🔄 Creating systemd service...${NC}"
$SUDO tee /etc/systemd/system/rust-proxy.service << EOF
[Unit]
Description=Rust Proxy Service
Requires=docker.service
After=docker.service network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=/opt/rust-proxy
ExecStart=/usr/bin/docker-compose up -d rust-proxy
ExecStop=/usr/bin/docker-compose stop rust-proxy
RemainAfterExit=yes
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

$SUDO systemctl daemon-reload
$SUDO systemctl enable rust-proxy

echo -e "${GREEN}✅ Setup completed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Set up DNS: Point cors.animehi.live to this server's IP address"
echo "2. Set up GitHub secrets for CI/CD:"
echo "   - DROPLET_HOST: $(hostname -I | awk '{print $1}')"
echo "   - DROPLET_USER: $USER"
echo "   - DROPLET_SSH_KEY: Your private SSH key content"
echo "3. For HTTPS, run: sudo certbot --nginx -d cors.animehi.live"
echo "4. Test the deployment: /opt/rust-proxy/deploy.sh"
echo ""
echo -e "${GREEN}🎉 Your Rust Proxy is ready for CI/CD deployment!${NC}"
echo ""
echo -e "${YELLOW}🚨 Important notes:${NC}"
echo "- This setup is isolated and won't affect other Docker containers"
echo "- The service will auto-restart on system reboot"
echo "- Logs can be viewed with: docker-compose logs rust-proxy"
echo "- Manual deployment: cd /opt/rust-proxy && ./deploy.sh"
