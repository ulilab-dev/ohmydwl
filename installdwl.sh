#!/usr/bin/env bash

# ==========================================
#                 CONFIG
# ==========================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
DWL_SRC_DIR="$CONFIG_DIR/dwl"

ASSUME_YES=0
PACMAN_FLAGS=()
AUR_FLAGS=()
MISSING_PKGS=()

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
    echo -e "${RED}[ERROR]${RESET} $1" >&2
    exit 1
}

trap 'echo -e "${RED}[ERROR]${RESET} Script failed at line $LINENO" >&2' ERR

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -y, --yes    Do not ask for confirmation (passes --noconfirm to pacman/AUR helper)
  -h, --help   Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                ASSUME_YES=1
                PACMAN_FLAGS+=(--noconfirm)
                AUR_FLAGS+=(--noconfirm)
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                usage
                error "Unknown option: $1"
                ;;
        esac
        shift
    done
}

# ==========================================
#             CHECK REQUIREMENTS
# ==========================================

check_requirements() {
    command -v pacman >/dev/null 2>&1 || error "pacman not found! This installer supports Arch-based systems only."

    [[ $EUID -ne 0 ]] || error "don't run this script as root!"

    command -v sudo >/dev/null 2>&1 || error "sudo not found!"
    sudo -v || error "Sudo authentication failed!"

    [[ -d "$SCRIPT_DIR/dwl" ]]      || error "dwl directory not found!"
    [[ -d "$SCRIPT_DIR/config" ]]   || error "config directory not found!"
    [[ -f "$SCRIPT_DIR/stuff/ohmydwl" ]] || error "stuff/ohmydwl not found!"

    info "Requirements checked"
}

# ==========================================
#             PACKAGE INSTALLATION
# ==========================================

detect_aur_helper() {
    local helper
    for helper in paru yay; do
        if command -v "$helper" >/dev/null 2>&1; then
            echo "$helper"
            return 0
        fi
    done
    return 1
}

install_packages() {

    local packages=(
        # Wayland / wlroots
        wlroots0.20
        wayland
        wayland-protocols
        libxkbcommon
        libinput
        xdg-desktop-portal-wlr
        fcft
        tllist
        wlr-randr

        # Gaming
        gamemode
        lib32-gamemode

        # Development / build
        git
        base-devel
        pkgconf

        # System utilities
        flatpak
        fish
        eza
        starship
        fastfetch
        htop
        btop
        baobab
        bat

        # Terminal / Editor
        kitty
        vim
        micro

        # Fonts
        ttf-jetbrains-mono-nerd

        # Launcher / Bar / Session
        rofi
        rofi-emoji
        waybar
        wlogout

        # Wayland utilities
        hyprshot
        hyprlock
        awww
        waypaper
        cliphist
        wl-clipboard
        wl-clip-persist
        grim
        slurp
        jq

        # Notifications
        dunst
        libnotify

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

    info "Synchronizing and upgrading system (pacman -Syu)..."
    sudo pacman -Syu "${PACMAN_FLAGS[@]}"

    # Split packages into official-repo and AUR/unknown, so one missing
    # package does not abort the whole transaction.
    local repo_pkgs=()
    local other_pkgs=()
    local pkg

    for pkg in "${packages[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            repo_pkgs+=("$pkg")
        else
            other_pkgs+=("$pkg")
        fi
    done

    info "Installing ${#repo_pkgs[@]} packages from official repositories..."
    sudo pacman -S --needed "${PACMAN_FLAGS[@]}" "${repo_pkgs[@]}"

    if [[ ${#other_pkgs[@]} -gt 0 ]]; then
        local helper=""
        if helper="$(detect_aur_helper)"; then
            info "Installing from AUR with $helper: ${other_pkgs[*]}"
            if ! "$helper" -S --needed "${AUR_FLAGS[@]}" "${other_pkgs[@]}"; then
                warning "AUR installation reported errors."
                MISSING_PKGS+=("${other_pkgs[@]}")
            fi
        else
            warning "Not in official repositories and no AUR helper (paru/yay) found:"
            warning "  ${other_pkgs[*]}"
            MISSING_PKGS+=("${other_pkgs[@]}")
        fi
    fi

    success "Package step finished"
}

# ==========================================
#             COPY CONFIGURATION
# ==========================================

remove_existing() {
    local target="$1"

    [[ -e "$target" || -L "$target" ]] || return 0

    rm -rf "$target"
}

install_config() {

    info "Installing configurations..."

    mkdir -p "$CONFIG_DIR"

    local entry name

    # dwl source + autostart
    remove_existing "$DWL_SRC_DIR"
    cp -a "$SCRIPT_DIR/dwl" "$DWL_SRC_DIR"

    # every directory inside config/ (kitty, rofi, waybar, ...)
    for entry in "$SCRIPT_DIR"/config/*; do
        [[ -e "$entry" ]] || continue
        name="$(basename "$entry")"
        remove_existing "$CONFIG_DIR/$name"
        cp -a "$entry" "$CONFIG_DIR/$name"
    done

    # make sure helper scripts are executable
    find "$CONFIG_DIR/dwl" "$CONFIG_DIR/waybar" "$CONFIG_DIR/rofi" \
        -maxdepth 2 -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

    # directories referenced by keybindings / hyprlock
    mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/wallpapers"

    success "Configuration installed"
}

# ==========================================
#             BUILD AND INSTALL DWL
# ==========================================

build_dwl() {

    [[ -f "$DWL_SRC_DIR/Makefile" ]] || error "$DWL_SRC_DIR/Makefile not found!"

    command -v make >/dev/null 2>&1 || error "make not found (install base-devel)!"
    pkg-config --exists wlroots-0.20 \
        || error "wlroots-0.20 not found. Install wlroots0.20 and run again."

    info "Building dwl..."

    # config.h is generated from config.def.h by the Makefile if missing.
    # Edit $DWL_SRC_DIR/config.h afterwards and rebuild to customize.
    make -C "$DWL_SRC_DIR" clean >/dev/null 2>&1 || true
    make -C "$DWL_SRC_DIR"

    info "Installing dwl (binary, man page, wayland session entry)..."
    sudo make -C "$DWL_SRC_DIR" install

    success "dwl built and installed"
}

# ==========================================
#             INSTALL LAUNCHER
# ==========================================

install_launcher() {

    local launcher="$SCRIPT_DIR/stuff/ohmydwl"

    info "Installing ohmydwl launcher..."

    sudo install -Dm755 "$launcher" /usr/local/bin/ohmydwl

    success "ohmydwl launcher installed"
}

# ==========================================
#                 SUMMARY
# ==========================================

print_summary() {

    echo
    success "Installation completed!"
    echo

    if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
        warning "These packages were NOT installed, install them manually (AUR):"
        warning "  ${MISSING_PKGS[*]}"
    fi

    info "Start from a TTY with: ohmydwl  (or pick the 'dwl' session in your display manager)"
    info "Edit ~/.config/dwl/config.h, then rebuild with:"
    info "  cd ~/.config/dwl && make && sudo make install"
    warning "~/.config/dwl/autostart.sh sets HDMI-A-1 at 1920x1080@100; adjust it for your monitor."
    echo
}

# ==========================================
#                  MAIN
# ==========================================

main() {

    parse_args "$@"

    echo
    echo "=========================================="
    echo "          OHMYDWL INSTALLER"
    echo "=========================================="
    echo

    check_requirements

    install_packages
    install_config
    build_dwl
    install_launcher

    print_summary
}

main "$@"
