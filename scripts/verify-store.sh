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
  nvidia-dkms mpv vlc; do
  chkg "Task1/2 intacto: $p" "$APP" "^${p}$"
done

# --- Paquetes Task3 (brief, verbatim) --------------------------------------------
chkg "append seccion Task3" "$APP" '--- Task3 store\+USB'
for p in pamac-gtk libpamac-flatpak-plugin appstream archlinux-appstream-data \
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

# --- 10-shortcuts.conf: launcher + hyprshell + fallback -------------------------------
chkg "shortcuts SUPER SPACE launcher" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*SPACE.*spotlight toggle'
chkg "shortcuts ALT TAB hyprshell switch" "$SHORT" 'bind[[:space:]]*=[[:space:]]*ALT,[[:space:]]*TAB.*hyprshell switch'
chkg "shortcuts URL hyprshell" "$SHORT" 'H3rmt/hyprshell'
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

# --- Unicidad: sin doble-disparo del toggle ----------------------------------------------
n_active="$(grep -cE '^[[:space:]]*bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*SPACE' "$HYPRDIR"/*.conf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')"
if [ "$n_active" -eq 1 ]; then ok "SUPER SPACE definido una sola vez (activo)"; else bad "SUPER SPACE definido una sola vez (activo): hay $n_active"; fi
n_alt="$(grep -cE '^[[:space:]]*bind[[:space:]]*=[[:space:]]*ALT,[[:space:]]*TAB' "$HYPRDIR"/*.conf 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')"
if [ "$n_alt" -eq 1 ]; then ok "ALT TAB definido una sola vez (activo)"; else bad "ALT TAB definido una sola vez (activo): hay $n_alt"; fi

# --- Sintaxis -------------------------------------------------------------------------------
chk "verify-store supera bash -n" bash -n "$ROOT/scripts/verify-store.sh"
if command -v hyprland >/dev/null 2>&1; then
  chk "live: hyprland --check-config" hyprland --check-config -c "$HYPR"
else
  skip "hyprland --check-config (hyprland no instalado en host)"
fi

echo "-------------------------------------------------------------"
echo "RESULT: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
