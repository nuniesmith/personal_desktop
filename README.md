# Linux Development & Gaming Setup Script

A comprehensive automated setup script for transforming fresh Linux installations into fully configured development and gaming workstations. Supports multiple distributions and handles both workstation and server configurations.

## 🚀 Features

### Core System Components
- **Python 3.12** with pip
- **Docker Engine** with Compose and NVIDIA container runtime support
- **Visual Studio Code** with extensions support
- **Tailscale** VPN for secure networking
- **Nextcloud Desktop** client for file synchronization
- **LibreOffice** productivity suite
- **System utilities** (htop, CIFS/SMB tools)

### Gaming Environment
- **Steam** gaming platform
- **Proton-GE** compatibility layer for Windows games
- **Game Launchers**:
  - Battle.net (Blizzard games)
  - EA App (Electronic Arts games)
  - Epic Games Launcher (Epic Games Store)

### GPU Support
- **NVIDIA**: Proprietary drivers, CUDA toolkit, cuDNN
- **AMD**: Mesa drivers and utilities
- **Intel**: Mesa drivers with hardware acceleration

### Supported Distributions
- **Manjaro Linux** (Arch-based)
- **Raw Arch Linux** (with GNOME installation option)
- **Fedora Linux** (with RPM Fusion)
- **Ubuntu Linux** (with official repositories)

## 📋 Prerequisites

- Fresh Linux installation (one of the supported distributions)
- Internet connection for downloading packages and installers
- User account with sudo privileges
- At least 10GB free disk space for gaming components

## 🛠 Installation

### Quick Start

1. **Download the script:**
   ```bash
   git clone https://github.com/your-username/linux-setup.git
   cd linux-setup
   chmod +x setup.sh
   ```

2. **Run with default settings:**
   ```bash
   sudo ./setup.sh
   ```

3. **Run interactively (recommended for first-time users):**
   ```bash
   ./setup.sh
   # Answer 'y' when prompted for interactive mode
   ```

### Configuration Options

The script can be configured by editing boolean flags at the top of `setup.sh`:

```bash
# Master Boolean Flags
INSTALL_PYTHON=true
INSTALL_DOCKER=true
INSTALL_VSCODE=true
INSTALL_TAILSCALE=true
INSTALL_NEXTCLOUD=true
INSTALL_LIBREOFFICE=true
INSTALL_HTOP=true
INSTALL_CIFS=true
INSTALL_STEAM=true
INSTALL_PROTON=true
INSTALL_BATTLENET=true
INSTALL_EA=true
INSTALL_EPIC=true
INSTALL_GPU_DRIVERS=true
INSTALL_EXTRA_CUDA=true
```

### Computer Types

- **Workstation**: Full installation including GUI applications and gaming
- **Server**: CLI-only installation, skips GUI and gaming components

## 🎮 Gaming Setup

### Game Launchers

After installation, the following launcher scripts are created:

#### Battle.net (Blizzard)
- **Location**: `~/Desktop/battlenet.sh` and `~/bin/battlenet.sh`
- **Usage**: `./battlenet.sh` or `battlenet.sh` (if ~/bin is in PATH)
- **Alternative**: `./battlenet-alt.sh` (DXVK renderer mode)
- **Games**: World of Warcraft, Overwatch, Diablo series, StarCraft, etc.

#### EA App (Electronic Arts)
- **Location**: `~/Desktop/ea-app.sh` and `~/bin/ea-app.sh`
- **Usage**: `./ea-app.sh` or `ea-app.sh`
- **Games**: FIFA, Battlefield, The Sims, Need for Speed, Apex Legends, etc.

#### Epic Games Launcher
- **Location**: `~/Desktop/epic-games.sh` and `~/bin/epic-games.sh`
- **Usage**: `./epic-games.sh` or `epic-games.sh`
- **Games**: Fortnite, Rocket League, Fall Guys, free weekly games, etc.

### Gaming Utilities

A comprehensive gaming management script is also created:

```bash
~/Desktop/gaming-utils.sh [command]
```

**Available commands:**
- `launch [battlenet|ea|epic]` - Launch specific game client
- `config [battlenet|ea|epic]` - Open Wine configuration
- `kill [battlenet|ea|epic]` - Terminate client processes
- `logs [battlenet|ea|epic]` - Show client logs
- `winetricks [battlenet|ea|epic]` - Run winetricks for prefix
- `reset [battlenet|ea|epic]` - Reset Wine prefix (WARNING: removes all data)

### Wine Prefixes

Each game launcher uses an isolated Wine environment:

- **Battle.net**: `~/.wine-battlenet/pfx/`
- **EA App**: `~/.wine-ea/pfx/`
- **Epic Games**: `~/.wine-epic/pfx/`

## 🔧 Configuration Details

### Proton-GE Setup

The script automatically downloads and installs the latest Proton-GE release:

- **Location**: `~/.proton/current/` (symlink to latest version)
- **Source**: [GloriousEggroll/proton-ge-custom](https://github.com/GloriousEggroll/proton-ge-custom)
- **Compatibility**: Optimized for gaming with latest fixes

### Docker Configuration

For NVIDIA systems, Docker is configured with:

```json
{
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### GPU Driver Detection

The script automatically detects your GPU and installs appropriate drivers:

```bash
# Auto-detection logic
if lspci | grep -i nvidia; then
    GPU_TYPE="nvidia"
elif lspci | grep -i amd; then
    GPU_TYPE="amd"
elif lspci | grep -i intel; then
    GPU_TYPE="intel"
fi
```

## 🐛 Troubleshooting

### Common Issues

#### Gaming Launchers Won't Start

1. **Check Wine prefix integrity:**
   ```bash
   ls -la ~/.wine-battlenet/pfx/drive_c/
   ls -la ~/.wine-ea/pfx/drive_c/
   ls -la ~/.wine-epic/pfx/drive_c/
   ```

2. **Verify Proton installation:**
   ```bash
   ls -la ~/.proton/current/proton
   ```

3. **Check for conflicting processes:**
   ```bash
   ps aux | grep -E "(Battle.net|EA|Epic)"
   pkill -f "Battle.net"  # Kill if needed
   ```

#### Display Issues

If launchers show display problems (black screens, multiple windows):

1. **Try software rendering mode** (default in our scripts):
   ```bash
   export PROTON_USE_WINED3D=1
   ```

2. **Alternative: Hardware rendering mode:**
   ```bash
   export PROTON_USE_WINED3D=0
   ```

3. **Use alternative Battle.net launcher:**
   ```bash
   ./battlenet-alt.sh  # Uses DXVK renderer
   ```

#### Docker Permission Issues

```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and log back in, or use:
newgrp docker
```

#### NVIDIA Container Runtime Issues

```bash
# Check NVIDIA container runtime
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

### Manual Installation Commands

If launcher scripts fail, use these manual commands:

#### Battle.net Manual Launch
```bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH=~/.steam
export STEAM_COMPAT_DATA_PATH=~/.wine-battlenet
export WINEPREFIX=~/.wine-battlenet/pfx
~/.proton/GE-Proton10-21/files/bin/wine "~/.wine-battlenet/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
```

#### EA App Manual Launch
```bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH=~/.steam
export STEAM_COMPAT_DATA_PATH=~/.wine-ea
export WINEPREFIX=~/.wine-ea/pfx
~/.proton/GE-Proton10-21/files/bin/wine "~/.wine-ea/pfx/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe"
```

#### Epic Games Manual Launch
```bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH=~/.steam
export STEAM_COMPAT_DATA_PATH=~/.wine-epic
export WINEPREFIX=~/.wine-epic/pfx
~/.proton/GE-Proton10-21/files/bin/wine "~/.wine-epic/pfx/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
```

### Log Files

- **Setup script logs**: `/tmp/setup_script.log`
- **Battle.net logs**: `~/.wine-battlenet/pfx/drive_c/users/steamuser/AppData/Roaming/Battle.net/`
- **EA App logs**: `~/.wine-ea/pfx/drive_c/users/steamuser/AppData/Local/Electronic Arts/EA Desktop/`
- **Epic Games logs**: `~/.wine-epic/pfx/drive_c/users/steamuser/AppData/Local/EpicGamesLauncher/Saved/Logs/`

## 🔄 Updates and Maintenance

### Updating Proton-GE

```bash
# Manual update to latest Proton-GE
cd ~/.proton
rm current
# Download latest release
latest_release=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest)
asset_url=$(echo "$latest_release" | jq -r '.assets[] | select(.name | endswith(".tar.gz")) .browser_download_url')
asset_name=$(echo "$latest_release" | jq -r '.assets[] | select(.name | endswith(".tar.gz")) .name')
curl -L -o "$asset_name" "$asset_url"
tar -xzf "$asset_name"
rm "$asset_name"
folder_name="${asset_name%.tar.gz}"
ln -s "$folder_name" current
```

### Updating Game Launchers

Game launchers typically update themselves automatically when launched. If you encounter issues:

1. **Reset Wine prefix** (⚠️ **WARNING**: This removes all installed games):
   ```bash
   ~/Desktop/gaming-utils.sh reset battlenet
   # Then re-run the setup script with only gaming flags enabled
   ```

2. **Reinstall specific launcher**:
   ```bash
   # Edit setup.sh to set only the desired launcher to true
   INSTALL_BATTLENET=true  # or INSTALL_EA=true or INSTALL_EPIC=true
   # Set all others to false, then run:
   sudo ./setup.sh
   ```

## 📁 File Structure

After installation, your system will have the following structure:

```
~/
├── .proton/
│   ├── current/                    # Symlink to latest Proton-GE
│   └── GE-Proton10-21/            # Actual Proton installation
├── .wine-battlenet/
│   └── pfx/drive_c/               # Battle.net Wine prefix
├── .wine-ea/
│   └── pfx/drive_c/               # EA App Wine prefix
├── .wine-epic/
│   └── pfx/drive_c/               # Epic Games Wine prefix
├── Desktop/
│   ├── battlenet.sh               # Battle.net launcher
│   ├── battlenet-alt.sh           # Alternative Battle.net launcher
│   ├── ea-app.sh                  # EA App launcher
│   ├── epic-games.sh              # Epic Games launcher
│   └── gaming-utils.sh            # Gaming management utilities
└── bin/                           # Copies of all launcher scripts
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test thoroughly
4. Commit your changes: `git commit -am 'Add feature-name'`
5. Push to the branch: `git push origin feature-name`
6. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **GloriousEggroll** for Proton-GE
- **Valve** for Steam and Proton
- **Wine** development team
- Linux gaming community for compatibility fixes and testing

## 💡 Tips for Gaming on Linux

1. **Enable Steam Proton**: Steam → Settings → Steam Play → Enable Steam Play for all other titles
2. **Check ProtonDB**: Visit [ProtonDB](https://www.protondb.com/) for game compatibility ratings
3. **Install additional fonts**: Some games need Windows fonts for proper display
4. **Monitor performance**: Use built-in Steam FPS counter or MangoHud
5. **Keep drivers updated**: Especially important for NVIDIA users
6. **Join communities**: r/linux_gaming, Discord servers for troubleshooting

---

**Created with ❤️ for the Linux Gaming Community**
