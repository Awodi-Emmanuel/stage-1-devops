#!/bin/bash

set -euo pipefail

LOGFILE="deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1
trap 'echo "❌ Error occurred. Check $LOGFILE"; exit 99' ERR

# --- 1. Collect Parameters ---
echo "🚀 Starting deployment..."

read -p "Git Repository URL: " REPO_URL
read -s -p "Personal Access Token (PAT): " PAT; echo
read -p "Branch name [default: main]: " BRANCH
BRANCH=${BRANCH:-main}
read -p "Remote SSH Username: " SSH_USER
read -p "Remote Server IP: " SERVER_IP
read -p "SSH Key Path: " SSH_KEY
read -p "Application Port (internal container port): " APP_PORT

# --- 2. Clone Repository ---
REPO_NAME=$(basename "$REPO_URL" .git)
if [ -d "$REPO_NAME" ]; then
  echo "📦 Repo exists. Pulling latest changes..."
  cd "$REPO_NAME"
  git pull origin "$BRANCH"
else
  echo "📥 Cloning repository..."
  git clone https://${PAT}@${REPO_URL#https://} --branch "$BRANCH"
  cd "$REPO_NAME"
fi

# --- 3. Validate Docker Setup ---
if [[ -f Dockerfile || -f docker-compose.yml ]]; then
  echo "✅ Docker setup found."
else
  echo "❌ No Dockerfile or docker-compose.yml found." && exit 1
fi

# --- 4. SSH Connectivity Check ---
echo "🔐 Checking SSH connectivity..."
ssh -i "$SSH_KEY" -o BatchMode=yes "$SSH_USER@$SERVER_IP" "echo Connected" || {
  echo "❌ SSH connection failed." && exit 2
}

# --- 5. Prepare Remote Environment ---
echo "🛠️ Preparing remote environment..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
sudo apt update
sudo apt install -y docker.io docker-compose nginx
sudo usermod -aG docker \$USER
sudo systemctl enable docker nginx
sudo systemctl start docker nginx
docker --version
docker-compose --version
nginx -v
EOF

# --- 6. Transfer Project Files ---
echo "📤 Transferring project files..."
rsync -avz -e "ssh -i $SSH_KEY" . "$SSH_USER@$SERVER_IP:~/app"

# --- 7. Deploy Dockerized App ---
echo "🐳 Deploying Docker containers..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
cd ~/app
docker-compose down || docker rm -f app || true
[[ -f docker-compose.yml ]] && docker-compose up -d || {
  docker build -t app .
  docker run -d --name app -p $APP_PORT:$APP_PORT app
}
EOF

# --- 8. Configure Nginx Reverse Proxy ---
echo "🌐 Configuring Nginx reverse proxy..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
cat <<NGINX | sudo tee /etc/nginx/sites-available/app
server {
    listen 80;
    location / {
        proxy_pass http://localhost:$APP_PORT;
    }
}
NGINX
sudo ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
sudo nginx -t && sudo systemctl reload nginx
EOF

# --- 9. Validate Deployment ---
echo "🔍 Validating deployment..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
docker ps
curl -I http://localhost
EOF

echo "✅ Deployment complete. Logs saved to $LOGFILE"

# --- 10. Cleanup Option ---
if [[ "$1" == "--cleanup" ]]; then
  echo "🧹 Cleaning up remote resources..."
  ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
  docker-compose down || docker rm -f app
  sudo rm -rf ~/app
  sudo rm /etc/nginx/sites-enabled/app /etc/nginx/sites-available/app
  sudo systemctl reload nginx
EOF
  echo "✅ Cleanup complete."
fi

