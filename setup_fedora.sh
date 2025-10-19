#!/bin/bash

# This script must be run as root or with sudo privileges.
# It installs Python 3.12, Docker Engine with Compose, Visual Studio Code, Tailscale,
# Nextcloud Desktop, LibreOffice, htop, CIFS/SMB tools, NVIDIA CUDA, and xorg-x11-drv-nvidia-cuda
# on Fedora Workstation 42 KDE. It also configures Docker and adds user 'jordan' to the docker group.

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root or with sudo privileges."
  exit 1
fi

# Update the system
echo "Updating system packages..."
dnf update -y

# Install RPM Fusion non-free repository for NVIDIA packages
echo "Adding RPM Fusion non-free repository..."
dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install Python 3.12 and attempt to install pip
echo "Installing Python 3.12..."
dnf install -y python3.12

# Check if python3.12-pip is available, fallback to get-pip.py if not
echo "Installing pip for Python 3.12..."
if ! dnf install -y python3.12-pip --skip-unavailable; then
  echo "python3.12-pip not available, installing pip via get-pip.py..."
  curl -fsSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py
  python3.12 get-pip.py
  rm get-pip.py
fi

# Install dnf-plugins-core for repository management
echo "Installing dnf-plugins-core..."
dnf install -y dnf-plugins-core

# Add Docker CE repository
echo "Adding Docker CE repository..."
cat <<EOF | tee /etc/yum.repos.d/docker-ce.repo
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF

# Install Docker Engine and Compose
echo "Installing Docker Engine and Compose..."
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure Docker daemon (e.g., enable logging, set default runtime if needed)
echo "Configuring Docker daemon..."
mkdir -p /etc/docker
cat <<EOF | tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Start and enable Docker
echo "Starting and enabling Docker service..."
systemctl start docker
systemctl enable docker

# Restart Docker to apply configuration
echo "Restarting Docker service..."
systemctl restart docker

# Add user 'jordan' to docker group
echo "Adding user 'jordan' to docker group..."
usermod -aG docker jordan

# Install Visual Studio Code
echo "Adding Visual Studio Code repository..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat <<EOF | tee /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

echo "Installing Visual Studio Code..."
dnf check-update
dnf install -y code

# Install Tailscale
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale with provided auth key
echo "Starting Tailscale..."
TAILSCALE_AUTH_KEY="tskey-auth-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
tailscale up --authkey="${TAILSCALE_AUTH_KEY}" --accept-routes

# Install Nextcloud Desktop
echo "Installing Nextcloud Desktop..."
dnf install -y nextcloud-client

# Install LibreOffice
echo "Installing LibreOffice..."
dnf install -y libreoffice

# Install htop
echo "Installing htop..."
dnf install -y htop

# Install CIFS/SMB tools
echo "Installing CIFS/SMB tools..."
dnf install -y cifs-utils samba-client

# Install NVIDIA CUDA and xorg-x11-drv-nvidia-cuda
echo "Installing NVIDIA CUDA and xorg-x11-drv-nvidia-cuda..."
dnf install -y cuda cuda-devel cuda-libs xorg-x11-drv-nvidia-cuda

# Verify installations
echo "Verifying installations..."
command -v python3.12 >/dev/null && echo "Python 3.12 installed" || echo "Python 3.12 installation failed"
command -v pip3.12 >/dev/null && echo "pip for Python 3.12 installed" || echo "pip for Python 3.12 installation failed"
command -v docker >/dev/null && echo "Docker installed" || echo "Docker installation failed"
command -v code >/dev/null && echo "Visual Studio Code installed" || echo "VS Code installation failed"
command -v tailscale >/dev/null && echo "Tailscale installed" || echo "Tailscale installation failed"
command -v nextcloud >/dev/null && echo "Nextcloud Desktop installed" || echo "Nextcloud Desktop installation failed"
command -v libreoffice >/dev/null && echo "LibreOffice installed" || echo "LibreOffice installation failed"
command -v htop >/dev/null && echo "htop installed" || echo "htop installation failed"
command -v smbclient >/dev/null && echo "CIFS/SMB tools installed" || echo "CIFS/SMB tools installation failed"
command -v nvcc >/dev/null && echo "NVIDIA CUDA installed" || echo "NVIDIA CUDA installation failed"
rpm -q xorg-x11-drv-nvidia-cuda >/dev/null && echo "xorg-x11-drv-nvidia-cuda installed" || echo "xorg-x11-drv-nvidia-cuda installation failed"

echo "Installation and configuration complete!"
echo "Please log out and log back in for group changes (e.g., docker group) to take effect."
