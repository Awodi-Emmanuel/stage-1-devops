# 🚀 DevOps Deployment Automation — Stage 1

This project automates the deployment of a web application to a remote EC2 instance using a Bash script. It handles cloning a GitHub repository, setting up Docker containers, configuring Nginx, and routing traffic to the application — all via SSH from a Vagrant box.

---

## 📦 Project Structure

# stage-1-devops


---

## 🎯 Task Objective

Automate the deployment of a GitHub-hosted application to a remote EC2 instance using:
- SSH from a Vagrant box
- Docker for containerization
- Nginx for reverse proxy
- Bash scripting for orchestration

---

## 🛠️ Prerequisites

Before running the script, ensure you have:

1. ✅ A GitHub repository (public or private)
2. ✅ A Personal Access Token (PAT) from GitHub
3. ✅ An EC2 instance running Ubuntu
4. ✅ A valid `.pem` keypair file for SSH access
5. ✅ Docker and Nginx installed on the EC2 instance
6. ✅ Vagrant box set up and running

---

## 🔐 How to Generate a GitHub PAT

1. Go to [GitHub Tokens](https://github.com/settings/tokens)
2. Click **Generate new token**
3. Select scopes:
   - `repo` → Full control of private repositories
   - `read:packages`
4. Copy and save the token securely

---

## 🚀 How to Run the Script

### 1. Move to a Writable Directory
```bash
cd ~
mkdir devops-deploy
cd devops-deploy
vim deploy.sh

./deploy.sh

## Cleanup Mode
./deploy.sh --cleanup

