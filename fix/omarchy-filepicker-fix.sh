#!/usr/bin/env bash
set -euo pipefail

# Fix "old file picker" on Omarchy/Hyprland by forcing portal usage + selecting portal backends.
# Idempotent: safe to re-run.

# --- knobs ---
# Set to "kde" (recommended) or "gtk"
FILECHOOSER_PRIMARY="${FILECHOOSER_PRIMARY:-kde}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }; }
need_cmd pacman
need_cmd systemctl
need_cmd grep
need_cmd mkdir
need_cmd mktemp

if [[ "$FILECHOOSER_PRIMARY" != "kde" && "$FILECHOOSER_PRIMARY" != "gtk" ]]; then
  echo "FILECHOOSER_PRIMARY must be 'kde' or 'gtk' (got: $FILECHOOSER_PRIMARY)" >&2
  exit 1
fi

have_pkg() { pacman -Qi "$1" >/dev/null 2>&1; }

install_pkgs=(
  xdg-desktop-portal
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
)

# KDE picker requires xdg-desktop-portal-kde
if [[ "$FILECHOOSER_PRIMARY" == "kde" ]]; then
  install_pkgs+=(xdg-desktop-portal-kde)
fi

missing=()
for p in "${install_pkgs[@]}"; do
  have_pkg "$p" || missing+=("$p")
done

if ((${#missing[@]})); then
  echo "Installing missing packages: ${missing[*]}"
  if [[ $EUID -eq 0 ]]; then
    pacman -S --needed "${missing[@]}"
  else
    need_cmd sudo
    sudo pacman -S --needed "${missing[@]}"
  fi
else
  echo "All required packages already installed."
fi

# 1) Portal backend selection for Hyprland:
# Hyprland portal doesn't implement FileChooser; default fallback is GTK.
# We set: default = hyprland;gtk and prefer FileChooser = kde;gtk (or gtk only).
# (Config format is per xdg-desktop-portal portals.conf rules: semicolon-separated backend list.) :contentReference[oaicite:2]{index=2}
XDG_PORTAL_DIR="$HOME/.config/xdg-desktop-portal"
mkdir -p "$XDG_PORTAL_DIR"

HYPR_PORTALS_CONF="$XDG_PORTAL_DIR/hyprland-portals.conf"

if [[ "$FILECHOOSER_PRIMARY" == "kde" ]]; then
  FILECHOOSER_LINE="org.freedesktop.impl.portal.FileChooser = kde;gtk"
else
  FILECHOOSER_LINE="org.freedesktop.impl.portal.FileChooser = gtk"
fi

desired_conf=$(
  cat <<EOF
[preferred]
default = hyprland;gtk
$FILECHOOSER_LINE
EOF
)

write_if_changed() {
  local path="$1"
  local content="$2"

  if [[ -f "$path" ]] && diff -q <(printf "%s\n" "$content") "$path" >/dev/null 2>&1; then
    echo "No change: $path"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  printf "%s\n" "$content" >"$tmp"
  mv "$tmp" "$path"
  echo "Wrote: $path"
}

write_if_changed "$HYPR_PORTALS_CONF" "$desired_conf"

# 2) Force GTK apps (Firefox, Chromium, etc.) to prefer portals for dialogs.
# Omarchy’s hyprland.conf sources ~/.config/hypr/envs.conf. :contentReference[oaicite:3]{index=3}
HYPR_DIR="$HOME/.config/hypr"
mkdir -p "$HYPR_DIR"
ENVS_CONF="$HYPR_DIR/envs.conf"
touch "$ENVS_CONF"

ensure_line() {
  local path="$1"
  local line="$2"
  grep -Fxq "$line" "$path" || { printf "\n%s\n" "$line" >>"$path"; echo "Added to $path: $line"; }
}

ensure_line "$ENVS_CONF" "env = GTK_USE_PORTAL,1"

# 3) Restart portal services (user services).
restart_if_exists() {
  local unit="$1"
  if systemctl --user list-unit-files | grep -q "^${unit}\.service"; then
    systemctl --user restart "${unit}.service" || true
  fi
}

echo "Restarting portal services..."
restart_if_exists xdg-desktop-portal
restart_if_exists xdg-desktop-portal-hyprland
restart_if_exists xdg-desktop-portal-gtk
restart_if_exists xdg-desktop-portal-kde
restart_if_exists xdg-document-portal

echo
echo "Done."
echo "Important: fully log out + log back in (or reboot) so GTK_USE_PORTAL=1 reaches all apps."
echo "Then restart your browser."

