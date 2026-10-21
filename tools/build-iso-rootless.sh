#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Construye la ISO de Nimbus SIN root.
#
# Por qué existe esto: `archiso` necesita montar un chroot, y `pacstrap` monta
# devtmpfs y sysfs, cosa que el kernel no permite dentro de un user namespace
# salvo que /dev y /sys esten "totalmente visibles". En una maquina de
# desarrollo normal esto obliga a `sudo`.
#
# La solucion es:
#   1. Descargar `archiso`, `squashfs-tools` y `arch-install-scripts` del
#      mirror y extraerlos a un prefijo local (sin instalar nada).
#   2. Parchar las copias locales de `pacstrap` y `makepkg` para que funcionen
#      dentro de un user namespace.
#   3. Ejecutar el build dentro de un user namespace con el maximo mapeo de
#      uids disponible (doble rango si newuidmap es operativo, si no el root
#      de la maquina; ver el comentario sobre MAP_ARGS mas abajo).
#
# En el CI (GitHub Actions, contenedor con root) NO hace falta nada de esto:
# ahi se instala `archiso` con pacman y se construye con normalidad. Este
# script es una comodidad para maquinas de desarrollo y para hardening.
#
# Uso:
#   tools/build-iso-rootless.sh [--outdir <dir>] [--keep]
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${NIMBUS_ROOTLESS_PREFIX:-${TMPDIR:-/tmp}/nimbus-rootless}"
OUTDIR="$ROOT/out"
KEEP=0
MIRROR="https://archlinux.cachyos.org/repo/extra/os/x86_64"
SYNC_DB="/var/lib/pacman/sync/extra.db"

while [ $# -gt 0 ]; do
  case "$1" in
    --outdir) OUTDIR="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    *) echo "opción desconocida: $1" >&2; exit 1 ;;
  esac
done

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -f "$SYNC_DB" ] || die "no se encuentra la base de datos de sincronizacion en $SYNC_DB (ejecuta: sudo pacman -Sy)"

# --- 1. Descargar y extraer las herramientas de build a un prefijo local ---
mkdir -p "$PREFIX/pacman-cache" "$PREFIX/prefix" "$PREFIX/db"

if [ ! -x "$PREFIX/prefix/usr/bin/mkarchiso" ] || [ ! -x "$PREFIX/prefix/usr/bin/xorriso" ]; then
  log "Extrayendo el perfil de base de datos de pacman"
  bsdtar -xf "$SYNC_DB" -C "$PREFIX/db" 2>/dev/null || true

  for pkg in archiso squashfs-tools arch-install-scripts libburn libisofs libisoburn; do
    # find en vez de ls: `ls -d` con glob no es seguro con nombres poco
    # ascii (shellcheck SC2012), y find no necesita el glob.
    dir="$(find "$PREFIX/db" -maxdepth 1 -type d -name "${pkg}-*" -print -quit 2>/dev/null)"
    [ -n "$dir" ] || die "el paquete $pkg no aparece en la base de datos"
    file="$(grep -A1 '^%FILENAME%$' "$dir/desc" | tail -1)"
    [ -n "$file" ] || die "no se encuentra el nombre de fichero de $pkg"
    if [ ! -f "$PREFIX/pacman-cache/$file" ]; then
      log "Descargando $file"
      curl -fsSL -o "$PREFIX/pacman-cache/$file" "$MIRROR/$file" \
        || die "no se puede descargar $file de $MIRROR"
    fi
  done

  log "Extrayendo los paquetes"
  for f in "$PREFIX"/pacman-cache/*.pkg.tar.zst; do
    bsdtar -xf "$f" -C "$PREFIX/prefix" 2>/dev/null || true
  done
fi

[ -x "$PREFIX/prefix/usr/bin/mkarchiso" ] || die "mkarchiso no esta en el prefijo local"

# --- 2. Parchar las copias locales para que funcionen sin root ---
patch_pacstrap() {
  local p="$PREFIX/prefix/usr/bin/pacstrap"
  [ -f "$p" ] || die "pacstrap no encontrado en el prefijo"
  # Version del parche. Si cambia, el pacstrap parcheado se regenera desde el
  # original: un chequeo de idempotencia mas grueso (por ejemplo, buscar solo
  # una cadena) se saltaba el parcheo y las correcciones nuevas NUNCA se
  # aplicaban, con lo que el build fallaba por causas ya resueltas.
  local patch_version=4
  # Reparar prefijos donde un parche anterior dejo el marcador en la linea 1,
  # rompiendo el shebang: env recaia a /bin/sh (modo posix) y el `trap -p`
  # de pacstrap fallaba de forma espuria.
  if [ "$(head -1 "$p")" = "# NIMBUS_ROOTLESS_PATCH" ] && [ -f "$p.orig" ]; then
    cp "$p.orig" "$p"
  fi
  # Si el parche aplicado es de otra version, se regenera desde el original.
  if [ -f "$p.orig" ] && ! grep -q "^# NIMBUS_ROOTLESS_PATCH_V${patch_version}$" "$p"; then
    cp "$p.orig" "$p"
  fi
  if grep -q "^# NIMBUS_ROOTLESS_PATCH_V${patch_version}$" "$p"; then
    return 0
  fi
  cp "$p" "$p.orig"

  python3 - "$p" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
subs = [
    # devtmpfs no se puede montar en un user namespace: se usa tmpfs y se
    # enlazan los nodos de dispositivo que si se pueden enlazar.
    ('''  chroot_add_mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid &&''',
     '''  chroot_add_mount udev "$1/dev" -t tmpfs -o mode=0755,nosuid &&
  for _dn in null zero full random urandom tty; do
    touch "$1/dev/$_dn" && mount --bind "/dev/$_dn" "$1/dev/$_dn"
  done &&
  mkdir -p "$1/dev/pts" "$1/dev/shm" "$1/dev/mqueue" &&'''),
    # En el user namespace solo hay un gid mapeado (0), asi que gid=5 no existe.
    ('-t devpts -o mode=0620,gid=5,nosuid,noexec &&', '-t devpts -o mode=0620,gid=0,nosuid,noexec &&'),
    # /run: un bind del /run del host no se puede montar en un user namespace
    # (tiene submontajes "locked"), pero un tmpfs limpio si. Y hace FALTA:
    # gpg-agent necesita un runtime dir, y sin el, `pacman-key --populate`
    # falla con "keyring is not writable" y aborta la transaccion.
    ('''  chroot_add_mount /run "$1/run" --bind --make-private &&''',
     '''  chroot_add_mount run "$1/run" -t tmpfs -o mode=0755,nosuid,nodev &&
  # El paquete `filesystem` instala /etc/resolv.conf como symlink a
  # /run/systemd/resolve/stub-resolv.conf (el stub de systemd-resolved). Con
  # /run como tmpfs ese stub no existe y el symlink queda colgando: el chroot
  # se queda SIN nameservers y todas las descargas fallan con
  # "Resolving timed out after 10000 milliseconds". Se crea el stub aqui, antes
  # de que se extraiga `filesystem`, para que el symlink resuelva.
  mkdir -p "$1/run/systemd/resolve" &&
  printf 'nameserver 1.1.1.1\\nnameserver 9.9.9.9\\noptions timeout:2 attempts:3\\n' \\
    > "$1/run/systemd/resolve/stub-resolv.conf" &&'''),
    ('''  chroot_add_mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro &&''', '''  true &&'''),
    # Los mountpoints deben ser directorios reales, no symlinks.
    ('''  chroot_add_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&''',
     '''  rm -f "$1/run" "$1/proc" "$1/sys" "$1/tmp" 2>/dev/null
  mkdir -p "$1/run" "$1/proc" "$1/sys" "$1/tmp" &&
  chroot_add_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&'''),
    # Los hooks de alpm (p. ej. mkinitcpio) leen de /dev/stdin: sin estos
    # enlaces el preset del kernel no se genera y la ISO queda sin initramfs.
    # Es el mismo juego de enlaces que el unshare_setup original.
    ('''  mkdir -p "$1/dev/pts" "$1/dev/shm" "$1/dev/mqueue" &&''',
     '''  mkdir -p "$1/dev/pts" "$1/dev/shm" "$1/dev/mqueue" &&
  ln -sf /proc/self/fd "$1/dev/fd" &&
  ln -sf /proc/self/fd/0 "$1/dev/stdin" &&
  ln -sf /proc/self/fd/1 "$1/dev/stdout" &&
  ln -sf /proc/self/fd/2 "$1/dev/stderr" &&'''),
]
for a, b in subs:
    if a not in s:
        sys.exit("pacstrap: no se encuentra el patron:\n" + a)
    s = s.replace(a, b, 1)
# El marcador va DETRAS del shebang: delante lo romperia y env recaeria a
# /bin/sh (modo posix), donde `trap -p EXIT` imprime de forma espuria y
# pacstrap aborta con "(BUG): attempting to overwrite existing EXIT trap".
lines = s.split("\n")
assert lines[0].startswith("#!"), "pacstrap: sin shebang en la linea 1"
lines.insert(1, "# NIMBUS_ROOTLESS_PATCH_V4")
s = "\n".join(lines)
io.open(p, "w", encoding="utf-8").write(s)
PY
  log "pacstrap parcheado para user namespace"
}

patch_makepkg() {
  local p="$PREFIX/prefix/usr/bin/makepkg"
  # makepkg viene del paquete `pacman`, que no se extrae al prefijo: se copia
  # el del host y se parcha. Sin esto el build muere aqui en un prefijo nuevo.
  if [ ! -f "$p" ]; then
    cp /usr/bin/makepkg "$p" || die "makepkg no encontrado en el host"
  fi
  grep -q "NIMBUS_ALLOW_ROOT" "$p" && return 0
  cp /usr/bin/makepkg "$p"
  python3 - "$p" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
old = "\tif (( EUID == 0 )); then\n\t\terror \"$(gettext \"Running %s as root is not allowed"
new = "\tif (( EUID == 0 )) && [[ -z ${NIMBUS_ALLOW_ROOT:-} ]]; then\n\t\terror \"$(gettext \"Running %s as root is not allowed"
if old not in s:
    sys.exit("makepkg: no se encuentra la comprobacion de root")
io.open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
  log "makepkg parcheado para permitir NIMBUS_ALLOW_ROOT=1"
}

patch_mkarchiso() {
  local p="$PREFIX/prefix/usr/bin/mkarchiso"
  [ -f "$p" ] || die "mkarchiso no encontrado en el prefijo"
  grep -q "NIMBUS_ROOTLESS_MKARCHISO" "$p" && return 0
  cp "$p" "$p.orig" 2>/dev/null || true

  python3 - "$p" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
# Tolerar el chown al usuario live cuando el namespace no mapea su uid
# (un solo rango: solo el 0 interior existe). Sin el mapeo completo el
# install/chown a uid!=0 falla con EINVAL y `set -e` aborta el build.
# Con mapeo completo las primarias tienen exito y la imagen es identica a
# la de CI; sin el, los rescates dejan un home root:root 0755 que basta
# para que la sesion live arranque en desarrollo.
# NIMBUS_ROOTLESS_MKARCHISO
subs = [
    ('''_unshare install -d -m 0750 -o "${passwd[2]}" -g "${passwd[3]}" -- "${pacstrap_dir}${passwd[5]}"''',
     '''_unshare install -d -m 0750 -o "${passwd[2]}" -g "${passwd[3]}" -- "${pacstrap_dir}${passwd[5]}" || _unshare install -d -m 0755 -- "${pacstrap_dir}${passwd[5]}"'''),
    ('''_unshare cp -dRT --update=none --preserve=mode,timestamps,links -- "${pacstrap_dir}/etc/skel/." "${pacstrap_dir}${passwd[5]}"''',
     '''_unshare cp -dRT --update=none --preserve=mode,timestamps,links -- "${pacstrap_dir}/etc/skel/." "${pacstrap_dir}${passwd[5]}" || true'''),
    ('''_unshare chmod -f 0750 -- "${pacstrap_dir}${passwd[5]}"''',
     '''_unshare chmod -f 0750 -- "${pacstrap_dir}${passwd[5]}" || true'''),
    ('''_unshare chown -hR -- "${passwd[2]}:${passwd[3]}" "${pacstrap_dir}${passwd[5]}"''',
     '''_unshare chown -hR -- "${passwd[2]}:${passwd[3]}" "${pacstrap_dir}${passwd[5]}" || _unshare chmod -f 0755 -- "${pacstrap_dir}${passwd[5]}"'''),
]
for a, b in subs:
    if a not in s:
        sys.exit("mkarchiso: no se encuentra el patron:\n" + a)
    s = s.replace(a, b, 1)
io.open(p, "w", encoding="utf-8").write(s)
PY
  log "mkarchiso parcheado para tolerar el home sin mapeo completo de uids"
}

patch_pacstrap
patch_makepkg
patch_mkarchiso

# --- 3. Construir la ISO dentro del namespace ---

# Cerrojo: dos builds sobre la misma cache de paquetes se pisan (uno renombra
# el .part que el otro va a renombrar y aparece "could not rename ...: No such
# file or directory"). flock serializa los builds que compartan prefijo.
LOCKFILE="$PREFIX/build.lock"
exec 9>"$LOCKFILE"
if command -v flock >/dev/null 2>&1; then
  if ! flock -n 9; then
    die "ya hay otro build en marcha con este prefijo (bloqueo en $LOCKFILE)"
  fi
fi
mkdir -p "$OUTDIR"
log "Construyendo la ISO (sin root) en $OUTDIR"
set +e
# Dos rangos de uid: el 0 interior (root) se mapea a nuestro usuario real, y
# el 1000 interior (el usuario de la sesion live) se mapea al rango de
# /etc/subuid. Con un solo rango no se puede hacer chown al uid 1000 y la
# construccion falla con "cannot change owner of .../home/nimbus".
# El doble rango exige un newuidmap operativo; si la maquina no lo tiene
# (p. ej. sin bit setuid), se usa un solo rango y el parche de mkarchiso
# deja un home temporal que basta para desarrollo.
SUBUID="$(awk -F: -v u="$(id -un)" '$1==u {print $2; exit}' /etc/subuid 2>/dev/null)"
SUBGID="$(awk -F: -v u="$(id -un)" '$1==u {print $2; exit}' /etc/subgid 2>/dev/null)"
MAP_ARGS=(--map-root-user)
if [ -n "$SUBUID" ] && [ -n "$SUBGID" ] \
   && unshare --user --map-users=0:"$(id -u)":1 --map-users=1000:"$SUBUID":1 \
              --map-groups=0:"$(id -g)":1 --map-groups=1000:"$SUBGID":1 \
              --mount true 2>/dev/null; then
  log "namespace con doble rango de uids (chown al usuario live disponible)"
  # El rango interno debe cubrir TODOS los uids/gids, no solo 0 y 1000+: los
  # paquetes de Arch usan gids tipicos (42 utmp, 102 tpm2-tss, 999 systemd-journal)
  # y un fchownat a un gid sin mapear falla con "Invalid argument", que hacia
  # fallar los hooks de post-transaccion (systemd-sysusers, systemd-tmpfiles) y
  # con ellos el hook de mkinitcpio que construye el initramfs.
  MAP_ARGS=(--map-users=0:"$(id -u)":1 --map-users=1:"$SUBUID":65535
            --map-groups=0:"$(id -g)":1 --map-groups=1:"$SUBGID":65535)
else
  log "namespace con un solo rango (el home del live sera temporal)"
fi

# Resolver DNS para el namespace: resolvers directos con timeout corto, en
# lugar del stub de systemd-resolved que se satura con las descargas paralelas.
# Se puede cambiar con NIMBUS_DNS (lista de IPs separadas por espacios).
RESOLV_CONF="$PREFIX/resolv-nimbus.conf"
mkdir -p "$PREFIX"
{
  for ip in ${NIMBUS_DNS:-1.1.1.1 9.9.9.9}; do
    printf 'nameserver %s\n' "$ip"
  done
  printf 'options timeout:2 attempts:3\n'
} > "$RESOLV_CONF"

# SC2016: las comillas simples del `bash -c` son INTENCIONALES: el script
# que se pasa se ejecuta dentro del chroot y sus ${...} deben expandirse
# alli, no en el host.
# shellcheck disable=SC2016
unshare --user "${MAP_ARGS[@]}" \
        --mount --pid --fork --mount-proc --ipc --uts \
  env NIMBUS_ALLOW_ROOT=1 \
      LD_LIBRARY_PATH="$PREFIX/prefix/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
      PATH="$PREFIX/prefix/usr/bin:$PATH" \
      NIMBUS_RESOLV_CONF="$RESOLV_CONF" \
      bash -c '
        # Resolver DNS estable. El stub de systemd-resolved (127.0.0.53) se
        # satura con las descargas paralelas del build y acaba con
        # "Resolving timed out after 10000 milliseconds", que aborta la
        # transaccion de pacman a mitad. Un resolv.conf con resolvers
        # directos y timeout corto aguanta la carga.
        if [ -n "${NIMBUS_RESOLV_CONF:-}" ] && [ -f "${NIMBUS_RESOLV_CONF}" ]; then
          mount --bind "${NIMBUS_RESOLV_CONF}" /etc/resolv.conf 2>/dev/null \
            || echo "aviso: no se pudo montar el resolv.conf propio; se usa el del host" >&2
        fi
        exec bash "$0" --outdir "$1" --local-repo
      ' "$ROOT/iso/build.sh" "$OUTDIR"
status=$?
set -e

if [ "$status" -ne 0 ]; then
  die "la construccion de la ISO fallo con codigo $status"
fi

log "ISO construida:"
ls -la "$OUTDIR"/*.iso 2>/dev/null || die "no se ha encontrado ninguna ISO en $OUTDIR"

if [ "$KEEP" -eq 0 ]; then
  log "Limpiando el directorio de trabajo (usa --keep para conservarlo)"
  rm -rf "$ROOT/iso/work"
fi
