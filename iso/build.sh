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
rm -rf "$WORK"/*
cp -r "$ROOT/iso/profiles/$PROFILE" "$WORK/profile"

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
  for pkgdir in "$ROOT"/packages/*/; do
    name="$(basename "$pkgdir")"
    [ -f "$pkgdir/PKGBUILD" ] || continue
    echo "[nimbus] compilando $name (log: $WORK/build-${name}.log)"
    # PKGDEST es la variable que dice a makepkg donde dejar el paquete.
    # Ojo: la opcion packagelist de makepkg NO construye nada, solo imprime
    # las rutas que se producirian.
    ( cd "$pkgdir" && PKGDEST="$REPO_DIR" makepkg --nodeps --noconfirm ) \
      >"$WORK/build-${name}.log" 2>&1
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
