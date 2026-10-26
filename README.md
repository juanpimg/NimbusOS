# NimbusOS

Distribución Linux booteable basada en **CachyOS**, con escritorio **Hyprland**
(sesión canónica Lua) en modo flotante y capa visual estilo macOS sobre
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

## Estado actual (2026-10-26, rama `main`)

- **ISO instalable**: `out/nimbus-2026.10.26-x86_64.iso` (3,7 GB), reproducible
  vía `./build_iso.sh` sobre el perfil `CachyOS-Live-ISO` pineado.
- **Ventanas nativas macOS**: titlebars vía plugin oficial `hyprbars`
  (semáforos 🔴🟡🟢 parte de la ventana, cero latencia), borde gris fino 1px,
  arrastre desde la barra, redimensión por bordes (`resize_on_border` + imán),
  y por teclado (`Super+Shift+flechas`). GTK usa sus CSD WhiteSur propios.
- **Workflow Mac**: ventanas flotantes centradas, Spaces (`Super+1..9`,
  `Super+←/→`), Mission Control (vista del switcher), pantalla completa con
  `Super+F`, minimizar al dock.
- **Piel macOS total**: WhiteSur GTK + iconos, Inter, cursores capitaine,
  terminal Kitty oscura translúcida, bloqueo `hyprlock` cristal, Qt heredando
  GTK, Nautilus vista iconos, tema GRUB Whitesur, fondo Sequoia al arrancar
  (hyprpaper autostart), hostname `nimbus`.
- **Teclas hardware**: volumen/brillo con OSD propio de MacBar; backends
  `brightnessctl` + `bluez`/`bluez-utils` incluidos.
- **Menú global**: módulo `appmenu-gtk-module` en la imagen (base D-Bus lista).
- **Entrada directa**: greetd con autologin a Hyprland (sin pantalla de login).
- **Tienda**: `pamac-aur` tematizado + Flathub (remote-add al primer arranque);
  AUR (`whitesur-*`, `pamac-aur`, `hyprshell`, `hyprland-plugin-hyprbars`)
  precompilados en repo local `[nimbus]` dentro de la ISO.
- **Portátil**: `auto-cpufreq`, ZRAM `zstd`, gestión NVIDIA híbrida, VA-API.
- **Instalador**: Calamares estilo "Hello" (abre en Hello), borrado de disco
  por defecto.
- **Suite en verde**: macshell 177/0, power 77/0, store 106/0,
  calamares 84/0 (+1 skip), build 130/0, más `--check-only`.

Pendiente conocido: texto del menú GRUB aún dice CachyOS; batería virtual no
disponible en QEMU 11 (opcional, no bloquea); reloj del live en inglés
(falta locale + `lang/es.js` upstream); sin pruebas en hardware real.

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
- `scripts/verify-*.sh` — suite de verificación; `scripts/test-qemu.sh` — VM;
  `scripts/build-aur-repo.sh` — precompila AUR al repo local.
- `docs/qemu.md` — checklist live; `docs/ESTADO.md` — estado y huecos;
  `docs/superpowers/plans/` — planes.
- `INICIO.txt` — especificación original (autoridad).
