#!/usr/bin/env bash
set -euo pipefail

# Change this if your library is on an external SSD.
COZY_LIBRARY_DIR="${COZY_LIBRARY_DIR:-$HOME/Media/Audiobooks}"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

restart_user_unit_if_exists() {
  local unit="$1"
  if systemctl --user list-unit-files --no-pager 2>/dev/null | awk '{print $1}' | grep -qx "$unit"; then
    systemctl --user restart "$unit" || true
  fi
}

echo "==> Installing portal dependencies (Arch/Omarchy via yay)"
if ! need_cmd yay; then
  echo "ERROR: yay not found. Install yay first (Omarchy usually has it)."
  exit 1
fi

# Hyprland portal does NOT implement a file picker; you need GTK or KDE for FileChooser. :contentReference[oaicite:3]{index=3}
yay -S --needed \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  xdg-desktop-portal-kde \
  flatpak

echo "==> Ensuring Flathub remote exists"
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "==> Installing Cozy (Flatpak; upstream-preferred) "
flatpak install -y --user flathub com.github.geigi.cozy

echo "==> Creating library folder structure at: $COZY_LIBRARY_DIR"
mkdir -p "$COZY_LIBRARY_DIR/Incoming" "$COZY_LIBRARY_DIR/Sorted"

echo "==> Forcing KDE portal as FileChooser while keeping Hyprland portal default"
# Portal selection via portals.conf :contentReference[oaicite:5]{index=5}
mkdir -p "$HOME/.config/xdg-desktop-portal"
cat > "$HOME/.config/xdg-desktop-portal/portals.conf" <<'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=kde
EOF

echo "==> Granting Cozy filesystem access to the library path (so it can actually scan)"
# Cozy upstream explicitly suggests using Flatseal/permissions for access. 
flatpak override --user --filesystem="$COZY_LIBRARY_DIR" com.github.geigi.cozy

echo "==> Restarting portal services (best effort)"
# On Arch, KDE portal service is plasma-xdg-desktop-portal-kde.service :contentReference[oaicite:7]{index=7}
restart_user_unit_if_exists xdg-desktop-portal.service
restart_user_unit_if_exists xdg-desktop-portal-hyprland.service
restart_user_unit_if_exists xdg-desktop-portal-gtk.service
restart_user_unit_if_exists plasma-xdg-desktop-portal-kde.service

echo "==> Sanity check: show Cozy permissions"
flatpak info --show-permissions com.github.geigi.cozy | sed -n '1,120p' || true

echo "==> Done."
echo "Next: launch Cozy and add the SAME folder: $COZY_LIBRARY_DIR"
