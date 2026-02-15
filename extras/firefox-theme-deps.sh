#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "ERROR: Don't run this as root. Run as your normal user (it will sudo when needed)." >&2
  exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing '$1' in PATH" >&2; exit 1; }; }

need sudo
need pacman
need yay

# 1) Pywal (official repo)
sudo pacman -S --needed --noconfirm python-pywal

# 2) Pywalfox native messaging host (AUR)
# --answerdiff/--answerclean suppress yay's extra interactive prompts in scripts.
yay -S --needed --noconfirm --answerdiff None --answerclean None python-pywalfox

# 3) Install/refresh the native messaging host registration (safe to re-run)
need pywalfox
pywalfox install || true

echo "Done."
echo "Next: install the Pywalfox Firefox extension in the Firefox profile(s) you want themed."

