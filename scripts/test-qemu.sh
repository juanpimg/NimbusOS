#!/bin/bash
# NimbusOS Task 5 — scripts/test-qemu.sh
# Test live de la ISO en QEMU/KVM con bateria virtual (acpi-battery).
# Uso:
#   ./scripts/test-qemu.sh [--iso out/nimbus-*.iso] [--disk /tmp/nimbus-test.qcow2]
# Pre-check: KVM + CPU x86-64-v3 (AVX2) + OVMF; aborta si no se cumplen.
# Checklist live (manual en el guest):
#   [ ] Hyprland arranca + macshell autostart (barra superior estilo macOS)
#   [ ] upower -d | grep -i battery muestra bateria (acpi-battery)
#   [ ] lanzar calamares (Hello), instalar en /dev/vda, reboot order=c
#   [ ] login Hyprland tras instalar
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO="${1:-}"
DISK="/tmp/nimbus-test.qcow2"
if [ "${1:-}" = "--iso" ]; then ISO="${2:-}"; fi
if [ -z "$ISO" ]; then ISO="$(ls -t "$ROOT"/out/nimbus-*-x86_64.iso 2>/dev/null | head -1 || true)"; fi
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "FAIL: ISO no encontrada (compila primero: ./build_iso.sh)" >&2; exit 1; }

# --- Pre-checks ------------------------------------------------------------------
[ -e /dev/kvm ] || { echo "FAIL: sin /dev/kvm (KVM no disponible)" >&2; exit 1; }
if ! lscpu 2>/dev/null | grep -qiE 'avx2'; then
    echo "FAIL: CPU sin AVX2/x86-64-v3; CachyOS aborta aqui" >&2; exit 1
fi
OVMF=""
for c in /usr/share/ovmf/x64/OVMF.fd /usr/share/edk2-ovmf/x64/OVMF.fd /usr/share/OVMF/OVMF_CODE_4M.fd; do
    [ -f "$c" ] && OVMF="$c" && break
done
[ -n "$OVMF" ] || { echo "FAIL: OVMF no encontrado (paquete ovmf)" >&2; exit 1; }
echo "pre-check OK: kvm + AVX2 + OVMF=$OVMF"
echo "ISO: $ISO"

[ -f "$DISK" ] || qemu-img create -f qcow2 "$DISK" 20G

exec qemu-system-x86_64 \
  -enable-kvm -M q35,accel=kvm -cpu host -smp 4 -m 4096 \
  -bios "$OVMF" \
  -drive "file=$ISO,media=cdrom,readonly=on" \
  -drive "file=$DISK,if=virtio,format=qcow2" \
  -device virtio-vga-gl -display sdl,gl=on \
  -device virtio-tablet-pci \
  -device virtio-net-pci,netdev=n0 -netdev user,id=n0 \
  -device acpi-battery \
  -boot order=d -serial stdio
