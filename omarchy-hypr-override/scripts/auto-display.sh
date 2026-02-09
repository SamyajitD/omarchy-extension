#!/bin/sh
# Use external-only when HDMI-A-1 is present; otherwise use laptop panel.
# POSIX sh, idempotent, and avoids disabling the last monitor.

set -eu

LAPTOP="eDP-1"
PREFERRED_EXTERNAL="HDMI-A-1"

# Desired modes (match your monitor capabilities)
EXT_MODE="2560x1440@144"
LAPTOP_MODE="1920x1080@60"

# Best-effort: only meaningful inside Hyprland.
command -v hyprctl >/dev/null 2>&1 || exit 0

# Lock to avoid concurrent runs when multiple events fire.
LOCK_BASE="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_DIR="$LOCK_BASE/auto-display.lockdir"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT HUP TERM

# Get available monitor names (active + inactive) per Hyprland docs.
# "hyprctl monitors all" lists all available monitors. :contentReference[oaicite:1]{index=1}
MONS="$(hyprctl monitors all 2>/dev/null | awk '$1=="Monitor"{print $2}' || true)"

# Externals = anything except laptop panel
EXTERNALS="$(printf "%s\n" "$MONS" | awk -v lap="$LAPTOP" 'NF && $0 != lap {print}' || true)"
EXT_COUNT="$(printf "%s\n" "$EXTERNALS" | awk 'NF{c++} END{print c+0}')"

if [ "$EXT_COUNT" -ge 1 ]; then
  # Prefer HDMI-A-1 if present; otherwise use first external.
  PRIMARY=""
  for m in $EXTERNALS; do
    if [ "$m" = "$PREFERRED_EXTERNAL" ]; then
      PRIMARY="$m"
      break
    fi
  done
  if [ -z "$PRIMARY" ]; then
    PRIMARY="$(printf "%s\n" "$EXTERNALS" | awk 'NF{print; exit}')"
  fi

  # Build a single hyprctl batch to avoid spamming calls. :contentReference[oaicite:2]{index=2}
  if [ "$PRIMARY" = "$PREFERRED_EXTERNAL" ]; then
    BATCH="keyword monitor ${PRIMARY},${EXT_MODE},0x0,1"
  else
    BATCH="keyword monitor ${PRIMARY},preferred,0x0,1"
  fi

  # Any additional externals: enable with preferred mode, auto placement.
  for m in $EXTERNALS; do
    [ "$m" = "$PRIMARY" ] && continue
    BATCH="${BATCH} ; keyword monitor ${m},preferred,auto,1"
  done

  # External-only: disable laptop panel (removes it from layout). :contentReference[oaicite:3]{index=3}
  BATCH="${BATCH} ; keyword monitor ${LAPTOP},disable"

  hyprctl --batch "$BATCH" >/dev/null 2>&1 || true
else
  # No external: ensure laptop is enabled at its high refresh.
  hyprctl --batch "keyword monitor ${LAPTOP},${LAPTOP_MODE},0x0,1" >/dev/null 2>&1 || true
fi

