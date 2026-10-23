#!/bin/bash
# NimbusOS Task 1 — scripts/verify-macshell.sh
# Verifica hyprland.conf flotante + macshell + desconflictos + theming global.
# Uso: bash scripts/verify-macshell.sh [--root DIR]  (DIR por defecto: repo)
# Devuelve 0 si todo PASS; 1 si algun FAIL. Checks de hyprland binario son
# SKIP si hyprland no esta instalado (p. ej. host de desarrollo).
set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
if [ "${1:-}" = "--root" ]; then
  ROOT="${2:-}"
  [ -n "$ROOT" ] || { echo "Uso: $0 [--root DIR]" >&2; exit 2; }
fi
HYPR="$ROOT/nimbus-overlay/etc/skel/.config/hypr/hyprland.conf"
LUA="$ROOT/nimbus-overlay/etc/skel/.config/hypr/macshell.lua"
WRAP="$ROOT/nimbus-overlay/usr/bin/macshell"
ENVF="$ROOT/nimbus-overlay/etc/skel/.config/macshell/env"
MDOCK="$ROOT/nimbus-overlay/etc/skel/.config/macdock/settings.json"
OVL="$ROOT/nimbus-overlay"
PASS=0; FAIL=0; SKIP=0
ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }
chk()  { # chk <desc> <comando...>
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi
}
chkg() { # chkg <desc> <fichero> <regex>
  local d="$1" f="$2" re="$3"
  if grep -qE "$re" "$f" 2>/dev/null; then ok "$d"; else bad "$d"; fi
}

echo "== Task 1 verify: macshell + hyprland flotante + theming =="

# --- Ficheros base existen ----------------------------------------------------
[ -f "$HYPR" ] && ok "hyprland.conf existe" || bad "hyprland.conf existe"
[ -f "$LUA" ]  && ok "macshell.lua existe"  || bad "macshell.lua existe"
[ -f "$WRAP" ] && ok "wrapper /usr/bin/macshell existe" || bad "wrapper existe"
[ -x "$WRAP" ] && ok "wrapper es ejecutable" || bad "wrapper es ejecutable"
[ -f "$ENVF" ] && ok "macshell/env existe" || bad "macshell/env existe"
[ -f "$MDOCK" ] && ok "macdock/settings.json existe" || bad "settings.json existe"

# --- hyprland.conf: flotante + blur + binds -----------------------------------
chkg "flotante global windowrulev2" "$HYPR" 'windowrulev2[[:space:]]*=[[:space:]]*float,[[:space:]]*class:\^\(\.\*\)\$'
chkg "rounding 12-14px" "$HYPR" 'rounding[[:space:]]*=[[:space:]]*1[234]'
chkg "blur enabled" "$HYPR" 'blur[[:space:]]*\{'
chkg "blur Dual-Kawase (passes)" "$HYPR" 'passes[[:space:]]*=[[:space:]]*[0-9]+'
chkg "layerrule blur macdock"  "$HYPR" 'layerrule[[:space:]]*=[[:space:]]*blur,[[:space:]]*macdock'
chkg "layerrule blur macspot"  "$HYPR" 'layerrule[[:space:]]*=[[:space:]]*blur,[[:space:]]*macspot'
chkg "layerrule blur macbarbg" "$HYPR" 'layerrule[[:space:]]*=[[:space:]]*blur,[[:space:]]*macbarbg'
chkg "layerrule ignorealpha presente" "$HYPR" 'layerrule[[:space:]]*=[[:space:]]*ignorealpha'
chkg "exec-once = macshell" "$HYPR" 'exec-once[[:space:]]*=[[:space:]]*macshell'
chkg "SUPER+ESPACIO spotlight" "$HYPR" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*SPACE.*spotlight toggle'
chkg "ALT+TAB switcher" "$HYPR" 'bind[[:space:]]*=[[:space:]]*ALT,[[:space:]]*TAB.*switcher next'
chkg "SUPER+V clipboard" "$HYPR" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*V.*spotlight clipboard'
chkg "SUPER+L lock" "$HYPR" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*L.*lock-via-ipc'
chkg "QS_ICON_THEME definido" "$HYPR" 'env[[:space:]]*=[[:space:]]*QS_ICON_THEME,'
if grep -qiE '^[[:space:]]*bind[^=]*=[^,]*,[[:space:]]*CTRL' "$HYPR"; then
  bad "cero binds CTRL-* (Ctrl intacto)"
else
  ok "cero binds CTRL-* (Ctrl intacto)"
fi

# --- macshell.lua coherente con .conf ------------------------------------------
chkg "lua: autostart hyprland.start" "$LUA" 'hyprland\.start'
chkg "lua: macshell-start" "$LUA" 'macshell-start'
chkg "lua: layer macdock/macspot/macbarbg" "$LUA" 'macdock.*macspot.*macbarbg|namespace = "macbarbg"'
chkg "lua: SUPER+Space toggle" "$LUA" 'SUPER \+ Space.*spotlight toggle'
chkg "lua: ALT+TAB next" "$LUA" 'ALT \+ TAB.*switcher next'
if grep -qE 'CTRL \+' "$LUA"; then bad "lua: sin binds CTRL"; else ok "lua: sin binds CTRL"; fi

# --- wrapper + env --------------------------------------------------------------
chkg "wrapper prefiere macshell-start" "$WRAP" 'macshell-start'
chkg "wrapper fallback qs -c MacShell" "$WRAP" 'qs -c MacShell'
chkg "wrapper guarda qs ausente (exit 127)" "$WRAP" 'command -v qs'
chkg "env QS_ICON_THEME" "$ENVF" '^QS_ICON_THEME='
# Coherencia QS_ICON_THEME entre hyprland.conf y macshell/env (mismo valor).
HYPR_ICON="$(grep -oE 'env[[:space:]]*=[[:space:]]*QS_ICON_THEME,[^[:space:]]+' "$HYPR" 2>/dev/null | sed 's/.*,//' | head -n1)"
ENV_ICON="$(grep -E '^QS_ICON_THEME=' "$ENVF" 2>/dev/null | cut -d= -f2 | head -n1)"
if [ -n "${HYPR_ICON:-}" ] && [ "$HYPR_ICON" = "$ENV_ICON" ]; then
  ok "QS_ICON_THEME coherente hyprland.conf/env ($HYPR_ICON)"
else
  bad "QS_ICON_THEME coherente hyprland.conf/env (conf='${HYPR_ICON:-?}' env='${ENV_ICON:-?}')"
fi

# --- settings.json valido + wallpaperPath fijo ----------------------------------
if python3 -c "import json;d=json.load(open('$MDOCK'));assert d.get('wallpaperPath','').startswith('/usr/share/backgrounds/nimbus/'), 'wallpaperPath'" 2>/dev/null; then
  ok "settings.json valido + wallpaperPath fijo"
else
  bad "settings.json valido + wallpaperPath fijo"
fi

# NOTA Task 5: debe proveer /usr/share/backgrounds/nimbus/sequoia-light.jpg
# (canonico en hyprpaper.conf + macdock settings.json). Sin el fichero real,
# hyprpaper `preload` falla al arrancar: no es FAIL de Task 1, es SKIP.
WP_REL="usr/share/backgrounds/nimbus/sequoia-light.jpg"
if [ -f "$OVL/$WP_REL" ] || [ -f "/$WP_REL" ]; then
  ok "wallpaper canonico provisionado"
else
  skip "wallpaper canonico no provisionado (Task 5 debe proveer /$WP_REL)"
fi

# --- Desconflictos: ningun shell/bar/daemon rival en el overlay -----------------
if grep -rniE 'waybar|hyprpanel|[^a-z]ags[^a-z]|dunst|mako[^u]|swaync|nwg-dock|noctalia|caelestia' "$OVL" \
     | grep -viE 'macshell\.lua|hyprland\.conf|README|Noctalia, `hyprpaper`|hyprpanel, ags|stop anything|dunstctl|makoctl|swaync-client|swaynotification' >/dev/null 2>&1; then
  # Re-chequeo estricto: solo cuentan referencias como paquetes/exec autostart.
  if grep -rniE 'exec-once[^=]*=(waybar|hyprpanel|ags|dunst|mako|swaync)|(waybar|hyprpanel|dunst|mako|swaync)$' "$OVL" >/dev/null 2>&1; then
    bad "overlay libre de shells conflictivos (waybar/hyprpanel/ags/dunst/mako/swaync)"
  else
    ok "overlay libre de shells conflictivos (solo menciones documentales)"
  fi
else
  ok "overlay libre de shells conflictivos (waybar/hyprpanel/ags/dunst/mako/swaync)"
fi

# --- Theming global: ficheros ----------------------------------------------------
for f in \
  "etc/skel/.config/gtk-3.0/settings.ini" \
  "etc/skel/.config/gtk-4.0/settings.ini" \
  "etc/skel/.config/kitty/kitty.conf" \
  "etc/skel/.config/fontconfig/fonts.conf" \
  "etc/skel/.icons/default/index.theme" \
  "etc/skel/.config/hypr/hyprpaper.conf" \
  "etc/nimbus/theming/grub-theme.src" \
  "etc/nimbus/theming/sddm-theme.src" \
  "etc/nimbus/theming/README.md" \
  "etc/sddm.conf.d/10-nimbus-theme.conf.example" ; do
  [ -f "$OVL/$f" ] && ok "theming: $f" || bad "theming: $f"
done
chkg "gtk WhiteSur" "$OVL/etc/skel/.config/gtk-3.0/settings.ini" 'gtk-theme-name[[:space:]]*=[[:space:]]*WhiteSur'
chkg "iconos WhiteSur" "$OVL/etc/skel/.config/gtk-3.0/settings.ini" 'gtk-icon-theme-name[[:space:]]*=[[:space:]]*WhiteSur'
chkg "fuente Inter" "$OVL/etc/skel/.config/gtk-3.0/settings.ini" 'gtk-font-name[[:space:]]*=[[:space:]]*Inter'
chkg "kitty fuente Inter" "$OVL/etc/skel/.config/kitty/kitty.conf" 'font_family Inter'
chkg "fontconfig prefiere Inter" "$OVL/etc/skel/.config/fontconfig/fonts.conf" '<family>Inter</family>'
chkg "grub pin whitesur (URL)" "$OVL/etc/nimbus/theming/grub-theme.src" 'grub-themes'
chkg "sddm pin auditado (URL)" "$OVL/etc/nimbus/theming/sddm-theme.src" 'echo-sddm'
if [ -f "$ROOT/nimbus-overlay/etc/sddm.conf.d/10-nimbus-theme.conf" ]; then
  bad "sddm: sin .conf activo (no romper base)"
else
  ok "sddm: sin .conf activo (solo .example)"
fi

# --- packages append + manifest ---------------------------------------------------
APP="$ROOT/packages.nimbus.x86_64.append"
MAN="$ROOT/iso.manifest"
[ -f "$APP" ] && ok "packages append existe" || bad "packages append existe"
[ -f "$MAN" ] && ok "iso.manifest existe" || bad "iso.manifest existe"
for p in hyprland quickshell hyprlock kitty inter-font whitesur-gtk-theme whitesur-icon-theme capitaine-cursors papirus-icon-theme; do
  chkg "append: $p" "$APP" "^${p}$"
done
chkg "manifest: pin MacShell + SHA" "$MAN" '0-ss/MacShell'
chkg "manifest: SHA 2026-10-23" "$MAN" 'bef9fc4'

# --- Sintaxis: hyprland --check-config si disponible ------------------------------
if command -v hyprland >/dev/null 2>&1; then
  if hyprland --check-config -c "$HYPR" >/dev/null 2>&1; then ok "hyprland --check-config"; else bad "hyprland --check-config"; fi
else
  skip "hyprland --check-config (hyprland no instalado en host)"
fi
chk "wrapper supera sh -n" sh -n "$WRAP"
if command -v luac >/dev/null 2>&1; then
  chk "macshell.lua supera luac -p" luac -p "$LUA"
elif command -v luac5.4 >/dev/null 2>&1; then
  chk "macshell.lua supera luac5.4 -p" luac5.4 -p "$LUA"
else
  skip "macshell.lua sintaxis (luac no instalado)"
fi

echo "-------------------------------------------------------------"
echo "RESULT: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
