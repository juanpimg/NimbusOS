#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Constructor de la ISO de Nimbus (archiso 91, mkarchiso).
#
# Uso: build.sh [--outdir <dir>] [--profile <nombre>] [--local-repo]
#
#   --outdir <dir>   destino de la ISO (por defecto: .).
#   --profile <name> perfil bajo iso/profiles/ (por defecto: nimbus).
#   --local-repo     bandera sin argumento: compila los PKGBUILDs de packages/
#                    con makepkg y los sirve a la imagen como repo local file://.
#                    El directorio del repo se deriva del directorio de trabajo
#                    (iso/work/nimbus-repo). Imprescindible durante el bootstrap,
#                    porque el repo `nimbus` aun no esta alojado en ningun servidor
#                    y sin el `nimbus-shell` no se puede resolver.
#
# El perfil sigue el formato declarativo de archiso 91: profiledef.sh,
# packages.x86_64, bootstrap_packages, pacman.conf, airootfs/, syslinux/ y
# grub/. La invocacion es la CLI nueva:
#   mkarchiso -m iso -o "$OUTDIR" -w "$WORK" "$WORK/profile"
set -euo pipefail

PROFILE="nimbus"
OUTDIR="."
LOCAL_REPO=0

while [ $# -gt 0 ]; do
  case "$1" in
    --outdir) OUTDIR="${2:?falta el valor de --outdir}"; shift 2 ;;
    --profile) PROFILE="${2:?falta el valor de --profile}"; shift 2 ;;
    --local-repo) LOCAL_REPO=1; shift ;;
    *) echo "opción desconocida: $1" >&2; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/iso/work"

# La cache de pacman del perfil (CacheDir) es la MISMA para todas las
# builds: /tmp/nimbus-pacman-cache. Dos builds a la vez se pisan la cache a
# medias y aparecen errores que parecen de confianza ("signature is invalid",
# "keyring is not writable") pero no son de confianza: son corrupcion. Un
# flock serializa las builds que comparten cache.
NIMBUS_BUILD_LOCK="${NIMBUS_BUILD_LOCK:-/tmp/nimbus-build.lock}"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$NIMBUS_BUILD_LOCK"
  if ! flock -n 9; then
    echo "hay otra build de Nimbus en marcha (bloqueo $NIMBUS_BUILD_LOCK)." >&2
    echo "espera a que termine, o usa NIMBUS_BUILD_LOCK=<otro fichero>." >&2
    exit 1
  fi
fi

# Punto de montaje del repo nimbus DENTRO de la ISO arrancada. Esta ruta es un
# contrato: tiene que coincidir exactamente con el `Server = file://...` de la
# seccion [nimbus] del pacman.conf del perfil.
NIMBUS_REPO_MOUNT="/run/archiso/bootmnt/nimbus-repo"

if [ ! -f "$ROOT/iso/profiles/$PROFILE/profiledef.sh" ]; then
  echo "perfil no encontrado: $PROFILE" >&2
  exit 1
fi

command -v mkarchiso >/dev/null || {
  echo "mkarchiso no está instalado: instala el paquete archiso para construir la ISO" >&2
  exit 1
}
command -v mksquashfs >/dev/null || {
  echo "mksquashfs no está instalado: instala el paquete squashfs-tools para construir la ISO" >&2
  exit 1
}

mkdir -p "$WORK" "$OUTDIR"
# La guarda ${WORK:?} es lo que evita el SC2115: si WORK estuviera vacio,
# `rm -rf "$WORK"/*` seria `rm -rf /*`. Con la guarda, el script aborta.
rm -rf -- "${WORK:?}"/*
cp -r "$ROOT/iso/profiles/$PROFILE" "$WORK/profile"

# La sesion live lee la config de Hyprland del home del usuario nimbus
# (~/.config/hypr/hyprland.lua). El origen real es dots/hypr/ del repo: se
# copia en tiempo de build sobre el perfil staged para que el airootfs nunca
# lleve una segunda copia desincronizada.
mkdir -p "$WORK/profile/airootfs/home/nimbus/.config/hypr"
cp "$ROOT/dots/hypr/hyprland.lua" \
  "$WORK/profile/airootfs/home/nimbus/.config/hypr/hyprland.lua"

# Repo local de bootstrap: se compilan los PKGBUILDs de Nimbus y se sirven
# por file:// desde el host durante pacstrap. El pacman.conf del perfil
# declara el repo en su punto de montaje dentro de la ISO, asi que se
# reescribe SOLO la copia staged con la ruta del host.
keyring_cleanup=0
cleanup_keyring_fallback() {
  if [ "$keyring_cleanup" -eq 1 ]; then
    rm -f "$ROOT/packages/nimbus-keyring/nimbus.gpg" \
          "$ROOT/packages/nimbus-keyring/nimbus-trusted" \
          "$ROOT/packages/nimbus-keyring/nimbus-revoked"
  fi
}
trap cleanup_keyring_fallback EXIT
if [ "$LOCAL_REPO" -eq 1 ]; then
  command -v makepkg >/dev/null || {
    echo "makepkg no está instalado: instala pacman para compilar los paquetes" >&2
    exit 1
  }
  command -v repo-add >/dev/null || {
    echo "repo-add no está instalado: instala pacman para indexar el repo local" >&2
    exit 1
  }
  # El paquete nimbus-keyring necesita sus fuentes (nimbus.gpg, nimbus-trusted,
  # nimbus-revoked). Si el keyring de produccion aun no esta en packages/
  # (se genera fuera del repo con tools/genkeyring.sh), se usan las de
  # bootstrap del perfil como apaño temporal y se limpian al salir, para no
  # dejar rastro en un arbol que no es nuestro.
  if [ ! -f "$ROOT/packages/nimbus-keyring/nimbus.gpg" ]; then
    cp "$WORK/profile/airootfs/usr/share/pacman/keyrings/nimbus.gpg" \
       "$WORK/profile/airootfs/usr/share/pacman/keyrings/nimbus-trusted" \
       "$WORK/profile/airootfs/usr/share/pacman/keyrings/nimbus-revoked" \
       "$ROOT/packages/nimbus-keyring/"
    keyring_cleanup=1
  fi
  # El airootfs staged lleva siempre los ficheros que de verdad se empaquetan.
  mkdir -p "$WORK/profile/airootfs/usr/share/pacman/keyrings"
  cp "$ROOT/packages/nimbus-keyring/nimbus.gpg" \
     "$ROOT/packages/nimbus-keyring/nimbus-trusted" \
     "$ROOT/packages/nimbus-keyring/nimbus-revoked" \
     "$WORK/profile/airootfs/usr/share/pacman/keyrings/"
  REPO_DIR="$WORK/nimbus-repo"
  mkdir -p "$REPO_DIR"
  # makepkg se NIEGA a correr como root, y con razon: evitar danios. Pero el
  # build normal corre con root (archiso tiene que montar un chroot), asi que
  # la compilacion de los paquetes se delega al usuario que lanzo el build.
  PKGBUILD_USER=""
  if [ "$(id -u)" -eq 0 ]; then
    PKGBUILD_USER="${SUDO_USER:-${NIMBUS_BUILD_USER:-}}"
    if [ -z "$PKGBUILD_USER" ] || ! id "$PKGBUILD_USER" >/dev/null 2>&1; then
      echo "el build corre como root y no se sabe con que usuario compilar los paquetes." >&2
      echo "lanzalo con sudo (SUDO_USER) o define NIMBUS_BUILD_USER." >&2
      exit 1
    fi
    chown "$PKGBUILD_USER" "$REPO_DIR"
  fi
  # BUILDDIR redirige los directorios de trabajo de makepkg (src/, pkg/)
  # fuera del arbol: el build no deja rastro en packages/.
  for pkgdir in "$ROOT"/packages/*/; do
    name="$(basename "$pkgdir")"
    [ -f "$pkgdir/PKGBUILD" ] || continue
    echo "[nimbus] compilando $name (log: $WORK/build-${name}.log)"
    # PKGDEST es la variable que dice a makepkg donde dejar el paquete.
    # Ojo: la opcion de makepkg que solo *lista* las rutas NO construye nada;
    # hay que dejar que makepkg construya de verdad.
    if [ -n "$PKGBUILD_USER" ]; then
      # Se compila EN SU SITIO: los PKGBUILDs usan rutas relativas al monorepo
      # ($startdir/../..), asi que copiar el directorio los romperia. Solo se
      # da permiso de escritura a los directorios que makepkg necesita.
      mkdir -p "$WORK/mkpkg/$name"
      chown -R "$PKGBUILD_USER" "$WORK/mkpkg/$name" "$REPO_DIR"
      # makepkg EXIGE que su directorio de trabajo sea escribible ("No tiene
      # permisos de escritura en la carpeta \$SRCDEST" y sale con codigo 11).
      # En la CI el checkout es de root y makepkg corre como otro usuario, asi
      # que hay que abrir permisos temporalmente y devolverlos al final.
      pkg_mode="$(stat -c '%a' "$pkgdir")"
      chmod a+w "$pkgdir"
      if ! ( cd "$pkgdir" && sudo -u "$PKGBUILD_USER" \
          env BUILDDIR="$WORK/mkpkg/$name" PKGDEST="$REPO_DIR" \
          makepkg --nodeps --noconfirm ) \
        >"$WORK/build-${name}.log" 2>&1; then
        chmod "$pkg_mode" "$pkgdir"
        # Sin esto el fallo se tragaba: makepkg escribia en su log, el bucle
        # continuaba y la CI moria con un codigo de salida sin explicar nada.
        echo "[nimbus] FALLO al compilar $name" >&2
        echo "[nimbus] --- ultimas lineas de $WORK/build-${name}.log ---" >&2
        tail -n 40 "$WORK/build-${name}.log" >&2
        exit 1
      fi
      chmod "$pkg_mode" "$pkgdir"
    else
      if ! ( cd "$pkgdir" && BUILDDIR="$WORK/mkpkg/$name" PKGDEST="$REPO_DIR" \
          makepkg --nodeps --noconfirm ) \
        >"$WORK/build-${name}.log" 2>&1; then
        echo "[nimbus] FALLO al compilar $name" >&2
        echo "[nimbus] --- ultimas lineas de $WORK/build-${name}.log ---" >&2
        tail -n 40 "$WORK/build-${name}.log" >&2
        exit 1
      fi
    fi
  done
  # Si no ha salido ningun paquete, el repo local quedaria vacio y la ISO no
  # podria resolver nimbus-shell. Falla aqui, de forma ruidosa.
  compgen -G "$REPO_DIR/*.pkg.tar.*" >/dev/null || {
    echo "no se ha construido ningun paquete en $REPO_DIR" >&2
    echo "revisa los logs de compilación en $WORK/build-*.log" >&2
    exit 1
  }
  # pacman 7 exige una extension de archivo valida: repo-add crea
  # nimbus.db.tar.gz y el symlink nimbus.db -> nimbus.db.tar.gz.
  repo-add "$REPO_DIR/nimbus.db.tar.gz" "$REPO_DIR"/*.pkg.tar.*
  sed -i "s|Server = file://${NIMBUS_REPO_MOUNT}|Server = file://${REPO_DIR}|" \
    "$WORK/profile/pacman.conf"
  grep -q "Server = file://${REPO_DIR}" "$WORK/profile/pacman.conf" || {
    echo "no se pudo reescribir el repo local en $WORK/profile/pacman.conf" >&2
    exit 1
  }
fi

mkarchiso -m iso -o "$OUTDIR" -w "$WORK" "$WORK/profile"
echo "ISO construida en: $OUTDIR"
