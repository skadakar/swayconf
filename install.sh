#!/bin/bash
set -euo pipefail

# ----------------------------------------
# Variables
# ----------------------------------------
USER_TO_RUN="$SUDO_USER"
HOME_DIR=$(eval echo "~$USER_TO_RUN")

CONFIG_REPO="https://github.com/skadakar/swayconf.git"
CONFIG_DIR="$HOME_DIR/.config/swayconf"
DOTFILES_DIR="$HOME_DIR/.dotfiles"

# ----------------------------------------
# Function: install pacman packages
# ----------------------------------------
install_pacman() {
    echo "Installing pacman packages..."
    while read -r pkg; do
        # skip empty lines and comments
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        sudo pacman -S --needed --noconfirm "$pkg"
    done < applications.txt
}

# ----------------------------------------
# Function: install AUR packages via yay
# ----------------------------------------
install_yay_aur() {
    echo "Installing AUR packages..."
    while read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        if [[ "$pkg" == yay:* ]]; then
            aur_pkg="${pkg#yay: }"
            sudo -u "$USER_TO_RUN" yay -S --noconfirm "$aur_pkg"
        fi
    done < applications.txt
}

# ----------------------------------------
# Function: Clone dotfiles and sway configs
# ----------------------------------------
setup_dotfiles() {
    echo "Setting up dotfiles..."
    # Clone swayconf
    if [[ ! -d "$CONFIG_DIR" ]]; then
        sudo -u "$USER_TO_RUN" git clone "$CONFIG_REPO" "$CONFIG_DIR"
    fi

    mkdir -p "$HOME_DIR/.config/rofi"
    mkdir -p "$HOME_DIR/.config/gtk-3.0"
    mkdir -p "$HOME_DIR/.config/gtk-4.0"

    # Copy cleaned sway config
    sudo -u "$USER_TO_RUN" cp "$CONFIG_DIR/sway/config" "$HOME_DIR/.config/sway/config"

    # Copy Rofi scripts
    sudo -u "$USER_TO_RUN" cp "$CONFIG_DIR/rofi/powermenu.lua" "$HOME_DIR/.config/rofi/powermenu.lua"
    sudo -u "$USER_TO_RUN" cp "$CONFIG_DIR/rofi/filebrowser" "$HOME_DIR/.config/rofi/filebrowser"
    sudo -u "$USER_TO_RUN" cp "$CONFIG_DIR/rofi/drun" "$HOME_DIR/.config/rofi/drun"

    # Set executable permissions
    chmod +x "$HOME_DIR/.config/rofi/powermenu.lua" "$HOME_DIR/.config/rofi/filebrowser" "$HOME_DIR/.config/rofi/drun"

    # Copy GTK config files (assuming user added them)
    cp -r "$CONFIG_DIR/gtk/." "$HOME_DIR/.config/gtk-3.0/"
    cp -r "$CONFIG_DIR/gtk/." "$HOME_DIR/.config/gtk-4.0/"
}

# ----------------------------------------
# Function: Install BetterGruvbox GTK theme
# ----------------------------------------
install_gruvbox_theme() {
    echo "Installing GTK dependencies..."
    sudo pacman -S --needed --noconfirm gtk-engine-murrine

    echo "Installing BetterGruvbox GTK theme..."
    sudo -u "$USER_TO_RUN" yay -S --noconfirm bettergruvbox-gtk-theme
}

# ----------------------------------------
# Main Script
# ----------------------------------------
main() {
    echo "Starting installer..."

    # Update system first (optional)
    sudo pacman -Syu --noconfirm

    # Install system packages
    install_pacman

    # Install AUR packages
    install_yay_aur

    # Install GTK theme
    install_gruvbox_theme

    # Setup dotfiles and configs
    setup_dotfiles

    echo "Installer complete!"
    echo "Reload Sway with Mod+Shift+C to apply configuration."
}

main