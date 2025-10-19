#!/bin/bash
# This script can be run as a regular user with sudo privileges or as sudo ./setup.sh.
# It installs Python 3.12 from AUR, Docker Engine with Compose and NVIDIA support, Visual Studio Code from AUR, Tailscale,
# Nextcloud Desktop, LibreOffice, htop, CIFS/SMB tools, nonfree NVIDIA driver, and NVIDIA CUDA
# on Manjaro. It also configures Docker and adds the target user to the docker group.
set -e

# Determine if running as root
is_root=0
if [ "$EUID" -eq 0 ]; then
  is_root=1
fi

# Determine the target user
if [ $is_root -eq 1 ]; then
  if [ -z "$SUDO_USER" ]; then
    echo "Script run directly as root without sudo. This may cause issues with makepkg."
    exit 1
  fi
  target_user="$SUDO_USER"
else
  target_user="$USER"
fi

# Privilege escalation command
if [ $is_root -eq 1 ]; then
  priv_cmd=""
else
  priv_cmd="sudo "
fi

# Function to run commands as the target user
run_as_user() {
  if [ $is_root -eq 1 ]; then
    su "$target_user" -c "$1"
  else
    bash -c "$1"
  fi
}

# Install jq for JSON parsing
echo "Installing jq..."
${priv_cmd}pacman -S --needed --noconfirm jq

# Enable ILoveCandy in pacman.conf if not already enabled
echo "Enabling ILoveCandy in pacman.conf..."
if ! grep -q "ILoveCandy" /etc/pacman.conf; then
  ${priv_cmd}sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
fi

# Update the system
echo "Updating system packages..."
${priv_cmd}pacman -Syu --noconfirm

# Install base-devel and git for AUR
echo "Installing base-devel and git..."
${priv_cmd}pacman -S --needed --noconfirm base-devel git

# Install go for building AUR packages
echo "Installing go..."
${priv_cmd}pacman -S --needed --noconfirm go

# Install yay AUR helper if not installed
if ! command -v yay >/dev/null; then
  echo "Installing yay AUR helper..."
  ${priv_cmd}rm -rf /tmp/yay
  run_as_user "git clone https://aur.archlinux.org/yay.git /tmp/yay"
  run_as_user "cd /tmp/yay && makepkg --noconfirm"
  ${priv_cmd}pacman -U /tmp/yay/*.pkg.tar* --noconfirm
  ${priv_cmd}rm -rf /tmp/yay
fi

# Install dependencies for AUR packages
echo "Installing dependencies for AUR packages..."
${priv_cmd}pacman -S --needed --noconfirm expat libffi gdbm openssl libnsl zlib bzip2 readline sqlite tk ncurses util-linux xz mpdecimal systemd-libs bluez-libs libx11 libxkbcommon-x11 libxml2 libtirpc libxcrypt libxcrypt-compat valgrind runc asar gendesk pngcrush squashfs-tools unzip glibc gcc-libs glib2 nss nspr libdrm libxkbfile libsecret gdk-pixbuf2 libxss at-spi2-core libxcb libxshmfence libxrandr mesa dbus-glib libnotify libxtst nvidia-utils elfutils bmake rpcsvc-proto lsb-release lsof

# Install Python 3.12 from AUR manually
echo "Installing Python 3.12 from AUR..."
${priv_cmd}rm -rf /tmp/python312
run_as_user "git clone https://aur.archlinux.org/python312.git /tmp/python312"
run_as_user "gpg --recv-keys 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D E3FF2839C048B25C084DEBE9B26995E310250568"
run_as_user "cd /tmp/python312 && makepkg --noconfirm"
${priv_cmd}pacman -U /tmp/python312/*.pkg.tar* --noconfirm
${priv_cmd}rm -rf /tmp/python312

# Install pip for Python 3.12
echo "Installing pip for Python 3.12..."
run_as_user "python3.12 -m ensurepip || { echo 'ensurepip not available, installing pip via get-pip.py...'; curl -fsSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py; python3.12 get-pip.py; rm get-pip.py; }"

# Install nonfree NVIDIA driver
echo "Installing nonfree NVIDIA driver..."
${priv_cmd}mhwd -a pci nonfree 0300

# Install NVIDIA CUDA
echo "Installing NVIDIA CUDA..."
${priv_cmd}pacman -S --noconfirm cuda cuda-tools

# Install Docker Engine and Compose
echo "Installing Docker Engine and Compose..."
${priv_cmd}pacman -S --noconfirm docker docker-compose

# Install libnvidia-container and nvidia-container-toolkit
echo "Installing libnvidia-container and nvidia-container-toolkit..."
${priv_cmd}pacman -S --needed --noconfirm libnvidia-container nvidia-container-toolkit

# Configure Docker daemon for NVIDIA support and logging
echo "Configuring Docker daemon..."
${priv_cmd}mkdir -p /etc/docker
cat <<EOF | ${priv_cmd}tee /etc/docker/daemon.json
{
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "/usr/bin/nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Start and enable Docker
echo "Starting and enabling Docker service..."
${priv_cmd}systemctl start docker
${priv_cmd}systemctl enable docker

# Restart Docker to apply configuration
echo "Restarting Docker service..."
${priv_cmd}systemctl restart docker

# Add target user to docker group
echo "Adding user '$target_user' to docker group..."
${priv_cmd}usermod -aG docker "$target_user"

# Install Visual Studio Code from AUR manually
echo "Installing Visual Studio Code from AUR..."
${priv_cmd}rm -rf /tmp/visual-studio-code-bin
run_as_user "git clone https://aur.archlinux.org/visual-studio-code-bin.git /tmp/visual-studio-code-bin"
run_as_user "cd /tmp/visual-studio-code-bin && makepkg --noconfirm"
${priv_cmd}pacman -U /tmp/visual-studio-code-bin/*.pkg.tar* --noconfirm
${priv_cmd}rm -rf /tmp/visual-studio-code-bin

# Install Tailscale if not installed or not connected
if command -v tailscale >/dev/null; then
  status=$(${priv_cmd}tailscale status --json | jq -r .BackendState)
  if [ "$status" = "Running" ]; then
    echo "Tailscale is already installed and connected. Skipping."
  else
    echo "Tailscale is installed but not connected."
    if [ -z "$TAILSCALE_AUTH_KEY" ]; then
      read -p "Enter Tailscale auth key: " TAILSCALE_AUTH_KEY
    fi
    ${priv_cmd}tailscale up --authkey="${TAILSCALE_AUTH_KEY}" --accept-routes
  fi
else
  echo "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
  if [ -z "$TAILSCALE_AUTH_KEY" ]; then
    read -p "Enter Tailscale auth key: " TAILSCALE_AUTH_KEY
  fi
  ${priv_cmd}tailscale up --authkey="${TAILSCALE_AUTH_KEY}" --accept-routes
fi

# Install Nextcloud Desktop
echo "Installing Nextcloud Desktop..."
${priv_cmd}pacman -S --noconfirm nextcloud-client

# Install LibreOffice
echo "Installing LibreOffice..."
${priv_cmd}pacman -S --noconfirm libreoffice-fresh

# Install htop
echo "Installing htop..."
${priv_cmd}pacman -S --noconfirm htop

# Install CIFS/SMB tools
echo "Installing CIFS/SMB tools..."
${priv_cmd}pacman -S --noconfirm cifs-utils smbclient

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
nvidia-smi >/dev/null && echo "NVIDIA driver installed" || echo "NVIDIA driver installation failed"

echo "Installation and configuration complete!"
echo "Please log out and log back in for group changes (e.g., docker group) to take effect."
echo "You may need to reboot for NVIDIA driver changes to take effect."
