# Nimbus 0.1.0 — beta de escritorio

Primera beta pública de **Nimbus**, una distribución Linux estilo macOS sobre CachyOS
(Arch-based) con un shell propio en **Quickshell/QML** sobre **Hyprland**.

## Qué puedes hacer con esta ISO

- **Arrancar el escritorio en vivo**: la sesión live levanta Hyprland y el shell de
  Nimbus (barra con la marca, Dock con iconos, fondo propio). El tema del greeter
  se ve al entrar.
- **Instalar Nimbus** en el equipo: el instalador es Calamares con seis módulos
  propios (dual-boot con copia de la tabla de particiones, apariencia, perfiles de
  software, bootloader con entradas de rollback, post-instalación y verificación de
  hardware).
- **Red**: la sesión live tiene red y DNS por NetworkManager.

## Cómo probarla

```bash
# 1. Comprobar el checksum
sha256sum -c nimbus-2026.10.22-x86_64.iso.sha256

# 2. Arrancar en QEMU (KVM)
qemu-system-x86_64 -accel kvm -cpu max -m 8192 -smp 4 \
  -device virtio-gpu-pci -vga none \
  -cdrom nimbus-2026.10.22-x86_64.iso -display gtk,show-cursor=on \
  -serial mon:stdio

# 3. En la VM: usuario "nimbus" (autologin del greeter).
#    Por consola serie: root / nimbus
```

## Cómo se verifica (lo que CI corre en cada push)

```bash
python -m pytest tests -q                                    # 390 tests
QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" \
  /usr/lib/qt6/bin/qmltestrunner -input shell/tests          # 301 tests
PATH="$HOME/.local/bin:$PATH" bats tests/*.bats              # 13 tests
python tools/check_spdx.py --root .                          # cabeceras SPDX
```

Y el arranque real de la ISO:

```bash
bash tests/integration/boot_live.sh --iso out/nimbus-*.iso --timeout 600
# -> OK: la sesión live de Nimbus está lista
```

## Qué NO hace todavía (léelo antes de opinar)

Esta beta es **el escritorio**, no un producto cerrado:

- **La instalación no se ha probado de extremo a extremo**: el instalador está
  empaquetado y sus módulos pasan sus tests, pero no hay una prueba automatizada
  que arranque la ISO, ejecute Calamares y llegue a un escritorio instalado. Es el
  hueco nº 1.
- **La tienda no instala de verdad**: invoca su backend, pero sin `flatpak` ni
  `PackageKit` en la imagen.
- **El repo público de paquetes no existe**: el sistema instalado apunta al repo
  local de bootstrap, así que `pacman -Syu` no trae nada todavía.
- **Secure Boot**: no está (es requisito de v1.0).
- **Nada está verificado en hardware real**: no hay GPU de escritorio, ni portátil
  híbrido, ni prueba de batería, VRR o dual-boot con Windows.
- La **clave de firma** es la de bootstrap y **hay que rotarla** antes de publicar
  de verdad (procedimiento en `packages/README.md`).

El estado completo, con lo que sí y lo que no, está en
[`docs/STATUS.md`](../docs/STATUS.md).

## Construir la ISO desde cero

```bash
sudo pacman -S --needed archiso repo fakeroot debugedit grub syslinux
sudo env NIMBUS_BUILD_USER=$USER bash iso/build.sh --outdir "$PWD/out" --local-repo
```

Ver [`docs/BUILDING.md`](../docs/BUILDING.md) para las trampas reales del build
(disco, caché de pacman compartida, `makepkg` como usuario sin privilegios…).

## Firmas

- La ISO de esta release **no va firmada** (la firma de la release se añade en el
  M4/M5, con la rotación de clave).
- El checksum SHA-256 va junto a la ISO.
