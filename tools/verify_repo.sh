#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Verifica las firmas GPG de la DB y de cada paquete de un repo pacman.
set -euo pipefail

REPO=""
GPGDIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --gpgdir)
      GPGDIR="${2:-}"
      shift 2
      ;;
    *)
      echo "verify_repo: opción desconocida: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$REPO" ] || [ -z "$GPGDIR" ]; then
  echo "verify_repo: se requieren --repo y --gpgdir" >&2
  exit 1
fi

failures=()

if [ ! -f "$REPO/nimbus.db" ]; then
  failures+=("falta la base de datos: $REPO/nimbus.db")
elif [ ! -f "$REPO/nimbus.db.sig" ]; then
  failures+=("falta la firma de la DB: $REPO/nimbus.db.sig")
else
  if ! gpg --homedir "$GPGDIR" --batch --verify "$REPO/nimbus.db.sig" "$REPO/nimbus.db" >/dev/null 2>&1; then
    failures+=("firma de la DB inválida: $REPO/nimbus.db")
  fi
fi

shopt -s nullglob
_all=( "$REPO"/*.pkg.tar.* )
shopt -u nullglob

pkgs=()
for f in "${_all[@]}"; do
  [[ "$f" == *.sig ]] && continue
  pkgs+=("$f")
done

for pkg in "${pkgs[@]}"; do
  if [ ! -f "$pkg.sig" ]; then
    failures+=("falta la firma: $pkg")
  elif ! gpg --homedir "$GPGDIR" --batch --verify "$pkg.sig" "$pkg" >/dev/null 2>&1; then
    failures+=("firma inválida: $pkg")
  fi
done

if [ ${#failures[@]} -gt 0 ]; then
  printf '%s\n' "${failures[@]}"
  exit 1
fi

echo "repo verificado: ${#pkgs[@]} paquetes"
