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
chkg "desc sidebar explicito" "$DESC" '^sidebar:[[:space:]]*(widget|none)'
chkg "desc navigation explicito" "$DESC" '^navigation:[[:space:]]*(widget|none)'

# --- branding assets: existen en el overlay --------------------------------------
for img in nimbus-logo.svg productWelcome.svg; do
  [ -f "$BR/$img" ] && ok "branding asset presente: $img" || bad "branding asset presente: $img"
done
if grep -qE '\.png' "$DESC" 2>/dev/null; then
  bad "desc sin referencias PNG inexistentes"
else
  ok "desc sin referencias PNG inexistentes"
fi

# --- show.qml: 5 slides (P1 anade slide de atajos), Hello, slideshowAPI 2 -----
nslides="$(grep -cE '^[[:space:]]*Slide[[:space:]]*\{' "$QML" 2>/dev/null || echo 0)"
if [ "$nslides" -eq 5 ]; then ok "qml 5 slides (4 + atajos P1)"; else bad "qml 5 slides (hallados: $nslides)"; fi
chkg "qml import calamares.slideshow" "$QML" 'import calamares\.slideshow'
chkg "qml Presentation" "$QML" 'Presentation'
chkg "qml Hello" "$QML" 'Hello\.'
chkg "qml slide Spaces/Spotlight" "$QML" 'Spaces'

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
chkg "partition initialPartitioningChoice erase" "$PART" '^initialPartitioningChoice:[[:space:]]*erase'
chkg "partition allowManualPartitioning false" "$PART" '^allowManualPartitioning:[[:space:]]*false'
chkg "partition swap file" "$PART" 'file'
chkg "partition btrfs" "$PART" 'btrfs'
chkg "partition ext4" "$PART" 'ext4'
chkg "partition EFI 512MiB" "$PART" '512Mi?B'

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

# --- Task ui-flows: Hello primero + erase por defecto (flujo Setup Assistant --
# El slideshow debe ABRIR con "Hello." (no basta con que exista en algun slide).
_first_hello="$(awk '/^[[:space:]]*Slide[[:space:]]*\{/{n++} /Hello\./{if(!f){f=n} } END{print f+0}' "$QML" 2>/dev/null)"
if [ "${_first_hello:-0}" = "1" ]; then ok "ui-flows Hello es el primer slide"; else bad "ui-flows Hello es el primer slide (esta en slide ${_first_hello:-?})"; fi

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

# --- customize_airootfs.sh: piel total (plan workflow-mac-piel-total Task 3) ------------
# Los 4 ficheros de piel de Task 2 deben instalarse via install -Dm644 con
# guards [ -f ] (idempotente, set -u safe; no falla si Task 2 aun no los trae).
CUST="$OVL/root/customize_airootfs.sh"
chk "customize presente" test -f "$CUST"
chk "customize supera bash -n" bash -n "$CUST"
for _skin in "etc/skel/.config/hypr/hyprlock.conf" \
             "etc/skel/.config/qt6ct/qt6ct.conf" \
             "etc/dconf/db/local.d/nimbus" \
             "etc/default/grub.d/nimbus.cfg"; do
  chkg "customize instala piel: $_skin" "$CUST" "$_skin"
done
chkg "customize install -Dm644 piel" "$CUST" 'install -Dm644'
chkg "customize guards [ -f ]" "$CUST" '\[ -f '

# --- Task instalado-p0: el INSTALADO funciona igual que el live -----------------
# 1) greetd con el usuario REAL (nunca liveuser hardcodeado): %post via
#    instancia shellprocess@nimbus_installed (dontChroot: false = en target),
#    declarada en instances: y secuenciada tras displaymanager (el usuario ya
#    existe: users corre antes). Patron auditado contra upstream
#    CachyOS/cachyos-calamares@cachyos (settings.conf: bloque `instances:`
#    id->config + secuencia `shellprocess@id`).
NIS="$OVL/usr/bin/nimbus-installed-setup"
NISC="$CAL/modules/shellprocess_nimbus_installed.conf"
chk "instalado-p0 nimbus-installed-setup existe" test -f "$NIS"
chk "instalado-p0 nimbus-installed-setup ejecutable" test -x "$NIS"
chk "instalado-p0 nimbus-installed-setup bash -n" bash -n "$NIS"
chk "instalado-p0 shellprocess_nimbus_installed.conf existe" test -f "$NISC"
if python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" \
  "$SET" "$NISC" 2>/dev/null; then ok "instalado-p0 yaml valido (settings + instancia)"; else bad "instalado-p0 yaml valido (settings + instancia)"; fi
chkg "instalado-p0 instancia dontChroot false (corre en target)" "$NISC" '^dontChroot:[[:space:]]*false'
chkg "instalado-p0 instancia invoca nimbus-installed-setup" "$NISC" 'nimbus-installed-setup'
chkg "instalado-p0 instancia recibe \${USER} de Calamares" "$NISC" '\$\{USER\}'
chkg "instalado-p0 settings declara instancia nimbus_installed" "$SET" 'shellprocess_nimbus_installed\.conf'
chkg "instalado-p0 settings id nimbus_installed -> shellprocess" "$SET" 'id:[[:space:]]*nimbus_installed'
chkg "instalado-p0 settings exec shellprocess@nimbus_installed" "$SET" '^[[:space:]]*-[[:space:]]*shellprocess@nimbus_installed$'
# Orden exec: users < displaymanager < shellprocess@nimbus_installed
_order_ok="$(awk '/^[[:space:]]*-[[:space:]]*users$/{u=NR} /^[[:space:]]*-[[:space:]]*displaymanager$/{d=NR} /^[[:space:]]*-[[:space:]]*shellprocess@nimbus_installed$/{s=NR} END{print (u>0 && d>u && s>d) ? "si" : "no"}' "$SET")"
if [ "$_order_ok" = "si" ]; then ok "instalado-p0 orden exec users<displaymanager<%post"; else bad "instalado-p0 orden exec users<displaymanager<%post"; fi
# Script: sin liveuser hardcodeado; deriva el usuario (argv Calamares o passwd)
if grep -q 'liveuser' "$NIS" 2>/dev/null; then bad "instalado-p0 script sin liveuser hardcodeado"; else ok "instalado-p0 script sin liveuser hardcodeado"; fi
chkg "instalado-p0 script regenera greetd config.toml" "$NIS" 'GREETD_CONF.*config\.toml'
chkg "instalado-p0 script usuario de argv o passwd uid>=1000" "$NIS" 'PASSWD_DB'
chkg "instalado-p0 script rechaza username sospechoso" "$NIS" 'sospechoso'
chkg "instalado-p0 script requiere root" "$NIS" 'requiere root'
chkg "instalado-p0 script fusiona pamac EnableFlatpak/EnableAUR" "$NIS" 'EnableFlatpak.*EnableAUR|EnableAUR.*EnableFlatpak'
chkg "instalado-p0 script flathub remote-add" "$NIS" 'flatpak remote-add --if-not-exists flathub'
chkg "instalado-p0 script mask power-profiles-daemon" "$NIS" 'mask power-profiles-daemon'
for _u in auto-cpufreq thermald bluetooth; do
  chkg "instalado-p0 script enable $_u" "$NIS" "$_u"
done
chkg "instalado-p0 script ensure nimbus-live-setup.service" "$NIS" 'nimbus-live-setup\.service'
chkg "instalado-p0 script exit 0" "$NIS" '^exit 0'
chkg "instalado-p0 live-setup tambien habilita bluetooth" "$OVL/usr/bin/nimbus-live-setup" 'bluetooth\.service'
# Herencia primer arranque: el wants-symlink copiado al instalado reintenta
# AUR/flathub con red aunque el %post fuera sin red:
chk "instalado-p0 wants symlink (hereda live-setup en instalado)" test -L "$OVL/etc/systemd/system/multi-user.target.wants/nimbus-live-setup.service"
# 3) Fallback .conf: stanza plugin:hyprbars presente Y validada sin el .so.
# `hyprland --verify-config` en sesion .conf pura (sin hyprland.lua, que tiene
# precedencia en >=0.55): prueba la paridad real del fallback.
chkg "instalado-p0 fallback .conf trae stanza plugin:hyprbars" "$HYPR" 'plugin[[:space:]]*\{'
chkg "instalado-p0 fallback documenta divergencias (amarilla/no_bar)" "$HYPR" 'no_bar'
if command -v hyprland >/dev/null 2>&1; then
  _vtmp="$(mktemp -d)"
  mkdir -p "$_vtmp/.config/hypr"
  cp "$ROOT/nimbus-overlay/etc/skel/.config/hypr/"*.conf "$_vtmp/.config/hypr/" 2>/dev/null
  if HOME="$_vtmp" hyprland --verify-config -c "$_vtmp/.config/hypr/hyprland.conf" >/dev/null 2>&1; then
    ok "instalado-p0 fallback .conf valida sin plugin (config ok)"
  else
    bad "instalado-p0 fallback .conf valida sin plugin (config ok)"
  fi
  rm -rf "$_vtmp"
else
  skip "instalado-p0 verify-config .conf (hyprland no instalado en host)"
fi

# Calamares/boost (desync upstream 2026-10-27): cachyos-calamares-next 3.4.2-13
# pide libboost_python 1.91.0, repos dan 1.92.0. Se probó symlink en VM: falla
# (ABI incompatible). Puente V2 con la libreria REAL 1.91 del archivo de Arch:
# tarball pineado en build, staging en apply_overlay, instalacion CONDICIONAL
# en customize (auto-expira cuando upstream reconstruya).
chkg "compat boost: pin tarball 1.91.0-2 archive.archlinux" "$ROOT/build_iso.sh" 'archive\.archlinux\.org/packages/b/boost-libs/boost-libs-1\.91'
chkg "compat boost: staging TODAS las versionadas (no solo python)" "$ROOT/build_iso.sh" 'libboost_\*\.so\.1\.91\.0'
chkg "compat boost: customize solo si Calamares lo pide (auto-expira)" "$ROOT/nimbus-overlay/root/customize_airootfs.sh" 'CAL_NEED_191'
if grep -q 'ln -s.*libboost_python' "$ROOT/nimbus-overlay/root/customize_airootfs.sh" "$ROOT/build_iso.sh" 2>/dev/null; then
  bad "compat boost: sin symlinks (ABI incompatible, probado en VM)"
else
  ok "compat boost: sin symlinks (ABI incompatible, probado en VM)"
fi

# --- Task calamares-btrfs: fallo mount `btrfs subvolume create @` ---------
# Ruling upstream/entorno (NO nuestra config), evidencia VM live ISO 10.27
# 2026-10-27: flujo limpio erase+btrfs en /dev/vda virtio da RC=0 en TODOS
# los pasos (parted GPT EFI512M+btrfs, mkfs.vfat/mkfs.btrfs, mount,
# subvolume create @ + 7 de CachyOS, umount, remount subvol=@);
# btrfs-progs 7.3 presente en la ISO; mount.conf = default CachyOS auditado
# (sin override aqui). El non-zero solo se reproduce con @ preexistente
# ("File exists" RC=1: disco reutilizado sin reformatear) o mount previo
# fallido en silencio (ver session.log). Este bloque fija el estado bueno.
chkg "calamares-btrfs: Ruling documentada en partition.conf" "$PART" 'Ruling calamares-btrfs'
chkg "calamares-btrfs: default btrfs" "$PART" '^defaultFileSystemType:[[:space:]]*"btrfs"'
chkg "calamares-btrfs: settings declara mount en exec" "$SET" '^[[:space:]]*-[[:space:]]*mount$'
_CBORU="$(awk '/^[[:space:]]*-[[:space:]]*partition$/{p=NR} /^[[:space:]]*-[[:space:]]*mount$/{m=NR} END{print (p>0 && m>p) ? "si" : "no"}' "$SET")"
if [ "$_CBORU" = "si" ]; then ok "calamares-btrfs: orden exec partition<mount"; else bad "calamares-btrfs: orden exec partition<mount"; fi
if [ -f "$CAL/modules/mount.conf" ]; then
  bad "calamares-btrfs: sin mount.conf propio (vale el default CachyOS auditado)"
else
  ok "calamares-btrfs: sin mount.conf propio (vale el default CachyOS auditado)"
fi

echo "-------------------------------------------------------------"
echo "RESULT: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
