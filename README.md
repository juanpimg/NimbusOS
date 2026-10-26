# NimbusOS

Distribución Linux booteable basada en **CachyOS**, con escritorio **Hyprland**
en modo flotante y capa visual estilo macOS sobre
**[MacShell](https://github.com/0-ss/MacShell)** (Quickshell/QML, MIT):
barra superior, dock con aumento, Spotlight y centro de control.

> **Filosofía: respeto y colaboración con MacShell.** No reinventamos ni
> opacamos su trabajo: MacShell es la capa visual y la citamos como tal
> (ver `iso.manifest` con repo, rama y commit pineado). NimbusOS va un paso
> más allá: lleva esa experiencia a **todo el SO** (arranque, bloqueo, apps,
> ajustes) y la entrega como **distro Linux fácil de instalar y usar**, sin
> terminal. Toda mejora reutilizable se propone aguas arriba a MacShell.

Pensada para quien no quiere tocar la terminal: atajos `Ctrl` intactos
(copiar/pegar/guardar como en Windows), `Alt+Tab` con previsualización,
todo arrastrable y redimensionable con el ratón.

## Estado actual (2026-10-26)

- **ISO instalable**: `out/nimbus-2026.10.26-x86_64.iso` (3,7 GB), reproducible
  vía `./build_iso.sh` sobre el perfil `CachyOS-Live-ISO` pineado.
- **Workflow Mac**: ventanas flotantes centradas, Spaces (`Super+1..9`,
  `Super+←/→`), Mission Control (vista del switcher), pantalla completa con
  `Super+F`, minimizar al dock.
- **Piel macOS total**: WhiteSur GTK + iconos, Inter, cursores capitaine,
  terminal Kitty oscura translúcida, bloqueo `hyprlock` cristal, Qt heredando
  GTK, Nautilus vista iconos, tema GRUB Whitesur.
- **Entrada directa**: greetd con autologin a Hyprland (sin pantalla de login).
- **Tienda**: `pamac-aur` + Flathub; AUR (`whitesur-*`, `pamac-aur`,
  `hyprshell`) precompilados en repo local `[nimbus]` dentro de la ISO.
- **Portátil**: `auto-cpufreq`, ZRAM `zstd`, gestión NVIDIA híbrida, VA-API.
- **Instalador**: Calamares estilo "Hello", borrado de disco por defecto.
- **Suite en verde**: `verify-macshell/power/store/calamares/build` + `--check-only`.

Pendiente conocido: texto del menú GRUB aún dice CachyOS; batería virtual no
disponible en QEMU 11 (opcional, no bloquea).

## Probar en VM

```bash
./scripts/test-qemu.sh
```

Arranca la última ISO con UEFI, disco de 20 GB y red. Dentro: escritorio con
barra, abrir el instalador "Hello" e instalar en `/dev/vda`.

## Estructura

- `nimbus-overlay/` — capa Nimbus sobre el perfil upstream (`etc/skel`, Calamares, greetd, theming).
- `packages.nimbus.x86_64.append` — paquetes extra (solo repos oficiales).
- `packages.nimbus-aur.txt` — AUR precompilados al repo local.
- `build_iso.sh` — build reproducible (7 pasos).
- `scripts/verify-*.sh` — suite de verificación; `scripts/test-qemu.sh` — VM.
- `docs/qemu.md` — checklist live; `docs/superpowers/plans/` — planes.
- `INICIO.txt` — especificación original (autoridad).
