#!/bin/bash
set -euo pipefail

# ----------------------------------------
# Variables
# ----------------------------------------
USER_TO_RUN="$SUDO_USER"
HOME_DIR=$(eval echo "~$USER_TO_RUN")

REPO_URL="https://github.com/skadakar/swayconf.git"
TMP_REPO=$(mktemp -d)

# ----------------------------------------
# Package Installation (pacman: / yay:)
# ----------------------------------------
install_packages() {
    echo "Installing packages from applications.txt..."

    while read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        case "$line" in
            pacman:*)
                pkg="${line#pacman:}"
                echo "Installing via pacman: $pkg"
                sudo pacman -S --needed --noconfirm "$pkg"
                ;;
            yay:*)
                pkg="${line#yay:}"
                echo "Installing via yay: $pkg"
                sudo -u "$USER_TO_RUN" yay -S --noconfirm "$pkg"
                ;;
            *)
                echo "Skipping unknown line: $line"
                ;;
        esac
    done < "./applications.txt"
}

# ----------------------------------------
# Clone Repo and Copy Configs
# ----------------------------------------
setup_configs() {
    echo "Cloning swayconf repo..."
    git clone --depth 1 "$REPO_URL" "$TMP_REPO"
    chown -R "$USER_TO_RUN":"$USER_TO_RUN" "$TMP_REPO"

    mkdir -p "$HOME_DIR/.config/sway"
    mkdir -p "$HOME_DIR/.config/rofi"
    mkdir -p "$HOME_DIR/.config/gtk-3.0"
    mkdir- p "$HOME_DIR/.config/gtk-4.0"

    # Copy Sway config
    sudo -u "$USER_TO_RUN" cp "$TMP_REPO/sway/config" "$HOME_DIR/.config/sway/config"

    # Copy Rofi scripts
    for script in powermenu.lua filebrowser drun; do
        if [[ -f "$TMP_REPO/rofi/$script" ]]; then
            sudo -u "$USER_TO_RUN" cp "$TMP_REPO/rofi/$script" "$HOME_DIR/.config/rofi/$script"
            chmod +x "$HOME_DIR/.config/rofi/$script"
        fi
    done

    # Copy GTK configs from your local repo location if provided
    if [[ -d "$TMP_REPO/gtk" ]]; then
        cp -r "$TMP_REPO/gtk/." "$HOME_DIR/.config/gtk-3.0/"
        cp -r "$TMP_REPO/gtk/." "$HOME_DIR/.config/gtk-4.0/"
    fi

    # Copy .profile from repo if present
    if [[ -f "$TMP_REPO/profile/.profile" ]]; then
        sudo -u "$USER_TO_RUN" cp "$TMP_REPO/profile/.profile" "$HOME_DIR/.profile"
    fi
}

# ----------------------------------------
# GTK Theme Install
# ----------------------------------------
install_gruvbox_theme() {
    echo "Installing BetterGruvbox GTK theme from AUR..."
    sudo -u "$USER_TO_RUN" yay -S --noconfirm bettergruvbox-gtk-theme
}

# ----------------------------------------
# Main
# ----------------------------------------
main() {
    echo "Starting installation..."

    # Update system packages
    sudo pacman -Syu --noconfirm

    # Install listed packages
    install_packages

    # Install GTK theme
    install_gruvbox_theme

    # Setup configs from repo
    setup_configs

    echo "Done! Reload Sway (Mod+Shift+C) and log out/in for GTK_THEME."
}

main