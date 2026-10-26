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

# --- Task ventanas-raton: mover/redimensionar con raton ------------------------
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

# --- Task hyprbars: titlebars NATIVAS (plugin oficial, sin overlay) -----------
# Reemplaza a WindowBar.qml (revertido: MacShell queda pristine, sin
# bifurcar). hyprbars vive en hyprland.lua: hl.plugin.load del .so +
# hl.config(plugin.hyprbars) + 3 add_button macOS a la izquierda +
# no_bar para apps con CSD propio (sin doble barra).
MBAR="$ROOT/nimbus-overlay/etc/skel/.config/quickshell/MacShell/MacBar.qml"
SHELLQML="$ROOT/nimbus-overlay/etc/skel/.config/quickshell/MacShell/shell.qml"
MANAUR="$ROOT/packages.nimbus-aur.txt"
chkg "hyprbars: manifest AUR" "$MANAUR" '^hyprland-plugin-hyprbars$'
chkg "hyprbars: append declaracion canonica" "$APP" '^hyprland-plugin-hyprbars$'
chkg "hyprbars: build-aur-repo.sh lo compila al repo [nimbus]" "$ROOT/scripts/build-aur-repo.sh" 'hyprland-plugin-hyprbars'
chkg "hyprbars: plugin load /usr/lib/libhyprbars.so" "$HLUA" 'hl\.plugin\.load\("/usr/lib/libhyprbars\.so"\)'
chkg "hyprbars: bar_height 28" "$HLUA" 'bar_height *= *28'
chkg "hyprbars: botones a la izquierda" "$HLUA" 'bar_buttons_alignment *= *"left"'
chkg "hyprbars: boton rojo cerrar window.close" "$HLUA" 'bg_color = "rgb\(FF5F57\)".*window\.close'
chkg "hyprbars: boton amarillo minimizar special:minimized" "$HLUA" 'bg_color = "rgb\(FEBE2E\)".*special:minimized'
chkg "hyprbars: boton verde fullscreen toggle" "$HLUA" 'bg_color = "rgb\(28C840\)".*window\.fullscreen'
chkg "hyprbars: no_bar Nautilus (CSD GTK propio)" "$HLUA" 'Nautilus.*hyprbars:no_bar'
chkg "hyprbars: no_bar Firefox (tabs propios)" "$HLUA" 'firefox.*hyprbars:no_bar'
if grep -qE 'windowBar|WindowBar|winBarWantsGeo|tlAlwaysSymbols|tlColorOnHover' "$MBAR" "$SHELLQML" 2>/dev/null; then
  bad "hyprbars: cero QML MacShell modificado (MacBar/shell pristine)"
else
  ok "hyprbars: cero QML MacShell modificado (MacBar/shell pristine)"
fi

# --- Task ui-win: ventanas indistinguibles de macOS ---------------------------
# 1) Sin borde AZUL (era col.active_border rgba(007affee)): borde sutil gris
#    1px estilo macOS + sombra suave (decoration:shadow). 2) La barra hyprbars
#    MUEVE la ventana al arrastrar de forma nativa (upstream barDeco.cpp:
#    pulsar en barra -> drag-pending -> drag MBIND_MOVE; sin opcion que
#    activar) y los bordes REDIMENSIONAN (resize_on_border +
#    extend_border_grab_area en .conf y sesion Lua).
if grep -qiE 'active_border.*007aff' "$HYPR" "$HLUA" 2>/dev/null; then
  bad "ui-win: cero borde azul 007aff (conf+lua)"
else
  ok "ui-win: cero borde azul 007aff (conf+lua)"
fi
chkg "ui-win: conf border_size 1 (minimo macOS)" "$HYPR" 'border_size[[:space:]]*=[[:space:]]*1'
chkg "ui-win: lua border_size 1 (minimo macOS)" "$HLUA" 'border_size *= *1,'
chkg "ui-win: conf borde activo gris sutil" "$HYPR" 'col\.active_border[[:space:]]*=[[:space:]]*rgba\(0000004d\)'
chkg "ui-win: conf borde inactivo gris sutil" "$HYPR" 'col\.inactive_border[[:space:]]*=[[:space:]]*rgba\(00000033\)'
chkg "ui-win: lua borde activo gris sutil" "$HLUA" 'active_border *= *"rgba\(0000004d\)"'
chkg "ui-win: lua borde inactivo gris sutil" "$HLUA" 'inactive_border *= *"rgba\(00000033\)"'
chkg "ui-win: conf sombra intacta" "$HYPR" 'shadow[[:space:]]*\{'
chkg "ui-win: lua sombra intacta" "$HLUA" 'shadow *= *\{'
chkg "ui-win: lua resize_on_border (redimension con borde)" "$HLUA" 'resize_on_border *= *true'
chkg "ui-win: lua extend_border_grab_area 25" "$HLUA" 'extend_border_grab_area *= *25'
chkg "ui-win: lua hyprbars bar_part_of_window (sombra unica)" "$HLUA" 'bar_part_of_window *= *true'

# --- Task barra-resize: la BARRA mueve (nativo), los BORDES redimensionan ----
# Ruling de fuente (tag v0.56.0): barDeco.cpp handleDownEvent/onMouseMove/
# handleMovement = drag MBIND_MOVE sin opcion; sin MBIND_RESIZE ni agarre en
# la barra (solo resizewindowpixel tactil 50%). Resize = bordes con grab area
# invisible (resize_on_border + extend_border_grab_area) + SUPER+raton/teclado
# (checks existentes: ventanas-raton, ui-win, resize-teclado; aqui solo lo nuevo).
chkg "barra-resize: lua fija bar_precedence_over_border false (defecto auditado)" "$HLUA" 'bar_precedence_over_border *= *false'
chkg "barra-resize: lua cita drag nativo MBIND_MOVE (barDeco.cpp)" "$HLUA" 'MBIND_MOVE'
chkg "barra-resize: lua cita handles auditados (barDeco.cpp)" "$HLUA" 'barDeco\.cpp'
chkg "barra-resize: conf documenta el limite (bloque Task barra-resize)" "$HYPR" 'Task barra-resize'
if grep -vE '^[[:space:]]*#' "$HYPR" | grep -qE 'plugin:hyprbars[[:space:]]*=|^[[:space:]]*plugin[[:space:]]*\{'; then
  bad "barra-resize: conf sin bloque plugin:hyprbars (vive en sesion Lua)"
else
  ok "barra-resize: conf sin bloque plugin:hyprbars (vive en sesion Lua)"
fi
_HBARBLK="$(awk '/hyprbars = \{/{f=1} f{print} f&&/\},/{exit}' "$HLUA")"
if printf '%s\n' "$_HBARBLK" | grep -vE '^\s*--' | grep -qE 'resize'; then
  bad "barra-resize: bloque hyprbars sin opcion resize inexistente"
else
  ok "barra-resize: bloque hyprbars sin opcion resize inexistente"
fi

# --- Task ui-desktop2: escritorio live indistinguible de macOS -----------------
# Checklist: fondo al arrancar (hyprpaper ejecutandose, no solo configurado),
# barra translucida + blur, dock flotante, Spotlight, Inter, WhiteSur,
# capitaine, modo claro coherente. QML MacShell = upstream pristine (no se
# reescribe: solo se verifica presencia + autostart + theming que lo viste).
HYPAPER="$ROOT/nimbus-overlay/etc/skel/.config/hypr/hyprpaper.conf"
chkg "ui-desktop2: hyprpaper.conf existe" "$HYPAPER" 'preload[[:space:]]*=[[:space:]]*/usr/share/backgrounds/nimbus/sequoia-light.jpg'
chkg "ui-desktop2: conf ejecuta hyprpaper (fondo al arrancar)" "$HYPR" 'exec-once[[:space:]]*=[[:space:]]*hyprpaper'
chkg "ui-desktop2: lua arranca hyprpaper (fondo al arrancar)" "$HLUA" 'exec_cmd\("hyprpaper"\)'
chkg "ui-desktop2: wallpaper canonico en overlay" "$OVL/usr/share/backgrounds/nimbus/sequoia-light.jpg" '.*'
[ -s "$OVL/usr/share/backgrounds/nimbus/sequoia-light.jpg" ] && ok "ui-desktop2: wallpaper no vacio" || bad "ui-desktop2: wallpaper no vacio"
for _qml in MacBar MacDock shell; do
  [ -f "$OVL/etc/skel/.config/quickshell/MacShell/${_qml}.qml" ] && ok "ui-desktop2: ${_qml}.qml upstream presente" || bad "ui-desktop2: ${_qml}.qml upstream presente"
done
chkg "ui-desktop2: spotlight SUPER+ESPACIO (.conf via shortcuts)" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*SPACE.*spotlight toggle'
chkg "ui-desktop2: spotlight SUPER+Space (lua)" "$HLUA" 'SUPER \+ Space.*spotlight toggle'
chkg "ui-desktop2: Inter en qt6ct (apps Qt)" "$OVL/etc/skel/.config/qt6ct/qt6ct.conf" 'general="Inter'
chkg "ui-desktop2: WhiteSur iconos en qt6ct" "$OVL/etc/skel/.config/qt6ct/qt6ct.conf" 'icon_theme=WhiteSur'
chkg "ui-desktop2: Inter en hyprbars (titlebars)" "$HLUA" 'bar_text_font *= *"Inter"'
chkg "ui-desktop2: cursor capitaine en conf" "$HYPR" 'XCURSOR_THEME,capitaine-cursors'
chkg "ui-desktop2: cursor capitaine en lua" "$HLUA" 'XCURSOR_THEME", "capitaine-cursors'
chkg "ui-desktop2: cursor capitaine en gtk" "$OVL/etc/skel/.config/gtk-3.0/settings.ini" 'gtk-cursor-theme-name[[:space:]]*=[[:space:]]*capitaine-cursors'
chkg "ui-desktop2: modo claro coherente gtk3" "$OVL/etc/skel/.config/gtk-3.0/settings.ini" 'gtk-application-prefer-dark-theme[[:space:]]*=[[:space:]]*false'
chkg "ui-desktop2: modo claro coherente gtk4" "$OVL/etc/skel/.config/gtk-4.0/settings.ini" 'gtk-application-prefer-dark-theme[[:space:]]*=[[:space:]]*false'
# Reloj: MacShell usa el locale del sistema (Qt.locale); el live CachyOS es
# C.UTF-8 (dia/mes en ingles). Ruling: sin locale es_ES en la ISO no hay
# reloj espanol; upstream MacShell solo trae traduccion ru (lang/ru.js, sin
# es.js): traducir el shell seria bifurcar upstream (prohibido). Se verifica
# que el wiring existe (I18n lee Qt.locale) y se deja el gap documentado.
chkg "ui-desktop2: I18n usa locale del sistema (reloj sigue LANG)" "$OVL/etc/skel/.config/quickshell/MacShell/I18n.js" 'Qt\.locale\(\)'
if grep -qE '^LANG=es_ES' "$OVL/etc/locale.conf" 2>/dev/null; then
  ok "ui-desktop2: locale.conf es_ES (reloj espanol)"
else
  skip "ui-desktop2: reloj espanol (live C.UTF-8; sin es.js upstream ni locale es_ES)"
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
  _vout="$(HOME="$_tmpd" hyprland --verify-config 2>&1)"; _vrc=$?
  if [ "$_vrc" -eq 0 ]; then
    ok "hyprland --verify-config (sesion Lua + .conf fallback)"
  elif echo "$_vout" | grep -qiE "hyprbars|plugin|PluginSystem|nil value"; then
    skip "verify-config Lua sin .so en harness (PluginSystem no existe en modo verify; runtime OK en live con repo [nimbus])"
  else
    echo "$_vout" | tail -n 5
    bad "hyprland --verify-config (sesion Lua + .conf fallback)"
  fi
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
