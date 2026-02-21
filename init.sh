#!/usr/bin/env bash
# Full Sway bootstrap installer with gtkgreet
# To run: curl -sfL https://sway.spurve.net/install.sh | sudo bash

set -euo pipefail

# -------------------------------
# CONFIG
# -------------------------------
REPO_URL="https://github.com/skadakar/swayconf.git"
APPLICATIONS_FILE="applications.txt"
CONFIG_DIR=".config"
ETC_DIR="etc"

# -------------------------------
# Determine non-root user
# -------------------------------
USER_TO_RUN="${SUDO_USER:-$USER}"
HOME_TO_USE=$(eval echo "~$USER_TO_RUN")

# -------------------------------
# Helper function: install yay
# -------------------------------
install_yay() {
    if ! command -v yay &>/dev/null; then
        echo "yay not found. Installing yay..."
        sudo pacman -S --needed --noconfirm git base-devel

        TMP_DIR=$(mktemp -d -p "$HOME_TO_USE")
        sudo chown -R "$USER_TO_RUN":"$USER_TO_RUN" "$TMP_DIR"

        sudo -u "$USER_TO_RUN" git clone https://aur.archlinux.org/yay.git "$TMP_DIR/yay"
        cd "$TMP_DIR/yay"
        sudo -u "$USER_TO_RUN" makepkg -si --noconfirm
        cd -
        rm -rf "$TMP_DIR"
    else
        echo "yay is already installed."
    fi
}

# -------------------------------
# Clone repo (latest commit only)
# -------------------------------
TMP_REPO=$(mktemp -d)
trap 'rm -rf "$TMP_REPO"' EXIT

echo "Cloning swayconf (latest commit only)..."
git clone --depth 1 --branch main "$REPO_URL" "$TMP_REPO"

# Make the repo owned by the non-root user
sudo chown -R "$USER_TO_RUN":"$USER_TO_RUN" "$TMP_REPO"
cd "$TMP_REPO"

# -------------------------------
# Install packages
# -------------------------------
if [[ -f "$APPLICATIONS_FILE" ]]; then
    pacman_pkgs=()
    yay_pkgs=()

    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        manager="${line%%:*}"
        package="${line#*:}"

        case "$manager" in
            pacman) pacman_pkgs+=("$package") ;;
            yay) yay_pkgs+=("$package") ;;
            *) echo "Unknown package manager: $manager" ;;
        esac
    done < "$APPLICATIONS_FILE"

    if [[ ${#pacman_pkgs[@]} -gt 0 ]]; then
        echo "Installing pacman packages..."
        sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
    fi

    if [[ ${#yay_pkgs[@]} -gt 0 ]]; then
        install_yay
        echo "Installing yay/AUR packages..."
        sudo -u "$USER_TO_RUN" yay -S --needed --noconfirm "${yay_pkgs[@]}"
    fi
fi

# -------------------------------
# Sync .config and etc to user home
# -------------------------------
echo "Copying .config and etc files to $HOME_TO_USE..."
mkdir -p "$HOME_TO_USE/.config" "$HOME_TO_USE/etc"

if [[ -d "$CONFIG_DIR" ]]; then
    rsync -a --delete "$CONFIG_DIR/" "$HOME_TO_USE/.config/"
fi

if [[ -d "$ETC_DIR" ]]; then
    rsync -a --delete "$ETC_DIR/" "$HOME_TO_USE/etc/"
fi

# -------------------------------
# Install gtkgreet and configure greetd
# -------------------------------
echo "Installing gtkgreet..."
sudo pacman -S --needed --noconfirm gtkgreet

# Ensure greeter user exists
if ! id greeter &>/dev/null; then
    echo "Creating greeter user..."
    sudo useradd -M -G video greeter
fi

# Configure greetd
echo "Configuring greetd to use gtkgreet and launch Sway..."
sudo mkdir -p /etc/greetd

sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[default]
user = "$USER_TO_RUN"
allow_suid = true

[greeter]
path = "/usr/bin/gtkgreet"
user = "greeter"

[session.sway]
command = "exec sway"
user = "$USER_TO_RUN"
EOF

# Copy gtkgreet theme if present in repo etc
if [[ -f ./etc/gtkgreet.css ]]; then
    sudo cp -rp ./etc/gtkgreet.css /etc/greetd/gtkgreet.css
fi

# Enable greetd service
echo "Enabling greetd.service..."
sudo systemctl enable --now greetd.service

# -------------------------------
# Reload Sway
# -------------------------------
echo "Dotfiles bootstrap complete!"
echo "Reloading sway..."
sudo -u "$USER_TO_RUN" swaymsg reload