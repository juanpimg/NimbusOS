#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

ISO=""
TIMEOUT=600

while [ $# -gt 0 ]; do
  case "$1" in
    --iso) ISO="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "opción desconocida: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
  echo "ISO no encontrada: $ISO" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/tests/integration/lib.sh"

LOG="$(mktemp -t nimbus-qemu-XXXXXX.log)"
ACCEL="$(qemu_accel)"
PID="$(qemu_run "$ISO" "$LOG" "$ACCEL")"
trap 'kill "$PID" 2>/dev/null || true' EXIT

echo "Arrancando la ISO en QEMU (accel: $ACCEL), log: $LOG"

if wait_for_marker "$LOG" "$TIMEOUT"; then
  echo "OK: la sesión live de Nimbus está lista"
  exit 0
fi

echo "FALLO: no se encontró $NIMBUS_MARKER en $TIMEOUT segundos" >&2
tail -n 60 "$LOG" >&2
exit 1
