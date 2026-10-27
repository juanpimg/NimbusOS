# Test rápido sin compilar la ISO (carriles)

Compilar la ISO tarda ~15 min y funde RAM. Usa el carril más barato que valide tu cambio:

## Nivel 1 — segundos, sin VM (QML, hyprland.conf/lua, scripts)

Hyprland anidado en el propio host (CachyOS + Hyprland 0.56.2 ya instalados):

```bash
# 1. Sintaxis: siempre primero, con HOME temporal (evita falsos globbing)
mkdir -p /tmp/fakehome/.config/hypr
cp nimbus-overlay/etc/skel/.config/hypr/* /tmp/fakehome/.config/hypr/
HOME=/tmp/fakehome hyprland --verify-config   # debe decir "config ok"

# 2. QML: luac -p para lua; para QML no hay validador fiable en el host
#    (qmllint de Qt5 da falsos fallos con QML Qt6) → inspección + VM.
luac -p nimbus-overlay/etc/skel/.config/hypr/macshell.lua

# 3. Comportamiento real de compositor: sesión anidada (ventana, no toca tu sesión)
Hyprland -c /tmp/fakehome/.config/hypr/hyprland.conf
```

## Nivel 2 — minutos, un solo arranque (integración en el live real)

Arranca la última ISO con la carpeta del repo compartida por 9p y prueba
cambios de overlay **sin recompilar**:

```bash
qemu-system-x86_64 -enable-kvm -M q35 -cpu host -smp 2 -m 2048 \
  -bios /usr/share/edk2/x64/OVMF.4m.fd \
  -drive file=out/nimbus-*-x86_64.iso,media=cdrom,readonly=on \
  -drive file=/tmp/test.qcow2,if=virtio,format=qcow2 \
  -fsdev local,path=$PWD,security_model=passthrough,readonly,mount_tag=repo \
  -device virtio-9p-pci,fsdev=repo,mount_tag=repo \
  -device virtio-vga -display none -monitor unix:/tmp/t.sock,server,nowait -boot order=d
# dentro del live:
sudo mount -t 9p repo /mnt/repo
cp /mnt/repo/nimbus-overlay/etc/skel/.config/hypr/hyprland.conf ~/.config/hypr/
hyprctl reload
```

Vale para dotfiles, QML, scripts y `customize_airootfs.sh` (este último
ejecutándolo a mano como root). NO vale para: lista de paquetes, repo
`[nimbus]`, `profiledef.sh`, Calamares/instalador (necesitan pacstrap).

## Nivel 3 — build completo (solo si cambió pacstrap)

Necesario solo cuando tocas `packages.*`, `pacman.conf`, `profiledef.sh`,
el repo `[nimbus]` o `customize_airootfs.sh` de verdad (no en seco):
`./build_iso.sh` (~15 min, 8 hilos). Futuro: modo `--fast` con reanudación
por hash de paquetes (pendiente, ver `iso.manifest`).

## Reglas de convivencia con builds

- NUNCA dos builds a la vez (`./build_iso.sh` lleva candado `.build.lock`).
- NUNCA VM pesada durante `mksquashfs` (una ligera `-smp 2 -m 2048` como máximo).
- El `verify-config` falla si falta el `.so` de un plugin: eso es SKIP documentado, no FAIL.
