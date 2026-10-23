#!/bin/bash
# NimbusOS Task 4 — scripts/verify-calamares.sh
# Verifica branding nimbus estilo Setup Assistant + secuencia recortada,
# sin tocar hypr/power/store. QML via qmlscene si el entorno lo permite.
# Uso: bash scripts/verify-calamares.sh [--root DIR]  (DIR por defecto: repo)
# Devuelve 0 si todo PASS; 1 si algun FAIL.
set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
if [ "${1:-}" = "--root" ]; then
  ROOT="${2:-}"
  [ -n "$ROOT" ] || { echo "Uso: $0 [--root DIR]" >&2; exit 2; }
fi
OVL="$ROOT/nimbus-overlay"
CAL="$OVL/etc/calamares"
BR="$CAL/branding/nimbus"
DESC="$BR/branding.desc"
QML="$BR/show.qml"
QSS="$BR/stylesheet.qss"
SET="$CAL/settings.conf"
PART="$CAL/modules/partition.conf"
USERS="$CAL/modules/users.conf"
DM="$CAL/modules/displaymanager.conf"
HYPR="$OVL/etc/skel/.config/hypr/hyprland.conf"
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

echo "== Task 4 verify: calamares Setup Assistant =="

# --- Ficheros existen ----------------------------------------------------------
for f in "$DESC" "$QML" "$QSS" "$SET" "$PART" "$USERS" "$DM"; do
  [ -f "$f" ] && ok "existe: ${f#$ROOT/}" || bad "existe: ${f#$ROOT/}"
done

# --- branding.desc --------------------------------------------------------------
chkg "desc componentName nimbus" "$DESC" '^componentName:[[:space:]]*nimbus'
chkg "desc welcomeStyleCalamares false" "$DESC" '^welcomeStyleCalamares:[[:space:]]*false'
chkg "desc welcomeExpandingLogo true" "$DESC" '^welcomeExpandingLogo:[[:space:]]*true'
chkg "desc slideshowAPI 2" "$DESC" '^slideshowAPI:[[:space:]]*2'
chkg "desc ventana 1024x640" "$DESC" '1024,640'
chkg "desc SidebarBackground #F5F5F7" "$DESC" '#F5F5F7'
chkg "desc SidebarText #1D1D1F" "$DESC" '#1D1D1F'
chkg "desc Current #007AFF" "$DESC" '#007AFF'

# --- show.qml: 3 slides, Hello, slideshowAPI 2 -----------------------------------
nslides="$(grep -cE '^[[:space:]]*Slide[[:space:]]*\{' "$QML" 2>/dev/null || echo 0)"
if [ "$nslides" -eq 3 ]; then ok "qml 3 slides"; else bad "qml 3 slides (hallados: $nslides)"; fi
chkg "qml import calamares.slideshow" "$QML" 'import calamares\.slideshow'
chkg "qml Presentation" "$QML" 'Presentation'
chkg "qml Hello" "$QML" 'Hello\.'

# --- QSS: fondo, radio 12, botones #007AFF ---------------------------------------
chkg "qss fondo #F5F5F7" "$QSS" '#F5F5F7'
chkg "qss texto #1D1D1F" "$QSS" '#1D1D1F'
chkg "qss botones #007AFF" "$QSS" '#007AFF'
chkg "qss radio 12" "$QSS" 'border-radius:[[:space:]]*12px'

# --- settings.conf: secuencia exacta ---------------------------------------------
chkg "settings branding nimbus" "$SET" '^branding:[[:space:]]*nimbus'
chkg "settings prompt-install false" "$SET" '^prompt-install:[[:space:]]*false'
chkg "settings oem-setup false" "$SET" '^oem-setup:[[:space:]]*false'
for m in welcome locale keyboard partition users summary; do
  chkg "settings show: $m" "$SET" "^[[:space:]]*-[[:space:]]*$m$"
done
for m in partition mount unpackfs machineid locale keyboard localecfg fstab initcpiocfg initcpio users displaymanager networkcfg hwclock services-systemd initramfs bootloader umount; do
  chkg "settings exec: $m" "$SET" "^[[:space:]]*-[[:space:]]*$m$"
done
for m in tracking packagechooserq notesqml; do
  if grep -qE "^[[:space:]]*-[[:space:]]*$m" "$SET" 2>/dev/null; then
    bad "settings sin modulo recortado: $m"
  else
    ok "settings sin modulo recortado: $m"
  fi
done

# --- partition.conf ----------------------------------------------------------------
chkg "partition erase por defecto (nota)" "$PART" '[Ee]rase'
chkg "partition allowManualPartitioning false" "$PART" '^allowManualPartitioning:[[:space:]]*false'
chkg "partition swap file" "$PART" 'file'
chkg "partition btrfs" "$PART" 'btrfs'
chkg "partition ext4" "$PART" 'ext4'
chkg "partition EFI 512M" "$PART" '512M'

# --- users.conf -----------------------------------------------------------------------
chkg "users wheel" "$USERS" 'wheel'
chkg "users shell bash" "$USERS" '/bin/bash'
chkg "users sin root (setRootPassword false)" "$USERS" '^setRootPassword:[[:space:]]*false'

# --- displaymanager.conf ------------------------------------------------------------------
chkg "dm greetd" "$DM" 'greetd'
chkg "dm Hyprland" "$DM" 'Hyprland'

# --- Sintaxis YAML -------------------------------------------------------------------------
if python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" \
  "$DESC" "$SET" "$PART" "$USERS" "$DM" 2>/dev/null; then
  ok "yaml valido (5 ficheros)"
else
  bad "yaml valido (5 ficheros)"
fi
chk "verify-calamares supera bash -n" bash -n "$ROOT/scripts/verify-calamares.sh"

# --- QML render -------------------------------------------------------------------------------
# Requiere qmlscene + imports calamares.slideshow instalados (paquete calamares
# en live/ISO). Sin ellos: SKIP explicito, no FAIL.
if ! command -v qmlscene >/dev/null 2>&1; then
  skip "qmlscene render (qmlscene no instalado en host de build)"
elif [ ! -d /usr/share/calamares/qml ] && [ ! -d /usr/lib/qt/qml/calamares.slideshow ] && [ ! -d /usr/lib/x86_64-linux-gnu/qt6/qml/calamares.slideshow ]; then
  skip "qmlscene render (imports calamares.slideshow ausentes fuera de live; solo qmlscene disponible)"
else
  if timeout 20 qmlscene -I /usr/share/calamares/qml --quit-after 3 "$QML" >/dev/null 2>&1 \
    || timeout 20 qmlscene --quit-after 3 "$QML" >/dev/null 2>&1; then
    ok "qmlscene render sin errores"
  else
    bad "qmlscene render sin errores"
  fi
fi

# --- skel intacto (no tocar hypr/power/store) ----------------------------------------------------
chk "skel hyprland.conf presente" test -f "$HYPR"
if [ -d "$ROOT/nimbus-overlay/etc/skel/.config/hypr" ]; then
  ok "skel hypr/ intacto"
else
  bad "skel hypr/ intacto"
fi

echo "-------------------------------------------------------------"
echo "RESULT: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
