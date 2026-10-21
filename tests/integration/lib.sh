#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

NIMBUS_MARKER="NIMBUS_LIVE_READY"

# `-cpu max` no es cosmetico: el modelo por defecto de QEMU (qemu64) NO expone
# AVX2, asi que cualquier binario compilado para x86-64-v3 aborta con SIGILL
# dentro de la VM de prueba. Con `-cpu max` la VM se parece al hardware real.
# La ISO en vivo usa repos genericos precisamente para poder arrancar en
# hardware desconocido; el instalador es quien elige v3 segun la CPU real.

qemu_accel() {
  if [ -w /dev/kvm ]; then
    echo "kvm"
  else
    echo "tcg"
  fi
}

qemu_run() {
  local iso="$1" log="$2" accel="$3"
  qemu-system-x86_64 \
    -accel "$accel" \
    -cpu max \
    -m 4096 \
    -smp 2 \
    -display none \
    -device virtio-gpu-pci \
    -vga none \
    -serial "mon:stdio" \
    -cdrom "$iso" \
    -snapshot \
    -no-reboot \
    >"$log" 2>&1 &
  echo $!
}

wait_for_marker() {
  local log="$1" timeout="$2" waited=0
  while [ "$waited" -lt "$timeout" ]; do
    if grep -q "$NIMBUS_MARKER" "$log" 2>/dev/null; then
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done
  return 1
}
