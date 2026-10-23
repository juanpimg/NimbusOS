# NimbusOS — test QEMU/KVM de la ISO live

Comando canonico (ver `scripts/test-qemu.sh`, que ademas hace los pre-checks):

```bash
qemu-img create -f qcow2 /tmp/nimbus-test.qcow2 20G
qemu-system-x86_64 -enable-kvm -M q35,accel=kvm -cpu host -smp 4 -m 4096 \
  -bios /usr/share/ovmf/x64/OVMF.fd \
  -drive file=out/nimbus-*.iso,media=cdrom,readonly=on \
  -drive file=/tmp/nimbus-test.qcow2,if=virtio,format=qcow2 \
  -device virtio-vga-gl -display sdl,gl=on \
  -device virtio-tablet-pci \
  -device virtio-net-pci,netdev=n0 -netdev user,id=n0 \
  -device acpi-battery \
  -boot order=d -serial stdio
```

## Pre-checks (el script aborta si fallan)

- `/dev/kvm` existe (KVM disponible).
- CPU con x86-64-v3: `lscpu | grep -i avx2` (CachyOS requiere v3/v4).
- Firmware OVMF instalado (paquete `ovmf`).

## Checklist live (manual en el guest)

1. Hyprland arranca + `macshell` autostart (barra superior estilo macOS).
2. `upower -d | grep -i battery` muestra bateria (`-device acpi-battery`).
3. Lanzar calamares (pantalla Hello), instalar en `/dev/vda`.
4. Reboot con `-boot order=c`, login en Hyprland instalado.
