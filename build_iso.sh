#!/bin/bash
# =============================================================================
# NimbusOS — build_iso.sh (Task 5)
# Build reproducible de la ISO sobre el perfil CachyOS-Live-ISO + overlay.
# Uso:
#   ./build_iso.sh [--check-only] [--upstream-tag BRANCH] [--work DIR] [--out DIR]
#   --check-only: valida todo sin root ni red pesada (sintaxis, rutas overlay,
#                 upstream clonable, append sin duplicados, file_permissions).
# Requiere (build real): archiso mkinitcpio-archiso git squashfs-tools grub
#   qemu-full ovmf + root (mkarchiso) + KVM para el test QEMU.
# Producen: out/nimbus-YYYY.MM.DD-x86_64.iso + .sha256 + build.log
# Reproducibilidad: SOURCE_DATE_EPOCH=$(git log -1 --format=%ct) (pin repo).
# Checklist obligatorio pre-release (solo live, no --check-only):
#   hyprland --check-config en el guest live antes de declarar la release
#   (valida hyprland.conf + 10-shortcuts.conf fusionados; ver docs/qemu.md).
#   Ni --check-only ni verify-build.sh lo ejecutan (requieren sesion live).
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
OVERLAY="$REPO_ROOT/nimbus-overlay"
APPEND="$REPO_ROOT/packages.nimbus.x86_64.append"
INC="$OVERLAY/profiledef.nimbus.inc"

UPSTREAM_URL="https://github.com/CachyOS/CachyOS-Live-ISO"
UPSTREAM_TAG="${UPSTREAM_TAG:-master}"   # sin tags publicados; rama canonica
# Pin reproducible (default: commit auditado en iso.manifest Task 5).
# Override: UPSTREAM_COMMIT=<sha> ./build_iso.sh
UPSTREAM_COMMIT="${UPSTREAM_COMMIT:-3215497d2e8c5fea90e185affcf973dfa2cf790b}"
WORKDIR="$REPO_ROOT/work"
OUTDIR="$REPO_ROOT/out"
LOG="$OUTDIR/build.log"
CHECK_ONLY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --check-only) CHECK_ONLY=1; shift ;;
        --upstream-tag) UPSTREAM_TAG="${2:-}"; shift 2 ;;
        --work) WORKDIR="$2"; shift 2 ;;
        --out) OUTDIR="$2"; shift 2 ;;
        *) echo "Uso: $0 [--check-only] [--upstream-tag BRANCH] [--work DIR] [--out DIR]" >&2; exit 2 ;;
    esac
done

UPSTREAM_DIR="$WORKDIR/upstream"
PROFILE_DIR="$UPSTREAM_DIR/archiso"
BUILD_DIR="$WORKDIR/build"

step() { echo "==> [build_iso] $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

# --- Paso 1: check_deps -------------------------------------------------------
step "1/7 check_deps"
DEPS_BIN=(git mkarchiso mkinitcpio pacman-key sha256sum isoinfo qemu-system-x86_64 qemu-img)
MISSING=()
for b in "${DEPS_BIN[@]}"; do
    command -v "$b" >/dev/null 2>&1 || MISSING+=("$b")
done
# Paquetes arch (validacion nominal; en --check-only solo se informa):
for p in archiso mkinitcpio-archiso squashfs-tools grub ovmf; do
    if command -v pacman >/dev/null 2>&1 && ! pacman -Q "$p" >/dev/null 2>&1; then
        MISSING+=("pkg:$p")
    fi
done
if [ "$CHECK_ONLY" = "1" ]; then
    [ "${#MISSING[@]}" -gt 0 ] && echo "check-only: faltan (solo build real): ${MISSING[*]}"
else
    [ "${#MISSING[@]}" -gt 0 ] && fail "dependencias ausentes: ${MISSING[*]}"
fi
# Pre-check CPU x86-64-v3/v4 (CachyOS lo exige; abortar si no cumple):
if command -v /lib/ld-linux-x86-64.so.2 >/dev/null 2>&1; then
    if ! /lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q .; then :; fi
fi
if lscpu 2>/dev/null | grep -qiE 'x86-64-v[34]|avx2.*bmi2'; then
    echo "check_deps: CPU con x86-64-v3+ OK"
else
    # lscpu no siempre anuncia el nivel; comprobar flags AVX2 (requisito v3):
    if lscpu 2>/dev/null | grep -qi 'avx2'; then
        echo "check_deps: CPU con AVX2 (x86-64-v3) OK"
    else
        [ "$CHECK_ONLY" = "1" ] \
            && echo "check-only AVISO: CPU sin AVX2 visible; el build real puede fallar en este host" \
            || fail "CPU sin x86-64-v3 (falta AVX2); abortar (CachyOS requiere v3/v4)"
    fi
fi

# --- Paso 2: pin SOURCE_DATE_EPOCH --------------------------------------------
step "2/7 pin SOURCE_DATE_EPOCH"
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    SOURCE_DATE_EPOCH="$(git -C "$REPO_ROOT" log -1 --format=%ct)"
else
    SOURCE_DATE_EPOCH="$(date +%s)"
    echo "AVISO: sin git; SOURCE_DATE_EPOCH=tiempo actual (no reproducible)"
fi
export SOURCE_DATE_EPOCH
echo "SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH ($(date -u --date="@$SOURCE_DATE_EPOCH" +%Y-%m-%d))"

# --- Rutas overlay (validar siempre, con o sin root) --------------------------
step "rutas overlay + append + profiledef.nimbus.inc"
[ -d "$OVERLAY" ] || fail "falta $OVERLAY"
[ -f "$APPEND" ] || fail "falta $APPEND"
[ -f "$INC" ] || fail "falta $INC"
# No sobrescribir credenciales live del upstream:
for f in etc/passwd etc/shadow etc/gshadow etc/group; do
    [ -e "$OVERLAY/$f" ] && fail "overlay no debe traer $f (lo gestiona upstream)"
done
echo "overlay: sin overwrite passwd/shadow/group OK"
# Binarios con permiso: deben existir + estar declarados en el .inc:
for b in usr/bin/macshell usr/bin/nimbus-live-setup; do
    [ -f "$OVERLAY/$b" ] || fail "falta binario overlay $b"
    grep -q "\"/$b\"" "$INC" || fail "$INC no declara file_permissions para /$b"
done
grep -qE '\["/(etc/(passwd|shadow|gshadow|group)|root)"\]' "$INC" && fail "$INC declara passwd/shadow (prohibido)"
echo "file_permissions declara macshell + nimbus-live-setup 0755 OK"
# Append sin duplicados (ignora comentarios/lineas vacias):
DUPES="$(grep -vE '^\s*#|^\s*$' "$APPEND" | sort | uniq -d || true)"
[ -z "$DUPES" ] || fail "duplicados en $APPEND: $DUPES"
echo "append sin duplicados OK ($(grep -vcE '^\s*#|^\s*$' "$APPEND") paquetes)"
# Fondo canonico presente:
[ -f "$OVERLAY/usr/share/backgrounds/nimbus/sequoia-light.jpg" ] \
    || fail "falta wallpaper canonico"

# --- Paso 3: setup_keys -------------------------------------------------------
step "3/7 setup_keys (pacman-key populate archlinux cachyos)"
if [ "$CHECK_ONLY" = "1" ]; then
    echo "check-only: salto pacman-key (requiere root)"
else
    [ "$(id -u)" = "0" ] || fail "setup_keys requiere root (usa --check-only sin root)"
    pacman-key --init
    pacman-key --populate archlinux cachyos
fi

# --- Paso 4: get_upstream -----------------------------------------------------
step "4/7 get_upstream ($UPSTREAM_URL @ $UPSTREAM_TAG pin $UPSTREAM_COMMIT)"
if [ "$CHECK_ONLY" = "1" ]; then
    git ls-remote "$UPSTREAM_URL" HEAD >/dev/null 2>&1 \
        || fail "upstream no clonable: $UPSTREAM_URL"
    # El pin debe ser un SHA valido y coincidir con iso.manifest
    # (ls-remote no resuelve SHAs; la existencia real se verifica en el
    # fetch del build real):
    echo "$UPSTREAM_COMMIT" | grep -qE '^[0-9a-f]{40}$' \
        || fail "UPSTREAM_COMMIT invalido: $UPSTREAM_COMMIT"
    grep -q "$UPSTREAM_COMMIT" "$REPO_ROOT/iso.manifest" \
        || fail "UPSTREAM_COMMIT no esta en iso.manifest"
    echo "check-only: upstream clonable + pin OK"
else
    mkdir -p "$WORKDIR"
    if [ -d "$UPSTREAM_DIR/.git" ]; then
        git -C "$UPSTREAM_DIR" fetch --depth 1 origin "$UPSTREAM_TAG"
        git -C "$UPSTREAM_DIR" fetch --depth 1 origin "$UPSTREAM_COMMIT"
        git -C "$UPSTREAM_DIR" reset --hard "$UPSTREAM_COMMIT"
    else
        rm -rf "$UPSTREAM_DIR"
        git clone --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_URL" "$UPSTREAM_DIR"
        git -C "$UPSTREAM_DIR" fetch --depth 1 origin "$UPSTREAM_COMMIT"
        git -C "$UPSTREAM_DIR" reset --hard "$UPSTREAM_COMMIT"
    fi
    echo "upstream: $(git -C "$UPSTREAM_DIR" log -1 --format='%H %cs %s')"
fi

# --- Paso 5: apply_overlay ----------------------------------------------------
step "5/7 apply_overlay"
if [ "$CHECK_ONLY" = "1" ]; then
    # Simular la fusion sin red: clonar superficial existente o validar en seco.
    echo "check-only: fusion simulada (sin escritura en work/)"
    # 5a. profiledef: iso_name renombrable + file_permissions insertables:
    grep -q 'NIMBUS_ISO_NAME="nimbus"' "$INC" || fail ".inc sin NIMBUS_ISO_NAME"
    grep -q '/usr/bin/macshell' "$INC" || fail ".inc sin macshell"
    grep -q '/usr/bin/nimbus-live-setup' "$INC" || fail ".inc sin nimbus-live-setup"
    # 5b. pamac.conf fusion: nimbus.conf aporta ambos flags:
    grep -q '^EnableFlatpak=true' "$OVERLAY/etc/pamac.conf.d/nimbus.conf" || fail "nimbus.conf sin EnableFlatpak"
    grep -q '^EnableAUR=true' "$OVERLAY/etc/pamac.conf.d/nimbus.conf" || fail "nimbus.conf sin EnableAUR"
    [ -f "$OVERLAY/usr/bin/nimbus-live-setup" ] || fail "falta script fusion pamac"
    # 5c. servicio live habilitado: el wants-symlink debe existir en el overlay
    # (systemd lo activa via preset/enable; sin symlink no arranca en el live):
    WANTS="$OVERLAY/etc/systemd/system/multi-user.target.wants/nimbus-live-setup.service"
    [ -L "$WANTS" ] || fail "falta symlink enable $WANTS"
    # 5d. fusion packages simulada: sin comentarios ni lineas vacias en el
    # resultado (el append trae secciones '# ...' que no deben contaminar
    # packages_desktop.x86_64):
    TMPD="$(mktemp -d)"
    printf 'mesa\nntfs-3g\n# upstream comment\n\nlinux-cachyos\n' > "$TMPD/upstream.pkgs"
    grep -vE '^\s*#|^\s*$' "$APPEND" | grep -vxFf "$TMPD/upstream.pkgs" > "$TMPD/merged.pkgs"
    grep -qE '^\s*#' "$TMPD/merged.pkgs" && { rm -rf "$TMPD"; fail "fusion simulada deja comentarios"; }
    grep -qE '^\s*$' "$TMPD/merged.pkgs" && { rm -rf "$TMPD"; fail "fusion simulada deja lineas vacias"; }
    rm -rf "$TMPD"
    echo "check-only: apply_overlay simulado OK"
    echo ""
    echo "CHECK-ONLY PASS"
    exit 0
fi

[ "$(id -u)" = "0" ] || fail "build real requiere root (usa --check-only sin root)"
[ -d "$PROFILE_DIR" ] || fail "falta perfil upstream en $PROFILE_DIR (re-ejecuta get_upstream)"
AIROOTFS="$PROFILE_DIR/airootfs"
[ -d "$AIROOTFS" ] || fail "falta airootfs en $PROFILE_DIR"

# 5a. Copiar overlay sobre airootfs (cp -a; el overlay nunca trae passwd/shadow):
cp -a "$OVERLAY"/. "$AIROOTFS"/
# 5b. Concatenar paquetes Nimbus al perfil desktop, deduplicando contra el
# perfil upstream (el append es append-only Task1-4; el solape conocido
# dosfstools exfatprogs mesa mtools noto-fonts ntfs-3g nvidia-utils se filtra
# aqui y se registra en el log):
mkdir -p "$OUTDIR"
grep -vE '^\s*#|^\s*$' "$APPEND" | sort -u > "$WORKDIR/append.pkgs"
grep -vE '^\s*#|^\s*$' "$PROFILE_DIR/packages_desktop.x86_64" | sort -u > "$WORKDIR/upstream.pkgs"
comm -12 "$WORKDIR/append.pkgs" "$WORKDIR/upstream.pkgs" > "$OUTDIR/skipped-dupes.txt" || true
# Solo paquetes (sin comentarios/vacias), deduplicados contra upstream:
grep -vE '^\s*#|^\s*$' "$APPEND" | grep -vxFf "$WORKDIR/upstream.pkgs" \
    >> "$PROFILE_DIR/packages_desktop.x86_64"
echo "apply_overlay: solape upstream filtrado (ver $OUTDIR/skipped-dupes.txt)"
# 5c. Renombrar ISO + inyectar file_permissions (delta profiledef.nimbus.inc):
sed -i -E 's/^iso_name="cachyos"/iso_name="nimbus"/' "$PROFILE_DIR/profiledef.sh"
grep -q '^iso_name="nimbus"' "$PROFILE_DIR/profiledef.sh" || fail "renombrado iso_name fallo"
python3 - "$PROFILE_DIR/profiledef.sh" <<'EOF'
import re, sys
path = sys.argv[1]
add = ['  ["/usr/bin/macshell"]="0:0:755"',
       '  ["/usr/bin/nimbus-live-setup"]="0:0:755"']
src = open(path).read()
assert '"/usr/bin/macshell"' not in src, "file_permissions ya contiene macshell"
# Anclar al bloque file_permissions=( ... ): localizar apertura y su cierre.
m = re.search(r'^file_permissions=\(\s*$', src, re.M)
assert m, "no se encontro apertura de file_permissions=(...)"
start = m.start()
close = re.search(r'^\s*\)\s*$', src[m.end():], re.M)
assert close, "no se encontro cierre del bloque file_permissions"
insert_at = m.end() + close.start()
# Validar que la insercion cae dentro del bloque (entre apertura y cierre):
block_end = m.end() + close.end()
assert start < insert_at < block_end, "insercion fuera del bloque file_permissions"
new = src[:insert_at] + ''.join(a + '\n' for a in add) + src[insert_at:]
# Post-condicion: las lineas anadidas estan dentro del bloque:
blk = new[start:block_end + sum(len(a) + 1 for a in add)]
assert '/usr/bin/macshell' in blk and '/usr/bin/nimbus-live-setup' in blk
open(path, 'w').write(new)
print("profiledef.sh: file_permissions Nimbus inyectados (bloque anclado)")
EOF
bash -n "$PROFILE_DIR/profiledef.sh" || fail "profiledef.sh roto tras parche"
echo "apply_overlay OK"

# --- Paso 6: build ------------------------------------------------------------
step "6/7 build (mkarchiso)"
mkdir -p "$OUTDIR" "$BUILD_DIR"
# mkarchiso ya exige root (verificado arriba); sin sudo redundante:
# shellcheck disable=SC2086
mkarchiso -v -w "$BUILD_DIR" -o "$OUTDIR" "$PROFILE_DIR" 2>&1 | tee "$LOG"
echo "build OK (log: $LOG)"

# --- Paso 7: verify -----------------------------------------------------------
step "7/7 verify (sha256sum + isoinfo)"
ISO="$(ls -t "$OUTDIR"/nimbus-*-x86_64.iso 2>/dev/null | head -1)"
[ -n "$ISO" ] || fail "no se genero out/nimbus-*-x86_64.iso"
sha256sum "$ISO" | tee "$ISO.sha256"
isoinfo -d -i "$ISO" | head -10
isoinfo -l -i "$ISO" | head -20
echo ""
echo "BUILD PASS: $ISO"
