#!/usr/bin/env bash
set -euo pipefail

PKG="television"
SHELL_RC="${HOME}/.zshrc"
INTEGRATION_LINE='eval "$(tv init zsh)"'

MIRRORLIST="/etc/pacman.d/mirrorlist"
BACKUP_MIRRORLIST="/etc/pacman.d/mirrorlist.omarchy-backup"
TMP_MIRRORLIST="$(mktemp)"

cleanup() {
  rm -f "${TMP_MIRRORLIST}"
}
trap cleanup EXIT

log() {
  printf '[television-setup] %s\n' "$*"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmds() {
  local missing=0
  for cmd in sudo pacman grep sed curl yay; do
    if ! have_cmd "$cmd"; then
      log "Missing required command: $cmd"
      missing=1
    fi
  done

  if [ "$missing" -ne 0 ]; then
    exit 1
  fi
}

backup_mirrorlist_once() {
  if [ -f "${BACKUP_MIRRORLIST}" ]; then
    log "Mirrorlist backup already exists at ${BACKUP_MIRRORLIST}"
  else
    log "Backing up current mirrorlist to ${BACKUP_MIRRORLIST}"
    sudo cp "${MIRRORLIST}" "${BACKUP_MIRRORLIST}"
  fi
}

mirrorlist_is_omarchy_only() {
  local servers
  servers="$(grep -E '^[[:space:]]*Server[[:space:]]*=' "${MIRRORLIST}" || true)"

  # No active server lines means it is unusable, so treat as broken.
  if [ -z "${servers}" ]; then
    return 0
  fi

  # If every active server line points at omarchy.org, treat it as Omarchy-only.
  if echo "${servers}" | grep -q 'omarchy\.org'; then
    if ! echo "${servers}" | grep -vq 'omarchy\.org'; then
      return 0
    fi
  fi

  return 1
}

write_official_arch_mirrorlist() {
  log "Fetching official Arch mirrorlist"
  curl -fsSL \
    'https://archlinux.org/mirrorlist/?country=IN&country=SG&country=JP&country=KR&protocol=https&use_mirror_status=on' \
    -o "${TMP_MIRRORLIST}"

  if ! grep -q '^#Server = ' "${TMP_MIRRORLIST}"; then
    log "Failed to fetch a valid Arch mirrorlist"
    exit 1
  fi

  log "Replacing ${MIRRORLIST} with official Arch mirrors"
  sed 's/^#Server/Server/' "${TMP_MIRRORLIST}" | sudo tee "${MIRRORLIST}" >/dev/null
}

refresh_and_upgrade_system() {
  log "Refreshing package databases and performing full system upgrade"
  sudo pacman -Syyu --noconfirm
}

ensure_working_mirrors() {
  if mirrorlist_is_omarchy_only; then
    log "Detected Omarchy-only mirrorlist; switching to official Arch mirrors"
    backup_mirrorlist_once
    write_official_arch_mirrorlist
    refresh_and_upgrade_system
  else
    log "Mirrorlist is not Omarchy-only; continuing"
  fi
}

install_television() {
  if pacman -Q "${PKG}" >/dev/null 2>&1; then
    log "${PKG} already installed"
    return 0
  fi

  log "Installing ${PKG} with yay"
  if yay -S --needed --noconfirm "${PKG}"; then
    return 0
  fi

  log "Initial install failed; forcing switch to official Arch mirrors and retrying"
  backup_mirrorlist_once
  write_official_arch_mirrorlist
  refresh_and_upgrade_system
  yay -S --needed --noconfirm "${PKG}"
}

verify_tv() {
  if have_cmd tv; then
    log "tv found at: $(command -v tv)"
    tv --version || true
  else
    log "tv binary not found after install"
    exit 1
  fi
}

ensure_shell_integration() {
  touch "${SHELL_RC}"

  if grep -Fqx "${INTEGRATION_LINE}" "${SHELL_RC}"; then
    log "zsh integration already present in ${SHELL_RC}"
  else
    log "Adding zsh integration to ${SHELL_RC}"
    printf '\n%s\n' "${INTEGRATION_LINE}" >> "${SHELL_RC}"
  fi
}

main() {
  require_cmds
  ensure_working_mirrors
  install_television
  verify_tv
  ensure_shell_integration

  log "Done"
  log "Open a new shell or run: source ${SHELL_RC}"
  log "Then run: tv"
}

main "$@"

