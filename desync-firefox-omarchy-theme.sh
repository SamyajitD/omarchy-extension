#!/usr/bin/env bash
# disable-omarchy-firefox-theme-sync.sh
# Idempotently STOP Omarchy -> Firefox theme sync (Pywal/Pywalfox integration)
#
# Removes:
#   ~/.config/omarchy/hooks/theme-set.d/50-firefox-pywalfox
#   the marker + sync call appended to ~/.config/omarchy/hooks/theme-set
#   ~/.local/bin/omarchy-firefox-theme-sync
#   ~/.config/omarchy/cache/pywal-omarchy-theme.json
#
# Re-enable: rerun your setup script that installs the sync + hooks.

set -euo pipefail

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="${HOME}/.local/bin"

SYNC_BIN="${LOCAL_BIN}/omarchy-firefox-theme-sync"
OMARCHY_HOOK_DIR="${XDG_CONFIG_HOME}/omarchy/hooks"
THEMESET_HOOK="${OMARCHY_HOOK_DIR}/theme-set"
THEMESET_D_DIR="${OMARCHY_HOOK_DIR}/theme-set.d"
D_HOOK="${THEMESET_D_DIR}/50-firefox-pywalfox"

CACHE_JSON="${XDG_CONFIG_HOME}/omarchy/cache/pywal-omarchy-theme.json"

MARKER="# OMARCHY: run firefox pywalfox sync"
PATTERN="omarchy-firefox-theme-sync"

removed_any=0

# 1) Remove the theme-set.d hook we installed
if [[ -e "$D_HOOK" ]]; then
  rm -f "$D_HOOK"
  say "Removed: $D_HOOK"
  removed_any=1
else
  say "Already absent: $D_HOOK"
fi

# 2) Remove the helper binary
if [[ -e "$SYNC_BIN" ]]; then
  rm -f "$SYNC_BIN"
  say "Removed: $SYNC_BIN"
  removed_any=1
else
  say "Already absent: $SYNC_BIN"
fi

# 3) Remove the generated cache JSON
if [[ -e "$CACHE_JSON" ]]; then
  rm -f "$CACHE_JSON"
  say "Removed: $CACHE_JSON"
  removed_any=1
else
  say "Already absent: $CACHE_JSON"
fi

# 4) Remove ONLY our appended marker + next-line call from theme-set (if present)
if [[ -f "$THEMESET_HOOK" ]]; then
  if grep -Fq "$MARKER" "$THEMESET_HOOK"; then
    ts="$(date +%Y%m%d%H%M%S)"
    backup="${THEMESET_HOOK}.bak.${ts}"
    cp -a "$THEMESET_HOOK" "$backup"
    say "Backup created: $backup"

    python3 - "$THEMESET_HOOK" "$MARKER" "$PATTERN" <<'PY'
import sys, os

path = sys.argv[1]
marker = sys.argv[2]
pattern = sys.argv[3]

st = os.stat(path)
with open(path, "r", encoding="utf-8", errors="replace") as f:
    lines = f.readlines()

out = []
i = 0
changed = False
while i < len(lines):
    line = lines[i]
    if line.rstrip("\n") == marker:
        changed = True
        i += 1
        # remove the immediate next line if it looks like our sync call
        if i < len(lines) and pattern in lines[i]:
            i += 1
        continue
    out.append(line)
    i += 1

if changed:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.writelines(out)
    os.replace(tmp, path)
    os.chmod(path, st.st_mode & 0o777)

PY

    say "Cleaned marker/call from: $THEMESET_HOOK"
    removed_any=1
  else
    say "No marker found in: $THEMESET_HOOK (nothing to clean)"
  fi
else
  say "theme-set hook not found: $THEMESET_HOOK (ok)"
fi

# 5) If theme-set.d exists and is now empty, remove it (optional cleanup)
if [[ -d "$THEMESET_D_DIR" ]]; then
  if ! ls -A "$THEMESET_D_DIR" >/dev/null 2>&1; then
    rmdir "$THEMESET_D_DIR" || true
    say "Removed empty dir: $THEMESET_D_DIR"
  fi
fi

say ""
if [[ "$removed_any" -eq 1 ]]; then
  say "Sync is DISABLED."
  say "To enable again: rerun your setup/install sync script."
else
  say "Nothing to do (already disabled)."
fi

