#!/usr/bin/env bash
set -euo pipefail

if command -v yazi >/dev/null 2>&1; then
  echo "yazi is already installed at: $(command -v yazi)"
  exit 0
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "error: pacman not found. This script is for Arch/Omarchy."
  exit 1
fi

sudo pacman -S --needed yazi

if command -v yazi >/dev/null 2>&1; then
  echo "yazi installed successfully."
  yazi --version
else
  echo "error: installation completed but 'yazi' is still not available in PATH."
  exit 1
fi
