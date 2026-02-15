#!/usr/bin/env bash
# setup-omarchy-firefox-theme-sync.sh
# Idempotently wire: Omarchy theme -> (colors.toml) -> Pywal cache -> Pywalfox -> Firefox Theme
#
# You do manually (once per Firefox profile you care about):
#   - Install the Pywalfox add-on in that profile (normal + WebApps)
#   - Restart Firefox
#   - In the add-on settings, "fetch" colors once if needed :contentReference[oaicite:1]{index=1}
#
# This script:
#   - Ensures ~/.local/bin is in PATH via ~/.zshrc (idempotent)
#   - Ensures Pywalfox native-messaging manifest exists (tries `pywalfox install`)
#   - Creates:
#       ~/.local/bin/omarchy-firefox-theme-sync
#       ~/.config/omarchy/hooks/theme-set.d/50-firefox-pywalfox   (preferred)
#     and if needed, appends a call into ~/.config/omarchy/hooks/theme-set
#
# Notes:
# - Omarchy hook style commonly supports theme-set.d style chaining :contentReference[oaicite:2]{index=2}
# - Pywalfox uses a native messaging host + update/fetch mechanism :contentReference[oaicite:3]{index=3}

set -euo pipefail

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing '$1' in PATH."; }

write_if_changed() {
  local path="$1" mode="$2"
  local tmp; tmp="$(mktemp)"
  cat >"$tmp"
  if [[ -f "$path" ]] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  install -m "$mode" "$tmp" "$path"
  rm -f "$tmp"
}

append_once() {
  local file="$1" marker="$2"
  shift 2
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -Fq "$marker" "$file"; then
    return 0
  fi
  {
    printf '\n%s\n' "$marker"
    cat
  } >>"$file"
}

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="${HOME}/.local/bin"

OMARCHY_COLORS_TOML="${XDG_CONFIG_HOME}/omarchy/current/theme/colors.toml"
OMARCHY_HOOK_DIR="${XDG_CONFIG_HOME}/omarchy/hooks"
THEMESET_HOOK="${OMARCHY_HOOK_DIR}/theme-set"
THEMESET_D_DIR="${OMARCHY_HOOK_DIR}/theme-set.d"

SYNC_BIN="${LOCAL_BIN}/omarchy-firefox-theme-sync"
D_HOOK="${THEMESET_D_DIR}/50-firefox-pywalfox"

# Hard requirements
need_cmd bash
need_cmd mktemp
need_cmd cmp
need_cmd install
need_cmd python3

# Functional requirements
need_cmd wal
need_cmd pywalfox
need_cmd firefox

[[ -r "$OMARCHY_COLORS_TOML" ]] || die "Cannot read: $OMARCHY_COLORS_TOML (set an Omarchy theme at least once)."

mkdir -p "$LOCAL_BIN" "$OMARCHY_HOOK_DIR" "$THEMESET_D_DIR"

# 1) Ensure ~/.local/bin is on PATH for zsh (idempotent)
ZSHRC="${HOME}/.zshrc"
PATH_MARKER="# OMARCHY: ensure ~/.local/bin on PATH"
append_once "$ZSHRC" "$PATH_MARKER" <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
EOF
say "Updated: $ZSHRC (ensured ~/.local/bin is on PATH)"

# 2) Install/verify Pywalfox native-messaging manifest
# Pywalfox requires a native messaging host manifest under ~/.mozilla/native-messaging-hosts :contentReference[oaicite:4]{index=4}
say "Ensuring Pywalfox native-messaging manifest is installed..."
PYWALFOX_INSTALL_OUT=""
if ! PYWALFOX_INSTALL_OUT="$(pywalfox install 2>&1)"; then
  warn "pywalfox install returned non-zero:"
  warn "$PYWALFOX_INSTALL_OUT"
fi

manifest_ok=0
for p in \
  "$HOME/.mozilla/native-messaging-hosts/pywalfox.json" \
  "/usr/lib/mozilla/native-messaging-hosts/pywalfox.json" \
  "/usr/lib64/mozilla/native-messaging-hosts/pywalfox.json"
do
  [[ -f "$p" ]] && manifest_ok=1
done

if [[ "$manifest_ok" -ne 1 ]]; then
  die "Pywalfox native-messaging manifest not found. Nothing will work until this exists.
Fix:
  - If ~/.mozilla/native-messaging-hosts exists but is owned by root, fix ownership or remove it and rerun.
  - Then run: pywalfox install
(See Pywalfox troubleshooting notes about the manifest and permissions.)"
fi

# 3) Create the sync helper (fixes your tomllib bytes/str bug by using tomllib.load on a binary file)
write_if_changed "$SYNC_BIN" 0755 <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
OMARCHY_COLORS_TOML="${XDG_CONFIG_HOME}/omarchy/current/theme/colors.toml"
OUT_THEME_JSON="${XDG_CONFIG_HOME}/omarchy/cache/pywal-omarchy-theme.json"

if [[ ! -r "$OMARCHY_COLORS_TOML" ]]; then
  warn "Missing Omarchy palette: $OMARCHY_COLORS_TOML"
  exit 0
fi

mkdir -p "$(dirname "$OUT_THEME_JSON")"

python3 - "$OMARCHY_COLORS_TOML" "$OUT_THEME_JSON" <<'PY'
import sys, json, tomllib
from pathlib import Path

src = Path(sys.argv[1])
out = Path(sys.argv[2])

with src.open("rb") as f:  # robust: tomllib.load expects a binary file handle
    data = tomllib.load(f)

needed = ["background","foreground","cursor"] + [f"color{i}" for i in range(16)]
missing = [k for k in needed if k not in data]
if missing:
    print(f"Missing keys in {src}: {missing}", file=sys.stderr)
    sys.exit(2)

theme = {
  "wallpaper": "",
  "alpha": "100",
  "special": {
    "background": data["background"],
    "foreground": data["foreground"],
    "cursor": data["cursor"],
  },
  "colors": { f"color{i}": data[f"color{i}"] for i in range(16) }
}

out.write_text(json.dumps(theme, indent=2), encoding="utf-8")
PY

# Generate ~/.cache/wal/* from the theme JSON (no wallpaper changes).
if ! wal --theme "$OUT_THEME_JSON" -n -s -e >/dev/null 2>&1; then
  warn "wal failed (pywal not working)."
  exit 0
fi

# Trigger Firefox theme refresh through Pywalfox.
# If this fails, you can still fetch via the add-on settings UI after restarting Firefox. :contentReference[oaicite:5]{index=5}
if ! pywalfox update >/dev/null 2>&1; then
  warn "pywalfox update failed. Common causes:"
  warn "  - Pywalfox add-on not installed/enabled in this Firefox profile"
  warn "  - Firefox not restarted after installing the add-on"
  warn "  - Native-messaging manifest path issues"
  exit 0
fi

say "Firefox theme updated from Omarchy palette."
EOF

# 4) Prefer theme-set.d hook (doesn't fight other hooks)
write_if_changed "$D_HOOK" 0755 <<EOF
#!/usr/bin/env bash
set -euo pipefail
"${SYNC_BIN}" "\$@" || true
EOF

# 5) Ensure theme-set hook will run our sync even if theme-set.d isn’t wired on this system
# If theme-set already mentions theme-set.d, we leave it alone.
if [[ -f "$THEMESET_HOOK" ]] && grep -q "theme-set\.d" "$THEMESET_HOOK"; then
  say "theme-set already supports theme-set.d (good)."
else
  # If theme-set exists but doesn't mention theme-set.d, do not overwrite unknown content.
  # Just append a safe call (idempotent marker).
  THEMESET_MARKER="# OMARCHY: run firefox pywalfox sync"
  append_once "$THEMESET_HOOK" "$THEMESET_MARKER" <<EOF
"${SYNC_BIN}" "\$@" || true
EOF
  chmod +x "$THEMESET_HOOK" 2>/dev/null || true
  say "Ensured: $THEMESET_HOOK will call the Firefox sync."
fi

# 6) Run initial sync once
say "Running initial sync..."
"$SYNC_BIN" || true

say ""
say "Done."
say "Auto-sync is wired to Omarchy theme changes via:"
say "  - $D_HOOK"
say "  - (and/or) $THEMESET_HOOK"
say ""
say "Manual re-sync anytime:"
say "  $SYNC_BIN"
say ""
say "If Firefox UI still doesn't fully match menus/context etc:"
say "  Pywalfox can also apply userChrome/userContent CSS, but Firefox requires:"
say "  toolkit.legacyUserProfileCustomizations.stylesheets=true in about:config :contentReference[oaicite:6]{index=6}"

