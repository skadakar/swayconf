#!/bin/bash
set -euo pipefail

# Determine where this script lives so we can reference files reliably
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------------------------------
# Variables
# ----------------------------------------
USER_TO_RUN="${SUDO_USER:-}"
if [[ -z "$USER_TO_RUN" ]]; then
    echo "Error: must run with sudo"
    exit 1
fi
HOME_DIR=$(eval echo "~$USER_TO_RUN")

REPO_URL="https://github.com/skadakar/swayconf.git"
TMP_REPO="$(mktemp -d)"

# ----------------------------------------
# Install packages from applications.txt
# ----------------------------------------
install_packages() {
    echo "Installing packages from applications.txt..."

    apps_file="$SCRIPT_DIR/applications.txt"
    if [[ ! -f "$apps_file" ]]; then
        echo "Error: applications.txt not found at $apps_file"
        exit 1
    fi

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
    done < "$apps_file"
}

# ----------------------------------------
# Clone repo and setup configs
# ----------------------------------------
setup_configs() {
    echo "Cloning swayconf repo…"
    git clone --depth 1 "$REPO_URL" "$TMP_REPO"
    chown -R "$USER_TO_RUN":"$USER_TO_RUN" "$TMP_REPO"

    mkdir -p "$HOME_DIR/.config/sway"
    mkdir -p "$HOME_DIR/.config/rofi"
    mkdir -p "$HOME_DIR/.config/gtk-3.0"
    mkdir -p "$HOME_DIR/.config/gtk-4.0"

    # Copy Sway config
    cp "$TMP_REPO/sway/config" "$HOME_DIR/.config/sway/config"
    chown "$USER_TO_RUN":"$USER_TO_RUN" "$HOME_DIR/.config/sway/config"

    # Copy Rofi scripts and make them executable
    for script in powermenu.lua filebrowser drun; do
        if [[ -f "$TMP_REPO/rofi/$script" ]]; then
            cp "$TMP_REPO/rofi/$script" "$HOME_DIR/.config/rofi/$script"
            chown "$USER_TO_RUN":"$USER_TO_RUN" "$HOME_DIR/.config/rofi/$script"
            chmod +x "$HOME_DIR/.config/rofi/$script"
        fi
    done

    # Copy GTK config if present in the repo
    if [[ -d "$TMP_REPO/gtk" ]]; then
        cp -r "$TMP_REPO/gtk/." "$HOME_DIR/.config/gtk-3.0/"
        cp -r "$TMP_REPO/gtk/." "$HOME_DIR/.config/gtk-4.0/"
        chown -R "$USER_TO_RUN":"$USER_TO_RUN" "$HOME_DIR/.config/gtk-3.0/" "$HOME_DIR/.config/gtk-4.0/"
    fi

    # Copy .profile if present in the repo
    if [[ -f "$TMP_REPO/profile/.profile" ]]; then
        cp "$TMP_REPO/profile/.profile" "$HOME_DIR/.profile"
        chown "$USER_TO_RUN":"$USER_TO_RUN" "$HOME_DIR/.profile"
        echo ".profile copied to home directory"
    fi
}

# ----------------------------------------
# Install BetterGruvbox GTK theme (AUR)
# ----------------------------------------
install_gruvbox_theme() {
    echo "Installing BetterGruvbox GTK theme from AUR…"
    sudo -u "$USER_TO_RUN" yay -S --noconfirm bettergruvbox-gtk-theme
}

# ----------------------------------------
# Main
# ----------------------------------------
main() {
    echo "Starting installer…"

    # Update system
    sudo pacman -Syu --noconfirm

    # Install listed packages
    install_packages

    # GTK theme (BetterGruvbox)
    install_gruvbox_theme

    # Dotfiles and configs
    setup_configs

    echo "Done!"
    echo "Reload Sway (Mod+Shift+C) and log out/in to apply GTK_THEME"
}

main