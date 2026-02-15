#!/usr/bin/env bash
set -euo pipefail

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
need_cmd yay
need_cmd systemctl

echo "==> Install portal stack (best effort, idempotent)"
yay -S --needed \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  xdg-desktop-portal-kde

echo "==> Write Hyprland portal config (KDE file picker)"
cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal"
mkdir -p "$cfg_dir"

cat > "$cfg_dir/hyprland-portals.conf" <<'EOF'
[preferred]
default = hyprland;gtk
org.freedesktop.impl.portal.FileChooser = kde
EOF

echo "==> Restart portals (best effort)"
systemctl --user stop \
  xdg-desktop-portal.service \
  xdg-desktop-portal-hyprland.service \
  xdg-desktop-portal-gtk.service \
  plasma-xdg-desktop-portal-kde.service 2>/dev/null || true

systemctl --user start xdg-desktop-portal.service

echo "==> Status"
systemctl --user --no-pager status xdg-desktop-portal.service xdg-desktop-portal-hyprland.service || true
systemctl --user --no-pager status plasma-xdg-desktop-portal-kde.service || true

echo "==> Logs (last 50 lines)"
journalctl --user -u xdg-desktop-portal -u xdg-desktop-portal-hyprland -u plasma-xdg-desktop-portal-kde -n 50 --no-pager || true

echo "Done."

