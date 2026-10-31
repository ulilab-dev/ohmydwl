#!/usr/bin/env bash

# ==========================================
#                 CONFIG
# ==========================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ==========================================
#                 COLORS
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

success() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1"
    exit 1
}

# ==========================================
#             CHECK REQUIREMENTS
# ==========================================

check_requirements() {
    command -v pacman >/dev/null 2>&1 || error "pacman not found!"

    [[ $EUID -ne 0 ]] || error "don't run this script as a root!"

    sudo -v || error "Sudo authentication failed!"

    info "Requirements checked"
}

# ==========================================
#             PACKAGE INSTALLATION
# ==========================================

install_packages() {

    local packages=(
        # Wayland / wlroots
        wlroots0.20
        wayland-protocols
        xdg-desktop-portal-wlr
        fcft
        tllist
        wlr-randr

        # Gaming
        gamemode
        lib32-gamemode

        # Development
        git
        base-devel

        # System utilities
        flatpak
        fish
        eza
        starship
        fastfetch
        htop
        btop
        baobab

        # Terminal / Editor
        kitty
        vim
        micro

        # Fonts
        ttf-jetbrains-mono-nerd

        # Launcher / Bar
        rofi
        rofi-emoji
        waybar

        # Wayland utilities
        hyprshot
        hyprlock
        awww
        cliphist
        wl-clipboard
        wl-clip-persist
        wl-randr

        # Notifications
        dunst

        # Qt / GTK
        qt5-wayland
        qt6-wayland
        qt6ct
        nwg-look
        adw-gtk-theme

        # Network
        network-manager-applet
        networkmanager-dmenu
        networkmanager

        # Multimedia
        ffmpegthumbs
        pavucontrol
        haruna

        # KDE applications / utilities
        dolphin
        ark
        kate
        gwenview
        archlinux-xdg-menu
        kde-cli-tools

        # Power management
        power-profiles-daemon

        # Authentication
        polkit-gnome
    )

    info "Updating system and installing packages..."

    sudo pacman -Syu --needed "${packages[@]}"

    success "Packages installed"
}

# ==========================================
#             INSTALL CUSTOM BINARY
# ==========================================

install_binary() {

    local binary="$SCRIPT_DIR/stuff/ohmydwl"

    [[ -f "$binary" ]] || error "stuff/ohmydwl not found!"

    info "Installing ohmydwl..."

    sudo install -Dm755 "$binary" /usr/local/bin/ohmydwl

    success "ohmydwl installed"
}

# ==========================================
#             COPY CONFIGURATION
# ==========================================

install_config() {

    local config_dir="$HOME/.config"

    [[ -d "$SCRIPT_DIR/dwl" ]] || error "dwl directory not found!"
    [[ -d "$SCRIPT_DIR/config" ]] || error "config directory not found!"

    info "Installing configurations..."

    mkdir -p "$config_dir"

    cp -r "$SCRIPT_DIR/dwl" "$config_dir/"
    cp -r "$SCRIPT_DIR/config/*" "$config_dir/"

    success "Configuration installed"
}

# ==========================================
#                  MAIN
# ==========================================

main() {

    echo
    echo "=========================================="
    echo "          OHMYDWL INSTALLER"
    echo "=========================================="
    echo

    check_requirements

    install_packages
    install_binary
    install_config

    echo
    success "Installation completed!"
    echo
}

main "$@"
