#!/bin/bash
# This script can be run as a regular user with sudo privileges or as sudo ./setup.sh.
# It installs Python 3.12, Docker Engine with Compose and NVIDIA support, Visual Studio Code, Tailscale,
# Nextcloud Desktop, LibreOffice, htop, CIFS/SMB tools, nonfree NVIDIA driver, and NVIDIA CUDA
# on Manjaro, Fedora, Ubuntu, or raw Arch Linux. It also configures Docker and adds the target user to the docker group.
# Additionally, it installs Steam and Wine for gaming purposes.
# It also sets up a Wine prefix and installs Battle.net, EA App, and Epic Games Store using Wine.
# Now with checks to skip already completed tasks.
# Added master boolean flags to enable/disable sections.
# Added GPU choice: nvidia, amd, intel (set at top, affects driver installation). Now with auto-detection.
# For interactive mode, you can edit the flags below or run with prompts (basic prompts added).
# Script broken into phases: Phase 1 (updates, packages, drivers), Phase 2 (gaming setup, extra CUDA).
# Added error handling: trap for errors, check after critical commands, logging.
# Added computer types: workstation/server. Server skips GUI/gaming installs. For raw Arch, installs GNOME if workstation.

# Master Boolean Flags (true/false) - Edit these to enable/disable installations
INSTALL_PYTHON=true
INSTALL_DOCKER=true
INSTALL_VSCODE=true
INSTALL_TAILSCALE=true
INSTALL_NEXTCLOUD=true
INSTALL_LIBREOFFICE=true
INSTALL_HTOP=true
INSTALL_CIFS=true
INSTALL_STEAM=true
INSTALL_WINE=true
INSTALL_BATTLENET=true
INSTALL_EA=true
INSTALL_EPIC=true
INSTALL_GPU_DRIVERS=true  # If true, installs drivers based on GPU_TYPE
INSTALL_EXTRA_CUDA=true   # If true and NVIDIA, installs extra like cudnn

# Computer Type: workstation or server (lowercase) - Will be prompted if interactive
COMPUTER_TYPE="workstation"

# GPU Type: nvidia, amd, intel (lowercase) - Will be auto-detected if not set
GPU_TYPE=""

# Error handling setup
LOG_FILE="/tmp/setup_script.log"
echo "Script started at $(date)" > "$LOG_FILE"
trap 'echo "Error occurred at line $LINENO with exit code $?" >> "$LOG_FILE"; exit 1' ERR
set -e  # Exit on error
set -o pipefail  # Fail on pipe errors

# Interactive prompts - If you want to override flags interactively
echo "Do you want to run in interactive mode? (y/n)"
read interactive
if [ "$interactive" = "y" ]; then
  echo "Enter computer type (workstation/server):"
  read COMPUTER_TYPE
  echo "Install Python? (y/n)"
  read ans; [ "$ans" = "y" ] && INSTALL_PYTHON=true || INSTALL_PYTHON=false
  echo "Install Docker? (y/n)"
  read ans; [ "$ans" = "y" ] && INSTALL_DOCKER=true || INSTALL_DOCKER=false
  # Add more prompts as needed...
  echo "Install Battle.net? (y/n)"
  read ans; [ "$ans" = "y" ] && INSTALL_BATTLENET=true || INSTALL_BATTLENET=false
  echo "Install EA App? (y/n)"
  read ans; [ "$ans" = "y" ] && INSTALL_EA=true || INSTALL_EA=false
  echo "Install Epic Games Store? (y/n)"
  read ans; [ "$ans" = "y" ] && INSTALL_EPIC=true || INSTALL_EPIC=false
  echo "Install extra CUDA packages (if NVIDIA)? (y/n)"
  read ans; [ "$ans" = "y" ] && INSTALL_EXTRA_CUDA=true || INSTALL_EXTRA_CUDA=false
fi

# Adjust flags for server type
if [ "$COMPUTER_TYPE" = "server" ]; then
  INSTALL_VSCODE=false
  INSTALL_NEXTCLOUD=false
  INSTALL_LIBREOFFICE=false
  INSTALL_STEAM=false
  INSTALL_WINE=false
  INSTALL_BATTLENET=false
  INSTALL_EA=false
  INSTALL_EPIC=false
fi

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
  if [ "$OS" = "manjaro" ]; then
    OS_FAMILY="arch"
  elif [ "$OS" = "arch" ]; then
    OS_FAMILY="arch_raw"
  elif [ "$OS" = "fedora" ]; then
    OS_FAMILY="fedora"
  elif [ "$OS" = "ubuntu" ]; then
    OS_FAMILY="ubuntu"
  else
    echo "Unsupported OS: $OS" | tee -a "$LOG_FILE"
    exit 1
  fi
else
  echo "Cannot detect OS" | tee -a "$LOG_FILE"
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
    echo "Script run directly as root without sudo. This may cause issues with makepkg on Arch." | tee -a "$LOG_FILE"
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
    su "$target_user" -c "$1" || { echo "Failed to run as user: $1" >> "$LOG_FILE"; exit 1; }
  else
    bash -c "$1" || { echo "Failed to run: $1" >> "$LOG_FILE"; exit 1; }
  fi
}
# Function to check if user is in group
user_in_group() {
  groups "$target_user" | grep -q "\b$1\b"
}
# Auto-detect GPU if not set
if [ -z "$GPU_TYPE" ]; then
  if command -v lspci >/dev/null; then
    if lspci | grep -i nvidia >/dev/null; then
      GPU_TYPE="nvidia"
    elif lspci | grep -i amd | grep -i vga >/dev/null; then
      GPU_TYPE="amd"
    elif lspci | grep -i intel | grep -i vga >/dev/null; then
      GPU_TYPE="intel"
    else
      GPU_TYPE="unknown"
      echo "Could not detect GPU type. Defaulting to no GPU-specific installs." | tee -a "$LOG_FILE"
    fi
  else
    echo "lspci not found. Cannot auto-detect GPU." | tee -a "$LOG_FILE"
    exit 1
  fi
  echo "Detected GPU type: $GPU_TYPE" | tee -a "$LOG_FILE"
else
  echo "Using specified GPU type: $GPU_TYPE" | tee -a "$LOG_FILE"
fi
# OS-specific commands
case $OS_FAMILY in
  arch|arch_raw)
    update_cmd="${priv_cmd}pacman -Syu --noconfirm"
    install_cmd="${priv_cmd}pacman -S --needed --noconfirm"
    search_cmd="pacman -Qi"
    jq_pkg="jq"
    base_devel_pkg="base-devel git"
    go_pkg="go"
    python_pkg="python312" # From AUR
    pip_cmd="pip3.12"
    # For GPU on Arch
    if [ "$GPU_TYPE" = "nvidia" ]; then
      nvidia_driver_cmd="${priv_cmd}mhwd -a pci nonfree 0300"
      cuda_pkg="cuda cuda-tools"  # Base CUDA
      extra_cuda_pkg="cudnn opencl-nvidia"  # Extra like cudnn
      libnvidia_container_pkg="libnvidia-container nvidia-container-toolkit"
    elif [ "$GPU_TYPE" = "amd" ]; then
      nvidia_driver_cmd="${priv_cmd}mhwd -a pci free 0300"  # Or nonfree if proprietary
      cuda_pkg=""
      extra_cuda_pkg=""
      libnvidia_container_pkg=""
    elif [ "$GPU_TYPE" = "intel" ]; then
      nvidia_driver_cmd="${priv_cmd}mhwd -a pci free 0300"
      cuda_pkg=""
      extra_cuda_pkg=""
      libnvidia_container_pkg=""
    fi
    docker_pkg="docker docker-compose"
    vscode_pkg="visual-studio-code-bin" # From AUR
    nextcloud_pkg="nextcloud-client"
    libreoffice_pkg="libreoffice-fresh"
    htop_pkg="htop"
    cifs_pkg="cifs-utils smbclient"
    steam_pkg="steam"
    wine_pkg="wine"
    winetricks_pkg="winetricks samba wine-mono wine-gecko"  # Added mono/gecko for Wine issues
    gnome_pkg="gnome gnome-tweaks gdm"  # For raw Arch workstation
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
    # For GPU on Fedora
    function install_gpu_fedora() {
      if [ "$GPU_TYPE" = "nvidia" ]; then
        ${priv_cmd}dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || { echo "Failed to add RPM Fusion nonfree" >> "$LOG_FILE"; exit 1; }
        ${priv_cmd}dnf update -y
        ${priv_cmd}dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda || { echo "Failed to install NVIDIA drivers" >> "$LOG_FILE"; exit 1; }
      elif [ "$GPU_TYPE" = "amd" ]; then
        ${priv_cmd}dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm || { echo "Failed to add RPM Fusion free" >> "$LOG_FILE"; exit 1; }
        ${priv_cmd}dnf update -y
        ${priv_cmd}dnf install -y akmod-amd-gpu xorg-x11-drv-amdgpu  # Adjust as needed
      elif [ "$GPU_TYPE" = "intel" ]; then
        ${priv_cmd}dnf install -y mesa-dri-drivers || { echo "Failed to install Intel drivers" >> "$LOG_FILE"; exit 1; }
      fi
    }
    nvidia_driver_cmd="install_gpu_fedora"
    if [ "$GPU_TYPE" = "nvidia" ]; then
      cuda_pkg="cuda cuda-devel cuda-libs"  # Base
      extra_cuda_pkg="cuda-cudnn cuda-cudnn-devel"  # Extra
      libnvidia_container_pkg="nvidia-container-toolkit"
    else
      cuda_pkg=""
      extra_cuda_pkg=""
      libnvidia_container_pkg=""
    fi
    function install_libnvidia_fedora() {
      if [ "$GPU_TYPE" = "nvidia" ]; then
        ${priv_cmd}dnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo || { echo "Failed to add NVIDIA container repo" >> "$LOG_FILE"; exit 1; }
        ${priv_cmd}dnf install -y nvidia-container-toolkit || { echo "Failed to install nvidia-container-toolkit" >> "$LOG_FILE"; exit 1; }
      fi
    }
    libnvidia_install_cmd="install_libnvidia_fedora"
    docker_pkg="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    vscode_pkg="code"
    nextcloud_pkg="nextcloud-client"
    libreoffice_pkg="libreoffice"
    htop_pkg="htop"
    cifs_pkg="cifs-utils samba-client"
    steam_pkg="steam"
    wine_pkg="wine"
    winetricks_pkg="winetricks samba wine-mono wine-gecko"  # Added mono/gecko
    gnome_pkg="gnome-desktop gnome-tweaks gdm"  # For Fedora workstation, but usually pre-installed
    ;;
  ubuntu)
    update_cmd="${priv_cmd}apt update && ${priv_cmd}apt upgrade -y"
    install_cmd="${priv_cmd}apt install -y"
    search_cmd="dpkg -s"
    jq_pkg="jq"
    base_devel_pkg="build-essential git"
    go_pkg="golang-go"
    python_pkg="python3.12 python3.12-venv"
    pip_cmd="pip3.12"
    # For GPU on Ubuntu
    if [ "$GPU_TYPE" = "nvidia" ]; then
      nvidia_driver_cmd="${priv_cmd}ubuntu-drivers autoinstall || { echo \"Failed to install NVIDIA drivers\" >> \"$LOG_FILE\"; exit 1; }"
      cuda_pkg="cuda-toolkit cuda-tools"  # Base
      extra_cuda_pkg="libcudnn9-cuda-12"  # Extra; assumes repo added
    elif [ "$GPU_TYPE" = "amd" ]; then
      nvidia_driver_cmd="${priv_cmd}apt install -y mesa-vulkan-drivers"  # Basic
      cuda_pkg=""
      extra_cuda_pkg=""
    elif [ "$GPU_TYPE" = "intel" ]; then
      nvidia_driver_cmd="${priv_cmd}apt install -y mesa-vulkan-drivers"
      cuda_pkg=""
      extra_cuda_pkg=""
    fi
    docker_pkg="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    if [ "$GPU_TYPE" = "nvidia" ]; then
      libnvidia_container_pkg="nvidia-container-toolkit"
    else
      libnvidia_container_pkg=""
    fi
    function install_libnvidia_ubuntu() {
      if [ "$GPU_TYPE" = "nvidia" ]; then
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | ${priv_cmd}gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg || { echo "Failed to add NVIDIA GPG key" >> "$LOG_FILE"; exit 1; }
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
          sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
          ${priv_cmd}tee /etc/apt/sources.list.d/nvidia-container-toolkit.list || { echo "Failed to add NVIDIA container list" >> "$LOG_FILE"; exit 1; }
        ${priv_cmd}apt update
        ${priv_cmd}apt install -y nvidia-container-toolkit || { echo "Failed to install nvidia-container-toolkit" >> "$LOG_FILE"; exit 1; }
      fi
    }
    libnvidia_install_cmd="install_libnvidia_ubuntu"
    function add_cuda_repo_ubuntu() {
      if [ "$GPU_TYPE" = "nvidia" ]; then
        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1-1_all.deb || { echo "Failed to download CUDA keyring" >> "$LOG_FILE"; exit 1; }
        ${priv_cmd}dpkg -i cuda-keyring_1-1_all.deb || { echo "Failed to install CUDA keyring" >> "$LOG_FILE"; exit 1; }
        ${priv_cmd}apt update
      fi
    }
    vscode_pkg="code"
    nextcloud_pkg="nextcloud-desktop"
    libreoffice_pkg="libreoffice"
    htop_pkg="htop"
    cifs_pkg="cifs-utils smbclient"
    steam_pkg="steam"
    wine_pkg="wine"
    winetricks_pkg="winetricks samba wine-mono wine-gecko"  # Added mono/gecko
    gnome_pkg="gnome gnome-tweaks gdm3"  # For Ubuntu workstation, but usually pre-installed
    ;;
esac
# Initial checks to see what's already done
echo "Performing initial checks..." | tee -a "$LOG_FILE"
has_jq=$(command -v jq >/dev/null && echo "yes" || echo "no")
has_base_devel=$($search_cmd base-devel >/dev/null 2>&1 || $search_cmd dnf-plugins-core >/dev/null 2>&1 || $search_cmd build-essential >/dev/null 2>&1 && echo "yes" || echo "no")
has_git=$(command -v git >/dev/null && echo "yes" || echo "no")
has_go=$(command -v go >/dev/null && echo "yes" || echo "no")
has_python312=$(command -v python3.12 >/dev/null && echo "yes" || echo "no")
has_pip312=$(command -v $pip_cmd >/dev/null && echo "yes" || echo "no")
has_gpu_driver=$(if [ "$GPU_TYPE" = "nvidia" ]; then nvidia-smi >/dev/null 2>&1 && echo "yes" || echo "no"; elif [ "$GPU_TYPE" = "amd" ] || [ "$GPU_TYPE" = "intel" ]; then lspci | grep -i vga >/dev/null && echo "yes" || echo "no"; else echo "no"; fi)
has_cuda=$(command -v nvcc >/dev/null && echo "yes" || echo "no")
has_docker=$(command -v docker >/dev/null && echo "yes" || echo "no")
has_docker_config=$([ -f /etc/docker/daemon.json ] && grep -q "nvidia" /etc/docker/daemon.json && [ "$GPU_TYPE" = "nvidia" ] && echo "yes" || echo "no")
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
has_wine_prefix_epic=$([ -d "/home/$target_user/.wine-epic" ] && echo "yes" || echo "no")
has_epic_installer=$([ -f "/home/$target_user/Downloads/EpicGamesLauncherInstaller.msi" ] && echo "yes" || echo "no")
has_epic=$([ -f "/home/$target_user/.wine-epic/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe" ] && echo "yes" || echo "no")
has_cudnn=$(if [ "$OS_FAMILY" = "arch" ] || [ "$OS_FAMILY" = "arch_raw" ]; then pacman -Qi cudnn >/dev/null 2>&1 && echo "yes" || echo "no"; elif [ "$OS_FAMILY" = "fedora" ]; then rpm -qi cuda-cudnn >/dev/null 2>&1 && echo "yes" || echo "no"; elif [ "$OS_FAMILY" = "ubuntu" ]; then dpkg -s libcudnn9-cuda-12 >/dev/null 2>&1 && echo "yes" || echo "no"; fi)
has_gnome=$(command -v gnome-shell >/dev/null && echo "yes" || echo "no")
# Print status
echo "Status:" | tee -a "$LOG_FILE"
echo "jq: $has_jq"
echo "base-devel: $has_base_devel"
echo "git: $has_git"
echo "go: $has_go"
echo "Python 3.12: $has_python312"
echo "pip 3.12: $has_pip312"
echo "GPU driver: $has_gpu_driver"  # Updated to has_gpu_driver
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
echo "Wine prefix Epic: $has_wine_prefix_epic"
echo "Epic installer: $has_epic_installer"
echo "Epic Games Launcher: $has_epic"
echo "cuDNN: $has_cudnn"
echo "GNOME: $has_gnome"
# Phase 1: Updates, install packages, drivers
echo "=== Phase 1: System Update, Base Packages, and Drivers ===" | tee -a "$LOG_FILE"
if [ "$has_jq" = "no" ]; then
  echo "Installing jq..." | tee -a "$LOG_FILE"
  $install_cmd $jq_pkg || { echo "Failed to install jq" >> "$LOG_FILE"; exit 1; }
fi
# Always update
echo "Updating system packages..." | tee -a "$LOG_FILE"
$update_cmd || { echo "System update failed" >> "$LOG_FILE"; exit 1; }
if [ "$has_base_devel" = "no" ] || [ "$has_git" = "no" ]; then
  echo "Installing base-devel and git..." | tee -a "$LOG_FILE"
  $install_cmd $base_devel_pkg || { echo "Failed to install base-devel/git" >> "$LOG_FILE"; exit 1; }
fi
if [ "$has_go" = "no" ]; then
  echo "Installing go..." | tee -a "$LOG_FILE"
  $install_cmd $go_pkg || { echo "Failed to install go" >> "$LOG_FILE"; exit 1; }
fi
if [ "$OS_FAMILY" = "arch_raw" ] && [ "$COMPUTER_TYPE" = "workstation" ] && [ "$has_gnome" = "no" ]; then
  echo "Installing latest GNOME desktop on raw Arch..." | tee -a "$LOG_FILE"
  $install_cmd $gnome_pkg || { echo "Failed to install GNOME" >> "$LOG_FILE"; exit 1; }
  ${priv_cmd}systemctl enable gdm || { echo "Failed to enable GDM" >> "$LOG_FILE"; exit 1; }
fi
if [ "$OS_FAMILY" = "arch" ] || [ "$OS_FAMILY" = "arch_raw" ]; then
  has_yay=$(command -v yay >/dev/null && echo "yes" || echo "no")
  if [ "$has_yay" = "no" ]; then
    echo "Installing yay AUR helper..." | tee -a "$LOG_FILE"
    ${priv_cmd}rm -rf /tmp/yay || { echo "Failed to rm /tmp/yay" >> "$LOG_FILE"; exit 1; }
    run_as_user "git clone https://aur.archlinux.org/yay.git /tmp/yay"
    run_as_user "cd /tmp/yay && makepkg --noconfirm"
    ${priv_cmd}pacman -U /tmp/yay/*.pkg.tar* --noconfirm || { echo "Failed to install yay" >> "$LOG_FILE"; exit 1; }
    ${priv_cmd}rm -rf /tmp/yay
  fi
fi
if [ "$INSTALL_PYTHON" = "true" ] && [ "$has_python312" = "no" ]; then
  if [ "$OS_FAMILY" = "arch" ] || [ "$OS_FAMILY" = "arch_raw" ]; then
    echo "Installing Python 3.12 from AUR..." | tee -a "$LOG_FILE"
    ${priv_cmd}rm -rf /tmp/python312 || { echo "Failed to rm /tmp/python312" >> "$LOG_FILE"; exit 1; }
    run_as_user "git clone https://aur.archlinux.org/python312.git /tmp/python312"
    run_as_user "gpg --recv-keys 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D E3FF2839C048B25C084DEBE9B26995E310250568"
    run_as_user "cd /tmp/python312 && makepkg --noconfirm"
    ${priv_cmd}pacman -U /tmp/python312/*.pkg.tar* --noconfirm || { echo "Failed to install Python 3.12" >> "$LOG_FILE"; exit 1; }
    ${priv_cmd}rm -rf /tmp/python312
  else
    $install_cmd $python_pkg || { echo "Failed to install Python 3.12" >> "$LOG_FILE"; exit 1; }
  fi
fi
if [ "$INSTALL_PYTHON" = "true" ] && [ "$has_pip312" = "no" ] && [ "$has_python312" = "yes" ]; then
  echo "Installing pip for Python 3.12..." | tee -a "$LOG_FILE"
  if [ "$OS_FAMILY" = "fedora" ]; then
    if ! $install_cmd python3.12-pip --skip-unavailable; then
      run_as_user "curl -fsSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py; python3.12 get-pip.py; rm get-pip.py;" || { echo "Failed to install pip via get-pip.py" >> "$LOG_FILE"; exit 1; }
    fi
  else
    run_as_user "python3.12 -m ensurepip || { echo 'ensurepip not available, installing pip via get-pip.py...'; curl -fsSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py; python3.12 get-pip.py; rm get-pip.py; }" || { echo "Failed to install pip" >> "$LOG_FILE"; exit 1; }
  fi
fi
if [ "$INSTALL_GPU_DRIVERS" = "true" ] && [ "$has_gpu_driver" = "no" ]; then
  echo "Installing GPU driver for $GPU_TYPE..." | tee -a "$LOG_FILE"
  $nvidia_driver_cmd
fi
if [ "$INSTALL_GPU_DRIVERS" = "true" ] && [ "$GPU_TYPE" = "nvidia" ] && [ "$has_cuda" = "no" ]; then
  echo "Installing base NVIDIA CUDA..." | tee -a "$LOG_FILE"
  $install_cmd $cuda_pkg || { echo "Failed to install CUDA" >> "$LOG_FILE"; exit 1; }
fi
if [ "$INSTALL_DOCKER" = "true" ] && [ "$has_docker" = "no" ]; then
  if [ "$OS_FAMILY" = "fedora" ] || [ "$OS_FAMILY" = "ubuntu" ]; then
    # Add Docker repo for Fedora/Ubuntu
    if [ "$OS_FAMILY" = "fedora" ]; then
      echo "Adding Docker CE repository..." | tee -a "$LOG_FILE"
      cat <<EOF | ${priv_cmd}tee /etc/yum.repos.d/docker-ce.repo || { echo "Failed to add Docker repo" >> "$LOG_FILE"; exit 1; }
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF
    elif [ "$OS_FAMILY" = "ubuntu" ]; then
      echo "Adding Docker CE repository..." | tee -a "$LOG_FILE"
      ${priv_cmd}apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release || { echo "Failed to install Docker prereqs" >> "$LOG_FILE"; exit 1; }
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | ${priv_cmd}gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || { echo "Failed to add Docker GPG key" >> "$LOG_FILE"; exit 1; }
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | ${priv_cmd}tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo "Failed to add Docker list" >> "$LOG_FILE"; exit 1; }
      ${priv_cmd}apt update || { echo "Failed to apt update after Docker repo" >> "$LOG_FILE"; exit 1; }
    fi
  fi
  echo "Installing Docker Engine and Compose..." | tee -a "$LOG_FILE"
  $install_cmd $docker_pkg || { echo "Failed to install Docker" >> "$LOG_FILE"; exit 1; }
fi
if [ "$INSTALL_DOCKER" = "true" ] && [ "$has_docker" = "yes" ] && [ "$GPU_TYPE" = "nvidia" ]; then
  if ! $search_cmd $libnvidia_container_pkg >/dev/null 2>&1; then
    echo "Installing nvidia-container-toolkit..." | tee -a "$LOG_FILE"
    if [ "$OS_FAMILY" = "fedora" ] || [ "$OS_FAMILY" = "ubuntu" ]; then
      $libnvidia_install_cmd
    else
      $install_cmd $libnvidia_container_pkg || { echo "Failed to install nvidia-container-toolkit" >> "$LOG_FILE"; exit 1; }
    fi
  fi
fi
if [ "$INSTALL_DOCKER" = "true" ] && [ "$has_docker_config" = "no" ] && [ "$GPU_TYPE" = "nvidia" ]; then
  echo "Configuring Docker daemon..." | tee -a "$LOG_FILE"
  ${priv_cmd}mkdir -p /etc/docker || { echo "Failed to mkdir /etc/docker" >> "$LOG_FILE"; exit 1; }
  cat <<EOF | ${priv_cmd}tee /etc/docker/daemon.json || { echo "Failed to configure Docker daemon" >> "$LOG_FILE"; exit 1; }
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
if [ "$INSTALL_DOCKER" = "true" ] && [ "$has_docker" = "yes" ] && [ "$has_docker_enabled" = "no" ]; then
  echo "Starting and enabling Docker service..." | tee -a "$LOG_FILE"
  ${priv_cmd}systemctl start docker || { echo "Failed to start Docker" >> "$LOG_FILE"; exit 1; }
  ${priv_cmd}systemctl enable docker || { echo "Failed to enable Docker" >> "$LOG_FILE"; exit 1; }
fi
if [ "$INSTALL_DOCKER" = "true" ] && [ "$has_docker" = "yes" ]; then
  echo "Restarting Docker service..." | tee -a "$LOG_FILE"
  ${priv_cmd}systemctl restart docker || { echo "Failed to restart Docker" >> "$LOG_FILE"; exit 1; }
fi
if [ "$INSTALL_DOCKER" = "true" ] && [ "$has_docker_group" = "no" ]; then
  echo "Adding user '$target_user' to docker group..." | tee -a "$LOG_FILE"
  ${priv_cmd}usermod -aG docker "$target_user" || { echo "Failed to add user to docker group" >> "$LOG_FILE"; exit 1; }
fi
if [ "$INSTALL_VSCODE" = "true" ] && [ "$has_vscode" = "no" ]; then
  if [ "$OS_FAMILY" = "arch" ] || [ "$OS_FAMILY" = "arch_raw" ]; then
    echo "Installing Visual Studio Code from AUR..." | tee -a "$LOG_FILE"
    ${priv_cmd}rm -rf /tmp/visual-studio-code-bin || { echo "Failed to rm /tmp/visual-studio-code-bin" >> "$LOG_FILE"; exit 1; }
    run_as_user "git clone https://aur.archlinux.org/visual-studio-code-bin.git /tmp/visual-studio-code-bin"
    run_as_user "cd /tmp/visual-studio-code-bin && makepkg --noconfirm"
    ${priv_cmd}pacman -U /tmp/visual-studio-code-bin/*.pkg.tar* --noconfirm || { echo "Failed to install VS Code" >> "$LOG_FILE"; exit 1; }
    ${priv_cmd}rm -rf /tmp/visual-studio-code-bin
  else
    # For Fedora/Ubuntu, add repo
    if [ "$OS_FAMILY" = "fedora" ]; then
      echo "Adding Visual Studio Code repository..." | tee -a "$LOG_FILE"
      rpm --import https://packages.microsoft.com/keys/microsoft.asc || { echo "Failed to import Microsoft key" >> "$LOG_FILE"; exit 1; }
      cat <<EOF | ${priv_cmd}tee /etc/yum.repos.d/vscode.repo || { echo "Failed to add VS Code repo" >> "$LOG_FILE"; exit 1; }
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
      echo "Adding Visual Studio Code repository..." | tee -a "$LOG_FILE"
      wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg || { echo "Failed to download Microsoft GPG" >> "$LOG_FILE"; exit 1; }
      ${priv_cmd}install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg || { echo "Failed to install Microsoft keyring" >> "$LOG_FILE"; exit 1; }
      echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | ${priv_cmd}tee /etc/apt/sources.list.d/vscode.list || { echo "Failed to add VS Code list" >> "$LOG_FILE"; exit 1; }
      rm packages.microsoft.gpg
      ${priv_cmd}apt update || { echo "Failed to apt update after VS Code repo" >> "$LOG_FILE"; exit 1; }
    fi
    echo "Installing Visual Studio Code..." | tee -a "$LOG_FILE"
    $install_cmd $vscode_pkg || { echo "Failed to install VS Code" >> "$LOG_FILE"; exit 1; }
  fi
fi
if [ "$INSTALL_TAILSCALE" = "true" ]; then
  # Tailscale already has its own check
  if [ "$has_tailscale" = "yes" ]; then
    if [ "$has_tailscale_connected" = "yes" ]; then
      echo "Tailscale is already installed and connected. Skipping." | tee -a "$LOG_FILE"
    else
      echo "Tailscale is installed but not connected." | tee -a "$LOG_FILE"
      if [ -z "$TAILSCALE_AUTH_KEY" ]; then
        read -p "Enter Tailscale auth key (generate at https://login.tailscale.com/admin/settings/keys): " TAILSCALE_AUTH_KEY
      fi
      ${priv_cmd}tailscale up --authkey="${TAILSCALE_AUTH_KEY}" --accept-routes || { echo "Failed to connect Tailscale" >> "$LOG_FILE"; exit 1; }
    fi
  else
    echo "Installing Tailscale..." | tee -a "$LOG_FILE"
    curl -fsSL https://tailscale.com/install.sh | sh || { echo "Failed to install Tailscale" >> "$LOG_FILE"; exit 1; }
    if [ -z "$TAILSCALE_AUTH_KEY" ]; then
      read -p "Enter Tailscale auth key (generate at https://login.tailscale.com/admin/settings/keys): " TAILSCALE_AUTH_KEY
    fi
    ${priv_cmd}tailscale up --authkey="${TAILSCALE_AUTH_KEY}" --accept-routes || { echo "Failed to connect Tailscale" >> "$LOG_FILE"; exit 1; }
  fi
fi
if [ "$INSTALL_NEXTCLOUD" = "true" ] && [ "$has_nextcloud" = "no" ]; then
  echo "Installing Nextcloud Desktop..." | tee -a "$LOG_FILE"
  $install_cmd $nextcloud_pkg || { echo "Failed to install Nextcloud" >> "$LOG_FILE"; exit 1; }
fi
if [ "$INSTALL_LIBREOFFICE" = "true" ] && [ "$has_libreoffice" = "no" ]; then
  echo "Installing LibreOffice..." | tee -a "$LOG_FILE"
  $install_cmd $libreoffice_pkg || { echo "Failed to install LibreOffice" >> "$LOG_FILE"; exit 1; }
fi
if [ "$INSTALL_HTOP" = "true" ] && [ "$has_htop" = "no" ]; then
  echo "Installing htop..." | tee -a "$LOG_FILE"
  $install_cmd $htop_pkg || { echo "Failed to install htop" >> "$LOG_FILE"; exit 1; }
fi
if [ "$INSTALL_CIFS" = "true" ] && [ "$has_cifs" = "no" ]; then
  echo "Installing CIFS/SMB tools..." | tee -a "$LOG_FILE"
  $install_cmd $cifs_pkg || { echo "Failed to install CIFS/SMB" >> "$LOG_FILE"; exit 1; }
fi
# Phase 2: Gaming setup and extra CUDA
echo "=== Phase 2: Gaming Setup and Extra CUDA (if NVIDIA) ===" | tee -a "$LOG_FILE"
if [ "$INSTALL_STEAM" = "true" ] && [ "$has_steam" = "no" ]; then
  echo "Installing Steam..." | tee -a "$LOG_FILE"
  $install_cmd $steam_pkg || { echo "Failed to install Steam" >> "$LOG_FILE"; exit 1; }
fi
if [ "$INSTALL_WINE" = "true" ] && [ "$has_wine" = "no" ]; then
  echo "Installing Wine..." | tee -a "$LOG_FILE"
  $install_cmd $wine_pkg || { echo "Failed to install Wine" >> "$LOG_FILE"; exit 1; }
fi
if ([ "$INSTALL_WINE" = "true" ] || [ "$INSTALL_BATTLENET" = "true" ] || [ "$INSTALL_EA" = "true" ] || [ "$INSTALL_EPIC" = "true" ]) && ([ "$has_winetricks" = "no" ] || [ "$has_samba" = "no" ]); then
  echo "Installing winetricks and samba..." | tee -a "$LOG_FILE"
  $install_cmd $winetricks_pkg || { echo "Failed to install winetricks/samba" >> "$LOG_FILE"; exit 1; }
fi
if [ "$INSTALL_EXTRA_CUDA" = "true" ] && [ "$GPU_TYPE" = "nvidia" ] && [ "$has_cudnn" = "no" ]; then
  if [ "$OS_FAMILY" = "ubuntu" ]; then
    add_cuda_repo_ubuntu
  fi
  echo "Installing extra CUDA packages (e.g., cuDNN)..." | tee -a "$LOG_FILE"
  $install_cmd $extra_cuda_pkg || { echo "Failed to install extra CUDA" >> "$LOG_FILE"; exit 1; }
fi
# Battle.net
if [ "$INSTALL_BATTLENET" = "true" ]; then
  if [ "$has_wine_prefix_bnet" = "no" ]; then
    echo "Setting up Wine prefix for Battle.net..." | tee -a "$LOG_FILE"
    run_as_user "mkdir -p ~/.wine-battlenet"
    run_as_user "WINEPREFIX=~/.wine-battlenet WINEARCH=win64 wineboot --init"
    run_as_user "WINEPREFIX=~/.wine-battlenet winetricks --unattended win10"
    run_as_user "WINEPREFIX=~/.wine-battlenet winetricks --unattended corefonts vcrun2019 dotnet48"
  fi
  if [ "$has_battlenet_installer" = "no" ]; then
    echo "Downloading Battle.net installer..." | tee -a "$LOG_FILE"
    run_as_user "mkdir -p ~/Downloads"
    run_as_user "curl -L -o ~/Downloads/Battle.net-Setup.exe 'https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live'" || { echo "Failed to download Battle.net installer" >> "$LOG_FILE"; exit 1; }
    [ -f "/home/$target_user/Downloads/Battle.net-Setup.exe" ] || { echo "Battle.net installer not found after download" >> "$LOG_FILE"; exit 1; }
  fi
  if [ "$has_battlenet" = "no" ]; then
    echo "Installing Battle.net... This will launch the installer GUI and may require user input." | tee -a "$LOG_FILE"
    run_as_user "WINEPREFIX=~/.wine-battlenet wine ~/Downloads/Battle.net-Setup.exe"
  fi
fi
# EA App
if [ "$INSTALL_EA" = "true" ]; then
  if [ "$has_wine_prefix_ea" = "no" ]; then
    echo "Setting up Wine prefix for EA App..." | tee -a "$LOG_FILE"
    run_as_user "mkdir -p ~/.wine-ea"
    run_as_user "WINEPREFIX=~/.wine-ea WINEARCH=win64 wineboot --init"
    run_as_user "WINEPREFIX=~/.wine-ea winetricks --unattended win10"
    run_as_user "WINEPREFIX=~/.wine-ea winetricks --unattended corefonts vcrun2019 dotnet48"
  fi
  if [ "$has_ea_installer" = "no" ]; then
    echo "Downloading EA App installer..." | tee -a "$LOG_FILE"
    run_as_user "mkdir -p ~/Downloads"
    run_as_user "curl -L -o ~/Downloads/EAappInstaller.exe 'https://origin-a.akamaihd.net/EA-Desktop-Client-Download/installer-releases/EAappInstaller.exe'" || { echo "Failed to download EA installer" >> "$LOG_FILE"; exit 1; }
    [ -f "/home/$target_user/Downloads/EAappInstaller.exe" ] || { echo "EA installer not found after download" >> "$LOG_FILE"; exit 1; }
  fi
  if [ "$has_ea" = "no" ]; then
    echo "Installing EA App... This will launch the installer GUI and may require user input." | tee -a "$LOG_FILE"
    run_as_user "WINEPREFIX=~/.wine-ea wine ~/Downloads/EAappInstaller.exe"
  fi
fi
# Epic Games Launcher
if [ "$INSTALL_EPIC" = "true" ]; then
  if [ "$has_wine_prefix_epic" = "no" ]; then
    echo "Setting up Wine prefix for Epic Games..." | tee -a "$LOG_FILE"
    run_as_user "mkdir -p ~/.wine-epic"
    run_as_user "WINEPREFIX=~/.wine-epic WINEARCH=win64 wineboot --init"
    run_as_user "WINEPREFIX=~/.wine-epic winetricks --unattended win10"
    run_as_user "WINEPREFIX=~/.wine-epic winetricks --unattended corefonts vcrun2019 dotnet48"
  fi
  if [ "$has_epic_installer" = "no" ]; then
    echo "Downloading Epic Games installer..." | tee -a "$LOG_FILE"
    run_as_user "mkdir -p ~/Downloads"
    run_as_user "curl -L -o ~/Downloads/EpicGamesLauncherInstaller.msi 'https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi'" || { echo "Failed to download Epic installer" >> "$LOG_FILE"; exit 1; }
    [ -f "/home/$target_user/Downloads/EpicGamesLauncherInstaller.msi" ] || { echo "Epic installer not found after download" >> "$LOG_FILE"; exit 1; }
  fi
  if [ "$has_epic" = "no" ]; then
    echo "Installing Epic Games Launcher... This will launch the installer GUI and may require user input." | tee -a "$LOG_FILE"
    run_as_user "WINEPREFIX=~/.wine-epic wine msiexec /i ~/Downloads/EpicGamesLauncherInstaller.msi"
  fi
fi
# Verify installations
echo "Verifying installations..." | tee -a "$LOG_FILE"
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
if [ "$GPU_TYPE" = "nvidia" ]; then nvidia-smi >/dev/null && echo "NVIDIA driver installed" || echo "NVIDIA driver installation failed"; fi
command -v steam >/dev/null && echo "Steam installed" || echo "Steam installation failed"
command -v wine >/dev/null && echo "Wine installed" || echo "Wine installation failed"
[ -f "/home/$target_user/.wine-battlenet/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe" ] && echo "Battle.net installed" || echo "Battle.net installation may have failed (check manually)"
[ -f "/home/$target_user/.wine-ea/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe" ] && echo "EA App installed" || echo "EA App installation may have failed (check manually)"
[ -f "/home/$target_user/.wine-epic/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe" ] && echo "Epic Games Launcher installed" || echo "Epic Games Launcher installation may have failed (check manually)"
echo "Installation and configuration complete!" | tee -a "$LOG_FILE"
echo "Please log out and log back in for group changes (e.g., docker group) to take effect."
echo "You may need to reboot for NVIDIA driver changes to take effect."
echo "To run Battle.net, use: WINEPREFIX=~/.wine-battlenet wine '~/.wine-battlenet/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe'"
echo "To run EA App, use: WINEPREFIX=~/.wine-ea wine '~/.wine-ea/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe'"
echo "To run Epic Games Launcher, use: WINEPREFIX=~/.wine-epic wine '~/.wine-epic/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe'"
echo "After installation, you can install games via Battle.net, EA App, or Epic Games Launcher."
echo "Log file: $LOG_FILE"
