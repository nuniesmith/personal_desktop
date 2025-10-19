#!/bin/bash
# This script can be run as a regular user with sudo privileges or as sudo ./setup.sh.
# It installs Python 3.12, Docker Engine with Compose and NVIDIA support, Visual Studio Code, Tailscale,
# Nextcloud Desktop, LibreOffice, htop, CIFS/SMB tools, nonfree NVIDIA driver, and NVIDIA CUDA
# on Manjaro, Fedora, or Ubuntu. It also configures Docker and adds the target user to the docker group.
# Additionally, it installs Steam and Wine for gaming purposes.
# It also sets up a Wine prefix and installs Battle.net using Wine.
# Now with checks to skip already completed tasks.
# Added EA App installation similarly to Battle.net.
set -e
# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
  if [ "$OS" = "manjaro" ] || [ "$OS" = "arch" ]; then
    OS_FAMILY="arch"
  elif [ "$OS" = "fedora" ]; then
    OS_FAMILY="fedora"
  elif [ "$OS" = "ubuntu" ]; then
    OS_FAMILY="ubuntu"
  else
    echo "Unsupported OS: $OS"
    exit 1
  fi
else
  echo "Cannot detect OS"
  exit 1
fi
# Determine if running as root
is_root=0
if [ "$EUID" -eq 0 ]; then
  is_root=1
fi
# Determine the target user
if [ $is_root -eq 1 ]; then
  if [ -z "$SUDO_USER" ]; then
    echo "Script run directly as root without sudo. This may cause issues with makepkg on Arch."
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
# Function to check if user is in group
user_in_group() {
  groups "$target_user" | grep -q "\b$1\b"
}
# OS-specific commands
case $OS_FAMILY in
  arch)
    update_cmd="${priv_cmd}pacman -Syu --noconfirm"
    install_cmd="${priv_cmd}pacman -S --needed --noconfirm"
    search_cmd="pacman -Qi"
    jq_pkg="jq"
    base_devel_pkg="base-devel git"
    go_pkg="go"
    python_pkg="python312" # From AUR
    pip_cmd="pip3.12"
    # For NVIDIA on Arch
    nvidia_driver_cmd="${priv_cmd}mhwd -a pci nonfree 0300"
    cuda_pkg="cuda cuda-tools"
    docker_pkg="docker docker-compose"
    libnvidia_container_pkg="libnvidia-container nvidia-container-toolkit"
    vscode_pkg="visual-studio-code-bin" # From AUR
    nextcloud_pkg="nextcloud-client"
    libreoffice_pkg="libreoffice-fresh"
    htop_pkg="htop"
    cifs_pkg="cifs-utils smbclient"
    steam_pkg="steam"
    wine_pkg="wine"
    winetricks_pkg="winetricks samba"
    ;;
  fedora)
    update_cmd="${priv_cmd}dnf update -y"
    install_cmd="${priv_cmd}dnf install -y"
    search_cmd="rpm -qi"
    jq_pkg="jq"
    base_devel_pkg="dnf-plugins-core git"
    go_pkg="golang"
    python_pkg="python3.12"
    pip_cmd="pip3.12"
    # For NVIDIA on Fedora, add RPM Fusion first
    function install_nvidia_fedora() {
      ${priv_cmd}dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
      ${priv_cmd}dnf update -y
      ${priv_cmd}dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
    }
    nvidia_driver_cmd="install_nvidia_fedora"
    cuda_pkg="cuda cuda-devel cuda-libs"
    docker_pkg="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    # For NVIDIA Docker on Fedora
    libnvidia_container_pkg="nvidia-container-toolkit"
    function install_libnvidia_fedora() {
      ${priv_cmd}dnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo
      ${priv_cmd}dnf install -y nvidia-container-toolkit
    }
    libnvidia_install_cmd="install_libnvidia_fedora"
    vscode_pkg="code"
    nextcloud_pkg="nextcloud-client"
    libreoffice_pkg="libreoffice"
    htop_pkg="htop"
    cifs_pkg="cifs-utils samba-client"
    steam_pkg="steam"
    wine_pkg="wine"
    winetricks_pkg="winetricks samba"
    ;;
  ubuntu)
    update_cmd="${priv_cmd}apt update && ${priv_cmd}apt upgrade -y"
    install_cmd="${priv_cmd}apt install -y"
    search_cmd="dpkg -s"
    jq_pkg="jq"
    base_devel_pkg="build-essential git"
    go_pkg="golang-go"
    python_pkg="python3.12 python3.12-venv" # Assume available; add deadsnakes PPA if needed
    pip_cmd="pip3.12"
    nvidia_driver_cmd="${priv_cmd}ubuntu-drivers autoinstall"
    cuda_pkg="cuda-toolkit cuda-tools"
    docker_pkg="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    libnvidia_container_pkg="nvidia-container-toolkit"
    function install_libnvidia_ubuntu() {
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | ${priv_cmd}gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
      curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        ${priv_cmd}tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
      ${priv_cmd}apt update
      ${priv_cmd}apt install -y nvidia-container-toolkit
    }
    libnvidia_install_cmd="install_libnvidia_ubuntu"
    vscode_pkg="code"
    nextcloud_pkg="nextcloud-desktop"
    libreoffice_pkg="libreoffice"
    htop_pkg="htop"
    cifs_pkg="cifs-utils smbclient"
    steam_pkg="steam"
    wine_pkg="wine"
    winetricks_pkg="winetricks samba"
    ;;
esac
# Initial checks to see what's already done
echo "Performing initial checks..."
has_jq=$(command -v jq >/dev/null && echo "yes" || echo "no")
# For system update, we always run it
has_base_devel=$($search_cmd base-devel >/dev/null 2>&1 || $search_cmd dnf-plugins-core >/dev/null 2>&1 || $search_cmd build-essential >/dev/null 2>&1 && echo "yes" || echo "no")
has_git=$(command -v git >/dev/null && echo "yes" || echo "no")
has_go=$(command -v go >/dev/null && echo "yes" || echo "no")
has_python312=$(command -v python3.12 >/dev/null && echo "yes" || echo "no")
has_pip312=$(command -v $pip_cmd >/dev/null && echo "yes" || echo "no")
has_nvidia_driver=$(nvidia-smi >/dev/null 2>&1 && echo "yes" || echo "no")
has_cuda=$(command -v nvcc >/dev/null && echo "yes" || echo "no")
has_docker=$(command -v docker >/dev/null && echo "yes" || echo "no")
has_docker_config=$([ -f /etc/docker/daemon.json ] && grep -q "nvidia" /etc/docker/daemon.json && echo "yes" || echo "no")
has_docker_enabled=$(systemctl is-enabled docker >/dev/null 2>&1 && echo "yes" || echo "no")
has_docker_group=$(user_in_group docker && echo "yes" || echo "no")
has_vscode=$(command -v code >/dev/null && echo "yes" || echo "no")
has_tailscale=$(command -v tailscale >/dev/null && echo "yes" || echo "no")
has_tailscale_connected=$(if [ "$has_tailscale" = "yes" ]; then status=$(${priv_cmd}tailscale status --json | jq -r .BackendState); [ "$status" = "Running" ] && echo "yes" || echo "no"; else echo "no"; fi)
has_nextcloud=$(command -v nextcloud >/dev/null && echo "yes" || echo "no")
has_libreoffice=$(command -v libreoffice >/dev/null && echo "yes" || echo "no")
has_htop=$(command -v htop >/dev/null && echo "yes" || echo "no")
has_cifs=$(command -v smbclient >/dev/null && echo "yes" || echo "no")
has_steam=$(command -v steam >/dev/null && echo "yes" || echo "no")
has_wine=$(command -v wine >/dev/null && echo "yes" || echo "no")
has_winetricks=$(command -v winetricks >/dev/null && echo "yes" || echo "no")
has_samba=$($search_cmd samba >/dev/null 2>&1 && echo "yes" || echo "no")
has_wine_prefix_bnet=$([ -d "/home/$target_user/.wine-battlenet" ] && echo "yes" || echo "no")
has_battlenet_installer=$([ -f "/home/$target_user/Downloads/Battle.net-Setup.exe" ] && echo "yes" || echo "no")
has_battlenet=$([ -f "/home/$target_user/.wine-battlenet/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe" ] && echo "yes" || echo "no")
has_wine_prefix_ea=$([ -d "/home/$target_user/.wine-ea" ] && echo "yes" || echo "no")
has_ea_installer=$([ -f "/home/$target_user/Downloads/EAappInstaller.exe" ] && echo "yes" || echo "no")
has_ea=$([ -f "/home/$target_user/.wine-ea/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe" ] && echo "yes" || echo "no")
# Print status
echo "Status:"
echo "jq: $has_jq"
echo "base-devel: $has_base_devel"
echo "git: $has_git"
echo "go: $has_go"
echo "Python 3.12: $has_python312"
echo "pip 3.12: $has_pip312"
echo "NVIDIA driver: $has_nvidia_driver"
echo "CUDA: $has_cuda"
echo "Docker: $has_docker"
echo "Docker config: $has_docker_config"
echo "Docker enabled: $has_docker_enabled"
echo "Docker group: $has_docker_group"
echo "VS Code: $has_vscode"
echo "Tailscale: $has_tailscale (connected: $has_tailscale_connected)"
echo "Nextcloud: $has_nextcloud"
echo "LibreOffice: $has_libreoffice"
echo "htop: $has_htop"
echo "CIFS/SMB: $has_cifs"
echo "Steam: $has_steam"
echo "Wine: $has_wine"
echo "Winetricks: $has_winetricks"
echo "Samba: $has_samba"
echo "Wine prefix Battle.net: $has_wine_prefix_bnet"
echo "Battle.net installer: $has_battlenet_installer"
echo "Battle.net: $has_battlenet"
echo "Wine prefix EA: $has_wine_prefix_ea"
echo "EA installer: $has_ea_installer"
echo "EA App: $has_ea"
# Now proceed with installations, skipping if already done
if [ "$has_jq" = "no" ]; then
  echo "Installing jq..."
  $install_cmd $jq_pkg
fi
# Always update
echo "Updating system packages..."
$update_cmd
if [ "$has_base_devel" = "no" ] || [ "$has_git" = "no" ]; then
  echo "Installing base-devel and git..."
  $install_cmd $base_devel_pkg
fi
if [ "$has_go" = "no" ]; then
  echo "Installing go..."
  $install_cmd $go_pkg
fi
if [ "$OS_FAMILY" = "arch" ]; then
  has_yay=$(command -v yay >/dev/null && echo "yes" || echo "no")
  if [ "$has_yay" = "no" ]; then
    echo "Installing yay AUR helper..."
    ${priv_cmd}rm -rf /tmp/yay
    run_as_user "git clone https://aur.archlinux.org/yay.git /tmp/yay"
    run_as_user "cd /tmp/yay && makepkg --noconfirm"
    ${priv_cmd}pacman -U /tmp/yay/*.pkg.tar* --noconfirm
    ${priv_cmd}rm -rf /tmp/yay
  fi
fi
if [ "$has_python312" = "no" ]; then
  if [ "$OS_FAMILY" = "arch" ]; then
    echo "Installing Python 3.12 from AUR..."
    ${priv_cmd}rm -rf /tmp/python312
    run_as_user "git clone https://aur.archlinux.org/python312.git /tmp/python312"
    run_as_user "gpg --recv-keys 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D E3FF2839C048B25C084DEBE9B26995E310250568"
    run_as_user "cd /tmp/python312 && makepkg --noconfirm"
    ${priv_cmd}pacman -U /tmp/python312/*.pkg.tar* --noconfirm
    ${priv_cmd}rm -rf /tmp/python312
  else
    $install_cmd $python_pkg
  fi
fi
if [ "$has_pip312" = "no" ] && [ "$has_python312" = "yes" ]; then
  echo "Installing pip for Python 3.12..."
  if [ "$OS_FAMILY" = "fedora" ]; then
    if ! $install_cmd python3.12-pip --skip-unavailable; then
      run_as_user "curl -fsSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py; python3.12 get-pip.py; rm get-pip.py;"
    fi
  else
    run_as_user "python3.12 -m ensurepip || { echo 'ensurepip not available, installing pip via get-pip.py...'; curl -fsSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py; python3.12 get-pip.py; rm get-pip.py; }"
  fi
fi
if [ "$has_nvidia_driver" = "no" ]; then
  echo "Installing nonfree NVIDIA driver..."
  $nvidia_driver_cmd
fi
if [ "$has_cuda" = "no" ]; then
  echo "Installing NVIDIA CUDA..."
  $install_cmd $cuda_pkg
fi
if [ "$has_docker" = "no" ]; then
  if [ "$OS_FAMILY" = "fedora" ] || [ "$OS_FAMILY" = "ubuntu" ]; then
    # Add Docker repo for Fedora/Ubuntu
    if [ "$OS_FAMILY" = "fedora" ]; then
      echo "Adding Docker CE repository..."
      cat <<EOF | ${priv_cmd}tee /etc/yum.repos.d/docker-ce.repo
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF
    elif [ "$OS_FAMILY" = "ubuntu" ]; then
      echo "Adding Docker CE repository..."
      ${priv_cmd}install -y apt-transport-https ca-certificates curl gnupg lsb-release
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | ${priv_cmd}gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | ${priv_cmd}tee /etc/apt/sources.list.d/docker.list > /dev/null
      ${priv_cmd}apt update
    fi
  fi
  echo "Installing Docker Engine and Compose..."
  $install_cmd $docker_pkg
fi
if [ "$has_docker" = "yes" ] && ([ "$OS_FAMILY" = "fedora" ] || [ "$OS_FAMILY" = "ubuntu" ]); then
  if ! $search_cmd $libnvidia_container_pkg >/dev/null 2>&1; then
    echo "Installing nvidia-container-toolkit..."
    $libnvidia_install_cmd
  fi
elif [ "$OS_FAMILY" = "arch" ] && [ "$has_docker" = "yes" ]; then
  if ! $search_cmd libnvidia-container >/dev/null 2>&1 || ! $search_cmd nvidia-container-toolkit >/dev/null 2>&1; then
    echo "Installing libnvidia-container and nvidia-container-toolkit..."
    $install_cmd $libnvidia_container_pkg
  fi
fi
if [ "$has_docker_config" = "no" ]; then
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
fi
if [ "$has_docker" = "yes" ] && [ "$has_docker_enabled" = "no" ]; then
  echo "Starting and enabling Docker service..."
  ${priv_cmd}systemctl start docker
  ${priv_cmd}systemctl enable docker
fi
if [ "$has_docker" = "yes" ]; then
  echo "Restarting Docker service..."
  ${priv_cmd}systemctl restart docker
fi
if [ "$has_docker_group" = "no" ]; then
  echo "Adding user '$target_user' to docker group..."
  ${priv_cmd}usermod -aG docker "$target_user"
fi
if [ "$has_vscode" = "no" ]; then
  if [ "$OS_FAMILY" = "arch" ]; then
    echo "Installing Visual Studio Code from AUR..."
    ${priv_cmd}rm -rf /tmp/visual-studio-code-bin
    run_as_user "git clone https://aur.archlinux.org/visual-studio-code-bin.git /tmp/visual-studio-code-bin"
    run_as_user "cd /tmp/visual-studio-code-bin && makepkg --noconfirm"
    ${priv_cmd}pacman -U /tmp/visual-studio-code-bin/*.pkg.tar* --noconfirm
    ${priv_cmd}rm -rf /tmp/visual-studio-code-bin
  else
    # For Fedora/Ubuntu, add repo
    if [ "$OS_FAMILY" = "fedora" ]; then
      echo "Adding Visual Studio Code repository..."
      rpm --import https://packages.microsoft.com/keys/microsoft.asc
      cat <<EOF | ${priv_cmd}tee /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
      ${priv_cmd}dnf check-update
    elif [ "$OS_FAMILY" = "ubuntu" ]; then
      echo "Adding Visual Studio Code repository..."
      wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
      ${priv_cmd}install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
      echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | ${priv_cmd}tee /etc/apt/sources.list.d/vscode.list
      rm packages.microsoft.gpg
      ${priv_cmd}apt update
    fi
    echo "Installing Visual Studio Code..."
    $install_cmd $vscode_pkg
  fi
fi
# Tailscale already has its own check
if [ "$has_tailscale" = "yes" ]; then
  if [ "$has_tailscale_connected" = "yes" ]; then
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
if [ "$has_nextcloud" = "no" ]; then
  echo "Installing Nextcloud Desktop..."
  $install_cmd $nextcloud_pkg
fi
if [ "$has_libreoffice" = "no" ]; then
  echo "Installing LibreOffice..."
  $install_cmd $libreoffice_pkg
fi
if [ "$has_htop" = "no" ]; then
  echo "Installing htop..."
  $install_cmd $htop_pkg
fi
if [ "$has_cifs" = "no" ]; then
  echo "Installing CIFS/SMB tools..."
  $install_cmd $cifs_pkg
fi
if [ "$has_steam" = "no" ]; then
  echo "Installing Steam..."
  $install_cmd $steam_pkg
fi
if [ "$has_wine" = "no" ]; then
  echo "Installing Wine..."
  $install_cmd $wine_pkg
fi
if [ "$has_winetricks" = "no" ] || [ "$has_samba" = "no" ]; then
  echo "Installing winetricks and samba..."
  $install_cmd $winetricks_pkg
fi
# Battle.net
if [ "$has_wine_prefix_bnet" = "no" ]; then
  echo "Setting up Wine prefix for Battle.net..."
  run_as_user "mkdir -p ~/.wine-battlenet"
  run_as_user "WINEPREFIX=~/.wine-battlenet WINEARCH=win64 wineboot --init"
  run_as_user "WINEPREFIX=~/.wine-battlenet winetricks --unattended win10"
  run_as_user "WINEPREFIX=~/.wine-battlenet winetricks --unattended corefonts vcrun2019 dotnet48"
fi
if [ "$has_battlenet_installer" = "no" ]; then
  echo "Downloading Battle.net installer..."
  run_as_user "mkdir -p ~/Downloads"
  run_as_user "curl -L -o ~/Downloads/Battle.net-Setup.exe 'https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live'"
fi
if [ "$has_battlenet" = "no" ]; then
  # Install Battle.net (may require user interaction)
  echo "Installing Battle.net... This will launch the installer GUI and may require user input."
  run_as_user "WINEPREFIX=~/.wine-battlenet wine ~/Downloads/Battle.net-Setup.exe"
fi
# EA App
if [ "$has_wine_prefix_ea" = "no" ]; then
  echo "Setting up Wine prefix for EA App..."
  run_as_user "mkdir -p ~/.wine-ea"
  run_as_user "WINEPREFIX=~/.wine-ea WINEARCH=win64 wineboot --init"
  run_as_user "WINEPREFIX=~/.wine-ea winetricks --unattended win10"
  run_as_user "WINEPREFIX=~/.wine-ea winetricks --unattended corefonts vcrun2019 dotnet48"
fi
if [ "$has_ea_installer" = "no" ]; then
  echo "Downloading EA App installer..."
  run_as_user "mkdir -p ~/Downloads"
  run_as_user "curl -L -o ~/Downloads/EAappInstaller.exe 'https://origin-a.akamaihd.net/EA-Desktop-Client-Download/installer-releases/EAappInstaller.exe'"
fi
if [ "$has_ea" = "no" ]; then
  # Install EA App (may require user interaction)
  echo "Installing EA App... This will launch the installer GUI and may require user input."
  run_as_user "WINEPREFIX=~/.wine-ea wine ~/Downloads/EAappInstaller.exe"
fi
# Verify installations
echo "Verifying installations..."
command -v python3.12 >/dev/null && echo "Python 3.12 installed" || echo "Python 3.12 installation failed"
command -v $pip_cmd >/dev/null && echo "pip for Python 3.12 installed" || echo "pip for Python 3.12 installation failed"
command -v docker >/dev/null && echo "Docker installed" || echo "Docker installation failed"
command -v code >/dev/null && echo "Visual Studio Code installed" || echo "VS Code installation failed"
command -v tailscale >/dev/null && echo "Tailscale installed" || echo "Tailscale installation failed"
command -v nextcloud >/dev/null && echo "Nextcloud Desktop installed" || echo "Nextcloud Desktop installation failed"
command -v libreoffice >/dev/null && echo "LibreOffice installed" || echo "LibreOffice installation failed"
command -v htop >/dev/null && echo "htop installed" || echo "htop installation failed"
command -v smbclient >/dev/null && echo "CIFS/SMB tools installed" || echo "CIFS/SMB tools installation failed"
command -v nvcc >/dev/null && echo "NVIDIA CUDA installed" || echo "NVIDIA CUDA installation failed"
nvidia-smi >/dev/null && echo "NVIDIA driver installed" || echo "NVIDIA driver installation failed"
command -v steam >/dev/null && echo "Steam installed" || echo "Steam installation failed"
command -v wine >/dev/null && echo "Wine installed" || echo "Wine installation failed"
[ -f "/home/$target_user/.wine-battlenet/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe" ] && echo "Battle.net installed" || echo "Battle.net installation may have failed (check manually)"
[ -f "/home/$target_user/.wine-ea/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe" ] && echo "EA App installed" || echo "EA App installation may have failed (check manually)"
echo "Installation and configuration complete!"
echo "Please log out and log back in for group changes (e.g., docker group) to take effect."
echo "You may need to reboot for NVIDIA driver changes to take effect."
echo "To run Battle.net, use: WINEPREFIX=~/.wine-battlenet wine '~/.wine-battlenet/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe'"
echo "To run EA App, use: WINEPREFIX=~/.wine-ea wine '~/.wine-ea/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe'"
echo "After installation, you can install games via Battle.net or EA App."
