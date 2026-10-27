#!/bin/bash
# NimbusOS Task 3 — scripts/verify-store.sh
# Verifica tienda pamac + USB plug&play + atajos (cero binds Ctrl).
# Uso: bash scripts/verify-store.sh [--root DIR]  (DIR por defecto: repo)
# Devuelve 0 si todo PASS; 1 si algun FAIL.
set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
if [ "${1:-}" = "--root" ]; then
  ROOT="${2:-}"
  [ -n "$ROOT" ] || { echo "Uso: $0 [--root DIR]" >&2; exit 2; }
fi
APP="$ROOT/packages.nimbus.x86_64.append"
HYPR="$ROOT/nimbus-overlay/etc/skel/.config/hypr/hyprland.conf"
SHORT="$ROOT/nimbus-overlay/etc/skel/.config/hypr/10-shortcuts.conf"
PAMC="$ROOT/nimbus-overlay/etc/pamac.conf.d/nimbus.conf"
HYPRDIR="$ROOT/nimbus-overlay/etc/skel/.config/hypr"
PASS=0; FAIL=0; SKIP=0
ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }
chk()  {
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi
}
chkg() {
  local d="$1" f="$2" re="$3"
  if grep -qE -- "$re" "$f" 2>/dev/null; then ok "$d"; else bad "$d"; fi
}

echo "== Task 3 verify: store pamac + USB plug&play + atajos =="

# --- Ficheros existen ----------------------------------------------------------
for f in "$APP" "$HYPR" "$SHORT" "$PAMC"; do
  [ -f "$f" ] && ok "existe: ${f#$ROOT/}" || bad "existe: ${f#$ROOT/}"
done

# --- Task1/Task2 intactos en el append (solo anadir, no borrar) -----------------
chkg "Task1 intacto (seccion Task 1)" "$APP" '--- Task 1'
chkg "Task2 intacto (seccion Task2 power)" "$APP" '--- Task2 power'
for p in hyprland quickshell hyprlock kitty inter-font whitesur-gtk-theme \
  whitesur-icon-theme capitaine-cursors auto-cpufreq thermald zram-generator \
  mpv vlc; do
  chkg "Task1/2 intacto: $p" "$APP" "^${p}$"
done
# Task5: nvidia-dkms fuera del append (lo aporta el pin upstream linux-cachyos-*-nvidia-open).
if grep -qx 'nvidia-dkms' "$APP" 2>/dev/null; then bad "Task5: sin nvidia-dkms duplicado (lo aporta upstream)"; else ok "Task5: sin nvidia-dkms duplicado (lo aporta upstream)"; fi

# --- Paquetes Task3 (brief, verbatim) --------------------------------------------
chkg "append seccion Task3" "$APP" '--- Task3 store\+USB'
# Task5: pamac-gtk / libpamac-flatpak-plugin NO existen en AUR (paquete real: pamac-aur).
for p in pamac-aur appstream archlinux-appstream-data \
  flatpak xdg-desktop-portal xdg-desktop-portal-hyprland base-devel git \
  polkit-gnome udisks2 udiskie gvfs gvfs-mtp ntfs-3g exfatprogs dosfstools \
  mtools nautilus hyprshell; do
  chkg "append: $p" "$APP" "^${p}$"
done
chkg "append nota base-devel metagrupo Task5 expande" "$APP" 'base-devel es metagrupo.*Task5.*expand|Task5.*expand.*base-devel|archiso lo expande'
chkg "append hyprshell URL H3rmt" "$APP" 'H3rmt/hyprshell'
chkg "append fallback cyclenext comentado" "$APP" 'cyclenext'
if grep -qE '^[[:space:]]*swaynotificationcenter[[:space:]]*$' "$APP" 2>/dev/null; then
  bad "append: swaynotificationcenter NO es default (debe ser solo comentario opcional)"
else
  ok "append: swaynotificationcenter NO es default (solo comentario opcional)"
fi
chkg "append swaynotificationcenter opcional comentado" "$APP" '#.*swaynotificationcenter'
chkg "append nota Flathub remote-add" "$APP" 'flatpak remote-add.*flathub'
chkg "append decision bauh descartado" "$APP" 'bauh'
chkg "append decision Discover sin AUR" "$APP" 'Discover'

# --- pamac.conf.d: flags Flatpak + AUR --------------------------------------------
chkg "pamac EnableFlatpak=true" "$PAMC" '^EnableFlatpak=true'
chkg "pamac EnableAUR=true" "$PAMC" '^EnableAUR=true'
chkg "pamac nota Task5 fusion /etc/pamac.conf" "$PAMC" 'pamac\.conf'

# --- hyprland.conf: import + 2 exec-once USB (polkit + udiskie; MacBar notifs) ---
chkg "hyprland importa 10-shortcuts.conf" "$HYPR" 'source[[:space:]]*=.*10-shortcuts\.conf'
chkg "exec-once polkit-gnome agent" "$HYPR" 'exec-once[[:space:]]*=[[:space:]]*/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1'
chkg "exec-once udiskie automount" "$HYPR" 'exec-once[[:space:]]*=[[:space:]]*udiskie --automount --notify --smart-tray'
chkg "hyprland nota MacBar daemon notifs + udiskie usa MacBar" "$HYPR" 'MacBar.*(daemon|Notifications)|udiskie --notify usa MacBar'
if grep -qE '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*swaynotificationcenter' "$HYPR" 2>/dev/null; then
  bad "hyprland SIN exec-once swaynotificationcenter (MacBar posee Notifications)"
else
  ok "hyprland SIN exec-once swaynotificationcenter (MacBar posee Notifications)"
fi
chkg "hyprland conserva exec-once macshell" "$HYPR" 'exec-once[[:space:]]*=[[:space:]]*macshell'
chkg "hyprland conserva ref Task1 comentada" "$HYPR" '10-shortcuts\.conf.*doble-disparo|canonica ACTIVA'

# --- 10-shortcuts.conf: launcher + switcher MacShell + fallback ----------------------
# RULING p2-final: ALT+TAB canonico = switcher MacShell (qs ipc, igual que la
# sesion Lua); hyprshell queda en el append sin bind (ver Ruling en el .conf).
chkg "shortcuts SUPER SPACE launcher" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*SPACE.*spotlight toggle'
chkg "shortcuts ALT TAB switcher MacShell (canonico p2-final)" "$SHORT" 'bind[[:space:]]*=[[:space:]]*ALT,[[:space:]]*TAB.*qs -c MacShell ipc call switcher next'
chkg "shortcuts URL hyprshell (Ruling: en append sin bind)" "$SHORT" 'H3rmt/hyprshell'
if grep -qE '^[[:space:]]*#[[:space:]]*bind[[:space:]]*=[[:space:]]*ALT,[[:space:]]*TAB,[[:space:]]*cyclenext' "$SHORT" 2>/dev/null; then
  ok "shortcuts fallback cyclenext comentado"
else
  bad "shortcuts fallback cyclenext comentado"
fi

# --- Cero binds CTRL (brief step 3, case-insensitive ctrl/CTRL) -----------------------
if grep -iE 'bind.*ctrl.*(C|V|X|Z|S|A|F|P)' "$HYPRDIR"/*.conf >/dev/null 2>&1; then
  bad "cero binds Ctrl (Ctrl+C/V/X/Z/S/A/F/P intactos)"
else
  ok "cero binds Ctrl (Ctrl+C/V/X/Z/S/A/F/P intactos)"
fi
# Refuerzo: ningun bind CTRL-* activo (sin comentar) en ningun .conf (case-insensitive).
if grep -hiE '^[[:space:]]*bind[^#=]*=[^#]*ctrl' "$HYPRDIR"/*.conf >/dev/null 2>&1; then
  bad "ningun bind CTRL-* activo en hypr/*.conf"
else
  ok "ningun bind CTRL-* activo en hypr/*.conf"
fi
chkg "SUPER SPACE presente (hypr/*.conf)" "$HYPRDIR/10-shortcuts.conf" 'SUPER, SPACE'
chkg "ALT TAB presente (hypr/*.conf)" "$HYPRDIR/10-shortcuts.conf" 'ALT, TAB'

# --- Task workflow-mac: Spaces/Mission Control/fullscreen sin Control ------------
chkg "spaces SUPER+1..9 workspace" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*[1-9],[[:space:]]*workspace,'
chkg "spaces SUPER+SHIFT+1..9 movetoworkspace" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER SHIFT,[[:space:]]*[1-9],[[:space:]]*movetoworkspace,'
chkg "spaces SUPER+LEFT/RIGHT workspace -1/+1" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*(LEFT|RIGHT),[[:space:]]*workspace,'
chkg "mission control SUPER+W switcher MacShell (fallback)" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*W,[[:space:]]*exec.*switcher'
chkg "boton verde SUPER+F fullscreen" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*F,[[:space:]]*fullscreen'
chkg "SUPER+SHIFT+F togglefloating" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER SHIFT,[[:space:]]*F,[[:space:]]*togglefloating'
if grep -hiE '^[[:space:]]*bind[^#=]*=[^#]*ctrl' "$SHORT" >/dev/null 2>&1; then
  bad "Task workflow-mac: cero CTRL en 10-shortcuts.conf (Control intacto)"
else
  ok "Task workflow-mac: cero CTRL en 10-shortcuts.conf (Control intacto)"
fi

# --- Unicidad: sin doble-disparo del toggle ----------------------------------------------
n_active="$(grep -cE '^[[:space:]]*bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*SPACE' "$HYPRDIR"/*.conf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')"
if [ "$n_active" -eq 1 ]; then ok "SUPER SPACE definido una sola vez (activo)"; else bad "SUPER SPACE definido una sola vez (activo): hay $n_active"; fi
n_alt="$(grep -cE '^[[:space:]]*bind[[:space:]]*=[[:space:]]*ALT,[[:space:]]*TAB' "$HYPRDIR"/*.conf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')"
if [ "$n_alt" -eq 1 ]; then ok "ALT TAB definido una sola vez (activo)"; else bad "ALT TAB definido una sola vez (activo): hay $n_alt"; fi

# --- Task menu-tienda: menú global D-Bus + tienda tematizada + Flathub -------
MT_GTK3="$ROOT/nimbus-overlay/etc/skel/.config/gtk-3.0/settings.ini"
MT_LIVE="$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup"
chkg "menu-tienda append: appmenu-gtk-module" "$APP" '^appmenu-gtk-module$'
chkg "menu-tienda hyprland env GTK_MODULES" "$HYPR" '^env *= *GTK_MODULES,appmenu-gtk-module'
chkg "menu-tienda pamac tema WhiteSur (gtk-3.0)" "$MT_GTK3" '^gtk-theme-name *= *WhiteSur'
chkg "menu-tienda live-setup flathub remote-add" "$MT_LIVE" 'flatpak remote-add --if-not-exists flathub'
chkg "menu-tienda ruling Qt skip documentado" "$APP" 'appmenu-qt5'

# --- Task ui-flows: flujos macOS (bloqueo, centro de control, OSD, hostname) --
UF_LOCK="$ROOT/nimbus-overlay/etc/skel/.config/quickshell/MacLock/lock-via-ipc.sh"
UF_HYPRLOCK="$ROOT/nimbus-overlay/etc/skel/.config/hypr/hyprlock.conf"
UF_LUA="$ROOT/nimbus-overlay/etc/skel/.config/hypr/hyprland.lua"
UF_HOST="$ROOT/nimbus-overlay/etc/hostname"
# Bloqueo: el bind SUPER+L (hyprland.conf + hyprland.lua) y MacBar.lockScreen
# llaman a MacLock/lock-via-ipc.sh; el skel solo vendorea MacShell, asi que el
# shim debe existir, ser ejecutable y delegar en hyprlock.
chk "ui-flows shim MacLock existe" test -f "$UF_LOCK"
chk "ui-flows shim MacLock ejecutable" test -x "$UF_LOCK"
chkg "ui-flows shim MacLock delega en hyprlock" "$UF_LOCK" 'exec hyprlock'
chkg "ui-flows hyprlock blur screenshot" "$UF_HYPRLOCK" 'path = screenshot'
chkg "ui-flows hyprlock hora grande" "$UF_HYPRLOCK" 'text = \$TIME'
chkg "ui-flows hyprlock input-field password" "$UF_HYPRLOCK" 'input-field'
# OSD/teclas hardware: XF86 -> ipc hardware de MacBar (su OSD interno pinta
# volumen/brillo; sin swayosd/avizo que duplicarian el popup).
for _k in "XF86AudioRaiseVolume.*hardware volumeUp" "XF86AudioLowerVolume.*hardware volumeDown" "XF86AudioMute.*hardware mute" "XF86MonBrightnessUp.*hardware brightnessUp" "XF86MonBrightnessDown.*hardware brightnessDown"; do
  chkg "ui-flows bind XF86 .conf: $_k" "$SHORT" "$_k"
  chkg "ui-flows bind XF86 lua: $_k" "$UF_LUA" "$_k"
done
if grep -qx 'swayosd' "$APP" 2>/dev/null || grep -qx 'avizo' "$APP" 2>/dev/null; then
  bad "ui-flows sin OSD externo (MacBar pinta su OSD)"
else
  ok "ui-flows sin OSD externo (MacBar pinta su OSD)"
fi
# Backends para que los controles ACTUEN (verificados pacman -Si 2026-10-26).
for _p in brightnessctl bluez bluez-utils; do
  chkg "ui-flows append: $_p" "$APP" "^${_p}$"
done
chkg "ui-flows append seccion ui-flows" "$APP" 'Task ui-flows'
chkg "ui-flows wifi sin paquete (nmcli upstream)" "$APP" 'nmcli via networkmanager upstream'
# Hostname live: el prompt era liveuser@CachyOS (airootfs/etc/hostname
# upstream); el overlay lo fija a nimbus. Prohibido etc/passwd (Task 5).
chkg "ui-flows hostname live nimbus" "$UF_HOST" '^nimbus$'
[ ! -e "$ROOT/nimbus-overlay/etc/passwd" ] && ok "ui-flows overlay sin etc/passwd" || bad "ui-flows overlay sin etc/passwd"

# --- Task menu-global: menu global REAL via D-Bus o Ruling (V1: Ruling) ------
MB_QML="$ROOT/nimbus-overlay/etc/skel/.config/quickshell/MacShell/MacBar.qml"
MT_README="$ROOT/nimbus-overlay/etc/nimbus/theming/README.md"
# Base exportadora intacta (Task menu-tienda): modulo + env.
chkg "menu-global base: modulo en append" "$APP" '^appmenu-gtk-module$'
chkg "menu-global base: GTK_MODULES en hyprland.conf" "$HYPR" '^env *= *GTK_MODULES,appmenu-gtk-module'
# MacBar V1: sin importer/registrador D-Bus (sin imports Quickshell.DBus/DBusMenu;
# el unico QsMenuOpener es el del system tray). Ruling: menu real no viable en V1.
if grep -qE 'Quickshell\.DBus|DBusMenu' "$MB_QML" 2>/dev/null; then
  bad "menu-global V1: MacBar sin importer D-Bus (Ruling: no viable en V1)"
else
  ok "menu-global V1: MacBar sin importer D-Bus (Ruling: no viable en V1)"
fi
# Sin atajos a ciegas en los menus: cero llamadas keys([...]) en menuModelFor.
_MG_BODY="$(awk '/function menuModelFor\(/,/return m;/' "$MB_QML" 2>/dev/null)"
if [ -z "$_MG_BODY" ]; then
  bad "menu-global: menuModelFor localizable en MacBar.qml"
elif echo "$_MG_BODY" | grep -qE 'keys\(\['; then
  bad "menu-global: menuModelFor sin atajos ciegos keys([...])"
else
  ok "menu-global: menuModelFor sin atajos ciegos keys([...])"
fi
# keys() se conserva solo para pasteSoon (automatizacion real del portapapeles).
chkg "menu-global keys() reservada a pasteSoon" "$MB_QML" 'pasteFn = appKind'
# Ruling documentada (README theming + comentario inline en menuModelFor).
chkg "menu-global Ruling en theming/README.md" "$MT_README" 'Ruling menu-global'
chkg "menu-global Ruling inline en MacBar.qml" "$MB_QML" 'Ruling menu-global'
# qmllint Qt6 al QML tocado (skip si ausente o si es el qmllint de Qt5,
# que no parsea QML Qt6/Quickshell y falla 255 en silencio).
if command -v qmllint >/dev/null 2>&1 && qmllint --version 2>/dev/null | grep -qE ' 6\.[0-9]'; then
  if (cd "$ROOT/nimbus-overlay/etc/skel/.config/quickshell/MacShell" && qmllint MacBar.qml >/dev/null 2>&1); then
    ok "menu-global qmllint MacBar.qml"
  else
    bad "menu-global qmllint MacBar.qml"
  fi
else
  skip "menu-global qmllint Qt6 (no instalado; el de Qt5 no vale)"
fi

# --- Sintaxis -------------------------------------------------------------------------------
chk "verify-store supera bash -n" bash -n "$ROOT/scripts/verify-store.sh"
if command -v hyprland >/dev/null 2>&1; then
  _tmpd="$(mktemp -d)"
  mkdir -p "$_tmpd/.config/hypr"
  cp "$ROOT/nimbus-overlay/etc/skel/.config/hypr/"*.conf "$_tmpd/.config/hypr/" 2>/dev/null || true
  if HOME="$_tmpd" hyprland --verify-config -c "$_tmpd/.config/hypr/hyprland.conf" >/dev/null 2>&1; then ok "live: hyprland --verify-config"; else bad "live: hyprland --verify-config"; fi
  rm -rf "$_tmpd"
else
  skip "hyprland --verify-config (hyprland no instalado en host)"
fi

echo "-------------------------------------------------------------"
echo "RESULT: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
