#!/bin/bash
# NimbusOS Task 5 — scripts/verify-build.sh
# Verifica el perfil de build sin root ni red pesada:
#   bash -n + shellcheck (si existe) + rutas overlay/skel + append sin
#   duplicados + manifest con pin MacShell + .inc file_permissions.
# Uso: bash scripts/verify-build.sh  →  PASS/FAIL + codigo salida.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0; SKIP=0
ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }
chkg() { local d="$1" f="$2" re="$3"; if grep -qE -- "$re" "$f" 2>/dev/null; then ok "$d"; else bad "$d"; fi; }

echo "== Task 5 verify: perfil archiso + build_iso.sh =="

# --- Sintaxis -----------------------------------------------------------------
[ -f "$ROOT/build_iso.sh" ] && ok "existe build_iso.sh" || bad "existe build_iso.sh"
if bash -n "$ROOT/build_iso.sh" 2>/dev/null; then ok "bash -n build_iso.sh"; else bad "bash -n build_iso.sh"; fi
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S warning "$ROOT/build_iso.sh" >/dev/null 2>&1; then ok "shellcheck build_iso.sh"; else bad "shellcheck build_iso.sh"; fi
else
    skip "shellcheck (no instalado)"
fi
if bash -n "$ROOT/scripts/verify-build.sh" 2>/dev/null; then ok "bash -n verify-build.sh"; else bad "bash -n verify-build.sh"; fi

# --- 7 pasos presentes en build_iso.sh ----------------------------------------
for s in check_deps SOURCE_DATE_EPOCH 'setup_keys|populate' get_upstream apply_overlay 'mkarchiso' 'verify|sha256sum.*isoinfo'; do
    if grep -qE -- "$s" "$ROOT/build_iso.sh" 2>/dev/null; then ok "paso presente: $s"; else bad "paso presente: $s"; fi
done
chkg "check-only sin root" "$ROOT/build_iso.sh" 'check-only'
chkg "pin git log --format=%ct" "$ROOT/build_iso.sh" 'git log -1 --format=%ct'
chkg "no overwrite passwd/shadow" "$ROOT/build_iso.sh" 'passwd.*shadow|shadow.*passwd'
chkg "file_permissions declara binarios" "$ROOT/build_iso.sh" 'file_permissions'
chkg "pin UPSTREAM_COMMIT default" "$ROOT/build_iso.sh" 'UPSTREAM_COMMIT.*3215497'
chkg "get_upstream fetch+reset pin" "$ROOT/build_iso.sh" 'reset --hard "\$UPSTREAM_COMMIT"'
chkg "apply_overlay cp -a (preserva symlinks)" "$ROOT/build_iso.sh" 'cp -a'
chkg "apply_overlay filtra comentarios antes de concat" "$ROOT/build_iso.sh" "grep -vE.*APPEND.*grep -vxFf"
chkg "apply_overlay genera packages.x86_64 (cp desktop)" "$ROOT/build_iso.sh" 'packages_desktop.x86_64.*packages.x86_64'
chkg "apply_overlay exige syslinux en packages.x86_64" "$ROOT/build_iso.sh" 'syslinux'
chkg "apply_overlay idempotente (restaura desktop desde git)" "$ROOT/build_iso.sh" 'checkout --.*packages_desktop'
chkg "iso_name sed solo si aun cachyos" "$ROOT/build_iso.sh" 'iso_name="cachyos"'
chkg "file_permissions anclado a bloque" "$ROOT/build_iso.sh" 'file_permissions=\('
chkg "sin sudo redundante ante mkarchiso" "$ROOT/build_iso.sh" '^mkarchiso -v'
chkg "conflictos staging (mv a usr/share/nimbus/staging)" "$ROOT/build_iso.sh" 'usr/share/nimbus/staging'
chkg "conflictos mueve displaymanager a staging" "$ROOT/build_iso.sh" 'displaymanager.conf'
chkg "customize_airootfs en airootfs/root +x (mkarchiso lo ejecuta ahi)" "$ROOT/build_iso.sh" 'AIROOTFS/root/customize_airootfs.sh'
[ -f "$ROOT/nimbus-overlay/root/customize_airootfs.sh" ] && ok "existe nimbus-overlay/root/customize_airootfs.sh" || bad "existe nimbus-overlay/root/customize_airootfs.sh"
if bash -n "$ROOT/nimbus-overlay/root/customize_airootfs.sh" 2>/dev/null; then ok "bash -n customize_airootfs.sh"; else bad "bash -n customize_airootfs.sh"; fi
chkg "customize instala displaymanager via install" "$ROOT/nimbus-overlay/root/customize_airootfs.sh" 'displaymanager.conf'
chkg "customize instala gtk settings via install" "$ROOT/nimbus-overlay/root/customize_airootfs.sh" 'gtk-3.0/settings.ini'
chkg "tool_options limita mksquashfs a 8 hilos" "$ROOT/build_iso.sh" "'-processors' '8'"

# --- Overlay: ficheros pendientes Task 1-4 -------------------------------------
for f in usr/share/backgrounds/nimbus/sequoia-light.jpg \
         usr/bin/macshell usr/bin/nimbus-live-setup usr/bin/nimbus-minimize-toggle \
         usr/lib/systemd/system/nimbus-live-setup.service \
         etc/pamac.conf.d/nimbus.conf profiledef.nimbus.inc; do
    [ -f "$ROOT/nimbus-overlay/$f" ] && ok "overlay: $f" || bad "overlay: $f"
done
if [ -f "$ROOT/nimbus-overlay/usr/share/backgrounds/nimbus/sequoia-light.jpg" ]; then
    if file "$ROOT/nimbus-overlay/usr/share/backgrounds/nimbus/sequoia-light.jpg" 2>/dev/null | grep -qi 'jpeg'; then
        ok "wallpaper es JPEG valido"
    else
        bad "wallpaper es JPEG valido"
    fi
fi
[ -x "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" ] && ok "nimbus-live-setup ejecutable" || bad "nimbus-live-setup ejecutable"
[ -x "$ROOT/nimbus-overlay/usr/bin/nimbus-minimize-toggle" ] && ok "nimbus-minimize-toggle ejecutable" || bad "nimbus-minimize-toggle ejecutable"
if sh -n "$ROOT/nimbus-overlay/usr/bin/nimbus-minimize-toggle" 2>/dev/null; then ok "sh -n nimbus-minimize-toggle"; else bad "sh -n nimbus-minimize-toggle"; fi
chkg "file_permissions incluye nimbus-minimize-toggle" "$ROOT/nimbus-overlay/profiledef.nimbus.inc" 'nimbus-minimize-toggle'
if bash -n "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 2>/dev/null; then ok "bash -n nimbus-live-setup"; else bad "bash -n nimbus-live-setup"; fi
chkg "live-setup flatpak remote-add flathub" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'flatpak remote-add --if-not-exists flathub'
chkg "live-setup invoca paru (AUR defer)" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'paru -S --needed --noconfirm'
chkg "live-setup no reinstala (pacman -Q como root)" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'pacman -Q'
chkg "live-setup AUR como usuario live (runuser, nunca root)" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'runuser -u'
chkg "live-setup crea pamac.conf minimo si falta" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'creado \$PAMAC_CONF minimo'
chkg "live-setup marker live-setup.done" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'live-setup.done'
if grep -qE 'die.*pamac\.conf|die.*PAMAC_CONF' "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 2>/dev/null; then bad "live-setup sin die por pamac.conf ausente"; else ok "live-setup sin die por pamac.conf ausente"; fi
if grep -qE '^ConditionPathExists=' "$ROOT/nimbus-overlay/usr/lib/systemd/system/nimbus-live-setup.service" 2>/dev/null; then bad "unit sin ConditionPathExists (el script gestiona el marker)"; else ok "unit sin ConditionPathExists (el script gestiona el marker)"; fi
if grep -qE '^ExecStartPost=' "$ROOT/nimbus-overlay/usr/lib/systemd/system/nimbus-live-setup.service" 2>/dev/null; then bad "unit sin ExecStartPost (el script gestiona el marker)"; else ok "unit sin ExecStartPost (el script gestiona el marker)"; fi
chkg "live-setup log + exit 0" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'nimbus-live-setup.log'
chkg "live-setup lee manifest AUR" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'packages.nimbus-aur.txt'
chkg "live-setup mask power-profiles-daemon" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'mask power-profiles-daemon'
chkg "live-setup enable auto-cpufreq" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'auto-cpufreq'
chkg "live-setup fusiona pamac.conf" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'EnableFlatpak|pamac.conf'
chkg "live service After=network.target (sin stall online)" "$ROOT/nimbus-overlay/usr/lib/systemd/system/nimbus-live-setup.service" 'After=network.target'
[ ! -e "$ROOT/nimbus-overlay/etc/passwd" ] && ok "overlay sin etc/passwd" || bad "overlay sin etc/passwd"
[ ! -e "$ROOT/nimbus-overlay/etc/shadow" ] && ok "overlay sin etc/shadow" || bad "overlay sin etc/shadow"
WANTS="$ROOT/nimbus-overlay/etc/systemd/system/multi-user.target.wants/nimbus-live-setup.service"
if [ -L "$WANTS" ]; then ok "live service habilitado (wants symlink)"; else bad "live service habilitado (wants symlink)"; fi
if [ -L "$WANTS" ]; then
    TGT="$(readlink "$WANTS")"
    case "$TGT" in
        *nimbus-live-setup.service) ok "wants symlink apunta a nimbus-live-setup.service" ;;
        *) bad "wants symlink apunta a nimbus-live-setup.service (es $TGT)" ;;
    esac
fi
[ ! -e "$ROOT/nimbus-overlay/etc/gshadow" ] && ok "overlay sin etc/gshadow" || bad "overlay sin etc/gshadow"
chkg ".inc declara macshell 0755" "$ROOT/nimbus-overlay/profiledef.nimbus.inc" '"/usr/bin/macshell.*0:0:755'
chkg ".inc declara nimbus-live-setup 0755" "$ROOT/nimbus-overlay/profiledef.nimbus.inc" '"/usr/bin/nimbus-live-setup.*0:0:755'
if grep -qE '\["/(etc/(passwd|shadow|gshadow|group)|root)"\]' "$ROOT/nimbus-overlay/profiledef.nimbus.inc" 2>/dev/null; then
    bad ".inc sin passwd/shadow"
else
    ok ".inc sin passwd/shadow"
fi

# --- Append: dedupe + secciones + base-devel + AUR ----------------------------
APP="$ROOT/packages.nimbus.x86_64.append"
[ -f "$APP" ] && ok "existe packages.nimbus.x86_64.append" || bad "existe packages.nimbus.x86_64.append"
if [ -f "$APP" ]; then
    DUPES="$(grep -vE '^\s*#|^\s*$' "$APP" | sort | uniq -d || true)"
    if [ -z "$DUPES" ]; then ok "append sin duplicados"; else bad "append sin duplicados ($DUPES)"; fi
    chkg "append Task1 intacto" "$APP" '--- Task 1'
    chkg "append Task2 intacto" "$APP" '--- Task2 power'
    chkg "append Task3 intacto" "$APP" '--- Task3 store\+USB'
    chkg "append nota base-devel/Task5" "$APP" 'base-devel'
    chkg "append hyprshell AUR" "$APP" 'hyprshell'
    chkg "append auto-cpufreq no-AUR" "$APP" 'auto-cpufreq'
    if grep -qx 'nvidia-dkms' "$APP" 2>/dev/null; then bad "append sin nvidia-dkms duplicado (lo aporta upstream)"; else ok "append sin nvidia-dkms duplicado (lo aporta upstream)"; fi
    if grep -qx 'nvidia-utils' "$APP" 2>/dev/null; then bad "append sin nvidia-utils duplicado (lo aporta upstream)"; else ok "append sin nvidia-utils duplicado (lo aporta upstream)"; fi
    for _d in iptables qt6-multimedia-ffmpeg tesseract-data-eng; do
        if grep -qx "$_d" "$APP" 2>/dev/null; then ok "append default no-interactivo: $_d"; else bad "append default no-interactivo: $_d"; fi
    done
fi

# --- Manifest: pins -------------------------------------------------------------
MAN="$ROOT/iso.manifest"
[ -f "$MAN" ] && ok "existe iso.manifest" || bad "existe iso.manifest"
if [ -f "$MAN" ]; then
    chkg "manifest pin MacShell" "$MAN" '0-ss/MacShell'
    chkg "manifest upstream Live-ISO" "$MAN" 'CachyOS-Live-ISO'
    chkg "manifest seccion Task 5" "$MAN" 'Task 5'
    chkg "manifest pin UPSTREAM_COMMIT" "$MAN" 'UPSTREAM_COMMIT=3215497|commit: 3215497'
fi
# Fusion simulada: el pipeline de apply_overlay no deja comentarios en
# packages_desktop (regresion Important 3) y filtra las 5 AUR a skipped-aur:
if [ -f "$APP" ]; then
    TMPSIM="$(mktemp -d)"
    printf 'mesa\nntfs-3g\nlinux-cachyos\n' > "$TMPSIM/upstream.txt"
    printf 'whitesur-gtk-theme\nwhitesur-icon-theme\npamac-aur\nhyprshell\n' > "$TMPSIM/aur.txt"
    grep -vE '^\s*#|^\s*$' "$APP" | grep -vxFf "$TMPSIM/upstream.txt" > "$TMPSIM/predup.txt" || true
    grep -xFf "$TMPSIM/aur.txt" "$TMPSIM/predup.txt" > "$TMPSIM/skipped-aur.txt" || true
    grep -vxFf "$TMPSIM/aur.txt" "$TMPSIM/predup.txt" > "$TMPSIM/merged.txt" || true
    if grep -qE '^\s*#' "$TMPSIM/merged.txt" 2>/dev/null; then
        bad "fusion simulada sin lineas '# Nimbus'"
    else
        ok "fusion simulada sin lineas '# Nimbus'"
    fi
    for _a in whitesur-gtk-theme whitesur-icon-theme pamac-aur hyprshell; do
        if grep -qx "$_a" "$TMPSIM/merged.txt" 2>/dev/null; then bad "packages.x86_64 sin AUR $_a"; else ok "packages.x86_64 sin AUR $_a"; fi
    done
    if grep -qx 'paru' "$TMPSIM/merged.txt" 2>/dev/null; then ok "packages.x86_64 con paru (cachyos/oficial)"; else bad "packages.x86_64 con paru (cachyos/oficial)"; fi
    if [ -s "$TMPSIM/skipped-aur.txt" ]; then ok "skipped-aur existe en simulacion"; else bad "skipped-aur existe en simulacion"; fi
    rm -rf "$TMPSIM"
fi
# Manifest AUR: canonico en raiz + copia en overlay para live-setup:
[ -f "$ROOT/packages.nimbus-aur.txt" ] && ok "existe packages.nimbus-aur.txt" || bad "existe packages.nimbus-aur.txt"
[ -f "$ROOT/nimbus-overlay/usr/share/nimbus/packages.nimbus-aur.txt" ] && ok "overlay: usr/share/nimbus/packages.nimbus-aur.txt" || bad "overlay: usr/share/nimbus/packages.nimbus-aur.txt"
if [ -f "$ROOT/packages.nimbus-aur.txt" ]; then
    for _a in whitesur-gtk-theme whitesur-icon-theme pamac-aur hyprshell; do
        if grep -qx "$_a" "$ROOT/packages.nimbus-aur.txt" 2>/dev/null; then ok "manifest AUR: $_a"; else bad "manifest AUR: $_a"; fi
        if grep -qx "$_a" "$APP" 2>/dev/null; then ok "append pide $_a (repo [nimbus] lo provee)"; else bad "append pide $_a (repo [nimbus] lo provee)"; fi
    done
    if grep -qx 'pamac-aur' "$ROOT/nimbus-overlay/usr/share/nimbus/packages.nimbus-aur.txt" 2>/dev/null; then ok "overlay AUR copia sincronizada (pamac-aur)"; else bad "overlay AUR copia sincronizada (pamac-aur)"; fi
    if grep -qx 'pamac-gtk' "$ROOT/packages.nimbus-aur.txt" 2>/dev/null; then bad "manifest AUR sin pamac-gtk (no existe en AUR)"; else ok "manifest AUR sin pamac-gtk (no existe en AUR)"; fi
    if grep -qx 'libpamac-flatpak-plugin' "$ROOT/packages.nimbus-aur.txt" 2>/dev/null; then bad "manifest AUR sin libpamac-flatpak-plugin (no existe en AUR)"; else ok "manifest AUR sin libpamac-flatpak-plugin (no existe en AUR)"; fi
    for _b in vala meson; do
        if grep -qx "$_b" "$APP" 2>/dev/null; then ok "append build-deps AUR: $_b"; else bad "append build-deps AUR: $_b"; fi
    done
    if grep -qE '^rust( |$)' "$APP" 2>/dev/null; then ok "append build-deps AUR: rust (provee cargo, evita prompt)"; else bad "append build-deps AUR: rust (provee cargo)"; fi
    if grep -qE '^[a-z0-9_.+-]+ +#' "$APP" 2>/dev/null; then bad "append sin comentarios en linea (rompen el nombre del paquete)"; else ok "append sin comentarios en linea"; fi
    chkg "build filtra AUR a skipped-aur.txt" "$ROOT/build_iso.sh" 'skipped-aur'
    chkg "build excluye AUR de pacstrap (aur-skip)" "$ROOT/build_iso.sh" 'aur-skip'
    chkg "repo local [nimbus] en pacman.conf (Server file://)" "$ROOT/build_iso.sh" 'Server = file://'
    chkg "DM greetd en append (pacstrap)" "$APP" '^greetd$'
    if [ -L "$ROOT/nimbus-overlay/etc/systemd/system/display-manager.service" ]; then ok "overlay DM symlink existe"; else bad "overlay DM symlink existe"; fi
    chkg "DM apunta a greetd" "$ROOT/build_iso.sh" 'greetd.service'
    chkg "greetd initial_session Hyprland" "$ROOT/nimbus-overlay/etc/greetd/config.toml" 'initial_session'
    chkg "build exige DM symlink + greetd config" "$ROOT/build_iso.sh" 'display-manager.service'
    chkg "macshell vendoreado en skel (shell.qml)" "$ROOT/nimbus-overlay/etc/skel/.config/quickshell/MacShell/shell.qml" 'shell'
    [ -x "$ROOT/nimbus-overlay/etc/skel/.local/bin/macshell-start" ] && ok "macshell-start ejecutable en skel" || bad "macshell-start ejecutable en skel"
    [ -f "$ROOT/nimbus-overlay/etc/systemd/system/greetd.service.d/wait-for-drm.conf" ] && ok "greetd drop-in wait-for-drm" || bad "greetd drop-in wait-for-drm"
    chkg "repo local con SigLevel TrustAll" "$ROOT/build_iso.sh" 'TrustAll'
    chkg "repo local solo si db existe (fallback live-setup)" "$ROOT/build_iso.sh" 'nimbus.db.tar.gz'
fi

# --- QEMU: doc + script ---------------------------------------------------------
[ -f "$ROOT/scripts/test-qemu.sh" ] && ok "existe scripts/test-qemu.sh" || bad "existe scripts/test-qemu.sh"
if [ -f "$ROOT/scripts/test-qemu.sh" ]; then
    if bash -n "$ROOT/scripts/test-qemu.sh" 2>/dev/null; then ok "bash -n test-qemu.sh"; else bad "bash -n test-qemu.sh"; fi
    chkg "qemu sin acpi-battery (QEMU 11 no lo trae)" "$ROOT/scripts/test-qemu.sh" 'QEMU 11'
    chkg "qemu OVMF" "$ROOT/scripts/test-qemu.sh" 'OVMF'
    chkg "qemu pre-check x86-64-v3" "$ROOT/scripts/test-qemu.sh" 'x86-64-v|avx2|AVX2'
fi
[ -f "$ROOT/docs/qemu.md" ] && ok "existe docs/qemu.md" || bad "existe docs/qemu.md"
chkg "qemu.md checklist hyprland --verify-config pre-release" "$ROOT/docs/qemu.md" 'hyprland --verify-config'

# --- DM (I4): greetd sin probar E2E; alertar si el upstream cambia de DM ----
# Nimbus V1 asume greetd+Hyprland (displaymanager.conf del overlay). El perfil
# upstream podria cambiar su DM/display-manager en un commit posterior al pin;
# el build real debe cruzar esto antes de la release (ver docs/qemu.md).
chkg "DM overlay greetd+Hyprland" "$ROOT/nimbus-overlay/etc/calamares/modules/displaymanager.conf" 'greetd'
# En --check-only no hay red pesada: avisar (no fallar) si no podemos
# inspeccionar el profiledef upstream. El build real (get_upstream) debe
# ejecutar: grep -ri 'display-manager\|displaymanager\|greetd\|sddm' PROFILE/profiledef.sh
# y abortar la release si el DM efectivo ya no es greetd.
if command -v git >/dev/null 2>&1; then
    if [ -d "$ROOT/work/upstream/.git" ]; then
        if grep -riE 'display-manager|displaymanager' "$ROOT/work/upstream/archiso/profiledef.sh" 2>/dev/null | grep -qv 'greetd'; then
            echo "AVISO DM: el profiledef upstream menciona un display-manager distinto de greetd; revisar docs/qemu.md antes de la release"
        else
            ok "DM upstream sin drift (o sin mencion display-manager)"
        fi
    else
        skip "DM upstream drift (sin work/upstream; verificar en build real)"
    fi
else
    skip "DM upstream drift (sin git)"
fi

# --- check-only end-to-end (requiere git + red ligera ls-remote) -----------------
if "$ROOT/build_iso.sh" --check-only >/tmp/nimbus-check-only.log 2>&1; then
    ok "build_iso.sh --check-only PASS"
else
    bad "build_iso.sh --check-only PASS (ver /tmp/nimbus-check-only.log)"
fi

echo "-------------------------------------------------------------"
echo "RESULT: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
