#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

PROFILE="nimbus"
OUTDIR="."
LOCAL_REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --outdir) OUTDIR="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --local-repo) LOCAL_REPO="$2"; shift 2 ;;
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

mkdir -p "$WORK" "$OUTDIR"
rm -rf "$WORK"/*
cp -r "$ROOT/iso/profiles/$PROFILE" "$WORK/profile"

# Repo local de bootstrap: se compilan los PKGBUILDs de Nimbus y se sirven
# por file:// desde el árbol de trabajo, montado en la ISO en
# /run/archiso/bootmnt/nimbus-repo.
if [ -n "$LOCAL_REPO" ]; then
  REPO_DIR="$WORK/nimbus-repo"
  mkdir -p "$REPO_DIR"
  for pkgdir in "$ROOT"/packages/*/; do
    name="$(basename "$pkgdir")"
    [ -f "$pkgdir/PKGBUILD" ] || continue
    echo "[nimbus] compilando $name"
    ( cd "$pkgdir" && makepkg --nodeps --noconfirm --packagelist "$REPO_DIR" >/dev/null )
  done
  # pacman 7 exige una extension de archivo valida: repo-add crea
  # nimbus.db.tar.gz y el symlink nimbus.db -> nimbus.db.tar.gz.
  repo-add "$REPO_DIR/nimbus.db.tar.gz" "$REPO_DIR"/*.pkg.tar.*
  mkdir -p "$WORK/profile/overlay/run/archiso/bootmnt"
  cp -r "$REPO_DIR" "$WORK/profile/overlay/run/archiso/bootmnt/nimbus-repo"
fi

archiso -p "$WORK/profile" -O "$OUTDIR/$ISO_NAME"
echo "ISO construida: $OUTDIR/$ISO_NAME"
