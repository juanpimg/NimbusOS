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
#   hyprland --verify-config en el guest live antes de declarar la release
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

# Candado anti-solape (2026-10-27: dos builds concurrentes compartiendo
# work/build corrompieron el arbol y produjeron un BUILD PASS falso).
# La frescura se comprueba contra $LOCK (creado al inicio del build).
LOCK="$REPO_ROOT/.build.lock"
[ ! -e "$LOCK" ] || fail "otro build en curso ($LOCK existe; si es resto, borrarlo a mano tras comprobar que no hay mkarchiso activo)"
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

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
for b in usr/bin/macshell usr/bin/nimbus-live-setup usr/bin/nimbus-minimize-toggle usr/bin/nimbus-installed-setup usr/bin/nimbus-screenshot; do
    [ -f "$OVERLAY/$b" ] || fail "falta binario overlay $b"
    grep -q "\"/$b\"" "$INC" || fail "$INC no declara file_permissions para /$b"
done
grep -qE '\["/(etc/(passwd|shadow|gshadow|group)|root)"\]' "$INC" && fail "$INC declara passwd/shadow (prohibido)"
echo "file_permissions declara macshell + nimbus-live-setup + nimbus-minimize-toggle + nimbus-installed-setup + nimbus-screenshot 0755 OK"
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
    grep -q '/usr/bin/nimbus-minimize-toggle' "$INC" || fail ".inc sin nimbus-minimize-toggle"
    grep -q '/usr/bin/nimbus-installed-setup' "$INC" || fail ".inc sin nimbus-installed-setup"
    grep -q '/usr/bin/nimbus-screenshot' "$INC" || fail ".inc sin nimbus-screenshot"
    # 5b. pamac.conf fusion: nimbus.conf aporta ambos flags:
    grep -q '^EnableFlatpak=true' "$OVERLAY/etc/pamac.conf.d/nimbus.conf" || fail "nimbus.conf sin EnableFlatpak"
    grep -q '^EnableAUR=true' "$OVERLAY/etc/pamac.conf.d/nimbus.conf" || fail "nimbus.conf sin EnableAUR"
    [ -f "$OVERLAY/usr/bin/nimbus-live-setup" ] || fail "falta script fusion pamac"
    # 5b-bis. %post del instalado (P0 instalado==live): script + instancia
    # shellprocess declarada y secuenciada tras displaymanager:
    [ -x "$OVERLAY/usr/bin/nimbus-installed-setup" ] || fail "falta nimbus-installed-setup ejecutable"
    [ -f "$OVERLAY/etc/calamares/modules/shellprocess_nimbus_installed.conf" ] \
        || fail "falta shellprocess_nimbus_installed.conf"
    grep -q 'shellprocess_nimbus_installed.conf' "$OVERLAY/etc/calamares/settings.conf" \
        || fail "settings.conf sin instancia shellprocess nimbus_installed"
    grep -qE '^[[:space:]]*-[[:space:]]*shellprocess@nimbus_installed$' "$OVERLAY/etc/calamares/settings.conf" \
        || fail "settings.conf sin shellprocess@nimbus_installed en exec"
    # 5c. servicio live habilitado: el wants-symlink debe existir en el overlay
    # (systemd lo activa via preset/enable; sin symlink no arranca en el live):
    WANTS="$OVERLAY/etc/systemd/system/multi-user.target.wants/nimbus-live-setup.service"
    [ -L "$WANTS" ] || fail "falta symlink enable $WANTS"
    # 5c-bis. Display Manager del live: greetd con autologin a Hyprland
    # (sin esto no hay DM: el symlink plasmalogin de upstream lo crea su
    # prepare_profile, que este build no ejecuta).
    DM="$OVERLAY/etc/systemd/system/display-manager.service"
    [ -L "$DM" ] || fail "falta symlink DM $DM"
    [ "$(readlink "$DM")" = "/usr/lib/systemd/system/greetd.service" ] || fail "DM no apunta a greetd"
    grep -q 'initial_session' "$OVERLAY/etc/greetd/config.toml" || fail "greetd sin initial_session"
    grep -qx 'greetd' <(grep -vE '^\s*#' "$APPEND") || fail "greetd fuera de pacstrap"
    # macshell vendoreado en skel (barra/dock reales en el live/instalado):
    [ -f "$OVERLAY/etc/skel/.config/quickshell/MacShell/shell.qml" ] || fail "falta MacShell vendoreado en skel"
    [ -x "$OVERLAY/etc/skel/.local/bin/macshell-start" ] || fail "falta macshell-start ejecutable en skel"
    # 5d. fusion packages simulada: sin comentarios ni lineas vacias en el
    # resultado (el append trae secciones '# ...' que no deben contaminar
    # packages_desktop.x86_64):
    TMPD="$(mktemp -d)"
    printf 'mesa\nntfs-3g\n# upstream comment\n\nlinux-cachyos\n' > "$TMPD/upstream.pkgs"
    # AUR-skip repo-aware (igual que el path real): solo se excluyen los que
    # el repo local NO provee como binario:
    : > "$TMPD/aur-skip.pkgs"
    while IFS= read -r _aur || [ -n "$_aur" ]; do
        case "$_aur" in ''|\#*) continue ;; esac
        ls "$REPO_ROOT/work/nimbus-repo/${_aur}-"*.pkg.tar.zst >/dev/null 2>&1 || printf '%s\n' "$_aur" >> "$TMPD/aur-skip.pkgs"
    done < "$REPO_ROOT/packages.nimbus-aur.txt"
    grep -vE '^\s*#|^\s*$' "$APPEND" | grep -vxFf "$TMPD/upstream.pkgs" | grep -vxFf "$TMPD/aur-skip.pkgs" > "$TMPD/merged.pkgs"
    grep -qE '^\s*#' "$TMPD/merged.pkgs" && { rm -rf "$TMPD"; fail "fusion simulada deja comentarios"; }
    grep -qE '^\s*$' "$TMPD/merged.pkgs" && { rm -rf "$TMPD"; fail "fusion simulada deja lineas vacias"; }
    # AUR defer: los no proveidos por el repo no deben llegar a pacstrap;
    # los proveidos SI (binarios); paru (cachyos/oficial) siempre:
    while IFS= read -r _aur || [ -n "$_aur" ]; do
        case "$_aur" in ''|\#*) continue ;; esac
        if ls "$REPO_ROOT/work/nimbus-repo/${_aur}-"*.pkg.tar.zst >/dev/null 2>&1; then
            grep -qx "$_aur" "$APPEND" 2>/dev/null || { rm -rf "$TMPD"; fail "repo provee $_aur pero no esta en append"; }
        else
            grep -qx "$_aur" "$TMPD/merged.pkgs" && { rm -rf "$TMPD"; fail "fusion simulada deja AUR $_aur sin repo (debe ir a skipped-aur)"; }
        fi
    done < "$REPO_ROOT/packages.nimbus-aur.txt"
    grep -qx 'paru' "$TMPD/merged.pkgs" || { rm -rf "$TMPD"; fail "fusion simulada filtra paru (es cachyos/oficial, debe quedar)"; }
    # Manifest AUR presente y copiado al overlay:
    [ -f "$REPO_ROOT/packages.nimbus-aur.txt" ] || { rm -rf "$TMPD"; fail "falta packages.nimbus-aur.txt"; }
    [ -f "$OVERLAY/usr/share/nimbus/packages.nimbus-aur.txt" ] || { rm -rf "$TMPD"; fail "overlay sin usr/share/nimbus/packages.nimbus-aur.txt"; }
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
# 5a2. Conflictos overlay vs paquetes (pacstrap aborta si el fichero ya existe
# en airootfs y lo posee un paquete): cachyos-calamares-next posee
# etc/calamares/modules/{displaymanager,partition,users}.conf y
# cachyos-kde-settings posee etc/skel/.config/gtk-{3,4}.0/settings.ini.
# archiso no permite overwrite en pacstrap, asi que se mueven a staging
# (/usr/share/nimbus/staging/) y customize_airootfs.sh (post-pacstrap, root)
# los reinstala con overwrite. Idempotente: guards [ -f ].
STAGING="$AIROOTFS/usr/share/nimbus/staging"
for _cf in etc/calamares/modules/displaymanager.conf etc/calamares/modules/partition.conf etc/calamares/modules/users.conf etc/skel/.config/gtk-3.0/settings.ini etc/skel/.config/gtk-4.0/settings.ini; do
    if [ -f "$AIROOTFS/$_cf" ]; then
        mkdir -p "$STAGING/$(dirname "$_cf")"
        mv "$AIROOTFS/$_cf" "$STAGING/$_cf"
        echo "apply_overlay: staging $_cf (conflicto paquete diferido a customize_airootfs)"
    fi
done
# customize_airootfs.sh corre post-pacstrap como root y si puede sobrescribir:
# mkarchiso (>= este) lo busca en airootfs/root/customize_airootfs.sh
# (la raiz del perfil ya no se usa). El overlay ya lo trae en
# nimbus-overlay/root/ y cp -a lo deja en $AIROOTFS/root/; solo verificar:
[ -x "$AIROOTFS/root/customize_airootfs.sh" ] || fail "falta customize_airootfs.sh en airootfs/root"
# Higiene: la ubicacion antigua (raiz del perfil) ya no se usa; si quedo de
# un build previo, eliminarla para no confundir:
rm -f "$PROFILE_DIR/customize_airootfs.sh"
# 5b. Concatenar paquetes Nimbus al perfil desktop, deduplicando contra el
# perfil upstream (el append es append-only Task1-4; el solape conocido
# dosfstools exfatprogs mesa mtools noto-fonts ntfs-3g nvidia-utils se filtra
# aqui y se registra en el log):
mkdir -p "$OUTDIR"
grep -vE '^\s*#|^\s*$' "$APPEND" | sort -u > "$WORKDIR/append.pkgs"
grep -vE '^\s*#|^\s*$' "$PROFILE_DIR/packages_desktop.x86_64" | sort -u > "$WORKDIR/upstream.pkgs"
comm -12 "$WORKDIR/append.pkgs" "$WORKDIR/upstream.pkgs" > "$OUTDIR/skipped-dupes.txt" || true
# AUR defer (mkarchiso/pacstrap solo repos oficiales; pacman.conf sin repos
# propios): estas 4 NO estan en repos (audit AUR RPC v5 2026-10-23) y se
# instalan en primer arranque live via paru. Se filtran de pacstrap y se
# registran en out/skipped-aur.txt. paru SI es cachyos/oficial y debe quedar
# en pacstrap.
# propios): si el repo local [nimbus] (5d-bis) provee un paquete como binario,
# entra a pacstrap (rápido, sin compilar); solo los NO proveidos se difieren
# a live-setup via paru y se registran en out/skipped-aur.txt.
# paru SI es cachyos/oficial y debe quedar en pacstrap.
AUR_LIST="$WORKDIR/aur-skip.pkgs"
: > "$AUR_LIST"
_manifest="$REPO_ROOT/packages.nimbus-aur.txt"
if [ ! -f "$_manifest" ]; then
    printf 'whitesur-gtk-theme\nwhitesur-icon-theme\npamac-aur\nhyprshell\n' > "$_manifest.tmp"
    _manifest="$_manifest.tmp"
fi
while IFS= read -r _aur || [ -n "$_aur" ]; do
    case "$_aur" in ''|\#*) continue ;; esac
    if ls "$REPO_ROOT/work/nimbus-repo/${_aur}-"*.pkg.tar.zst >/dev/null 2>&1; then
        echo "apply_overlay: $_aur proveido por repo local [nimbus] (binario a pacstrap)"
    else
        printf '%s\n' "$_aur" >> "$AUR_LIST"
    fi
done < "$_manifest"
rm -f "$REPO_ROOT/packages.nimbus-aur.txt.tmp"
grep -xFf "$AUR_LIST" "$WORKDIR/append.pkgs" > "$OUTDIR/skipped-aur.txt" || true
# Solo paquetes (sin comentarios/vacias), deduplicados contra upstream y sin AUR.
# Idempotencia ante re-run: get_upstream ya hizo reset --hard $UPSTREAM_COMMIT
# antes de apply, asi que packages_desktop.x86_64 esta limpio. Si aun asi el
# marcador Nimbus ya esta presente (re-run sin get_upstream), restaurar desde
# git antes de concatenar para no duplicar el append:
if grep -q '# --- Task' "$PROFILE_DIR/packages_desktop.x86_64"; then
    git -C "$UPSTREAM_DIR" checkout -- archiso/packages_desktop.x86_64
fi
grep -vE '^\s*#|^\s*$' "$APPEND" | grep -vxFf "$WORKDIR/upstream.pkgs" | grep -vxFf "$AUR_LIST" \
    >> "$PROFILE_DIR/packages_desktop.x86_64"
echo "apply_overlay: solape upstream filtrado (ver $OUTDIR/skipped-dupes.txt) + AUR diferido (ver $OUTDIR/skipped-aur.txt)"
# 5c. Renombrar ISO + inyectar file_permissions (delta profiledef.nimbus.inc).
# Idempotente: sed solo si aun dice cachyos:
grep -q '^iso_name="cachyos"' "$PROFILE_DIR/profiledef.sh" \
    && sed -i -E 's/^iso_name="cachyos"/iso_name="nimbus"/' "$PROFILE_DIR/profiledef.sh"
grep -q '^iso_name="nimbus"' "$PROFILE_DIR/profiledef.sh" || fail "renombrado iso_name fallo"
if ! grep -q '"/usr/bin/macshell"' "$PROFILE_DIR/profiledef.sh"; then
python3 - "$PROFILE_DIR/profiledef.sh" <<'EOF'
import re, sys
path = sys.argv[1]
add = ['  ["/usr/bin/macshell"]="0:0:755"',
       '  ["/usr/bin/nimbus-live-setup"]="0:0:755"',
       '  ["/usr/bin/nimbus-minimize-toggle"]="0:0:755"',
       '  ["/usr/bin/nimbus-screenshot"]="0:0:755"',
       '  ["/usr/bin/nimbus-installed-setup"]="0:0:755"']
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
assert '/usr/bin/macshell' in blk and '/usr/bin/nimbus-live-setup' in blk and '/usr/bin/nimbus-minimize-toggle' in blk and '/usr/bin/nimbus-installed-setup' in blk
open(path, 'w').write(new)
print("profiledef.sh: file_permissions Nimbus inyectados (bloque anclado)")
EOF
fi
bash -n "$PROFILE_DIR/profiledef.sh" || fail "profiledef.sh roto tras parche"
# 5c-bis. Limitar hilos de mksquashfs: con 20 procesadores falla de forma
# reproducible (FATAL xz uncompress error 9 ~30-38% del squashfs); con 8
# pasa (verificado manual). mkarchiso reenvia airootfs_image_tool_options
# tal cual a mksquashfs, asi que el limite vive en el perfil.
# Idempotente: saltar si ya presente (re-run tras reset conserva el parche
# porque reset --hard solo afecta a archivos trackeados sin cambios... el
# parche se reaplica igual, el guard evita duplicados).
if ! grep -q "'-processors'" "$PROFILE_DIR/profiledef.sh"; then
    sed -i "s/'-Xdict-size' '1M')/'-Xdict-size' '1M' '-processors' '8')/" "$PROFILE_DIR/profiledef.sh"
fi
grep -q "'-processors' '8'" "$PROFILE_DIR/profiledef.sh" || fail "no se inyecto -processors 8 en tool_options"
bash -n "$PROFILE_DIR/profiledef.sh" || fail "profiledef.sh roto tras parche processors"
# 5d. mkarchiso lee packages.x86_64 (no packages_desktop.x86_64): el perfil
# upstream solo trae packages_desktop.x86_64 y su util-iso.sh prepare_profile
# hace cp packages_desktop.x86_64 -> packages.x86_64 antes de buildear.
# Sin este cp la lista queda vacia y falla con syslinux missing:
cp "$PROFILE_DIR/packages_desktop.x86_64" "$PROFILE_DIR/packages.x86_64"
[ -f "$PROFILE_DIR/packages.x86_64" ] || fail "no se genero packages.x86_64"
grep -q '^syslinux$' "$PROFILE_DIR/packages.x86_64" || fail "packages.x86_64 sin syslinux (lista incompleta)"
# 5d-bis. Repo local [nimbus] con AUR pre-compilados (scripts/build-aur-repo.sh
# genera work/nimbus-repo/). Si existe y esta completo, pacstrap instala
# binarios en segundos en vez de compilar en el live. Idempotente: get_upstream
# ya hizo reset --hard (pacman.conf vuelve a upstream), se reinyecta limpio.
# Sin repo o incompleto: se mantiene el defer a live-setup via paru (paso 5,
# filtrado por AUR_LIST mas abajo... ver 5b: el filtro excluye del pacstrap
# solo los que NO provee el repo).
if [ -f "$REPO_ROOT/work/nimbus-repo/nimbus.db.tar.gz" ]; then
    rm -rf "$PROFILE_DIR/nimbus-repo"
    cp -a "$REPO_ROOT/work/nimbus-repo" "$PROFILE_DIR/nimbus-repo"
    if ! grep -q '^\[nimbus\]' "$PROFILE_DIR/pacman.conf"; then
        python3 - "$PROFILE_DIR/pacman.conf" "$PROFILE_DIR/nimbus-repo" <<'EOF'
import sys
path, repodir = sys.argv[1], sys.argv[2]
src = open(path).read()
entry = ("[nimbus]\n"
         "SigLevel = Optional TrustAll\n"
         f"Server = file://{repodir}\n\n")
assert '[nimbus]' not in src
# Insertar ANTES del primer repo ([cachyos]) para precedencia:
idx = src.find('[cachyos]')
assert idx != -1, "pacman.conf sin [cachyos]"
open(path, 'w').write(src[:idx] + entry + src[idx:])
print("pacman.conf: repo local [nimbus] inyectado")
EOF
    fi
    grep -q '^\[nimbus\]' "$PROFILE_DIR/pacman.conf" || fail "no se inyecto [nimbus] en pacman.conf"
    echo "apply_overlay: repo local [nimbus] activo ($(ls "$PROFILE_DIR/nimbus-repo/"*.pkg.tar.zst | wc -l) paquetes)"
else
    echo "apply_overlay: sin repo local (work/nimbus-repo/nimbus.db.tar.gz ausente); AUR via live-setup"
fi
# 5d-ter. Compat Calamares/boost (desync upstream 2026-10-27): cachyos-calamares
# necesita libboost_*.so.1.91.0 y los repos solo dan 1.92 (ABI incompatible:
# NO valen symlinks, probado en VM). Puente temporal con TODAS las librerias
# versionadas 1.91 del archivo historico de Arch (solo *.so.1.91.0: sin
# symlinks dev ni .a, para no secuestrar -lboost_*). Se auto-desactiva:
# customize solo las instala si Calamares sigue pidiendo 1.91.
COMPAT_URL="https://archive.archlinux.org/packages/b/boost-libs/boost-libs-1.91.0-2-x86_64.pkg.tar.zst"
COMPAT_PKG="$WORKDIR/compat/$(basename "$COMPAT_URL")"
COMPAT_STAGE_DIR="$AIROOTFS/usr/share/nimbus/compat"
if [ "$CHECK_ONLY" = "1" ]; then
    echo "check-only: compat boost 1.91 (URL + staging simulados) OK"
else
    mkdir -p "$WORKDIR/compat"
    if [ ! -f "$COMPAT_PKG" ]; then
        curl -sSL -o "$COMPAT_PKG" "$COMPAT_URL" || fail "no se pudo descargar $COMPAT_URL"
    fi
    [ -s "$COMPAT_PKG" ] || fail "compat tarball vacio: $COMPAT_PKG"
    mkdir -p "$COMPAT_STAGE_DIR"
    _n_before="$(ls "$COMPAT_STAGE_DIR"/libboost_*.so.1.91.0 2>/dev/null | wc -l)"
    tar -xf "$COMPAT_PKG" -C "$WORKDIR/compat" --wildcards 'usr/lib/libboost_*.so.1.91.0' 2>/dev/null \
        || fail "el tarball no trae libs 1.91"
    cp "$WORKDIR/compat"/usr/lib/libboost_*.so.1.91.0 "$COMPAT_STAGE_DIR"/ \
        || fail "no se pudo preparar staging compat"
    _n_after="$(ls "$COMPAT_STAGE_DIR"/libboost_*.so.1.91.0 2>/dev/null | wc -l)"
    [ "$_n_after" -gt "$_n_before" ] || [ "$_n_after" -gt 0 ] || fail "compat staging vacio"
    echo "apply_overlay: compat boost 1.91 en staging ($_n_after libs, $(du -sh "$COMPAT_STAGE_DIR" | cut -f1))"
fi
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
# La imagen airootfs debe ser FRESCA de este build (no reutilizada ni ausente:
# 2026-10-27 dos builds solapados dejaron work/build sin imagen y el paso 7
# validaba una ISO vieja como PASS falso).
IMG_SFS="$BUILD_DIR/iso/arch/x86_64/airootfs.sfs"
IMG_ERO="$BUILD_DIR/iso/arch/x86_64/airootfs.erofs"
IMG=""
[ -f "$IMG_SFS" ] && IMG="$IMG_SFS"
[ -f "$IMG_ERO" ] && IMG="$IMG_ERO"
[ -n "$IMG" ] || fail "no se genero airootfs.{sfs,erofs} en $BUILD_DIR/iso/arch/x86_64/"
[ "$IMG" -nt "$LOCK" ] || fail "airootfs es anterior al inicio del build (resto corrupto)"
ISO="$(ls -t "$OUTDIR"/nimbus-*-x86_64.iso 2>/dev/null | head -1)"
[ -n "$ISO" ] || fail "no se genero out/nimbus-*-x86_64.iso"
[ "$ISO" -nt "$LOCK" ] || fail "$ISO es anterior al inicio del build (mkarchiso no produjo ISO nueva)"
sha256sum "$ISO" | tee "$ISO.sha256"
isoinfo -d -i "$ISO" | head -10
isoinfo -l -i "$ISO" | head -20
echo ""
echo "BUILD PASS: $ISO"
