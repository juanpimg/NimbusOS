# NimbusOS

**Distribución Linux instalable con estética y flujo de trabajo estilo macOS: basada en CachyOS, con el shell MacShell sobre Hyprland.**

> **English:** NimbusOS is a bootable Linux distro with a macOS look and feel, based on CachyOS with the MacShell shell on Hyprland. This project is documented primarily in Spanish.

> **Aviso importante — sin afiliación.** NimbusOS es un proyecto independiente y **no está afiliado, respaldado ni patrocinado** por CachyOS, Apple Inc. (macOS/Mac), ni por el proyecto MacShell. macOS y Mac son marcas de Apple Inc. Usamos los siguientes proyectos de terceros, cada uno con su licencia: [CachyOS](https://cachyos.org) (base del sistema), [MacShell](https://github.com/0-ss/MacShell) (capa visual, MIT), [Hyprland](https://hyprland.org) (compositor), [WhiteSur](https://github.com/vinceliuice/WhiteSur-gtk-theme) (temas GTK) y Calamares (instalador, GPL).

## Qué es

Una ISO booteable que instala un escritorio listo para usar **sin tocar la terminal**: ventanas flotantes con semáforos nativos, dock con aumento, Spotlight, Spaces y Mission Control, tienda de software gráfica y asistente de instalación estilo "Hello".

> **¿Ya tienes Arch instalado?** La capa de escritorio es un proyecto propio: [**NimbusShell**](https://github.com/juanpimg/NimbusShell) — su `install.sh` (+ `--check`) transforma cualquier Arch en este escritorio sin reinstalar. Esta ISO empaquetará esa capa ya probada.

## Estado

ISO `nimbus-2026.10.27` verificada en QEMU (arranque UEFI → escritorio live → instalador). Suite de verificación en verde (`scripts/verify-*.sh` + `./build_iso.sh --check-only`). El manifiesto [`iso.manifest`](iso.manifest) registra el SHA de cada build.

## Probarlo

```bash
./scripts/test-qemu.sh   # arranca la última ISO en QEMU/KVM (UEFI, 20 GB, red)
```

Dentro: escritorio con barra y dock, instalador "Hello" e instalación en `/dev/vda`.

## Construir la ISO

```bash
./build_iso.sh                 # build reproducible sobre el perfil CachyOS-Live-ISO pineado
./build_iso.sh --check-only    # validación sin root ni red pesada
./scripts/build-aur-repo.sh    # precompila los paquetes AUR al repo local [nimbus]
```

Requiere Arch/CachyOS + root + KVM para la VM. Detalles en [`docs/qemu.md`](docs/qemu.md).

## Estructura

| Ruta | Qué es |
|---|---|
| `nimbus-overlay/` | Capa Nimbus sobre el perfil upstream (`etc/skel`, Calamares, greetd, theming) |
| `packages.nimbus.x86_64.append` | Paquetes extra (solo repos oficiales) |
| `packages.nimbus-aur.txt` | AUR precompilados al repo local `[nimbus]` |
| `build_iso.sh` | Build reproducible en 7 pasos |
| `scripts/verify-*.sh` | Suite de verificación · `test-qemu.sh` VM · `build-aur-repo.sh` repo AUR local |
| `docs/` | `ESPECIFICACION.md` (diseño original), `ARQUITECTURA.md`, `FILOSOFIA.md`, `ESTADO.md`, `qemu.md`, `TEST-RAPIDO.md` (probar sin recompilar), planes e informes |
| `AGENTS.md` | Instrucciones obligatorias para sesiones de IA |

## Filosofía

Respeto y colaboración con los proyectos que nos sostienen: **no reinventamos** lo que ya existe (cero desarrollo desde cero pudiendo reutilizar) y **no opacamos** a nadie — citamos cada fuente con repo, rama y commit en `iso.manifest`. Las mejoras reutilizables se proponen aguas arriba. Nuestro aporte: llevar esa experiencia a **todo el SO** y entregarla como **distro fácil de instalar y usar**.

## Licencia

El código propio de NimbusOS (scripts, overlay, configs, docs) se publica bajo **GPL-3.0-or-later** (ver `LICENSE`). Los componentes de terceros conservan sus licencias: MacShell (MIT), temas WhiteSur (GPL-3.0), Calamares (GPL-3.0), GRUB themes (GPL-3.0).
