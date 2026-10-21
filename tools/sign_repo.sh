#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Firma la base de datos de un repositorio pacman con la clave GPG de Nimbus.
set -euo pipefail

REPO=""
GPGDIR=""
KEY=""

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
    --key)
      KEY="${2:-}"
      shift 2
      ;;
    *)
      echo "sign_repo: opción desconocida: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$REPO" ] || [ -z "$GPGDIR" ] || [ -z "$KEY" ]; then
  echo "sign_repo: se requieren --repo, --gpgdir y --key" >&2
  exit 1
fi

shopt -s nullglob
DBS=("$REPO"/*.db)
shopt -u nullglob

if [ "${#DBS[@]}" -eq 0 ]; then
  echo "sign_repo: no hay base de datos que firmar en $REPO" >&2
  exit 1
fi

DB="${DBS[0]}"

if [ -f "$DB.sig" ]; then
  echo "sign_repo: $DB ya firmado" >&2
  exit 1
fi

gpg --homedir "$GPGDIR" --batch --yes --local-user "$KEY" --detach-sign "$DB"
