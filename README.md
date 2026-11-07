# NimbusOS

**Distribución Linux instalable con estética y flujo de trabajo estilo macOS: basada en CachyOS, con el escritorio KDE Plasma 6.8 y la capa NimbusShell.**

> **Estado 2026-11-07 — rama `plasma-migration`.** NimbusOS 1.0 se basa en
> **Plasma + NimbusShell**. `main` sigue siendo la ISO Hyprland estable hasta
> validar la ISO Plasma en VM/hardware (F12). PR draft:
> <https://github.com/juanpimg/NimbusOS/pull/1>. Ver
> [`docs/MIGRACION-PLASMA.md`](docs/MIGRACION-PLASMA.md).

> **English:** NimbusOS is a bootable Linux distro with a macOS look and feel, based on CachyOS with KDE Plasma 6.8 and the NimbusShell desktop layer. This project is documented primarily in Spanish.

> **Aviso importante — sin afiliación.** NimbusOS es un proyecto independiente y **no está afiliado, respaldado ni patrocinado** por CachyOS, Apple Inc. (macOS/Mac), KDE ni por el proyecto NimbusShell. macOS y Mac son marcas de Apple Inc. Usamos proyectos de terceros con su licencia: [CachyOS](https://cachyos.org) (base), [KDE Plasma](https://kde.org/plasma-desktop/) (GPL), [NimbusShell](https://github.com/juanpimg/NimbusShell) (capa de escritorio propia), [Krema](https://github.com/iruzard/krema) (Dock, GPL), [WhiteSur](https://github.com/vinceliuice/WhiteSur-kde) (GPL) y Calamares (GPL). El perfil Hyprland/MacShell queda congelado como `legacy-hypr`.

## Qué es

Una ISO booteable que instala un escritorio listo para usar **sin tocar la terminal**: Plasma 6.8 con barra superior, semáforos estilo macOS, Dock, Spotlight, Mission Control, ajustes Nimbus, tienda gráfica y asistente de instalación estilo "Hello".

> **¿Ya tienes Arch instalado?** La capa de escritorio es un proyecto propio: [**NimbusShell**](https://github.com/juanpimg/NimbusShell) — su `install.sh` (+ `--check`) transforma cualquier Arch en este escritorio sin reinstalar. NimbusOS **consume** esa capa en el build; no la copia a mano.

## Estado

- **Línea Plasma (`plasma-migration`):** `./build_iso.sh --check-only --profile
  plasma` **verde** (127 paquetes, SDDM, skel NimbusShell, overlay Plasma). La
  ISO real, la instalación y F12 siguen pendientes.
- **Línea estable (`main`):** ISO `nimbus-2026.10.27` Hyprland verificada en
  QEMU; se mantiene como rollback hasta que Plasma pase la validación real.
- El manifiesto [`iso.manifest`](iso.manifest) registra los SHA de cada build.

## Probarlo

```bash
./scripts/test-qemu.sh   # arranca la última ISO en QEMU/KVM (UEFI, 20 GB, red)
```

Dentro: escritorio con barra y dock, instalador "Hello" e instalación en `/dev/vda`.

## Construir la ISO

```bash
# Línea nueva Plasma + NimbusShell (rama plasma-migration)
NIMBUS_SHELL=../NimbusShell ./scripts/verify-plasma.sh   # gate estático + CI
NIMBUS_SHELL=../NimbusShell ./build_iso.sh --check-only --profile plasma
NIMBUS_SHELL=../NimbusShell ./build_iso.sh --profile plasma

# Perfil estable Hyprland (rollback)
./build_iso.sh --check-only --profile legacy-hypr
./build_iso.sh --profile legacy-hypr
```

Requiere Arch/CachyOS + root + KVM para la VM. Detalles en [`docs/qemu.md`](docs/qemu.md).

## Estructura

| Ruta | Qué es |
|---|---|
| `nimbus-overlay-plasma/` | **Línea nueva:** delta Plasma (SDDM, Calamares, barra, tema, skel). |
| `nimbus-overlay/` | Overlay base (live, Calamares, systemd, theming). |
| `packages.nimbus-plasma.append` | Paquetes del sistema + escritorio Plasma (127). |
| `packages.nimbus-plasma-aur.txt` | AUR del perfil Plasma (sin Hyprland). |
| `packages.nimbus.x86_64.append` | Paquetes del perfil Hyprland (legacy estable). |
| `packages.nimbus-aur.txt` | AUR del perfil Hyprland (legacy). |
| `build_iso.sh` | Build reproducible; `--profile plasma|legacy-hypr`. |
| `docs/architecture/` | Modelo de producto, mapa y ramas. |
| `docs/MIGRACION-PLASMA.md` | Checklist del corte Hyprland → Plasma. |
| `scripts/verify-*.sh` | Verificación · `test-qemu.sh` VM · `build-aur-repo.sh`. |
| `AGENTS.md` | Instrucciones obligatorias para sesiones de IA. |

## Filosofía

Respeto y colaboración con los proyectos que nos sostienen: **no reinventamos** lo que ya existe (cero desarrollo desde cero pudiendo reutilizar) y **no opacamos** a nadie — citamos cada fuente con repo, rama y commit en `iso.manifest`. Las mejoras reutilizables se proponen aguas arriba. Nuestro aporte: llevar esa experiencia a **todo el SO** y entregarla como **distro fácil de instalar y usar**.

## Licencia

El código propio de NimbusOS (scripts, overlay, configs, docs) se publica bajo **GPL-3.0-or-later** (ver `LICENSE`). Los componentes de terceros conservan sus licencias: KDE Plasma (GPL), NimbusShell (GPL-3.0), Krema (GPL), WhiteSur (GPL-3.0), Calamares (GPL-3.0), GRUB themes (GPL-3.0). El perfil legacy conserva MacShell (MIT) e Hyprland (BSD).
