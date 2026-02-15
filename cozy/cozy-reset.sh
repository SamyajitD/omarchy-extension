#!/usr/bin/env bash
set -euo pipefail

APP_ID="com.github.geigi.cozy"

echo "==> Killing Cozy if running (best effort)"
if command -v flatpak >/dev/null 2>&1; then
  flatpak kill "$APP_ID" >/dev/null 2>&1 || true
fi

ts="$(date +%Y%m%d-%H%M%S)"
backup_dir="$HOME/Backups/cozy-$ts"
mkdir -p "$backup_dir"

echo "==> Backing up Flatpak Cozy data (if present)"
src="$HOME/.var/app/$APP_ID"
if [ -d "$src" ]; then
  cp -a "$src" "$backup_dir/" || true
  echo "    Backup saved at: $backup_dir/$(basename "$src")"
fi

echo "==> Removing Flatpak Cozy app + per-user overrides (best effort)"
if command -v flatpak >/dev/null 2>&1; then
  flatpak uninstall -y --user "$APP_ID" >/dev/null 2>&1 || true
  flatpak override --user --reset "$APP_ID" >/dev/null 2>&1 || true
fi

echo "==> Removing possible native (AUR) Cozy leftovers (best effort)"
rm -rf "$HOME/.config/cozy" "$HOME/.cache/cozy" "$HOME/.local/share/cozy" >/dev/null 2>&1 || true

echo "==> Done. If you want a totally clean slate, log out/in once."

