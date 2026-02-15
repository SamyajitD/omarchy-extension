#!/usr/bin/env bash
set -euo pipefail

HYPR_DIR="${HOME}/.config/hypr"
DST="${HYPR_DIR}/keybinds.conf"
SRC="${HOME}/omarchy-extension/omarchy-keybinds/keybinds.conf"
HYPRCONF="${HYPR_DIR}/hyprland.conf"

mkdir -p "${HYPR_DIR}"

# 1) Ensure source file exists (otherwise symlink would be broken)
if [[ ! -f "${SRC}" ]]; then
  echo "Error: source keybinds file not found:"
  echo "  ${SRC}"
  exit 1
fi

# 2) Ensure ~/.config/hypr/keybinds.conf is a symlink to the desired file
if [[ ! -e "${DST}" ]]; then
  ln -s "${SRC}" "${DST}"
else
  if [[ -L "${DST}" ]]; then
    # If it's a symlink but points elsewhere, fix it (idempotent)
    current_target="$(readlink -f "${DST}" || true)"
    desired_target="$(readlink -f "${SRC}")"
    if [[ "${current_target}" != "${desired_target}" ]]; then
      ln -sf "${SRC}" "${DST}"
    fi
  else
    echo "Error: ${DST} exists and is not a symlink."
    echo "Refusing to overwrite. Move/backup it, then re-run."
    exit 1
  fi
fi

# 3) Ensure hyprland.conf exists (Omarchy/Hyprland normally has this)
if [[ ! -f "${HYPRCONF}" ]]; then
  echo "Error: Hyprland config not found:"
  echo "  ${HYPRCONF}"
  exit 1
fi

# 4) Ensure hyprland.conf sources ~/.config/hypr/keybinds.conf (idempotent)
# We accept any existing 'source = .../.config/hypr/keybinds.conf' line
if ! grep -Eq '^[[:space:]]*source[[:space:]]*=[[:space:]]*.*\.config/hypr/keybinds\.conf[[:space:]]*$' "${HYPRCONF}"; then
  {
    echo ""
    echo "# --- user keybinds (managed by ensure-omarchy-keybinds.sh) ---"
    echo "source = ~/.config/hypr/keybinds.conf"
  } >> "${HYPRCONF}"
fi

echo "OK:"
echo "  ${DST} -> ${SRC}"
echo "  ensured: ${HYPRCONF} sources ~/.config/hypr/keybinds.conf"
echo "Apply with: hyprctl reload"

