#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

OUTDIR="/tmp/opencode/nimbus-iso"
TIMEOUT=900

while [ $# -gt 0 ]; do
  case "$1" in
    --outdir) OUTDIR="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "opción desconocida: $1" >&2; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [ ! -f "$ROOT/iso/build.sh" ]; then
  echo "constructor no encontrado: $ROOT/iso/build.sh" >&2
  exit 1
fi

bash "$ROOT/iso/build.sh" --outdir "$OUTDIR" --local-repo

shopt -s nullglob
ISOS=("$OUTDIR"/nimbus-*.iso)
shopt -u nullglob
if [ "${#ISOS[@]}" -eq 0 ]; then
  echo "no se encontró ninguna ISO en $OUTDIR" >&2
  exit 1
fi

ISO="${ISOS[0]}"
for CAND in "${ISOS[@]}"; do
  if [ "$CAND" -nt "$ISO" ]; then
    ISO="$CAND"
  fi
done

bash "$ROOT/tests/integration/boot_live.sh" --iso "$ISO" --timeout "$TIMEOUT"
