#!/usr/bin/env bash
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TMUX_DIR="$XDG_CONFIG_HOME/tmux"
PLUGINS_DIR="$TMUX_DIR/plugins"
TPM_DIR="$PLUGINS_DIR/tpm"
OMARCHY_TMUX_INSTALL_URL="https://raw.githubusercontent.com/joaofelipegalvao/omarchy-tmux/main/scripts/omarchy-tmux-install.sh"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

log() { printf "\033[0;32m▶\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m⚠\033[0m %s\n" "$*" >&2; }

install_pkgs_arch() {
  log "Installing packages (Arch/pacman)…"
  sudo pacman -S --needed --noconfirm \
    tmux git curl fzf bat zoxide wl-clipboard \
    ttf-jetbrains-mono-nerd
}

clone_or_update() {
  local repo="$1"
  local dest="$2"

  if [[ -d "$dest/.git" ]]; then
    log "Updating $(basename "$dest")…"
    git -C "$dest" fetch --tags --prune
    git -C "$dest" pull --ff-only || true
  else
    log "Cloning $(basename "$dest")…"
    git clone --depth 1 "$repo" "$dest"
  fi
}

backup_if_exists() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local b="${f}.backup-$(date +%Y%m%d-%H%M%S)"
  cp -f "$f" "$b"
  log "Backup: $b"
}

write_tmux_conf() {
  mkdir -p "$TMUX_DIR"

  cat >"$TMUX_DIR/tmux.conf" <<'EOF'
# ~/.config/tmux/tmux.conf
# Minimal + pretty, with Omarchy theme sync (PowerKit) and persistence.

##### Reload
unbind r
bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"

##### Terminal / colors
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

##### Prefix
unbind C-b
set -g prefix C-s
bind C-s send-prefix

##### UX
set -g mouse on
setw -g mode-keys vi
set -g set-clipboard on
set -g history-limit 100000
set -g status-position top
set -g status-style bg=default

##### Pane navigation (prefix + hjkl)
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

##### Omarchy theme sync (managed by omarchy-tmux)
# This symlink updates when you switch themes in Omarchy.
source-file ~/.config/tmux/omarchy-current-theme.conf

##### PowerKit look (rounded + minimal, omerxx-ish)
# Status layout: session | windows | plugins (plugins on the right)
set -g @powerkit_status_order "session,windows,plugins"
set -g @powerkit_separator_style "rounded"
set -g @powerkit_edge_separator_style "rounded:all"
set -g @powerkit_transparent "true"
set -g @powerkit_status_interval "5"
set -g @powerkit_icon_padding "2"

# Right side: current dir (basename) + time/date
# (external() is a PowerKit plugin helper)
set -g @powerkit_plugins "external(\"󰉋\"|\"#{b:pane_current_path}\"|\"info-base\"|\"info-base-lighter\"|\"3\"),datetime"

# Windows: keep it clean
set -g @powerkit_zoomed_window_icon ""
set -g @powerkit_active_window_title "#W#{?window_zoomed_flag,(),}"
set -g @powerkit_inactive_window_title "#W"
set -g @powerkit_inactive_window_show_index "false"

##### Session management (prefix + o)
set -g @sessionx-bind 'o'
set -g @sessionx-zoxide-mode 'on'
set -g @sessionx-window-width '75%'
set -g @sessionx-window-height '85%'

##### Persistence
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
set -g @resurrect-strategy-nvim 'session'

##### Plugins (TPM)
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'fabioluciano/tmux-powerkit'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'omerxx/tmux-sessionx'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'  # keep last

# TPM boot (XDG path)
run '~/.config/tmux/plugins/tpm/tpm'
EOF
}

install_tpm_plugins_noninteractive() {
  log "Installing TPM plugins (non-interactive)…"
  tmux -f "$TMUX_DIR/tmux.conf" start-server || true
  tmux -f "$TMUX_DIR/tmux.conf" new-session -d -s __tpm_install 2>/dev/null || true
  tmux -f "$TMUX_DIR/tmux.conf" run-shell "$TPM_DIR/bin/install_plugins" || true
  tmux -f "$TMUX_DIR/tmux.conf" kill-session -t __tpm_install 2>/dev/null || true
  tmux -f "$TMUX_DIR/tmux.conf" kill-server 2>/dev/null || true
}

main() {
  if ! need_cmd pacman; then
    warn "This installer assumes Arch (pacman). Install deps manually if you're not on Arch."
    exit 1
  fi

  install_pkgs_arch

  mkdir -p "$PLUGINS_DIR"
  clone_or_update "https://github.com/tmux-plugins/tpm" "$TPM_DIR"

  # Set up Omarchy theme sync (hook + generator + symlink)
  if [[ ! -f "$TMUX_DIR/omarchy-current-theme.conf" ]]; then
    log "Installing omarchy-tmux (theme sync)…"
    curl -fsSL "$OMARCHY_TMUX_INSTALL_URL" | bash -s -- --quiet --force
  else
    log "omarchy-tmux already present (omarchy-current-theme.conf exists)."
  fi

  backup_if_exists "$TMUX_DIR/tmux.conf"
  write_tmux_conf

  # Optional safety: symlink ~/.tmux.conf for any tooling that still expects it.
  if [[ ! -e "$HOME/.tmux.conf" ]]; then
    ln -s "$TMUX_DIR/tmux.conf" "$HOME/.tmux.conf"
    log "Symlinked ~/.tmux.conf -> $TMUX_DIR/tmux.conf"
  fi

  install_tpm_plugins_noninteractive

  log "Done. Start tmux: tmux"
  warn "If Ctrl-s freezes your terminal outside tmux, disable XON/XOFF: add 'stty -ixon' to your shell rc."
}

main "$@"
