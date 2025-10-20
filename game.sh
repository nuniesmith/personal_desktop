#!/bin/bash
# Game Launcher Menu - Launch all your game clients easily
# This script provides a convenient menu to launch Battle.net, EA App, and Epic Games
#
# IMPORTANT: Run this script as your regular user (NOT with sudo)!
# Running with sudo may cause display issues with game launchers.
# 
# Usage:
#   ./game.sh              # Interactive menu
#   ./game.sh battlenet    # Launch Battle.net
#   ./game.sh status       # Check installations

# Don't exit on errors in status checks
set +e

# Warn if running with sudo unnecessarily
if [ "$EUID" -eq 0 ] && [ -z "$SUDO_USER" ]; then
    echo "⚠️  WARNING: Running as root. Game launchers may not display properly."
    echo "💡 TIP: Run this script as your regular user instead."
    echo ""
    sleep 2
fi

# Detect the actual user (not root if run with sudo)
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME="/home/$SUDO_USER"
else
    ACTUAL_USER="$USER"
    ACTUAL_HOME="$HOME"
fi

# Colors for better visual output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art Header
show_header() {
    echo -e "${BLUE}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════╗
    ║              🎮 GAME LAUNCHER MENU 🎮              ║
    ║                                                   ║
    ║           Launch your favorite games!             ║
    ╚═══════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Function to check if a game launcher is installed
check_installation() {
    local launcher="$1"
    local path="$2"
    
    if [ -f "$path" ]; then
        echo -e "${GREEN}✅ $launcher: INSTALLED${NC}"
        return 0
    else
        echo -e "${RED}❌ $launcher: NOT FOUND${NC}"
        return 1
    fi
}

# Function to launch Battle.net
launch_battlenet() {
    echo -e "${CYAN}🎯 Starting Battle.net Launcher...${NC}"
    
    local battlenet_path="$ACTUAL_HOME/.wine-battlenet/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
    
    if [ ! -f "$battlenet_path" ]; then
        echo -e "${RED}❌ Battle.net not found at: $battlenet_path${NC}"
        echo -e "${YELLOW}💡 Please run the setup script to install Battle.net${NC}"
        return 1
    fi
    
    # Set environment variables
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$ACTUAL_HOME/.steam"
    export STEAM_COMPAT_DATA_PATH="$ACTUAL_HOME/.wine-battlenet"
    export WINEPREFIX="$ACTUAL_HOME/.wine-battlenet/pfx"
    
    # Battle.net specific compatibility settings (matches setup.sh working config)
    export PROTON_USE_WINED3D=1      # Force software renderer
    export PROTON_NO_ESYNC=1         # Disable esync for stability
    export PROTON_NO_FSYNC=1         # Disable fsync for compatibility
    export PROTON_FORCE_LARGE_ADDRESS_AWARE=1  # Memory fix
    export PROTON_OLD_GL_STRING=1    # OpenGL compatibility
    export PROTON_HIDE_NVIDIA_GPU=0  # Don't hide GPU info
    export PROTON_LOG=1              # Enable logging for debugging
    export WINEDLLOVERRIDES="winemenubuilder.exe=d;mscoree=d;mshtml=d"
    
    # Kill any existing Battle.net processes
    pkill -f "Battle.net" 2>/dev/null || true
    pkill -9 -f "Agent.exe" 2>/dev/null || true
    pkill -9 -f "Blizzard" 2>/dev/null || true
    sleep 3
    
    # Launch Battle.net (as the actual user if running with sudo)
    if [ -f "$ACTUAL_HOME/.proton/current/files/bin/wine" ]; then
        if [ -n "$SUDO_USER" ]; then
            sudo -u "$SUDO_USER" DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
                STEAM_COMPAT_CLIENT_INSTALL_PATH="$ACTUAL_HOME/.steam" \
                STEAM_COMPAT_DATA_PATH="$ACTUAL_HOME/.wine-battlenet" \
                WINEPREFIX="$ACTUAL_HOME/.wine-battlenet/pfx" \
                PROTON_USE_WINED3D=1 \
                PROTON_NO_ESYNC=1 \
                PROTON_NO_FSYNC=1 \
                PROTON_FORCE_LARGE_ADDRESS_AWARE=1 \
                PROTON_OLD_GL_STRING=1 \
                PROTON_HIDE_NVIDIA_GPU=0 \
                PROTON_LOG=1 \
                WINEDLLOVERRIDES="winemenubuilder.exe=d;mscoree=d;mshtml=d" \
                "$ACTUAL_HOME/.proton/current/files/bin/wine" "$battlenet_path" > /dev/null 2>&1 &
        else
            "$ACTUAL_HOME/.proton/current/files/bin/wine" "$battlenet_path" > /dev/null 2>&1 &
        fi
        echo -e "${GREEN}✅ Battle.net launched successfully!${NC}"
        echo -e "${PURPLE}🎮 Available games: World of Warcraft, Overwatch, Diablo, StarCraft, Diablo Immortal${NC}"
        echo -e "${YELLOW}⏳ Please wait 10-15 seconds for Battle.net window to fully load...${NC}"
    else
        echo -e "${RED}❌ Proton Wine not found. Please run the setup script first.${NC}"
        return 1
    fi
}

# Function to launch EA App
launch_ea() {
    echo -e "${CYAN}🎯 Starting EA App...${NC}"
    
    local ea_path="$ACTUAL_HOME/.wine-ea/pfx/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe"
    
    if [ ! -f "$ea_path" ]; then
        echo -e "${RED}❌ EA App not found at: $ea_path${NC}"
        echo -e "${YELLOW}💡 Please run the setup script to install EA App${NC}"
        return 1
    fi
    
    # Set environment variables
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$ACTUAL_HOME/.steam"
    export STEAM_COMPAT_DATA_PATH="$ACTUAL_HOME/.wine-ea"
    export WINEPREFIX="$ACTUAL_HOME/.wine-ea/pfx"
    
    # EA App specific fixes
    export PROTON_NO_ESYNC=1
    export PROTON_NO_FSYNC=1
    export PROTON_USE_WINED3D=1
    
    # Kill any existing EA processes
    pkill -f "EA" 2>/dev/null || true
    sleep 2
    
    # Launch EA App (as the actual user if running with sudo)
    if [ -f "$ACTUAL_HOME/.proton/current/files/bin/wine" ]; then
        if [ -n "$SUDO_USER" ]; then
            sudo -u "$SUDO_USER" DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
                STEAM_COMPAT_CLIENT_INSTALL_PATH="$ACTUAL_HOME/.steam" \
                STEAM_COMPAT_DATA_PATH="$ACTUAL_HOME/.wine-ea" \
                WINEPREFIX="$ACTUAL_HOME/.wine-ea/pfx" \
                PROTON_NO_ESYNC=1 \
                PROTON_NO_FSYNC=1 \
                PROTON_USE_WINED3D=1 \
                "$ACTUAL_HOME/.proton/current/files/bin/wine" "$ea_path" > /dev/null 2>&1 &
        else
            "$ACTUAL_HOME/.proton/current/files/bin/wine" "$ea_path" > /dev/null 2>&1 &
        fi
        echo -e "${GREEN}✅ EA App launched successfully!${NC}"
        echo -e "${PURPLE}🎮 Available games: FIFA, Battlefield, The Sims, Need for Speed, Apex Legends${NC}"
    else
        echo -e "${RED}❌ Proton Wine not found. Please run the setup script first.${NC}"
        return 1
    fi
}

# Function to launch Epic Games
launch_epic() {
    echo -e "${CYAN}🎯 Starting Epic Games Launcher...${NC}"
    
    local epic_path="$ACTUAL_HOME/.wine-epic/pfx/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
    
    if [ ! -f "$epic_path" ]; then
        echo -e "${RED}❌ Epic Games Launcher not found at: $epic_path${NC}"
        echo -e "${YELLOW}💡 Please run the setup script to install Epic Games Launcher${NC}"
        return 1
    fi
    
    # Set environment variables
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$ACTUAL_HOME/.steam"
    export STEAM_COMPAT_DATA_PATH="$ACTUAL_HOME/.wine-epic"
    export WINEPREFIX="$ACTUAL_HOME/.wine-epic/pfx"
    
    # Force software rendering to avoid OpenGL issues
    export PROTON_USE_WINED3D=1
    export PROTON_NO_ESYNC=1
    export PROTON_NO_FSYNC=1
    
    # Kill any existing Epic processes
    pkill -f "Epic" 2>/dev/null || true
    sleep 2
    
    # Launch Epic Games (as the actual user if running with sudo)
    if [ -f "$ACTUAL_HOME/.proton/current/files/bin/wine" ]; then
        if [ -n "$SUDO_USER" ]; then
            sudo -u "$SUDO_USER" DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
                STEAM_COMPAT_CLIENT_INSTALL_PATH="$ACTUAL_HOME/.steam" \
                STEAM_COMPAT_DATA_PATH="$ACTUAL_HOME/.wine-epic" \
                WINEPREFIX="$ACTUAL_HOME/.wine-epic/pfx" \
                PROTON_USE_WINED3D=1 \
                PROTON_NO_ESYNC=1 \
                PROTON_NO_FSYNC=1 \
                "$ACTUAL_HOME/.proton/current/files/bin/wine" "$epic_path" > /dev/null 2>&1 &
        else
            "$ACTUAL_HOME/.proton/current/files/bin/wine" "$epic_path" > /dev/null 2>&1 &
        fi
        echo -e "${GREEN}✅ Epic Games Launcher launched successfully!${NC}"
        echo -e "${PURPLE}🎮 Available games: Fortnite, Rocket League, Fall Guys, Free Weekly Games${NC}"
    else
        echo -e "${RED}❌ Proton Wine not found. Please run the setup script first.${NC}"
        return 1
    fi
}

# Function to launch Steam
launch_steam() {
    echo -e "${CYAN}🎯 Starting Steam...${NC}"
    
    if command -v steam >/dev/null 2>&1; then
        if [ -n "$SUDO_USER" ]; then
            sudo -u "$SUDO_USER" DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" steam > /dev/null 2>&1 &
        else
            steam > /dev/null 2>&1 &
        fi
        echo -e "${GREEN}✅ Steam launched successfully!${NC}"
        echo -e "${PURPLE}🎮 Native Linux games and Proton compatibility layer available${NC}"
    else
        echo -e "${RED}❌ Steam not found. Please install Steam first.${NC}"
        return 1
    fi
}

# Function to launch all launchers
launch_all() {
    echo -e "${YELLOW}🚀 Launching all game clients...${NC}"
    echo ""
    
    launch_steam
    sleep 3
    launch_battlenet
    sleep 3
    launch_ea
    sleep 3
    launch_epic
    
    echo ""
    echo -e "${GREEN}🎉 All available game launchers have been started!${NC}"
}

# Function to check status of all installations
check_status() {
    echo -e "${BLUE}📋 Checking installation status...${NC}"
    echo ""
    
    # Check game launchers
    check_installation "Battle.net" "$ACTUAL_HOME/.wine-battlenet/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
    check_installation "EA App" "$ACTUAL_HOME/.wine-ea/pfx/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe"
    check_installation "Epic Games" "$ACTUAL_HOME/.wine-epic/pfx/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
    
    # Check Steam
    if command -v steam >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Steam: INSTALLED${NC}"
    else
        echo -e "${RED}❌ Steam: NOT INSTALLED${NC}"
    fi
    
    # Check Proton
    if [ -f "$ACTUAL_HOME/.proton/current/proton" ]; then
        echo -e "${GREEN}✅ Proton-GE: INSTALLED${NC}"
    else
        echo -e "${RED}❌ Proton-GE: NOT INSTALLED${NC}"
    fi
    
    echo ""
}

# Function to kill all gaming processes
kill_all() {
    echo -e "${YELLOW}⏹️  Stopping all game launchers...${NC}"
    
    pkill -f "Battle.net" 2>/dev/null || true
    pkill -f "EA" 2>/dev/null || true
    pkill -f "Epic" 2>/dev/null || true
    pkill -f "steam" 2>/dev/null || true
    
    echo -e "${GREEN}✅ All game launcher processes stopped${NC}"
}

# Show help
show_help() {
    echo -e "${BLUE}🎮 Game Launcher Help${NC}"
    echo ""
    echo -e "${CYAN}Usage:${NC} $0 [option]"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  1, battlenet    Launch Battle.net"
    echo "  2, ea           Launch EA App"
    echo "  3, epic         Launch Epic Games Launcher"
    echo "  4, steam        Launch Steam"
    echo "  5, all          Launch all game clients"
    echo "  status          Check installation status"
    echo "  kill            Stop all game launcher processes"
    echo "  help            Show this help message"
    echo ""
    echo -e "${PURPLE}Examples:${NC}"
    echo "  $0 battlenet    # Launch Battle.net only"
    echo "  $0 all          # Launch all game clients"
    echo "  $0 status       # Check what's installed"
    echo ""
}

# Show interactive menu
show_menu() {
    show_header
    check_status
    
    echo -e "${YELLOW}📋 Select an option:${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} 🎯 Launch Battle.net"
    echo -e "  ${CYAN}2)${NC} 🎯 Launch EA App"
    echo -e "  ${CYAN}3)${NC} 🎯 Launch Epic Games Launcher"
    echo -e "  ${CYAN}4)${NC} 🎯 Launch Steam"
    echo -e "  ${CYAN}5)${NC} 🚀 Launch ALL game clients"
    echo -e "  ${CYAN}6)${NC} 📊 Check installation status"
    echo -e "  ${CYAN}7)${NC} ⏹️  Kill all game processes"
    echo -e "  ${CYAN}8)${NC} ❓ Show help"
    echo -e "  ${CYAN}9)${NC} 🚪 Exit"
    echo ""
    
    read -p "Enter your choice (1-9): " choice
    
    case $choice in
        1) launch_battlenet ;;
        2) launch_ea ;;
        3) launch_epic ;;
        4) launch_steam ;;
        5) launch_all ;;
        6) check_status ;;
        7) kill_all ;;
        8) show_help ;;
        9) echo -e "${GREEN}👋 Goodbye! Happy gaming!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid option. Please try again.${NC}" ;;
    esac
}

# Main logic
case "${1:-menu}" in
    "1"|"battlenet") launch_battlenet ;;
    "2"|"ea") launch_ea ;;
    "3"|"epic") launch_epic ;;
    "4"|"steam") launch_steam ;;
    "5"|"all") launch_all ;;
    "status") check_status ;;
    "kill") kill_all ;;
    "help"|"-h"|"--help") show_help ;;
    "menu"|"") 
        while true; do
            show_menu
            echo ""
            read -p "Press Enter to continue or Ctrl+C to exit..."
            clear
        done
        ;;
    *) 
        echo -e "${RED}❌ Unknown option: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac