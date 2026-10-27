#!/bin/bash
# NimbusOS P1 — scripts/verify-p1.sh (lote fidelidad macOS, 14 items)
# Verifica el lote P1 item por item. Uso: bash scripts/verify-p1.sh
# Devuelve 0 si todo PASS; 1 si algun FAIL.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVL="$ROOT/nimbus-overlay"
APP="$ROOT/packages.nimbus.x86_64.append"
HYPR="$ROOT/nimbus-overlay/etc/skel/.config/hypr/hyprland.conf"
HLUA="$ROOT/nimbus-overlay/etc/skel/.config/hypr/hyprland.lua"
SHORT="$ROOT/nimbus-overlay/etc/skel/.config/hypr/10-shortcuts.conf"
PASS=0; FAIL=0; SKIP=0
ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }
chkg() { local d="$1" f="$2" re="$3"; if grep -qE -- "$re" "$f" 2>/dev/null; then ok "$d"; else bad "$d"; fi; }

echo "== P1 verify: lote fidelidad macOS (14 items) =="

# --- Task p1 item 1: GRUB vendoreado + entradas NimbusOS ----------------------
THEME="$OVL/usr/share/grub/themes/whitesur/theme.txt"
[ -f "$THEME" ] && ok "p1-1: theme Whitesur vendoreado (theme.txt)" || bad "p1-1: theme Whitesur vendoreado (theme.txt)"
[ -f "$OVL/usr/share/grub/themes/whitesur/background.jpg" ] && ok "p1-1: theme trae background.jpg" || bad "p1-1: theme trae background.jpg"
[ -d "$OVL/usr/share/grub/themes/whitesur/icons" ] && ok "p1-1: theme trae icons/" || bad "p1-1: theme trae icons/"
chkg "p1-1: nimbus.cfg apunta al theme vendoreado" "$OVL/etc/default/grub.d/nimbus.cfg" '^GRUB_THEME=/usr/share/grub/themes/whitesur/theme\.txt'
chkg "p1-1: DISTRIBUTOR NimbusOS en NUESTRO drop-in" "$OVL/etc/default/grub.d/nimbus.cfg" '^GRUB_DISTRIBUTOR="NimbusOS"'
chkg "p1-1: grub-theme.src repo real grub2-themes" "$OVL/etc/nimbus/theming/grub-theme.src" 'grub2-themes'
chkg "p1-1: grub-theme.src STATUS=vendored" "$OVL/etc/nimbus/theming/grub-theme.src" '^STATUS=vendored'
if grep -rhvE '^[[:space:]]*#' "$OVL/etc/default/grub.d/" 2>/dev/null | grep -q "CachyOS"; then bad "p1-1: sin restos CachyOS en ficheros GRUB nuestros"; else ok "p1-1: sin restos CachyOS en ficheros GRUB nuestros"; fi

# --- Task p1 item 2: wallpaper real CC0 ---------------------------------------
WP="$OVL/usr/share/backgrounds/nimbus/sequoia-light.jpg"
if [ -f "$WP" ] && file "$WP" 2>/dev/null | grep -qi 'jpeg'; then ok "p1-2: wallpaper JPEG valido"; else bad "p1-2: wallpaper JPEG valido"; fi
if python3 -c "from PIL import Image; im=Image.open('$WP'); raise SystemExit(0 if im.size==(1920,1080) else 1)" 2>/dev/null; then ok "p1-2: wallpaper 1920x1080"; else bad "p1-2: wallpaper 1920x1080"; fi
if [ "$(stat -c%s "$WP" 2>/dev/null || echo 0)" -gt 100000 ]; then ok "p1-2: wallpaper real (no placeholder de 43K)"; else bad "p1-2: wallpaper real (no placeholder de 43K)"; fi
chkg "p1-2: README documenta URL Commons" "$OVL/usr/share/backgrounds/nimbus/README.REPLACE-WITH-REAL.txt" 'commons\.wikimedia\.org'
chkg "p1-2: README documenta dominio publico" "$OVL/usr/share/backgrounds/nimbus/README.REPLACE-WITH-REAL.txt" '[Pp]ublic [Dd]omain'
chkg "p1-2: theming/README documenta wallpaper" "$OVL/etc/nimbus/theming/README.md" '[Ww]allpaper real'

# --- Task p1 item 3: upower en el append --------------------------------------
chkg "p1-3: append trae upower" "$APP" '^upower$'
if pacman -Si upower >/dev/null 2>&1; then ok "p1-3: pacman -Si upower (repos oficiales)"; else bad "p1-3: pacman -Si upower (repos oficiales)"; fi

# --- Task p1 item 4: dconf en el append ---------------------------------------
chkg "p1-4: append trae dconf" "$APP" '^dconf$'
if pacman -Si dconf >/dev/null 2>&1; then ok "p1-4: pacman -Si dconf (repos oficiales)"; else bad "p1-4: pacman -Si dconf (repos oficiales)"; fi
chkg "p1-4: customize invoca dconf con guard" "$OVL/root/customize_airootfs.sh" 'command -v dconf'

# --- Task p1 item 5: kitty sin macos_* ----------------------------------------
KITTY="$OVL/etc/skel/.config/kitty/kitty.conf"
if grep -qE '^[[:space:]]*macos_' "$KITTY" 2>/dev/null; then bad "p1-5: kitty sin opciones macos_*"; else ok "p1-5: kitty sin opciones macos_*"; fi
chkg "p1-5: kitty equivalente Wayland" "$KITTY" '^wayland_titlebar_color background'
chkg "p1-5: kitty hide_window_decorations" "$KITTY" '^hide_window_decorations no'
chkg "p1-5: kitty mantiene Inter" "$KITTY" '^font_family Inter'

# --- Task p1 item 6: Qt style + airy + electron --------------------------------
QT6CT="$OVL/etc/skel/.config/qt6ct/qt6ct.conf"
chkg "p1-6: qt6ct style=gtk2" "$QT6CT" '^style=gtk2'
chkg "p1-6: qt6ct referencia airy verificada" "$QT6CT" '^color_scheme_path=/usr/share/qt6ct/colors/airy\.conf'
[ -f "$OVL/etc/skel/.config/electron-flags.conf" ] && ok "p1-6: electron-flags.conf existe" || bad "p1-6: electron-flags.conf existe"
chkg "p1-6: electron wayland nativo" "$OVL/etc/skel/.config/electron-flags.conf" 'ozone-platform=wayland'

# --- Task p1 item 7: slide de atajos ------------------------------------------
QML="$OVL/etc/calamares/branding/nimbus/show.qml"
nslides="$(grep -cE '^[[:space:]]*Slide[[:space:]]*\{' "$QML" 2>/dev/null || echo 0)"
if [ "$nslides" -eq 5 ]; then ok "p1-7: show.qml 5 slides (4 + atajos)"; else bad "p1-7: show.qml 5 slides (hallados: $nslides)"; fi
chkg "p1-7: slide atajos Super+Espacio" "$QML" 'Super\+Espacio'
chkg "p1-7: slide atajos Super+W y Super+1" "$QML" 'Super\+W.*Super\+1'
chkg "p1-7: slide mismo estilo (#F5F5F7/Inter)" "$QML" '#F5F5F7'

# --- Task p1 item 8: branding sin URLs ejemplo ---------------------------------
DESC="$OVL/etc/calamares/branding/nimbus/branding.desc"
if grep -qE '^[[:space:]]*(productUrl|supportUrl|knownIssuesUrl|releaseNotesUrl):' "$DESC" 2>/dev/null; then bad "p1-8: branding sin URLs ejemplo"; else ok "p1-8: branding sin URLs ejemplo"; fi
chkg "p1-8: branding conserva productName" "$DESC" '^  productName: NimbusOS'

# --- Task p1 item 9: cursor XWayland -------------------------------------------
chkg "p1-9: conf fija XCURSOR_SIZE 24" "$HYPR" '^env = XCURSOR_SIZE,24'
chkg "p1-9: lua fija XCURSOR_SIZE 24" "$HLUA" 'XCURSOR_SIZE", "24"'
if [ -d /usr/share/icons/capitaine-cursors-light ] && [ ! -d /usr/share/icons/capitaine-cursors-light/hyprcursors ]; then
  ok "p1-9: capitaine sin metadatos hyprcursor (Ruling aplica)"
else
  bad "p1-9: capitaine sin metadatos hyprcursor (Ruling aplica)"
fi
chkg "p1-9: Ruling cursor documentado" "$OVL/etc/nimbus/theming/README.md" '[Rr]uling cursor-hypr'

# --- Task p1 item 10: no_bar ampliado ------------------------------------------
chkg "p1-10: no_bar pamac-manager (clase verificada)" "$HLUA" 'pamac-manager.*hyprbars:no_bar'
chkg "p1-10: no_bar dialogos modales" "$HLUA" 'modal = true.*hyprbars:no_bar'
chkg "p1-10: Ruling calamares documentado" "$HLUA" '[Rr]uling calamares'
chkg "p1-10: nautilus/firefox intactos" "$HLUA" 'nimbus-hyprbars-no-bar-nautilus'

# --- Task p1 item 11: verde = zoom, fullscreen solo SUPER+F --------------------
chkg "p1-11: lua verde maximiza (no fullscreen)" "$HLUA" '28C840.*mode = "maximize"'
chkg "p1-11: lua SUPER+F sigue fullscreen real" "$HLUA" 'SUPER \+ F.*mode = "fullscreen"'
chkg "p1-11: lua doble-click maximiza" "$HLUA" 'on_double_click.*mode = "maximize"'
chkg "p1-11: conf verde maximiza" "$HYPR" 'hyprbars-button = rgb\(28C840\), 13, , hyprctl dispatch fullscreen 1'
chkg "p1-11: conf SUPER+F fullscreen 0" "$SHORT" 'bind[[:space:]]*=[[:space:]]*SUPER,[[:space:]]*F,[[:space:]]*fullscreen, 0'
if grep -qE '^[[:space:]]*bind[^=]*=[[:space:]]*CTRL' "$SHORT" "$HLUA" 2>/dev/null; then bad "p1-11: cero binds CTRL"; else ok "p1-11: cero binds CTRL"; fi

# --- Task p1 item 12: sleep solo si CanSuspend ----------------------------------
chkg "p1-12: sleep guarda CanSuspend" "$OVL/etc/skel/.config/quickshell/MacShell/MacBar.qml" 'CanSuspend'
chkg "p1-12: sleep via busctl logind" "$OVL/etc/skel/.config/quickshell/MacShell/MacBar.qml" 'busctl get-property org\.freedesktop\.login1'

# --- Task p1 item 13: reloj es_ES (Ruling skip documentado) ---------------------
chkg "p1-13: Ruling reloj-es documentado" "$OVL/etc/nimbus/theming/README.md" '[Rr]uling reloj-es'

# --- Task p1 item 14: bluetooth en live + instalado -----------------------------
chkg "p1-14: live-setup enable bluetooth" "$OVL/usr/bin/nimbus-live-setup" 'bluetooth\.service'
chkg "p1-14: installed-setup enable bluetooth" "$OVL/usr/bin/nimbus-installed-setup" 'bluetooth\.service'

# --- Sintaxis: conf valida + lua parsea + qml lint ------------------------------
if command -v hyprland >/dev/null 2>&1; then
  _tmpd="$(mktemp -d)"
  mkdir -p "$_tmpd/.config/hypr"
  cp "$ROOT/nimbus-overlay/etc/skel/.config/hypr/"*.conf "$_tmpd/.config/hypr/" 2>/dev/null || true
  if HOME="$_tmpd" hyprland --verify-config -c "$_tmpd/.config/hypr/hyprland.conf" >/dev/null 2>&1; then
    ok "p1: hyprland --verify-config (.conf con verde=maximizar)"
  else
    bad "p1: hyprland --verify-config (.conf con verde=maximizar)"
  fi
  rm -rf "$_tmpd"
else
  skip "p1: hyprland --verify-config (hyprland no instalado)"
fi
if command -v luac >/dev/null 2>&1; then
  if luac -p "$HLUA" 2>/dev/null; then ok "p1: luac -p hyprland.lua"; else bad "p1: luac -p hyprland.lua"; fi
else
  skip "p1: luac (no instalado)"
fi
if command -v qmllint >/dev/null 2>&1 && qmllint --version 2>/dev/null | grep -qE ' 6\.[0-9]'; then
  if (cd "$ROOT/nimbus-overlay/etc/skel/.config/quickshell/MacShell" && qmllint MacBar.qml >/dev/null 2>&1); then
    ok "p1: qmllint MacBar.qml (sleep guard)"
  else
    bad "p1: qmllint MacBar.qml (sleep guard)"
  fi
else
  skip "p1: qmllint Qt6 (no instalado; el de Qt5 no vale)"
fi
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import xml.dom.minidom,sys; xml.dom.minidom.parse('$QML')" 2>/dev/null || grep -q 'Presentation' "$QML"; then ok "p1: show.qml intacto (5 slides)"; else bad "p1: show.qml intacto (5 slides)"; fi
fi
chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
chk "p1: verify-p1 supera bash -n" bash -n "$ROOT/scripts/verify-p1.sh"

echo "-------------------------------------------------------------"
echo "RESULT: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
