#!/bin/bash

# This script must be run as root or with sudo privileges.
# It installs Python 3.12, Docker Engine with Compose, adds user 'jordan' to the docker group,
# installs CUDA toolkit, and sets up NVIDIA Container Toolkit on Fedora 42.
# Note: A reboot may be required after installing the NVIDIA driver.
# Also, user 'jordan' will need to log out and log back in to use Docker without sudo.

set -e

# Update the system
dnf update -y

# Install Python 3.12
dnf install python3.12 -y

# Install dnf-plugins-core for repository management
dnf install dnf-plugins-core -y

# Manually add Docker CE repository
cat <<EOF | tee /etc/yum.repos.d/docker-ce.repo
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF

# Install Docker Engine and Compose
dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add user 'jordan' to docker group
usermod -aG docker jordan

# Enable RPM Fusion repositories for NVIDIA driver
dnf install --nogpgcheck https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm -y
dnf install --nogpgcheck https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
dnf update -y

# Install NVIDIA driver and CUDA support
dnf install akmod-nvidia -y
dnf install xorg-x11-drv-nvidia-cuda -y

# Set up NVIDIA CUDA repository (using fedora41 as fedora42 may not be available yet; adjust if needed)
dnf config-manager --add-repo=https://developer.download.nvidia.com/compute/cuda/repos/fedora41/x86_64/cuda-fedora41.repo
dnf config-manager --set-disabled cuda-fedora41

# Install CUDA toolkit
dnf clean all
dnf --enablerepo=cuda-fedora41 install cuda-toolkit -y

# Set up NVIDIA Container Toolkit
distribution=$(source /etc/os-release; echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | tee /etc/yum.repos.d/nvidia-container-toolkit.repo
dnf update -y
dnf install nvidia-container-toolkit -y

# Configure Docker for NVIDIA runtime
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo "Installation complete. Reboot the system for the NVIDIA driver to take effect."
echo "User 'jordan' should log out and log back in to apply docker group changes."
