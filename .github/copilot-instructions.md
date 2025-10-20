# Linux Setup Automation Script

This repository contains a comprehensive system setup script for Linux development and gaming environments.

## Project Overview

This is a single-purpose automation script that transforms fresh Linux installations into fully configured development and gaming workstations. The script supports multiple distributions (Manjaro, Fedora, Ubuntu, raw Arch) and handles both workstation and server configurations.

## Core Architecture

**Main Script**: `setup.sh` - A monolithic bash script organized into two phases:
- **Phase 1**: System updates, base packages, GPU drivers, Docker, development tools
- **Phase 2**: Gaming setup (Steam, Wine, game launchers) and extra CUDA packages

**Configuration Pattern**: Master boolean flags at the top of the script control installations:
```bash
INSTALL_PYTHON=true
INSTALL_DOCKER=true
INSTALL_VSCODE=true
# ... etc
```

**OS Detection Logic**: Uses `/etc/os-release` to detect distribution and sets `OS_FAMILY` variable that drives package manager selection and installation commands throughout the script.

## Key Development Patterns

### Error Handling Strategy
- Uses `set -e` and `set -o pipefail` for strict error handling
- Implements trap for error logging: `trap 'echo "Error occurred at line $LINENO with exit code $?" >> "$LOG_FILE"; exit 1' ERR`
- All critical operations check return codes and log to `/tmp/setup_script.log`

### Privilege Management
- Detects if running as root or with sudo via `$EUID` check
- Uses `$SUDO_USER` to identify target user when running with sudo
- Implements `run_as_user()` function for operations that must run as non-root (like AUR packages)

### GPU-Aware Installation
- Auto-detects GPU type (nvidia/amd/intel) using `lspci`
- Conditionally installs drivers and CUDA packages based on detected hardware
- Handles NVIDIA container runtime configuration for Docker

### Multi-Distribution Support
- Each OS family has distinct package names and installation commands stored in variables
- Special handling for AUR packages on Arch-based systems (installs `yay` helper)
- Distribution-specific repository addition for Docker, VS Code, etc.

## Critical Workflows

### Running the Script
```bash
# Interactive mode with prompts
./setup.sh
# Answer 'y' to interactive mode

# Direct execution (uses flag defaults)
sudo ./setup.sh
```

### Adding New Software
1. Add boolean flag at top: `INSTALL_NEWSOFTWARE=true`
2. Add to interactive prompts section if desired
3. Add package variables for each OS family
4. Add installation logic with existing pattern checks
5. Add verification in final verification section

### Wine Gaming Setup
The script creates separate Wine prefixes for each game launcher:
- Battle.net: `~/.wine-battlenet`
- EA App: `~/.wine-ea` 
- Epic Games: `~/.wine-epic`

Each prefix gets Windows 10 compatibility and required redistributables via winetricks.

## Testing Approach

- Script includes comprehensive status checks at start to detect already-installed components
- Skips installations if components already exist (idempotent execution)
- Logs all operations to `/tmp/setup_script.log` for debugging
- Final verification section confirms successful installations

## Distribution-Specific Notes

- **Arch/Manjaro**: Uses AUR for some packages (Python 3.12, VS Code), requires manual GPG key import
- **Fedora**: Adds RPM Fusion repositories for proprietary drivers
- **Ubuntu**: Adds Microsoft and Docker official repositories
- **Raw Arch**: Installs GNOME desktop if workstation type selected

When modifying the script, always test the OS detection logic and ensure package names are correct for each supported distribution.