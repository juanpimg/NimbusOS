# Nimbus

[![CI](https://github.com/juanpimg/NimbusOS/actions/workflows/ci.yml/badge.svg)](https://github.com/juanpimg/NimbusOS/actions/workflows/ci.yml)
[![ISO](https://github.com/juanpimg/NimbusOS/actions/workflows/iso.yml/badge.svg)](https://github.com/juanpimg/NimbusOS/actions/workflows/iso.yml)

> **Note for English-speaking contributors:** this project is documented in Spanish first (the owner and the primary audience are Spanish-speaking). An English version of every document will follow. Code, identifiers and commit messages stay in English.

Nimbus es una distribución Linux basada en CachyOS con un escritorio estilo macOS, construido con Hyprland y un shell propio en Quickshell (QML).

Está pensada para personas que nunca van a abrir una terminal. El objetivo: un instalador con aspecto de asistente, un solo lenguaje visual en todo el sistema, tienda de aplicaciones propia, perfil "gameready" de un clic y actualizaciones con red de seguridad (snapshots Btrfs y rollback). Con perfil gameready y soporte de portátiles: Steam nativo con Proton, gamescope con VRR/HDR, gráficos híbridos y perfiles de energía.

## Estado

Si llegas nuevo, empieza por [docs/STATUS.md](docs/STATUS.md): un único sitio que dice qué
funciona (y cómo se verifica), qué no funciona todavía y qué puedes coger.

El proyecto ha completado los hitos **M0 ("cimientos")**, **M1 (shell)** y **M2 (instalador)**: el código de los tres está en el repo con tests. El escritorio visual (barra, Dock, Spotlight, Centro de Control, notificaciones, switcher, capturas, QuickLook, fondos, bloqueo, Ajustes, Store, tour de bienvenida) y el instalador completo (seis módulos de Calamares, herramientas de post-instalación y tema de SDDM) existen como código verificado por tests, no como maquetas.

**Sé honesto con lo verificado aquí:** el arranque de la sesión live en la ISO se verifica con QEMU (el harness espera el marcador `NIMBUS_LIVE_READY`, que solo se escribe cuando Hyprland y el shell responden de verdad). **El escritorio de verdad solo se verá cuando la integración del M1 termine**: nadie ha visto aún estas pantallas en una sesión real, y no se promete ninguna captura que no exista.

**Lo que funciona hoy** (verificado con los tres suites de tests: 251 pytest + 13 bats + 249 QML, ver salidas en [docs/BUILDING.md](docs/BUILDING.md)):

- Andamiaje del monorepo, control de licencias SPDX (`tools/check_spdx.py`, verificado con `python tools/check_spdx.py --root .`) y CI (`ci.yml` con lint + tests, `iso.yml` que construye la ISO y la arranca en QEMU).
- Cadena de confianza: generación del keyring (`tools/genkeyring.sh`), firma offline (`tools/sign_repo.sh`) y promoción `testing` → `stable` con verificación (`tools/promote.sh`, `tools/verify_repo.sh`).
- Paquetes `nimbus-keyring`, `nimbus-shell`, `nimbus-dots`, `nimbus-gaming` y `nimbus-energy` con sus PKGBUILDs.
- Shell completo (M1): singletons `Theme`, `Config`, `Translations`, `ShellController`, `Ipc`, `Services` y `PolkitAgent`; biblioteca de componentes (`shell/src/Nimbus/lib/`); superficies (`shell/src/Nimbus/modules/`: TopBar, Dock, Spotlight, Centro de Control, notificaciones, switcher, capturas, QuickLook, fondos, bloqueo); aplicaciones (`shell/src/Nimbus/apps/`: Ajustes, Store, tour). Ver [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (§ "Arquitectura del shell").
- Configuración de Hyprland (`dots/hypr/hyprland.lua`, API Lua nativa): layout flotante, atajos estilo macOS y sesión de emergencia con terminal (`SUPER + MAYÚS + E`).
- Perfil de ISO para **archiso 91** (`iso/profiles/nimbus/`) y constructor (`iso/build.sh --local-repo`), con banco de pruebas rootless (`tools/build-iso-rootless.sh`).
- Instalador Calamares (M2) con los seis módulos propios (`nimbus-dualboot`, `nimbus-appearance`, `nimbus-software`, `nimbus-bootloader`, `nimbus-postinstall`, `nimbus-verify`), tabla i18n ES/EN (`installer/calamares/nimbus_i18n.py`), herramientas (`installer/tools/`: `nimbus-postinstall`, `nimbus-partitionsafe`, `nimbus-snapshots`) y tema de SDDM (`installer/greeter/nimbus-greeter/`). Ver [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (§ "Instalador Calamares").
- Harness de integración en QEMU (`tests/integration/boot_live.sh`) que arranca la ISO y espera el marcador `NIMBUS_LIVE_READY`.
- Documentación: arquitectura, guía de build, guía de contribución, roadmap (este fichero y `docs/`).

**Lo que no existe todavía** (sin adornos):

- El perfil gameready (M3) está parcial y sin verificar en hardware real: en el árbol están el metapaquete `nimbus-gaming` (T1), `nimbus-energy` (T3), `nimbus-scheduler` con las reglas de ananicy (T4) y `nimbus-gaming-tune` con los presets (T5), en `packages/nimbus-gaming` y `packages/nimbus-energy`. Faltan la sesión `nimbus-gaming-session` con `gamescope-vrr-check` y `nimbus-gaming.desktop` (T2) y la pantalla de Ajustes `SettingsGaming.qml` (T6). Sin T6, el único camino para energía y gaming es la terminal: lo que hay es fontanería para la futura pantalla de Ajustes, no una característica disponible. Los presets (`gamescope.conf`, `mangohud.conf`, `90-nimbus-gaming.conf`) se distribuyen, todavía no los aplica nadie. El instalador ya ofrece un perfil de software `gaming` (lista de paquetes en `installer/calamares/modules/nimbus-software/nimbus-software.conf`), pero eso no es el perfil de un clic.
- Secure Boot con shim firmado (M5; las betas usan MOK provisional), el sistema de actualizaciones maduro (`nimbus-update`, M5) y la publicación del repo de paquetes (el repo `nimbus` aún no está alojado; la ISO se construye contra un repo local de bootstrap, ver [docs/BUILDING.md](docs/BUILDING.md)).
- La verificación visual del escritorio en una sesión real (ver nota sobre QEMU arriba).

## Estructura del repositorio

| Directorio | Contenido |
|------------|-----------|
| `tools/` | Scripts de la cadena de firma y promoción (bash + Python). |
| `packages/` | PKGBUILDs del repo `nimbus` y el documento del modelo de pins. |
| `shell/` | Shell Quickshell/QML: singletons (`Theme`, `Config`, `Translations`, `ShellController`, `Ipc`, `Services`, `PolkitAgent`), biblioteca (`lib/`), superficies (`modules/`) y aplicaciones (`apps/`: Ajustes, Store, tour); punto de entrada `shell.qml` y tests en `shell/tests/` (16 ficheros). |
| `dots/` | Configuración de Hyprland (layout flotante, atajos estilo macOS, sesión de emergencia) y defaults del sistema. |
| `iso/` | Perfil archiso 91 y constructor de la ISO (`build.sh --local-repo`). |
| `installer/` | Configuración de Calamares (`settings.conf`), seis módulos propios (`nimbus-dualboot`, `nimbus-appearance`, `nimbus-software`, `nimbus-bootloader`, `nimbus-postinstall`, `nimbus-verify`), tabla i18n (`nimbus_i18n.py`), herramientas (`tools/`) y tema de SDDM (`greeter/nimbus-greeter/`). |
| `tests/` | Tests pytest (251) y bats (13); `tests/integration/` con el harness QEMU (`boot_live.sh`, espera `NIMBUS_LIVE_READY`). |
| `docs/` | Índice, arquitectura, guía de construcción, roadmap y documentos de diseño. |
| `third_party/` | Reservado para futuro código vendorizado de terceros (MIT); el directorio no existe aún en el árbol y hoy no se distribuye código de terceros. |
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

- [docs/STATUS.md](docs/STATUS.md) — estado verificable: qué funciona, qué no y qué coger.
- [docs/README.md](docs/README.md) — índice y orden de lectura.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — cómo encaja el sistema.
- [docs/BUILDING.md](docs/BUILDING.md) — guía de construcción y pruebas.
- [docs/ROADMAP.md](docs/ROADMAP.md) — hitos M0…M5.
- [docs/superpowers/specs/2026-10-21-nimbus-design.md](docs/superpowers/specs/2026-10-21-nimbus-design.md) — documento de diseño (fuente de verdad).
- [CONTRIBUTING.md](CONTRIBUTING.md) — cómo contribuir.
- [packages/README.md](packages/README.md) — modelo de pins `testing`/`stable`.

## Licencia

Nimbus es software libre bajo **GPL-3.0-or-later**. Ver [LICENSE](LICENSE) y [LICENSES.md](LICENSES.md).
Hoy no se distribuye código de terceros: no existe `third_party/`; los créditos de Ajustes →
Acerca de nombran los proyectos ascendentes (MacShell, WhiteSur, Quickshell), no código vendorizado.

Nimbus **no está afiliado a Apple**. Los nombres estilo macOS se usan de forma descriptiva; ningún asset, logotipo ni tipografía de Apple se incluye ni se distribuye en este repositorio.
