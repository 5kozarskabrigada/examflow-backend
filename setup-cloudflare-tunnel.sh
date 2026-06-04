#!/bin/bash
# Setup Permanent Cloudflare Tunnel for ExamFlow Backend
# Run this script on your Hetzner server

echo "==================================="
echo "ExamFlow Cloudflare Tunnel Setup"
echo "==================================="
echo ""

# Step 1: Install cloudflared
echo "Step 1: Installing cloudflared..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
rm cloudflared-linux-amd64.deb
echo "✓ cloudflared installed"
echo ""

# Step 2: Authenticate with Cloudflare
echo "Step 2: Authenticate with Cloudflare..."
echo "A browser window will open. Login to Cloudflare (or create free account)"
echo "Then authorize the tunnel."
echo ""
read -p "Press Enter to continue..."
cloudflared tunnel login
echo "✓ Authenticated"
echo ""

# Step 3: Create named tunnel
echo "Step 3: Creating permanent tunnel..."
TUNNEL_NAME="examflow-backend"
cloudflared tunnel create $TUNNEL_NAME
echo "✓ Tunnel created: $TUNNEL_NAME"
echo ""

# Step 4: Get tunnel ID
TUNNEL_ID=$(cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')
echo "Tunnel ID: $TUNNEL_ID"
echo ""

# Step 5: Create config file
echo "Step 5: Creating tunnel configuration..."
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: examflow-api.trycloudflare.com
    service: http://localhost:8080
  - service: http_status:404
EOF
echo "✓ Config created at ~/.cloudflared/config.yml"
echo ""

# Step 6: Route DNS
echo "Step 6: Routing DNS..."
cloudflared tunnel route dns $TUNNEL_NAME examflow-api.trycloudflare.com
echo "✓ DNS routed"
echo ""

# Step 7: Create systemd service
echo "Step 7: Creating systemd service for auto-start..."
sudo tee /etc/systemd/system/cloudflared.service > /dev/null << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/cloudflared tunnel run $TUNNEL_NAME
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
echo "✓ Systemd service created and started"
echo ""

# Done!
echo "==================================="
echo "✓ Setup Complete!"
echo "==================================="
echo ""
echo "Your permanent HTTPS URL is:"
echo "https://examflow-api.trycloudflare.com"
echo ""
echo "Add this to Vercel environment variable:"
echo "VITE_API_BASE_URL=https://examflow-api.trycloudflare.com/api"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status cloudflared  # Check status"
echo "  sudo systemctl restart cloudflared # Restart tunnel"
echo "  sudo systemctl stop cloudflared    # Stop tunnel"
echo "  cloudflared tunnel list            # List tunnels"
echo ""
