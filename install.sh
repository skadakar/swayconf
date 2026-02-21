#!/bin/bash
set -euo pipefail

# ----------------------------------------
# Script directory
# ----------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------------------------------
# Check for sudo
# ----------------------------------------
USER_TO_RUN="${SUDO_USER:-}"
if [[ -z "$USER_TO_RUN" ]]; then
    echo "Error: Please run this script with sudo"
    exit 1
fi
HOME_DIR=$(eval echo "~$USER_TO_RUN")

# ----------------------------------------
# Repo URL
# ----------------------------------------
REPO_URL="https://github.com/skadakar/swayconf.git"
TMP_REPO="$(mktemp -d)"

# ----------------------------------------
# Find applications.txt
# ----------------------------------------
if [[ -f "./applications.txt" ]]; then
    APPS_FILE="./applications.txt"
elif [[ -f "$SCRIPT_DIR/applications.txt" ]]; then
    APPS_FILE="$SCRIPT_DIR/applications.txt"
else
    echo "Error: applications.txt not found in current directory or script directory"
    exit 1
fi

# ----------------------------------------
# Install packages
# ----------------------------------------
install_packages() {
    echo "Installing packages from $APPS_FILE..."

    while read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        case "$line" in
            pacman:*)
                pkg="${line#pacman:}"
                echo "Installing pacman package: $pkg"
                sudo pacman -S --needed --noconfirm "$pkg"
                ;;
            yay:*)
                pkg="${line#yay:}"
                echo "Installing AUR package via yay: $pkg"
                sudo -u "$USER_TO_RUN" yay -S --noconfirm "$pkg"
                ;;
            *)
                echo "Skipping unknown line: $line"
                ;;
        esac
    done < "$APPS_FILE"
}

# ----------------------------------------
# Clone swayconf and copy configs
# ----------------------------------------
setup_configs() {
    echo "Cloning swayconf repo..."
    git clone --depth 1 "$REPO_URL" "$TMP_REPO"
    chown -R "$USER_TO_RUN":"$USER_TO_RUN" "$TMP_REPO"

    mkdir -p "$HOME_DIR/.config/sway"
    mkdir -p "$HOME_DIR/.config/rofi"
    mkdir -p "$HOME_DIR/.config/gtk-3.0"
    mkdir -p "$HOME_DIR/.config/gtk-4.0"

    # Copy Sway config
    cp "$TMP_REPO/sway/config" "$HOME_DIR/.config/sway/config"
    chown "$USER_TO_RUN":"$USER_TO_RUN" "$HOME_DIR/.config/sway/config"

    # Copy Rofi scripts and fix permissions
    for script in powermenu.lua filebrowser drun; do
        if [[ -f "$TMP_REPO/rofi/$script" ]]; then
            cp "$TMP_REPO/rofi/$script" "$HOME_DIR/.config/rofi/$script"
            chown "$USER_TO_RUN":"$USER_TO_RUN" "$HOME_DIR/.config/rofi/$script"
            chmod +x "$HOME_DIR/.config/rofi/$script"
        fi
    done

    # Copy GTK configs if present
    if [[ -d "$TMP_REPO/gtk" ]]; then
        cp -r "$TMP_REPO/gtk/." "$HOME_DIR/.config/gtk-3.0/"
        cp -r "$TMP_REPO/gtk/." "$HOME_DIR/.config/gtk-4.0/"
        chown -R "$USER_TO_RUN":"$USER_TO_RUN" "$HOME_DIR/.config/gtk-3.0/" "$HOME_DIR/.config/gtk-4.0/"
    fi

    # Copy .profile if present
    if [[ -f "$TMP_REPO/profile/.profile" ]]; then
        cp "$TMP_REPO/profile/.profile" "$HOME_DIR/.profile"
        chown "$USER_TO_RUN":"$USER_TO_RUN" "$HOME_DIR/.profile"
        echo ".profile copied to home directory"
    fi
}

# ----------------------------------------
# Install BetterGruvbox GTK theme
# ----------------------------------------
install_gruvbox_theme() {
    echo "Installing BetterGruvbox GTK theme from AUR..."
    sudo -u "$USER_TO_RUN" yay -S --noconfirm bettergruvbox-gtk-theme
}

# ----------------------------------------
# Main
# ----------------------------------------
main() {
    echo "Starting installer..."

    # Update system packages
    sudo pacman -Syu --noconfirm

    # Install packages
    install_packages

    # Install GTK theme
    install_gruvbox_theme

    # Setup configs
    setup_configs

    echo "Installation complete!"
    echo "Reload Sway (Mod+Shift+C) and log out/in to apply GTK_THEME for Zen Browser and other GTK apps."
}

main