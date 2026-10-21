# Nimbus

> **Note for English-speaking contributors:** this project is documented in Spanish first (the owner and the primary audience are Spanish-speaking). An English version of every document will follow. Code, identifiers and commit messages stay in English.

Nimbus es una distribución Linux basada en CachyOS con un escritorio estilo macOS, construido con Hyprland y un shell propio en Quickshell (QML).

Está pensada para personas que nunca van a abrir una terminal. El objetivo: un instalador con aspecto de asistente, un solo lenguaje visual en todo el sistema, tienda de aplicaciones propia, perfil "gameready" de un clic y actualizaciones con red de seguridad (snapshots Btrfs y rollback). Con perfil gameready y soporte de portátiles: Steam nativo con Proton, gamescope con VRR/HDR, gráficos híbridos y perfiles de energía.

## Estado

El proyecto está en el hito **M0 ("cimientos")** y **no hay nada utilizable como sistema todavía**: no existe ISO, no existe instalador y el shell es un punto de entrada mínimo con los singletons de diseño. Lo que sigue es honesto a fecha de este commit.

**Lo que funciona hoy** (verificado con los tres suites de tests):

- Control de licencias SPDX (`tools/check_spdx.py`) y CI de lint.
- Keyring GPG offline y firma de repositorios (`tools/genkeyring.sh`, `tools/sign_repo.sh`).
- Modelo de pins con canales `testing`/`stable` y promoción manual (`tools/promote.sh`, `tools/verify_repo.sh`).
- Tokens de diseño y configuración del shell (`Theme`, `Config`, `Translations`) con tests QML.

**Lo que no existe todavía** (hitos M0 pendientes y posteriores):

- Configuración de Hyprland (`dots/`), perfil de ISO y constructor (`iso/`), módulos de Calamares (`installer/`), harness de integración en QEMU (`tests/integration/`).
- Módulos del escritorio (TopBar, Dock, Spotlight, …), Nimbus Store, instalador, sesión de juegos: hitos M1–M4.
- Beta pública e i18n completa: hitos M5–M6. Ver [docs/ROADMAP.md](docs/ROADMAP.md).

## Estructura del repositorio

| Directorio | Contenido |
|------------|-----------|
| `tools/` | Scripts de la cadena de firma y promoción (bash + Python). |
| `packages/` | PKGBUILDs del repo `nimbus` y el documento del modelo de pins. |
| `shell/` | Shell QML/Quickshell: singletons `Theme`, `Config`, `Translations`, punto de entrada y tests. |
| `dots/` | Configuración de Hyprland y defaults del sistema (pendiente en M0). |
| `iso/` | Perfil archiso y constructor de la ISO (pendiente en M0). |
| `installer/` | Configuración y módulos propios de Calamares (pendiente en M0). |
| `tests/` | Tests pytest y bats; `tests/integration/` con el harness QEMU (pendiente en M0). |
| `docs/` | Índice, arquitectura, guía de construcción, roadmap y documentos de diseño. |
| `third_party/` | Código vendorizado de terceros (MIT); hoy solo existe como convención documentada. |
| `.github/` | Workflows de CI (`ci.yml` existe; `iso.yml` pendiente en M0). |

## Inicio rápido

Clonar y ejecutar los tests (comandos verificados en este entorno):

```bash
git clone https://github.com/juanpimg/NimbusOS.git
cd NimbusOS
```

Instalar las dependencias de construcción (requiere CachyOS y root; comando no verificado en este entorno):

```bash
sudo pacman -S --needed base-devel archiso quickshell hyprland qt6-declarative \
  qt6-wayland qt6-shadertools repo bats python-pytest lua yamllint actionlint \
  shellcheck qemu-desktop cachyos-calamares-next inter-font
```

Los tres suites de tests (verificados; ver salidas exactas en [docs/BUILDING.md](docs/BUILDING.md)). El comando canónico es `python -m pytest tests -v` (funciona en cuanto instalas `python-pytest`); en este contenedor `pytest` no está en el PATH y se usa el venv:

```bash
python -m pytest tests -v
# En este entorno: /tmp/opencode/nimbus-venv/bin/python -m pytest tests -v
PATH="$HOME/.local/bin:$PATH" bats tests/*.bats
QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests
```

> Nota: `pytest` no está en el PATH de este entorno; se invoca el intérprete del venv directamente. `bats` vive en `~/.local/bin` y hay que anteponerlo al PATH. El `qmltestrunner` de `/usr/bin` es Qt5; los tests del shell exigen el de Qt6 (`/usr/lib/qt6/bin`).

Construir la ISO y arrancarla en QEMU todavía **no es posible en esta rama**: `iso/build.sh` y `tests/integration/boot_live.sh` no existen aún (M0, Tasks 6 y 8 pendientes). La interfaz prevista está documentada en [docs/BUILDING.md](docs/BUILDING.md).

Espejos de CachyOS que usa la construcción (salvo el repo `nimbus`, todo lo demás sale de aquí):

- Arch (`core`, `extra`): `https://archlinux.cachyos.org/repo/$repo/os/$arch`
- CachyOS v3: `https://cdn77.cachyos.org/repo/$arch_v3/$repo`
- CachyOS genérico: `https://cdn77.cachyos.org/repo/$arch/$repo`

## Documentación

- [docs/README.md](docs/README.md) — índice y orden de lectura.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — cómo encaja el sistema.
- [docs/BUILDING.md](docs/BUILDING.md) — guía de construcción y pruebas.
- [docs/ROADMAP.md](docs/ROADMAP.md) — hitos M0…M6.
- [docs/superpowers/specs/2026-10-21-nimbus-design.md](docs/superpowers/specs/2026-10-21-nimbus-design.md) — documento de diseño (fuente de verdad).
- [CONTRIBUTING.md](CONTRIBUTING.md) — cómo contribuir.
- [packages/README.md](packages/README.md) — modelo de pins `testing`/`stable`.

## Licencia

Nimbus es software libre bajo **GPL-3.0-or-later**. Ver [LICENSE](LICENSE) y [LICENSES.md](LICENSES.md) para la procedencia de cada componente (el código vendorizado de MacShell es MIT y vive bajo `third_party/`).

Nimbus **no está afiliado a Apple**. Los nombres estilo macOS se usan de forma descriptiva; ningún asset, logotipo ni tipografía de Apple se incluye ni se distribuye en este repositorio.
