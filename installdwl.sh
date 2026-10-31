#!/usr/bin/env bash
# ohmydwl installer (Arch Linux)
# Usage: bash installdwl.sh [-y|--yes]

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
DWL_DIR="$CONFIG_DIR/dwl"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; RESET='\033[0m'

log()     { printf '%b[%s]%b %s\n' "$1" "$2" "$RESET" "$3"; }
info()    { log "$BLUE"   INFO    "$1"; }
success() { log "$GREEN"  OK      "$1"; }
warning() { log "$YELLOW" WARNING "$1"; }
error()   { log "$RED"    ERROR   "$1" >&2; exit 1; }

trap 'log "$RED" ERROR "Failed at line $LINENO" >&2' ERR

PACMAN_FLAGS=()
case "${1:-}" in
    "")           ;;
    -y|--yes)     PACMAN_FLAGS+=(--noconfirm) ;;
    *)            error "Usage: $(basename "$0") [-y|--yes]" ;;
esac

PACKAGES=(
    # Wayland / build dependencies
    wlroots0.20 wayland wayland-protocols libxkbcommon libinput
    xdg-desktop-portal-wlr fcft tllist wlr-randr
    git base-devel pkgconf

    # Gaming
    gamemode lib32-gamemode

    # System utilities
    flatpak fish eza starship fastfetch htop btop baobab bat

    # Terminal / editor / fonts
    foot vim micro ttf-jetbrains-mono-nerd

    # Launcher / bar / session
    rofi rofi-emoji waybar wlogout

    # Wayland utilities
    hyprshot hyprlock awww waypaper cliphist wl-clipboard wl-clip-persist

    # Notifications
    dunst libnotify

    # Qt / GTK
    qt5-wayland qt6-wayland qt6ct nwg-look adw-gtk-theme

    # Network
    network-manager-applet networkmanager-dmenu networkmanager

    # Multimedia
    ffmpegthumbs pavucontrol haruna

    # KDE applications
    dolphin ark kate gwenview archlinux-xdg-menu kde-cli-tools

    # Power / authentication
    power-profiles-daemon polkit-gnome    
)

check_requirements() {
    command -v pacman >/dev/null 2>&1 || error "pacman not found (Arch-based systems only)"
    command -v sudo   >/dev/null 2>&1 || error "sudo not found"
    [[ $EUID -ne 0 ]]                 || error "do not run this script as root"

    [[ -d "$SCRIPT_DIR/dwl" && -d "$SCRIPT_DIR/config" && -f "$SCRIPT_DIR/stuff/ohmydwl" ]] \
        || error "run this script from the ohmydwl repository (dwl/, config/, stuff/ missing)"

    sudo -v || error "sudo authentication failed"
}

add_cachyos_repo() {
    # waypaper is not in the official Arch repositories; the CachyOS repo provides it.
    if grep -Eq '^\[cachyos[^]]*\]' /etc/pacman.conf; then
        info "CachyOS repository already configured"
        return
    fi
    if [[ "$(uname -m)" != x86_64 ]]; then
        warning "CachyOS repository supports x86_64 only"
        return
    fi
 
    info "Adding CachyOS repository..."
 
    # Trust the CachyOS signing key
    sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key F3B607488DB35A47

    sudo pacman -U \
   'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
   'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-27-1-any.pkg.tar.zst'

    printf '\n[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null

    sudo pacman -Syu --needed "${PACMAN_FLAGS[@]}" cachyos-keyring
    sudo pacman-key --populate cachyos
 }

install_packages() {
    info "Upgrading system and syncing databases..."
    sudo pacman -Syu "${PACMAN_FLAGS[@]}"

    # Install only what exists in the enabled repositories; report the rest.
    local wanted repos available skipped
    wanted="$(printf '%s\n' "${PACKAGES[@]}" | sort -u)"
    repos="$(pacman -Slq | sort -u)"
    available="$(comm -12 <(printf '%s\n' "$wanted") <(printf '%s\n' "$repos"))"
    skipped="$(comm -23 <(printf '%s\n' "$wanted") <(printf '%s\n' "$repos"))"

    info "Installing packages..."
    mapfile -t available <<<"$available"
    sudo pacman -S --needed "${PACMAN_FLAGS[@]}" "${available[@]}"

    if [[ -n "$skipped" ]]; then
        warning "Not found in official repositories, skipped: $(tr '\n' ' ' <<<"$skipped")"
    fi
}

install_config() {
    info "Installing configuration to $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$HOME/Pictures"

    # dwl/ and every directory inside config/ land directly in ~/.config
    local entry target
    for entry in "$SCRIPT_DIR/dwl" "$SCRIPT_DIR"/config/*; do
        target="$CONFIG_DIR/$(basename "$entry")"
        cp -r "$entry" "$target"

   # copy wallpapers to ~/Pictures/wallpapers
    if [[ -d "$SCRIPT_DIR/wallpapers" ]]; then
        cp -r "$SCRIPT_DIR/wallpapers" "$HOME/Pictures/"
    fi
   
    done
}

build_dwl() {
    pkg-config --exists wlroots-0.20 \
        || error "wlroots-0.20 not found (package wlroots0.20 is unavailable or failed to install)"

    info "Building dwl..."
    make -C "$DWL_DIR" clean >/dev/null 2>&1 || true
    make -C "$DWL_DIR"
    sudo make -C "$DWL_DIR" install
}

install_launcher() {
    sudo install -Dm755 "$SCRIPT_DIR/stuff/ohmydwl" /usr/local/bin/ohmydwl
}

main() {
    printf '\n==========================================\n          OHMYDWL INSTALLER\n==========================================\n\n'

    check_requirements
    install_packages
    install_config
    build_dwl
    install_launcher

    success "Installation completed"
    info "Start with 'ohmydwl' from a TTY, or select the 'dwl' session in your display manager"
    info "Customize: edit ~/.config/dwl/config.h, then: cd ~/.config/dwl && make && sudo make install"
    warning "~/.config/dwl/autostart.sh sets HDMI-A-1 at 1920x1080@100; adjust it for your monitor"
}

main
