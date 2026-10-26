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
HLUA="$ROOT/nimbus-overlay/etc/skel/.config/hypr/hyprland.lua"
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
# Hyprland >= 0.53: windowrulev2 -> window_rule / layerrule -> layer_rule.
chkg "flotante global window_rule" "$HYPR" 'window_rule[[:space:]]*=[[:space:]]*float,[[:space:]]*class:\^\(\.\*\)\$'
chkg "rounding 12-14px" "$HYPR" 'rounding[[:space:]]*=[[:space:]]*1[234]'
chkg "blur enabled" "$HYPR" 'blur[[:space:]]*\{'
chkg "blur Dual-Kawase (passes)" "$HYPR" 'passes[[:space:]]*=[[:space:]]*[0-9]+'
chkg "layer_rule blur macdock"  "$HYPR" 'layer_rule[[:space:]]*=[[:space:]]*blur,[[:space:]]*macdock'
chkg "layer_rule blur macspot"  "$HYPR" 'layer_rule[[:space:]]*=[[:space:]]*blur,[[:space:]]*macspot'
chkg "layer_rule blur macbarbg" "$HYPR" 'layer_rule[[:space:]]*=[[:space:]]*blur,[[:space:]]*macbarbg'
chkg "layer_rule ignorealpha presente" "$HYPR" 'layer_rule[[:space:]]*=[[:space:]]*ignorealpha'
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
# (Task sesion-lua: los binds viven en hyprland.lua; macshell.lua solo trae
# autostart + layer rules para no duplicar registros via dofile.)
chkg "lua: autostart hyprland.start" "$LUA" 'hyprland\.start'
chkg "lua: macshell-start" "$LUA" 'macshell-start'
chkg "lua: layer macdock/macspot/macbarbg" "$LUA" 'macdock.*macspot.*macbarbg|namespace = "macbarbg"'
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

# --- Task workflow-mac: centrado + Spaces + Mission Control + fullscreen ---------
SHORT="$ROOT/nimbus-overlay/etc/skel/.config/hypr/10-shortcuts.conf"
chkg "ventana centrada window_rule center" "$HYPR" 'window_rule[[:space:]]*=[[:space:]]*center,'
chkg "ventana tamano Mac window_rule size 1100 700" "$HYPR" 'window_rule[[:space:]]*=[[:space:]]*size 1100 700,'
for n in 1 2 3 4 5 6 7 8 9; do
  chkg "Spaces SUPER+$n workspace $n" "$SHORT" "bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*${n},[[:space:]]*workspace,[[:space:]]*${n}"
  chkg "Spaces SUPER+SHIFT+$n movetoworkspace $n" "$SHORT" "bind[[:space:]]*=[[:space:]]*SUPER SHIFT,[[:space:]]*${n},[[:space:]]*movetoworkspace,[[:space:]]*${n}"
done
chkg "Spaces anterior SUPER+LEFT" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*LEFT,[[:space:]]*workspace,[[:space:]]*-1'
chkg "Spaces siguiente SUPER+RIGHT" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*RIGHT,[[:space:]]*workspace,[[:space:]]*\+1'
chkg "Mission Control SUPER+W switcher MacShell (fallback sin overview)" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*W,[[:space:]]*exec.*switcher'
chkg "boton verde SUPER+F fullscreen" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*F,[[:space:]]*fullscreen'
chkg "SUPER+SHIFT+F togglefloating" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER SHIFT,[[:space:]]*F,[[:space:]]*togglefloating'
if grep -hiE '^[[:space:]]*bind[^#=]*=[^#]*ctrl' "$ROOT/nimbus-overlay/etc/skel/.config/hypr/"*.conf >/dev/null 2>&1; then
  bad "Task workflow-mac: cero CTRL en Spaces/Mission Control (Control intacto)"
else
  ok "Task workflow-mac: cero CTRL en Spaces/Mission Control (Control intacto)"
fi

# --- Task ventanas-raton: mover/redimensionar con raton + semaforos ------------
chkg "ventanas-raton: resize_on_border" "$HYPR" 'resize_on_border[[:space:]]*=[[:space:]]*true'
chkg "ventanas-raton: extend_border_grab_area 25" "$HYPR" 'extend_border_grab_area[[:space:]]*=[[:space:]]*25'
chkg "ventanas-raton: bloque snap" "$HYPR" 'snap[[:space:]]*\{'
_SNAPBLK="$(awk '/snap *\{/{f=1} f{print} f&&/\}/{exit}' "$HYPR")"
if printf '%s\n' "$_SNAPBLK" | grep -qE 'enabled[[:space:]]*=[[:space:]]*true'; then
  ok "ventanas-raton: snap enabled"
else
  bad "ventanas-raton: snap enabled"
fi
if printf '%s\n' "$_SNAPBLK" | grep -qE 'window_gap[[:space:]]*=[[:space:]]*10'; then
  ok "ventanas-raton: snap window_gap 10"
else
  bad "ventanas-raton: snap window_gap 10"
fi
if printf '%s\n' "$_SNAPBLK" | grep -qE 'monitor_gap[[:space:]]*=[[:space:]]*10'; then
  ok "ventanas-raton: snap monitor_gap 10"
else
  bad "ventanas-raton: snap monitor_gap 10"
fi
chkg "ventanas-raton: bindm SUPER mouse:272 movewindow" "$SHORT" 'bindm[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*mouse:272,[[:space:]]*movewindow'
chkg "ventanas-raton: bindm SUPER mouse:273 resizewindow" "$SHORT" 'bindm[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*mouse:273,[[:space:]]*resizewindow'
WINBAR="$ROOT/nimbus-overlay/etc/skel/.config/quickshell/MacShell/WindowBar.qml"
[ -f "$WINBAR" ] && ok "ventanas-raton: WindowBar.qml existe" || bad "ventanas-raton: WindowBar.qml existe"
chkg "ventanas-raton: WindowBar activo por defecto" "$WINBAR" 'readonly property bool enabled: bar \? bar\.windowBar : true'
if grep -rn 'windowBar' "$OVL" 2>/dev/null | grep -vE 'bar\.windowBar(Title)? : true' | grep -q .; then
  bad "ventanas-raton: nada en overlay desactiva windowBar"
else
  ok "ventanas-raton: nada en overlay desactiva windowBar"
fi

# --- Task resize-teclado: redimensionar con teclado (SUPER+SHIFT+flechas) ------
chkg "resize-teclado: SUPER+SHIFT+LEFT resizeactive -40" "$SHORT" 'binde?[[:space:]]*=[[:space:]]*SUPER SHIFT,[[:space:]]*LEFT,[[:space:]]*resizeactive,[[:space:]]*-40 0'
chkg "resize-teclado: SUPER+SHIFT+RIGHT resizeactive +40" "$SHORT" 'binde?[[:space:]]*=[[:space:]]*SUPER SHIFT,[[:space:]]*RIGHT,[[:space:]]*resizeactive,[[:space:]]*40 0'
chkg "resize-teclado: SUPER+SHIFT+UP resizeactive -40" "$SHORT" 'binde?[[:space:]]*=[[:space:]]*SUPER SHIFT,[[:space:]]*UP,[[:space:]]*resizeactive,[[:space:]]*0 -40'
chkg "resize-teclado: SUPER+SHIFT+DOWN resizeactive +40" "$SHORT" 'binde?[[:space:]]*=[[:space:]]*SUPER SHIFT,[[:space:]]*DOWN,[[:space:]]*resizeactive,[[:space:]]*0 40'
chkg "resize-teclado: lua SUPER+SHIFT+left relative" "$HLUA" 'SUPER \+ SHIFT \+ left.*window\.resize.*x = -40.*relative = true'
chkg "resize-teclado: lua SUPER+SHIFT+right relative" "$HLUA" 'SUPER \+ SHIFT \+ right.*window\.resize.*x = 40.*relative = true'
chkg "resize-teclado: lua SUPER+SHIFT+up relative" "$HLUA" 'SUPER \+ SHIFT \+ up.*window\.resize.*y = -40.*relative = true'
chkg "resize-teclado: lua SUPER+SHIFT+down relative" "$HLUA" 'SUPER \+ SHIFT \+ down.*window\.resize.*y = 40.*relative = true'
chkg "resize-teclado: lua bindm mouse drag { mouse = true }" "$HLUA" 'mouse:272.*window\.drag.*mouse = true'
chkg "resize-teclado: lua bindm mouse resize { mouse = true }" "$HLUA" 'mouse:273.*window\.resize.*mouse = true'

# --- Task sesion-lua: hyprland.lua canonico, sin binds duplicados --------------
[ -f "$HLUA" ] && ok "hyprland.lua existe" || bad "hyprland.lua existe"
chkg "lua: SUPER+Space toggle" "$HLUA" 'SUPER \+ Space.*spotlight toggle'
chkg "lua: SUPER+V clipboard" "$HLUA" 'SUPER \+ V.*spotlight clipboard'
chkg "lua: ALT+TAB switcher MacShell (qs ipc, no hyprshell)" "$HLUA" 'ALT \+ TAB.*switcher next'
if grep -vE '^\s*--' "$HLUA" | grep -q 'hyprshell'; then bad "lua: sin hyprshell en sesion Lua"; else ok "lua: sin hyprshell en sesion Lua"; fi
chkg "lua: SUPER+W switcher (Mission Control fallback)" "$HLUA" 'SUPER \+ W.*switcher'
chkg "lua: SUPER+L lock" "$HLUA" 'SUPER \+ L.*lock-via-ipc'
chkg "lua: SUPER+Q close" "$HLUA" 'SUPER \+ Q.*window\.close'
chkg "lua: SUPER+T kitty" "$HLUA" 'SUPER \+ T.*kitty'
chkg "lua: PRINT screenshot" "$HLUA" 'PRINT.*screenshot region'
chkg "lua: Spaces SUPER+1 workspace" "$HLUA" 'focus\(\{ workspace = i \}\)'
chkg "lua: SUPER+SHIFT+F togglefloating" "$HLUA" 'window\.float\({ action = "toggle" }\)'
chkg "lua: bindm drag mouse:272" "$HLUA" 'mouse:272.*window\.drag'
chkg "lua: bindm resize mouse:273" "$HLUA" 'mouse:273.*window\.resize'
chkg "lua: gesto 3 dedos horizontal workspace" "$HLUA" 'hl\.gesture.*fingers = 3.*direction = "horizontal".*action = "workspace"'
chkg "lua: ventana flotante global" "$HLUA" 'window_rule.*float *= *true'
chkg "lua: ventana centrada" "$HLUA" 'window_rule.*center *= *true'
chkg "lua: ventana tamano 1100x700" "$HLUA" 'window_rule.*size *= *"1100 700"'
chkg "lua: dofile macshell.lua al final" "$HLUA" 'dofile\(os\.getenv\("HOME"\) \.\. "/\.config/hypr/macshell\.lua"\)'
if grep -qE 'hl\.bind\(' "$LUA"; then
  bad "lua: macshell.lua sin binds (todos viven en hyprland.lua, sin duplicar)"
else
  ok "lua: macshell.lua sin binds (todos viven en hyprland.lua, sin duplicar)"
fi
if grep -qE 'CTRL \+' "$HLUA"; then bad "lua: sin binds CTRL"; else ok "lua: sin binds CTRL"; fi
if command -v luac >/dev/null 2>&1; then
  chk "hyprland.lua supera luac -p" luac -p "$HLUA"
elif command -v luac5.4 >/dev/null 2>&1; then
  chk "hyprland.lua supera luac5.4 -p" luac5.4 -p "$HLUA"
else
  skip "hyprland.lua sintaxis (luac no instalado)"
fi
# Precedencia: con .lua + .conf presentes, Hyprland 0.56 usa el .lua.
if command -v hyprland >/dev/null 2>&1; then
  _tmpd="$(mktemp -d)"
  mkdir -p "$_tmpd/.config/hypr"
  cp "$ROOT/nimbus-overlay/etc/skel/.config/hypr/"*.conf "$_tmpd/.config/hypr/" 2>/dev/null || true
  cp "$ROOT/nimbus-overlay/etc/skel/.config/hypr/"*.lua "$_tmpd/.config/hypr/" 2>/dev/null || true
  if HOME="$_tmpd" hyprland --verify-config 2>&1 | grep -q "Using lua config"; then
    ok "hyprland.lua tiene precedencia sobre .conf (ambos presentes)"
  else
    bad "hyprland.lua tiene precedencia sobre .conf (ambos presentes)"
  fi
  if HOME="$_tmpd" hyprland --verify-config >/dev/null 2>&1; then ok "hyprland --verify-config (sesion Lua + .conf fallback)"; else bad "hyprland --verify-config (sesion Lua + .conf fallback)"; fi
  rm -rf "$_tmpd"
else
  skip "hyprland --verify-config sesion Lua (hyprland no instalado en host)"
fi

# --- Sintaxis: hyprland --verify-config si disponible --------------------------
# Hyprland 0.56: --check-config no existe, es --verify-config. El source=
# usa ~, asi que se fusiona en un HOME temporal para no dar falso globbing.
if command -v hyprland >/dev/null 2>&1; then
  _tmpd="$(mktemp -d)"
  mkdir -p "$_tmpd/.config/hypr"
  cp "$ROOT/nimbus-overlay/etc/skel/.config/hypr/"*.conf "$_tmpd/.config/hypr/" 2>/dev/null || true
  if HOME="$_tmpd" hyprland --verify-config -c "$_tmpd/.config/hypr/hyprland.conf" >/dev/null 2>&1; then ok "hyprland --verify-config"; else bad "hyprland --verify-config"; fi
  rm -rf "$_tmpd"
else
  skip "hyprland --verify-config (hyprland no instalado en host)"
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
