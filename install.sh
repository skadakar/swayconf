#!/usr/bin/env bash
# Production Sway bootstrap installer with gtkgreet + greetd
# curl -sfL https://sway.spurve.net/install.sh | sudo bash

set -euo pipefail

# -------------------------------
# CONFIG
# -------------------------------
REPO_URL="https://github.com/skadakar/swayconf.git"
APPLICATIONS_FILE="applications.txt"
CONFIG_DIR=".config"
ETC_DIR="etc"
GREETER_HOME="/var/lib/greeter"

# -------------------------------
# Ensure running as root
# -------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

# -------------------------------
# Determine non-root user
# -------------------------------
USER_TO_RUN="${SUDO_USER:-}"
if [[ -z "$USER_TO_RUN" ]]; then
  echo "Could not determine non-root user."
  exit 1
fi

HOME_TO_USE=$(eval echo "~$USER_TO_RUN")

# -------------------------------
# Helper: install yay
# -------------------------------
install_yay() {
  if ! command -v yay &>/dev/null; then
    echo "Installing yay..."
    pacman -S --needed --noconfirm git base-devel
    TMP_DIR=$(mktemp -d -p "$HOME_TO_USE")
    chown -R "$USER_TO_RUN":"$USER_TO_RUN" "$TMP_DIR"
    sudo -u "$USER_TO_RUN" git clone https://aur.archlinux.org/yay.git "$TMP_DIR/yay"
    cd "$TMP_DIR/yay"
    sudo -u "$USER_TO_RUN" makepkg -si --noconfirm
    cd -
    rm -rf "$TMP_DIR"
  fi
}

# -------------------------------
# Clone repo
# -------------------------------
TMP_REPO=$(mktemp -d)
trap 'rm -rf "$TMP_REPO"' EXIT

echo "Cloning swayconf..."
git clone --depth 1 --branch main "$REPO_URL" "$TMP_REPO"
chown -R "$USER_TO_RUN":"$USER_TO_RUN" "$TMP_REPO"
cd "$TMP_REPO"

# -------------------------------
# Install packages
# (UNCHANGED)
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
    esac
  done < "$APPLICATIONS_FILE"

  if [[ ${#pacman_pkgs[@]} -gt 0 ]]; then
    echo "Installing pacman packages..."
    pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
  fi

  if [[ ${#yay_pkgs[@]} -gt 0 ]]; then
    install_yay
    echo "Installing AUR packages..."
    for pkg in "${yay_pkgs[@]}"; do
      if ! sudo -u "$USER_TO_RUN" yay -Q "$pkg" &>/dev/null; then
        echo "Installing $pkg..."
        sudo -u "$USER_TO_RUN" yay -S --noconfirm "$pkg"
      else
        echo "$pkg is already installed, skipping..."
      fi
    done
  fi
fi

# -------------------------------
# Sync only repo-managed user configs
# -------------------------------
echo "Syncing user config..."
mkdir -p "$HOME_TO_USE/.config"

if [[ -d "$CONFIG_DIR" ]]; then
  for item in "$CONFIG_DIR"/*; do
    base_item=$(basename "$item")
    dest="$HOME_TO_USE/.config/$base_item"
    if [[ -d "$item" ]]; then
      mkdir -p "$dest"
      rsync -a "$item/" "$dest/"
    else
      cp -a "$item" "$dest"
    fi
  done

  # ❗ FIX: Make rofi and script files executable
  echo "Fixing executable permissions for rofi scripts..."
  find "$HOME_TO_USE/.config/rofi" -type f -iname "*.lua" -exec chmod +x {} \; 2>/dev/null || true
  find "$HOME_TO_USE/.config/rofi" -type f -iname "*.sh" -exec chmod +x {} \; 2>/dev/null || true

  chown -R "$USER_TO_RUN":"$USER_TO_RUN" "$HOME_TO_USE/.config"
fi

# -------------------------------
# Copy repo /etc files safely
# (UNCHANGED)
# -------------------------------
if [[ -d "$ETC_DIR" ]]; then
  echo "Installing /etc files..."
  find "$ETC_DIR" -type f | while read -r f; do
    dest="/etc/${f#$ETC_DIR/}"
    mkdir -p "$(dirname "$dest")"
    cp -f "$f" "$dest"
    chown root:root "$dest"
    chmod 644 "$dest"
  done
  find "$ETC_DIR" -type d | while read -r d; do
    dest="/etc/${d#$ETC_DIR/}"
    chmod 755 "$dest" 2>/dev/null || true
  done
fi



# -------------------------------
# Setup greeter user properly
# (UNCHANGED)
# -------------------------------
if ! id greeter &>/dev/null; then
  echo "Creating greeter user..."
  useradd -m \
    -d "$GREETER_HOME" \
    -s /usr/bin/nologin \
    -G video,input \
    greeter
else
  echo "Ensuring greeter groups..."
  usermod -aG video,input greeter || true
fi

mkdir -p "$GREETER_HOME"
chown -R greeter:greeter "$GREETER_HOME"
chmod 700 "$GREETER_HOME"

if [[ -d /etc/greetd ]]; then
  chown root:root /etc/greetd
  chmod 755 /etc/greetd
  for f in config.toml sway-config; do
    if [[ -f "/etc/greetd/$f" ]]; then
      chown root:root "/etc/greetd/$f"
      chmod 644 "/etc/greetd/$f"
    fi
  done
else
  echo "WARNING: /etc/greetd not found.
Did packages install correctly?"
fi

systemctl enable greetd.service
systemctl restart greetd.service