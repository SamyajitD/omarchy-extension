#!/bin/sh
# Auto-disable laptop panel when an external monitor is present.
# POSIX sh, idempotent, safe (won't disable last remaining monitor).

set -eu

# ---- USER CONFIG ----
# Set this to your internal panel name from: hyprctl monitors
# Common values: eDP-1, eDP-2
LAPTOP="${LAPTOP:-eDP-1}"

# Rules:
# Hyprland monitor rule format: name,resolution,position,scale
# We'll keep it simple and stable:
# - Primary external at 0x0
# - Other externals auto-placed
PRIMARY_RULE="${PRIMARY_RULE:-preferred,0x0,1.25}"
EXTERNAL_RULE="${EXTERNAL_RULE:-preferred,auto,1.25}"
LAPTOP_RULE="${LAPTOP_RULE:-preferred,0x0,1}"
# ---------------------

# Best-effort: only meaningful inside Hyprland.
command -v hyprctl >/dev/null 2>&1 || exit 0

# Lock to prevent concurrent runs when multiple events fire.
LOCK_BASE="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_DIR="$LOCK_BASE/auto-display.lockdir"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # Someone else is running; exit quietly.
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT HUP TERM

# Get monitor names from hyprctl output (no jq dependency).
# Lines look like: "Monitor eDP-1 (ID 0):"
MONS="$(hyprctl monitors 2>/dev/null | awk '$1=="Monitor"{print $2}' || true)"

# Compute externals (anything not equal to LAPTOP)
EXTERNALS="$(printf "%s\n" "$MONS" | awk -v lap="$LAPTOP" 'NF && $0 != lap {print}' || true)"
EXT_COUNT="$(printf "%s\n" "$EXTERNALS" | awk 'NF{c++} END{print c+0}')"

if [ "$EXT_COUNT" -ge 1 ]; then
  # Pick a stable primary external: first in the list.
  PRIMARY_EXT="$(printf "%s\n" "$EXTERNALS" | awk 'NF{print; exit}')"

  # Build a single batch command to avoid hyprctl spam.
  # hyprctl --batch expects "cmd ; cmd ; cmd" :contentReference[oaicite:3]{index=3}
  BATCH="keyword monitor ${PRIMARY_EXT},${PRIMARY_RULE}"

  # Configure any additional external monitors.
  for m in $EXTERNALS; do
    [ "$m" = "$PRIMARY_EXT" ] && continue
    BATCH="${BATCH} ; keyword monitor ${m},${EXTERNAL_RULE}"
  done

  # Disable laptop panel ONLY if at least one external exists.
  BATCH="${BATCH} ; keyword monitor ${LAPTOP},disable"

  hyprctl --batch "$BATCH" >/dev/null 2>&1 || true
else
  # No external monitor: ensure laptop panel is enabled.
  hyprctl --batch "keyword monitor ${LAPTOP},${LAPTOP_RULE}" >/dev/null 2>&1 || true
fi

