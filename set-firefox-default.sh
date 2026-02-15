#!/bin/sh
# Set Firefox as default browser if it exists (idempotent).
# Works for most desktop environments / Omarchy setups.

set -eu

want_desktop="firefox.desktop"

have_firefox() {
  command -v firefox >/dev/null 2>&1 || command -v firefox-bin >/dev/null 2>&1
}

have_desktop_file() {
  # Common locations for .desktop entries
  [ -r "/usr/share/applications/$want_desktop" ] || \
  [ -r "$HOME/.local/share/applications/$want_desktop" ]
}

if ! have_firefox; then
  echo "firefox not found in PATH; not changing default browser." >&2
  exit 0
fi

if ! have_desktop_file; then
  echo "$want_desktop not found in /usr/share/applications or ~/.local/share/applications." >&2
  echo "Not changing defaults (xdg-settings expects a .desktop id)." >&2
  exit 0
fi

# --- xdg-settings (primary) ---
if command -v xdg-settings >/dev/null 2>&1; then
  current="$(xdg-settings get default-web-browser 2>/dev/null || true)"
  if [ "$current" != "$want_desktop" ]; then
    xdg-settings set default-web-browser "$want_desktop"
    echo "Set default web browser via xdg-settings -> $want_desktop"
  else
    echo "Default web browser already $want_desktop (xdg-settings)"
  fi
fi

# --- xdg-mime (scheme handlers) ---
if command -v xdg-mime >/dev/null 2>&1; then
  for t in x-scheme-handler/http x-scheme-handler/https; do
    cur="$(xdg-mime query default "$t" 2>/dev/null || true)"
    if [ "$cur" != "$want_desktop" ]; then
      xdg-mime default "$want_desktop" "$t"
      echo "Set $t handler via xdg-mime -> $want_desktop"
    else
      echo "$t handler already $want_desktop"
    fi
  done
fi

echo "Done."

