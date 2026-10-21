#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Constructor de la ISO de Nimbus.
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
DATE="$(date +%Y%m%d)"
SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
ISO_NAME="nimbus-${DATE}-${SHA}.iso"

if [ ! -f "$ROOT/iso/profiles/$PROFILE/airoot.sh" ]; then
  echo "perfil no encontrado: $PROFILE" >&2
  exit 1
fi

command -v archiso >/dev/null || {
  echo "archiso no está instalado: instala el paquete archiso para construir la ISO" >&2
  exit 1
}

mkdir -p "$WORK" "$OUTDIR"
rm -rf "$WORK"/*
cp -r "$ROOT/iso/profiles/$PROFILE" "$WORK/profile"

# Repo local de bootstrap: se compilan los PKGBUILDs de Nimbus y se sirven
# por file:// desde el árbol de trabajo, montado en la ISO en
# /run/archiso/bootmnt/nimbus-repo.
if [ "$LOCAL_REPO" -eq 1 ]; then
  command -v makepkg >/dev/null || {
    echo "makepkg no está instalado: instala pacman para compilar los paquetes" >&2
    exit 1
  }
  command -v repo-add >/dev/null || {
    echo "repo-add no está instalado: instala pacman para indexar el repo local" >&2
    exit 1
  }
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
  mkdir -p "$WORK/profile/overlay/run/archiso/bootmnt"
  cp -r "$REPO_DIR" "$WORK/profile/overlay/run/archiso/bootmnt/nimbus-repo"
fi

archiso -p "$WORK/profile" -O "$OUTDIR/$ISO_NAME"
echo "ISO construida: $OUTDIR/$ISO_NAME"
