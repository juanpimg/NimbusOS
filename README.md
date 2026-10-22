# Nimbus

[![CI](https://github.com/juanpimg/NimbusOS/actions/workflows/ci.yml/badge.svg)](https://github.com/juanpimg/NimbusOS/actions/workflows/ci.yml)
[![ISO](https://github.com/juanpimg/NimbusOS/actions/workflows/iso.yml/badge.svg)](https://github.com/juanpimg/NimbusOS/actions/workflows/iso.yml)

> **Note for English-speaking contributors:** this project is documented in Spanish first (the owner and the primary audience are Spanish-speaking). An English version of every document will follow. Code, identifiers and commit messages stay in English.

Nimbus es una distribución Linux basada en CachyOS con un escritorio estilo macOS, construido con Hyprland y un shell propio en Quickshell (QML).

Está pensada para personas que nunca van a abrir una terminal. El objetivo: un instalador con aspecto de asistente, un solo lenguaje visual en todo el sistema, tienda de aplicaciones propia, perfil "gameready" de un clic y actualizaciones con red de seguridad (snapshots Btrfs y rollback). Con perfil gameready y soporte de portátiles: Steam nativo con Proton, gamescope con VRR/HDR, gráficos híbridos y perfiles de energía.

## Estado

**Si llegas nuevo, empieza por [docs/CONTINUAR.md](docs/CONTINUAR.md)**: tiene el
estado, los comandos, las trampas reales del build y por dónde seguir. Y si solo
quieres **probarlo**, hay una release con la ISO lista:
[⬇ Nimbus 0.1.0 beta](https://github.com/juanpimg/NimbusOS/releases/tag/v0.1.0-beta).

El detalle de qué funciona y qué no, con la evidencia, está en
[docs/STATUS.md](docs/STATUS.md).

### Lo que funciona hoy

- **El escritorio live levanta y se parece a macOS**: barra superior con la marca
  de Nimbus, el reloj por idioma y los indicadores; Dock inferior con iconos
  dibujados en QML; fondo propio; greeter de SDDM con el tema de Nimbus y
  autologin del usuario `nimbus`. **Verificado con capturas del guest** (la ISO
  arrancada en QEMU, capturada con `screendump` del monitor).
- **La ISO lleva el instalador**: el paquete `nimbus-installer` mete los seis
  módulos de Calamares, el tema del greeter y la configuración de SDDM.
- **La puerta de readiness es honesta**: `NIMBUS_LIVE_READY` solo se escribe si
  Hyprland **y** el shell responden; si el shell no arranca, la ISO **no** está
  lista (y el harness lo dice).
- **El shell hace cosas**: `nimbus-shell ipc call <target> <función>` despacha de
  verdad (un handler por target), hay un puente para ejecutar procesos (con
  polkit cuando hace falta) y Ajustes→Energía llama a `nimbus-energy` de verdad.
- **Actualizaciones con snapshot y rollback**: el paquete `nimbus-update` crea un
  snapshot antes de cada transacción, y las unidades de timer están.
- **Suite completa en verde**: 390 pytest + 301 QML + 13 bats, SPDX correcto
  (122 ficheros) y **CI en verde** en cada push.

### Lo que no existe todavía (sin adornos)

- **La instalación no se ha probado de extremo a extremo**: el instalador está
  empaquetado y sus módulos pasan sus tests, pero no hay una prueba
  automatizada que arranque la ISO, ejecute Calamares y llegue a un escritorio
  instalado. Es el hueco nº 1.
- **La Store no instala de verdad**: invoca su backend, pero la imagen no trae
  `flatpak` ni `PackageKit`.
- **El repo público de paquetes no existe**: el sistema instalado apunta al repo
  local de bootstrap, así que `pacman -Syu` todavía no trae nada.
- **Secure Boot** (requisito de v1.0) y **rotación de la clave de firma** (sigue
  la de bootstrap; el procedimiento está en `packages/README.md`).
- **Nada está verificado en hardware real**: no hay GPU de escritorio, ni portátil
  híbrido, ni pruebas de batería, VRR o dual-boot con Windows.
- La **sesión de juegos** y la **pantalla de Ajustes de energía/juegos** están
  implementadas (`nimbus-gaming-session` con detección de VRR y
  `SettingsGaming.qml`), pero **sin verificar en hardware**.

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

- [docs/CONTINUAR.md](docs/CONTINUAR.md) — **punto de entrada para retomar el proyecto**: estado, comandos, trampas y siguiente paso.
- [docs/STATUS.md](docs/STATUS.md) — estado verificable: qué funciona, qué no y qué coger.
- [docs/README.md](docs/README.md) — índice y orden de lectura.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — cómo encaja el sistema.
- [docs/BUILDING.md](docs/BUILDING.md) — guía de construcción y pruebas.
- [docs/QUICKSHELL-API.md](docs/QUICKSHELL-API.md) — la API real de Quickshell 0.3.2 y Hyprland 0.56.
- [docs/RELEASE-NOTES.md](docs/RELEASE-NOTES.md) — lo que dice la beta de la release.
- [docs/ROADMAP.md](docs/ROADMAP.md) — hitos M0…M5.
- [docs/superpowers/specs/2026-10-21-nimbus-design.md](docs/superpowers/specs/2026-10-21-nimbus-design.md) — documento de diseño (fuente de verdad).
- [CONTRIBUTING.md](CONTRIBUTING.md) — cómo contribuir.
- [packages/README.md](packages/README.md) — modelo de pins `testing`/`stable`.

## Licencia

Nimbus es software libre bajo **GPL-3.0-or-later**. Ver [LICENSE](LICENSE) y [LICENSES.md](LICENSES.md).
Hoy no se distribuye código de terceros: no existe `third_party/`; los créditos de Ajustes →
Acerca de nombran los proyectos ascendentes (MacShell, WhiteSur, Quickshell), no código vendorizado.

Nimbus **no está afiliado a Apple**. Los nombres estilo macOS se usan de forma descriptiva; ningún asset, logotipo ni tipografía de Apple se incluye ni se distribuye en este repositorio.
