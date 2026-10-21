#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Promueve paquetes de testing a stable: copia atómica, indexa y firma.
set -euo pipefail

FROM=""
TO=""
GPGDIR=""
KEY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --from)
      FROM="${2:-}"
      shift 2
      ;;
    --to)
      TO="${2:-}"
      shift 2
      ;;
    --gpgdir)
      GPGDIR="${2:-}"
      shift 2
      ;;
    --key)
      KEY="${2:-}"
      shift 2
      ;;
    *)
      echo "promote: opción desconocida: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$FROM" ] || [ -z "$TO" ] || [ -z "$GPGDIR" ] || [ -z "$KEY" ]; then
  echo "promote: se requieren --from, --to, --gpgdir y --key" >&2
  exit 1
fi

if [ ! -d "$FROM" ]; then
  echo "promote: no existe --from: $FROM" >&2
  exit 1
fi

mkdir -p "$TO"

if ! command -v repo-add >/dev/null 2>&1; then
  echo "repo-add no encontrado: instala el paquete repo" >&2
  exit 1
fi

shopt -s nullglob
_srcs=( "$FROM"/*.pkg.tar.* )
shopt -u nullglob

src_pkgs=()
for f in "${_srcs[@]}"; do
  [[ "$f" == *.sig ]] && continue
  src_pkgs+=("$f")
done

# Comprobación atómica: ninguna colisión antes de copiar nada.
for src in "${src_pkgs[@]}"; do
  base="$(basename "$src")"
  tmp="${base%.pkg.tar.*}"
  namever="${tmp%-*}"
  shopt -s nullglob
  _existing=( "$TO/$namever"-*.pkg.tar.* )
  shopt -u nullglob
  found=0
  for e in "${_existing[@]}"; do
    [[ "$e" == *.sig ]] && continue
    found=1
    break
  done
  if [ "$found" -eq 1 ]; then
    echo "el paquete $namever ya existe en el destino" >&2
    exit 1
  fi
done

for src in "${src_pkgs[@]}"; do
  cp -- "$src" "$TO/"
done

# Firma los paquetes del destino con la clave offline. La CI compila sin
# firmar; la firma ocurre aquí, en el acto manual de promoción.
shopt -s nullglob
_all=( "$TO"/*.pkg.tar.* )
shopt -u nullglob
for pkg in "${_all[@]}"; do
  [[ "$pkg" == *.sig ]] && continue
  if [ ! -f "$pkg.sig" ]; then
    gpg --homedir "$GPGDIR" --batch --yes --local-user "$KEY" --detach-sign "$pkg"
  fi
done

# Regenera la DB desde cero (repo-add incremental falla si se le pasan
# paquetes ya indexados) y firma el resultado.
shopt -s nullglob
_all2=( "$TO"/*.pkg.tar.* )
shopt -u nullglob
pkgs=()
for f in "${_all2[@]}"; do
  [[ "$f" == *.sig ]] && continue
  pkgs+=("$f")
done

rm -f "$TO"/nimbus.db "$TO"/nimbus.db.tar.gz "$TO"/nimbus.files "$TO"/nimbus.files.tar.gz "$TO"/nimbus.db.sig "$TO"/nimbus.db.tar.gz.sig "$TO"/*.old

if [ ${#pkgs[@]} -gt 0 ]; then
  repo-add "$TO/nimbus.db.tar.gz" "${pkgs[@]}"
else
  tar -czf "$TO/nimbus.db.tar.gz" --files-from /dev/null
  ln -sf nimbus.db.tar.gz "$TO/nimbus.db"
fi

rm -f "$TO"/*.old
rm -f "$TO"/nimbus.db.sig

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/sign_repo.sh" --repo "$TO" --gpgdir "$GPGDIR" --key "$KEY"
