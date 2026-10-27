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

## E2E instalado P0 (feature/instalado-p0): Rulings + pasos manuales exactos

Verificado headless en VM ligera (`-smp 2 -m 2048`, disco propio,
socket QMP propio) contra `out/nimbus-2026.10.27-x86_64.iso` el 2026-10-27
(via serie TCP `console=ttyS0` + QMP `screendump`; el VGA `-vga std` queda
ciego tras el handoff de GRUB, todo el E2E real fue por serie):

- LIVE probado de verdad: GRUB -> kernel -> `Reached target Graphical
  Interface` -> greetd autologin -> sesion Hyprland 0.56.2 ACTIVA
  (`loginctl State=active Type=wayland`; `hyprctl monitors`: Virtual-1
  1280x800@75 workspace 1; procesos `Hyprland` + `qs -c MacShell` +
  `xdg-desktop-portal-hyprland` vivos). `nimbus-live-setup.service` ya
  corrio en el live (`inactive`, marker hecho): `/etc/pamac.conf` con
  `EnableFlatpak/EnableAUR=true` y `flatpak remotes` = `flathub system`.
- Fallback `.conf` probado de verdad EN EL GUEST con su propio Hyprland:
  sin `hyprland.lua` -> `hyprland --verify-config` = `config ok`
  (stanza `plugin:hyprbars` valida sin el `.so`).
- INSTALADO automático: NO ejecutable en este entorno por un defecto de la
  ISO de referencia (no del overlay): `/usr/bin/calamares` no arranca
  (`libboost_python314.so.1.91.0 => not found`; la ISO trae `1.92.0`).
  Sin instalador no hay instalacion GUI headless ni con display.
  REQUIERE rebuild de ISO (root + mkarchiso, no disponible en este
  entorno) con el overlay de esta rama (que SI trae el %post).
- Via elegida para el %post (auditoria contra upstream
  CachyOS/cachyos-calamares@cachyos): instancia Calamares
  `shellprocess@nimbus_installed` (bloque `instances:` + `dontChroot:
  false` = corre EN EL TARGET tras `users`+`displaymanager`).
  El script `/usr/bin/nimbus-installed-setup` NUNCA hardcodea usuarios
  (argv `${USER}` de Calamares, fallback primer uid>=1000) y es
  idempotente (testeado con shims: argv, derivacion, sin-usuario,
  argv malicioso, pamac merge, flathub, enables, md5 estable).
  El mecanismo existe en el live probado
  (`/usr/lib/calamares/modules/{shellprocess,users,displaymanager}.so`).

Pasos manuales exactos (maquina con display + ISO reconstruida con esta rama):

1. `qemu-img create -f qcow2 /tmp/nimbus-inst.qcow2 20G` y arrancar la ISO
   con `-boot order=d` (con display: `-device virtio-vga-gl -display sdl`).
2. En el live, abrir Calamares (Hello primero), usuario de prueba
   (p. ej. `nimbus`), `erase disk` en `/dev/vda` (unico disco), instalar.
3. Apagar la VM, rearrancar con `-boot order=c` (mismo qcow2, sin ISO).
4. Verificar login grafico directo (sin teclear): `echo $USER` = `nimbus`
   (NO `liveuser`); `cat /etc/greetd/config.toml` con `user = "nimbus"`
   en ambas sesiones; `grep -E '^Enable(Flatpak|AUR)' /etc/pamac.conf`
   (ambos `true`); `flatpak remotes` con `flathub`; `systemctl is-enabled
   auto-cpufreq thermald bluetooth` (los 3 `enabled`).
5. `hyprland --verify-config` en la sesion instalada (lua si hay red para
   el plugin AUR en primer arranque, `.conf` siempre `config ok`).

## Checklist obligatorio pre-release (no bloquea --check-only)

- En el guest live, antes de declarar la release: `hyprland --verify-config`
  debe pasar sin errores. Con `hyprland.lua` presente valida la sesion Lua
  (precedencia: el .lua gana al .conf; verificado en 0.56.2) e ignora
  `hyprland.conf`/`10-shortcuts.conf`, que quedan como fallback legacy
  (para validarlos, mover el .lua fuera de `~/.config/hypr` y reejecutar).
  `--check-only`/`verify-build.sh` NO lo ejecutan
  (requiere Hyprland instalado + sesion live); este paso es manual en QEMU.
  Si falla, bloquear la release aunque `build_iso.sh --check-only` sea PASS.
- DM: confirmar que el DM efectivo del live sigue siendo el esperado
  (ver nota greetd en `scripts/verify-build.sh`: alerta si el upstream
  cambia `display-manager` en profiledef). Greetd sin probar E2E en V1.

## Limitaciones V1 conocidas (verificar en QEMU)

- Semáforos: WhiteSur + MacShell cubren GTK/CSD; ventanas Hyprland SSD
  no-GTK no tienen semáforos nativos (limitación V1, no bloquea).
