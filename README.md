# Nimbus

> **Note for English-speaking contributors:** this project is documented in Spanish first (the owner and the primary audience are Spanish-speaking). An English version of every document will follow. Code, identifiers and commit messages stay in English.

Nimbus es una distribución Linux basada en CachyOS con un escritorio estilo macOS, construido con Hyprland y un shell propio en Quickshell (QML).

Está pensada para personas que nunca van a abrir una terminal. El objetivo: un instalador con aspecto de asistente, un solo lenguaje visual en todo el sistema, tienda de aplicaciones propia, perfil "gameready" de un clic y actualizaciones con red de seguridad (snapshots Btrfs y rollback). Con perfil gameready y soporte de portátiles: Steam nativo con Proton, gamescope con VRR/HDR, gráficos híbridos y perfiles de energía.

## Estado

El proyecto está en el hito **M0 ("cimientos")** y ya hay un sistema mínimo que se construye y se prueba de extremo a extremo, pero **todavía no es un sistema utilizable**: el escritorio visual (barra, Dock, Spotlight, Centro de Control) está planificado para el Plan 2 / M1 y no existe.

**Lo que funciona hoy** (verificado con los tres suites de tests: 90 pytest + 13 bats + 17 QML, ver salidas en [docs/BUILDING.md](docs/BUILDING.md)):

- Andamiaje del monorepo, control de licencias SPDX (`tools/check_spdx.py`, 34 ficheros) y CI (`ci.yml` con lint + tests, `iso.yml` que construye la ISO y la arranca en QEMU).
- Cadena de confianza: generación del keyring (`tools/genkeyring.sh`), firma offline (`tools/sign_repo.sh`) y promoción `testing` → `stable` con verificación (`tools/promote.sh`, `tools/verify_repo.sh`).
- Paquetes `nimbus-keyring`, `nimbus-shell` y `nimbus-dots` con sus PKGBUILDs.
- Sistema de diseño del shell: singletons `Theme`, `Config` y `Translations` con tests QML.
- Configuración de Hyprland (`dots/hypr/hyprland.lua`, API Lua nativa): layout flotante, atajos estilo macOS y sesión de emergencia con terminal (`SUPER + MAYÚS + E`).
- Perfil de ISO para **archiso 91** (`iso/profiles/nimbus/`) y constructor (`iso/build.sh --local-repo`), con banco de pruebas rootless (`tools/build-iso-rootless.sh`).
- Instalador Calamares con los módulos `nimbus-appearance`, `nimbus-software` y `nimbus-verify`.
- Harness de integración en QEMU (`tests/integration/boot_live.sh`) que arranca la ISO y espera el marcador `NIMBUS_LIVE_READY`.
- Documentación: arquitectura, guía de build, guía de contribución, roadmap (este fichero y `docs/`).

**Lo que no existe todavía** (sin adornos):

- El shell visual en sí: barra, Dock, Spotlight, Centro de Control, notificaciones y resto de módulos (Plan 2 / M1).
- La Nimbus Store, los Ajustes del sistema, el perfil gameready, el arranque dual implementado, Secure Boot y la publicación del repo de paquetes (el repo `nimbus` aún no está alojado; la ISO se construye contra un repo local de bootstrap, ver [docs/BUILDING.md](docs/BUILDING.md)).

## Estructura del repositorio

| Directorio | Contenido |
|------------|-----------|
| `tools/` | Scripts de la cadena de firma y promoción (bash + Python). |
| `packages/` | PKGBUILDs del repo `nimbus` y el documento del modelo de pins. |
| `shell/` | Shell QML/Quickshell: singletons `Theme`, `Config`, `Translations`, punto de entrada y tests. |
| `dots/` | Configuración de Hyprland (layout flotante, atajos estilo macOS, sesión de emergencia) y defaults del sistema. |
| `iso/` | Perfil archiso 91 y constructor de la ISO (`build.sh --local-repo`). |
| `installer/` | Configuración de Calamares y módulos propios (`nimbus-appearance`, `nimbus-software`, `nimbus-verify`). |
| `tests/` | Tests pytest (90) y bats (13); `tests/integration/` con el harness QEMU (`boot_live.sh`, espera `NIMBUS_LIVE_READY`). |
| `docs/` | Índice, arquitectura, guía de construcción, roadmap y documentos de diseño. |
| `third_party/` | Código vendorizado de terceros (MIT); hoy solo existe como convención documentada: el directorio no existe aún en el árbol. |
| `.github/` | Workflows de CI (`ci.yml`: lint + tests; `iso.yml`: construye la ISO y la arranca en QEMU). |

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

> `cachyos-calamares-next` solo hace falta para las tareas del instalador; `inter-font` la exige el paquete `nimbus-shell`.

Los tres suites de tests (verificados en este entorno; ver salidas exactas en [docs/BUILDING.md](docs/BUILDING.md)). El comando canónico es `python -m pytest tests -v` (funciona en cuanto instalas `python-pytest`); en este contenedor `pytest` no está en el PATH y se usa el venv:

```bash
# Python: no hay pytest en el PATH de forma general; el proyecto usa un venv
/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v
# bats
PATH="$HOME/.local/bin:$PATH" bats tests/*.bats
# QML
QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests
```

> Nota: `pytest` no está en el PATH de este entorno; se invoca el intérprete del venv directamente. `bats` vive en `~/.local/bin` y hay que anteponerlo al PATH. El `qmltestrunner` de `/usr/bin` es Qt5; los tests del shell exigen el de Qt6 (`/usr/lib/qt6/bin`).

Construir la ISO (requiere CachyOS; el primer bloque es el camino oficial con root, el que usa el CI; el segundo es el banco de pruebas sin root del repo):

```bash
# Con root (camino oficial, como en CI):
sudo pacman -S --needed archiso repo
bash iso/build.sh --outdir out --local-repo
# Sin root, con el banco de pruebas del repo:
bash tools/build-iso-rootless.sh --outdir out
```

> `iso/build.sh` y `tools/build-iso-rootless.sh` existen y pasan `bash -n`, pero **no se ejecutaron en este entorno**: no hay `mkarchiso` ni root aquí, y el banco rootless exige red y mapeos en `/etc/subuid`. El arranque de la ISO resultante en QEMU se documenta en [docs/BUILDING.md](docs/BUILDING.md).

Espejos que usa la construcción (los mismos que el perfil de la ISO en `iso/profiles/nimbus/pacman.conf`; salvo el repo `nimbus`, todo lo demás sale de aquí):

- Arch (`core`, `extra`): `https://mirror.rackspace.com/archlinux/$repo/os/$arch` y `https://mirror.leaseweb.com/archlinux/$repo/os/$arch`.
- CachyOS: `https://mirror.bali0531.hu/repo/$arch/$repo` (primero: el único verificado con el `glibc` nuevo) y `https://cdn77.cachyos.org/repo/$arch/$repo` (segundo).

No usar `https://archlinux.cachyos.org/repo/$repo/os/$arch`: sirve un borde desfasado que devolvió 404 para `glibc` recién sincronizado y abortó la construcción de la ISO entera.

Sobre `cachyos-v3`: la ISO en vivo usa siempre los repos genéricos, porque tiene que arrancar en hardware desconocido y la CPU por defecto de QEMU (`qemu64`) no tiene AVX2: un binario v3 abortaría con SIGILL. La elección de `cachyos-v3` la hace el instalador sobre el hardware real de destino.

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
