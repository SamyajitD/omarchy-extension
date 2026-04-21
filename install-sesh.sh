#!/usr/bin/env bash
set -euo pipefail

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

if need_cmd sesh; then
  echo "sesh is already installed at: $(command -v sesh)"
  exit 0
fi

if ! need_cmd yay; then
  echo "error: yay is not installed."
  echo "Install yay first, then rerun this script."
  exit 1
fi

if ! need_cmd tmux; then
  echo "error: tmux is not installed."
  echo "sesh requires tmux to be set up first."
  exit 1
fi

if ! need_cmd zoxide; then
  echo "error: zoxide is not installed."
  echo "sesh uses zoxide for directory/project discovery, so install/setup zoxide first."
  exit 1
fi

yay -S --needed sesh-bin

if need_cmd sesh; then
  echo "sesh installed successfully."
  echo "Run: sesh list"
else
  echo "error: installation finished but 'sesh' is still not available in PATH."
  exit 1
fi
