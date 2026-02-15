#!/usr/bin/env bash
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1; }

if ! need yay; then
  echo "ERROR: yay not found."
  exit 1
fi

# Install KDE portal backend (this will pull KDE/Plasma deps; expected).
yay -S --needed xdg-desktop-portal-kde

# Ensure we still have Hyprland portal + the main portal service
yay -S --needed xdg-desktop-portal xdg-desktop-portal-hyprland

# Configure Hyprland portal routing:
# - keep default fallback as hyprland;gtk (recommended by Hyprland docs)
# - force FileChooser to KDE
mkdir -p "$HOME/.config/xdg-desktop-portal"
cat > "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf" <<CONF
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=kde
CONF

# Export env to user systemd/dbus (helps portals pick up session vars)
if need dbus-update-activation-environment; then
  dbus-update-activation-environment --systemd --all || true
fi

# Restart portal services so config is reloaded
if need systemctl; then
  systemctl --user restart xdg-desktop-portal.service || true
  systemctl --user restart xdg-desktop-portal-hyprland.service || true
  systemctl --user restart xdg-desktop-portal-gtk.service || true
fi

echo
echo "✅ Switched FileChooser to KDE."
echo "Config: ~/.config/xdg-desktop-portal/hyprland-portals.conf"
echo "Now re-launch Cozy and try selecting the folder again."


