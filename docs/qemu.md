# NimbusOS — test QEMU/KVM de la ISO live

Comando canonico (ver `scripts/test-qemu.sh`, que ademas hace los pre-checks):

```bash
qemu-img create -f qcow2 /tmp/nimbus-test.qcow2 20G
qemu-system-x86_64 -enable-kvm -M q35,accel=kvm -cpu host -smp 4 -m 4096 \
  -bios /usr/share/edk2/x64/OVMF.4m.fd \
  -drive file=out/nimbus-*.iso,media=cdrom,readonly=on \
  -drive file=/tmp/nimbus-test.qcow2,if=virtio,format=qcow2 \
  -device virtio-vga-gl -display sdl,gl=on \
  -device virtio-tablet-pci \
  -device virtio-net-pci,netdev=n0 -netdev user,id=n0 \
  -boot order=d -serial stdio
```

## Pre-checks (el script aborta si fallan)

- `/dev/kvm` existe (KVM disponible).
- CPU con x86-64-v3: `lscpu | grep -i avx2` (CachyOS requiere v3/v4).
- Firmware OVMF instalado (paquete `ovmf`).

## Checklist live (manual en el guest)

1. Hyprland arranca + `macshell` autostart (barra superior estilo macOS).
2. `upower -d | grep -i battery` muestra bateria si hay bateria virtual (QEMU 11 no trae acpi-battery; opcional, no bloquea).
3. Lanzar calamares (pantalla Hello), instalar en `/dev/vda`.
4. Reboot con `-boot order=c`, login en Hyprland instalado.

## Checklist obligatorio pre-release (no bloquea --check-only)

- En el guest live, antes de declarar la release: `hyprland --verify-config`
  debe pasar sin errores (valida hyprland.conf + 10-shortcuts.conf tras la
  fusion del overlay). `--check-only`/`verify-build.sh` NO lo ejecutan
  (requiere Hyprland instalado + sesion live); este paso es manual en QEMU.
  Si falla, bloquear la release aunque `build_iso.sh --check-only` sea PASS.
- DM: confirmar que el DM efectivo del live sigue siendo el esperado
  (ver nota greetd en `scripts/verify-build.sh`: alerta si el upstream
  cambia `display-manager` en profiledef). Greetd sin probar E2E en V1.

## Limitaciones V1 conocidas (verificar en QEMU)

- Semáforos: WhiteSur + MacShell cubren GTK/CSD; ventanas Hyprland SSD
  no-GTK no tienen semáforos nativos (limitación V1, no bloquea).
