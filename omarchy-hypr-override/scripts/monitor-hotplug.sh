#!/bin/sh
# Listens to Hyprland socket2 events and re-runs auto-display on hotplug.
# POSIX sh.

set -eu

AUTO="$HOME/omarchy-extension/omarchy-hypr-override/scripts/auto-display.sh"

command -v socat >/dev/null 2>&1 || exit 0
command -v hyprctl >/dev/null 2>&1 || exit 0

HIS="${HYPRLAND_INSTANCE_SIGNATURE:-}"
[ -n "$HIS" ] || exit 0

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
SOCK1="$RUNTIME/hypr/$HIS/.socket2.sock"
SOCK2="/tmp/hypr/$HIS/.socket2.sock"

if [ -S "$SOCK1" ]; then
  SOCK="$SOCK1"
elif [ -S "$SOCK2" ]; then
  SOCK="$SOCK2"
else
  exit 0
fi

# Run once at startup (handles "already connected" case).
"$AUTO" >/dev/null 2>&1 || true

# socket2 lines are EVENT>>DATA, and monitoradded/monitorremoved exist. :contentReference[oaicite:4]{index=4}
socat -U - "UNIX-CONNECT:$SOCK" 2>/dev/null | while IFS= read -r line; do
  event=${line%%>>*}
  case "$event" in
    monitoradded|monitoraddedv2|monitorremoved|monitorremovedv2)
      "$AUTO" >/dev/null 2>&1 || true
      ;;
  esac
done

