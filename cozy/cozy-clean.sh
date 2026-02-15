#!/usr/bin/env bash
set -euo pipefail

echo "==> Removing Cozy (Flatpak) if present"
if command -v flatpak >/dev/null 2>&1; then
  flatpak uninstall -y --noninteractive com.github.geigi.cozy >/dev/null 2>&1 || true
  flatpak uninstall -y --unused --noninteractive >/dev/null 2>&1 || true
fi

echo "==> Removing Cozy (AUR/native) if present"
if command -v yay >/dev/null 2>&1; then
  yay -Rns --noconfirm cozy-audiobooks cozy-audiobooks-git >/dev/null 2>&1 || true
fi

echo "==> Removing Cozy app data (backup-safe: we just delete Cozy's sandbox data)"
rm -rf "$HOME/.var/app/com.github.geigi.cozy" || true

echo "==> Removing Hyprland portals override (we'll recreate it)"
rm -f "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf" || true

echo "==> Done"

