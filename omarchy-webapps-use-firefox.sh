#!/usr/bin/env bash
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
note() { echo "==> $*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

need_cmd xdg-settings
need_cmd firefox

# 1) Check Firefox is the default browser (do NOT change it here)
default_browser="$(xdg-settings get default-web-browser 2>/dev/null || true)"
case "$default_browser" in
  firefox* ) ;;
  * )
    die "default browser is '$default_browser' (not Firefox). Set it first, e.g.: xdg-settings set default-web-browser firefox.desktop"
    ;;
esac

# 2) Ensure the dedicated profile exists (recommended by community approach)
profiles_ini="$HOME/.mozilla/firefox/profiles.ini"
if [[ -f "$profiles_ini" ]] && grep -qE '^[[:space:]]*Name=WebApps[[:space:]]*$' "$profiles_ini"; then
  note "Firefox profile 'WebApps' already exists."
else
  note "Firefox profile 'WebApps' not found; attempting to create it..."
  # Try common forms seen in practice/tutorials
  if firefox -CreateProfile "WebApps" >/dev/null 2>&1; then
    :
  elif firefox -P "WebApps" -CreateProfile "WebApps" >/dev/null 2>&1; then
    :
  else
    die "couldn't auto-create profile. Create it manually, then re-run:
  firefox -P \"WebApps\" -CreateProfile \"WebApps\""
  fi
fi

# 3) Find Omarchy launcher (expected location per Omarchy community tutorial)
candidate_paths=()

if command -v omarchy-launch-webapp >/dev/null 2>&1; then
  candidate_paths+=("$(command -v omarchy-launch-webapp)")
fi

expected="$HOME/.local/share/omarchy/bin/omarchy-launch-webapp"
if [[ -f "$expected" ]]; then
  candidate_paths+=("$expected")
fi

# De-duplicate + resolve symlinks
declare -A seen=()
targets=()
for p in "${candidate_paths[@]}"; do
  rp="$(readlink -f "$p" 2>/dev/null || echo "$p")"
  [[ -n "${seen[$rp]+x}" ]] && continue
  seen["$rp"]=1
  targets+=("$rp")
done

[[ "${#targets[@]}" -gt 0 ]] || die "couldn't find omarchy-launch-webapp (expected: $expected)"

# 4) Patch (idempotent) + backup once
for target in "${targets[@]}"; do
  [[ -w "$target" ]] || die "not writable: $target"

  if grep -q 'OMARCHY_FIREFOX_WEBAPPS_PATCH' "$target" 2>/dev/null; then
    note "Already patched: $target"
    continue
  fi

  backup="${target}.bak"
  if [[ ! -f "$backup" ]]; then
    cp -a "$target" "$backup"
    note "Backup created: $backup"
  else
    note "Backup already exists: $backup"
  fi

  tmp="$(mktemp)"
  cat >"$tmp" <<'EOF'
#!/usr/bin/env bash
# OMARCHY_FIREFOX_WEBAPPS_PATCH v1
# Switch Omarchy WebApps from Chromium to Firefox (WebApps profile)

set -euo pipefail

url="${1:-}"
if [[ -z "$url" ]]; then
  echo "usage: omarchy-launch-webapp <url> [extra args...]" >&2
  exit 2
fi

# Prefer uwsm if present (Omarchy), otherwise run directly.
launcher=()
if command -v uwsm-app >/dev/null 2>&1; then
  launcher=(uwsm-app --)
elif command -v uwsm >/dev/null 2>&1; then
  launcher=(uwsm app --)
fi

# --class is commonly used for X11/window-class matching; --name helps on Wayland app-id matching.
exec setsid "${launcher[@]}" firefox --no-remote -P "WebApps" --new-window --class WebApp --name WebApp "$url" "${@:2}"
EOF

  chmod --reference="$target" "$tmp" 2>/dev/null || chmod +x "$tmp"
  mv "$tmp" "$target"
  note "Patched: $target"
done

note "Done. Test with:"
echo "  omarchy-launch-webapp \"https://web.whatsapp.com\""

