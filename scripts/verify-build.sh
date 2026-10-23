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

# --- Overlay: ficheros pendientes Task 1-4 -------------------------------------
for f in usr/share/backgrounds/nimbus/sequoia-light.jpg \
         usr/bin/macshell usr/bin/nimbus-live-setup \
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
if bash -n "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 2>/dev/null; then ok "bash -n nimbus-live-setup"; else bad "bash -n nimbus-live-setup"; fi
chkg "live-setup flatpak remote-add flathub" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'flatpak remote-add --if-not-exists flathub'
chkg "live-setup mask power-profiles-daemon" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'mask power-profiles-daemon'
chkg "live-setup enable auto-cpufreq" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'auto-cpufreq'
chkg "live-setup fusiona pamac.conf" "$ROOT/nimbus-overlay/usr/bin/nimbus-live-setup" 'EnableFlatpak|pamac.conf'
[ ! -e "$ROOT/nimbus-overlay/etc/passwd" ] && ok "overlay sin etc/passwd" || bad "overlay sin etc/passwd"
[ ! -e "$ROOT/nimbus-overlay/etc/shadow" ] && ok "overlay sin etc/shadow" || bad "overlay sin etc/shadow"
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
fi

# --- Manifest: pins -------------------------------------------------------------
MAN="$ROOT/iso.manifest"
[ -f "$MAN" ] && ok "existe iso.manifest" || bad "existe iso.manifest"
if [ -f "$MAN" ]; then
    chkg "manifest pin MacShell" "$MAN" '0-ss/MacShell'
    chkg "manifest upstream Live-ISO" "$MAN" 'CachyOS-Live-ISO'
    chkg "manifest seccion Task 5" "$MAN" 'Task 5'
fi

# --- QEMU: doc + script ---------------------------------------------------------
[ -f "$ROOT/scripts/test-qemu.sh" ] && ok "existe scripts/test-qemu.sh" || bad "existe scripts/test-qemu.sh"
if [ -f "$ROOT/scripts/test-qemu.sh" ]; then
    if bash -n "$ROOT/scripts/test-qemu.sh" 2>/dev/null; then ok "bash -n test-qemu.sh"; else bad "bash -n test-qemu.sh"; fi
    chkg "qemu acpi-battery" "$ROOT/scripts/test-qemu.sh" 'acpi-battery'
    chkg "qemu OVMF" "$ROOT/scripts/test-qemu.sh" 'OVMF'
    chkg "qemu pre-check x86-64-v3" "$ROOT/scripts/test-qemu.sh" 'x86-64-v|avx2|AVX2'
fi
[ -f "$ROOT/docs/qemu.md" ] && ok "existe docs/qemu.md" || bad "existe docs/qemu.md"

# --- check-only end-to-end (requiere git + red ligera ls-remote) -----------------
if "$ROOT/build_iso.sh" --check-only >/tmp/nimbus-check-only.log 2>&1; then
    ok "build_iso.sh --check-only PASS"
else
    bad "build_iso.sh --check-only PASS (ver /tmp/nimbus-check-only.log)"
fi

echo "-------------------------------------------------------------"
echo "RESULT: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
