# Contribuir a Nimbus

> **Note for English-speaking contributors:** this guide is written in Spanish first. An English version will follow. Commit messages and code stay in English.

Gracias por querer contribuir a Nimbus. El proyecto ha completado los hitos M0 (cimientos), M1 (shell) y M2 (instalador): las reglas básicas importan más que las features. Si nunca has contribuido a una distribución Linux, esta guía te lleva de cero a tu primer pull request.

## Configuración en un comando

Nimbus se construye sobre CachyOS (Arch) x86-64. Instala las dependencias con:

```bash
sudo pacman -S --needed base-devel archiso quickshell hyprland qt6-declarative \
  qt6-wayland qt6-shadertools repo bats python-pytest lua yamllint actionlint \
  shellcheck qemu-desktop cachyos-calamares-next inter-font
```

> No verificado en este entorno: requiere CachyOS y root. Lo que sí está verificado aquí son los tres comandos de tests de abajo.

Qué es cada cosa: `base-devel` y `repo` para compilar e indexar paquetes; `archiso` para construir la ISO; `quickshell`, `hyprland` y las librerías `qt6-*` para el shell; `bats`, `python-pytest` y `qmltestrunner` (viene con `qt6-declarative`) para los tests; `lua` para validar la config de Hyprland; `yamllint`, `actionlint` y `shellcheck` para el lint de CI; `qemu-desktop` para probar la ISO en VM; `inter-font` porque el paquete `nimbus-shell` depende de ella; `cachyos-calamares-next` solo hace falta para las tareas del instalador (validar `installer/`).

Versiones mínimas (del documento de diseño): `quickshell >= 0.3.2`, `hyprland >= 0.56.2`, `qt6 >= 6.12` con `qt6-shadertools`, `archiso >= 91`, `calamares >= 3.4.2`.

## Los tres comandos de tests

Ejecútalos siempre antes de abrir un PR. Cubren cosas distintas:

```bash
/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v
```

Cubre la lógica en Python: cabeceras SPDX, configuración de Hyprland (`test_hyprland_config.py`), perfil de la ISO (`test_iso_profile.py`), Calamares (`test_calamares_settings.py`, `test_calamares_behavior.py`, `test_dualboot_safety.py`, `test_bootloader_rollback.py`, `test_postinstall.py`, `test_greeter_theme.py`) y punto de entrada del shell (`test_shell_entrypoint.py`). 189 tests. El comando canónico es `python -m pytest tests -v` (funciona en cuanto instalas `python-pytest`); en este contenedor `pytest` no está en el PATH y se usa el venv del proyecto.

```bash
PATH="$HOME/.local/bin:$PATH" bats tests/*.bats
```

Cubre los scripts de la cadena de firma: generación del keyring, firma de la DB, promoción `testing` → `stable` y verificación del repo. 13 tests. `bats` vive en `~/.local/bin` y hay que anteponerlo al PATH.

```bash
QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests
```

Cubre el shell QML: singletons (`Theme`, `Config`, `Translations`, `ShellController`, `Ipc`, `Services`, `PolkitAgent`), biblioteca, superficies, Ajustes, Store, tour y fondos (16 ficheros `tst_*.qml`). 249 tests. Usa el runner de **Qt6** (`/usr/lib/qt6/bin`); el `qmltestrunner` de `/usr/bin` es Qt5 y muere en silencio (verificado: enlaza `libQt5QuickTest.so.5`; el de Qt6 enlaza `libQt6QuickTest.so.6`). `QT_QPA_PLATFORM=offscreen` permite correrlos sin sesión gráfica. `QML2_IMPORT_PATH` debe apuntar a `shell/src`, que es el directorio que contiene la carpeta del módulo `Nimbus/` (no a `shell/src/Nimbus/`).

Las trampas reales (un `.conf` suelto junto a `hyprland.lua` que nunca se carga, `ShellRoot` frente a `Item`, el `qmldir` en el sitio equivocado, `makepkg` como root, y el resto) ya están documentadas con síntoma, causa y remedio en [docs/BUILDING.md](docs/BUILDING.md) (§ "Resolución de problemas"): léelas antes de depurar, no las dupliques aquí.

## Dónde contribuir: las 8 áreas

El repo ya tiene 8 zonas con código y tests. Elige una y empieza por el fichero y el test que se indican:

1. **Tooling** (`tools/`): `genkeyring.sh`, `sign_repo.sh`, `promote.sh`, `verify_repo.sh`, `check_spdx.py`, `build-iso-rootless.sh`. Empieza leyendo `packages/README.md` (contratos de `promote.sh` y `verify_repo.sh`) y ejecuta `PATH="$HOME/.local/bin:$PATH" bats tests/*.bats`.
2. **Paquetes** (`packages/`): `nimbus-keyring`, `nimbus-shell`, `nimbus-dots` (PKGBUILDs). Empieza por `packages/README.md` (modelo `testing`/`stable`, rotación de clave) y comprueba que `makepkg` está disponible; recuerda que `makepkg` no corre como root.
3. **Shell/QML** (`shell/`): singletons `Theme`, `Config`, `Translations`, `ShellController`, `Ipc`, `Services` y `PolkitAgent` en `shell/src/Nimbus/`; biblioteca en `shell/src/Nimbus/lib/`; superficies en `shell/src/Nimbus/modules/`; aplicaciones en `shell/src/Nimbus/apps/` (Ajustes, Store, tour); punto de entrada `shell/src/shell.qml`; tests en `shell/tests/`. Empieza ejecutando el comando QML de arriba y leyendo [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (§ "Arquitectura del shell"). Toda cadena visible va a `Translations` y todo color/métrica a `Theme` (ver "Cómo traducir" y "Reglas del proyecto" abajo). Para registrar un componente nuevo se añade su línea al `qmldir` (`singleton <Nombre> 1.0 <Fichero>.qml` para singletons, `<Nombre> 1.0 <ruta>.qml` para el resto).
4. **Configuración de Hyprland** (`dots/`): `dots/hypr/hyprland.lua` (API Lua nativa: layout flotante, atajos estilo macOS, sesión de emergencia), `dots/nimbus/defaults.conf`, `dots/nimbus/nimbus-start`. Empieza con `/tmp/opencode/nimbus-venv/bin/python -m pytest tests/test_hyprland_config.py -v`. Necesitas `lua` para validar la sintaxis fuera de Hyprland.
5. **ISO** (`iso/`): perfil archiso 91 en `iso/profiles/nimbus/` (`profiledef.sh`, `pacman.conf`, `packages.x86_64`, `airootfs/`) y `iso/build.sh --local-repo`. Empieza con `/tmp/opencode/nimbus-venv/bin/python -m pytest tests/test_iso_profile.py -v` y leyendo [docs/BUILDING.md](docs/BUILDING.md) (§ "Construir la ISO").
6. **Instalador** (`installer/`): `installer/calamares/settings.conf` (la secuencia, con el porqué del orden en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)) y los seis módulos `nimbus-dualboot`, `nimbus-appearance`, `nimbus-software`, `nimbus-bootloader`, `nimbus-postinstall`, `nimbus-verify`; tabla i18n en `installer/calamares/nimbus_i18n.py`; herramientas en `installer/tools/`; tema de SDDM en `installer/greeter/nimbus-greeter/`. Empieza con `/tmp/opencode/nimbus-venv/bin/python -m pytest tests/test_calamares_settings.py tests/test_calamares_behavior.py -v`. Solo necesitas `cachyos-calamares-next` si vas a validar `installer/` contra Calamares real.
7. **Tests** (`tests/`, `shell/tests/`): pytest (189), bats (13) y qmltestrunner (249) más el harness de integración (`tests/integration/boot_live.sh`, marcador `NIMBUS_LIVE_READY`). Empieza ejecutando los tres comandos de arriba en orden. Si añades código, añade o actualiza su test en el mismo PR.
8. **Documentación** (`README.md`, `CONTRIBUTING.md`, `docs/`, `packages/README.md`): en español, términos técnicos en inglés, sin adjetivos de marketing, sin hechos inventados ("pendiente de decidir" si algo no está decidido), enlaces relativos y sin assets ni marcas de Apple. Empieza comprobando que cada enlace interno resuelve y que ningún "no existe" describe algo que ya existe.

## Convención de commits

Mensajes en **inglés**, estilo convencional:

- `feat:` funcionalidad nueva.
- `fix:` corrección.
- `docs:` solo documentación.
- `test:` solo tests.
- `refactor:` reestructuración sin cambio de comportamiento.
- `chore:` mantenimiento (CI, dependencias, andamiaje).
- `!` tras el tipo (`feat!:`) cuando el cambio rompe compatibilidad.

## Regla SPDX

Cada fichero fuente lleva su licencia en los primeros 600 bytes, y `tools/check_spdx.py` lo verifica en CI:

- `SPDX-License-Identifier: GPL-3.0-or-later` en todo el código propio.
- `SPDX-License-Identifier: MIT` bajo `third_party/`.

El porqué: `third_party/` contiene código vendorizado de MacShell con su licencia original MIT. Si un fichero MIT se mezclara sin marcar entre el código GPL, la procedencia dejaría de ser auditable y el proyecto no podría demostrar qué licencia aplica a cada línea. La regla existe para que un auditor externo pueda comprobar el origen de cualquier fichero en segundos. Antes de abrir un PR, ejecuta:

```bash
python tools/check_spdx.py --root .
```

## Flujo de ramas y PRs

1. Abre o elige un issue y comenta tu intención antes de programar.
2. Trabaja en una rama `feature/<nombre-corto>` desde la rama principal.
3. Sigue el estilo del repo (`.editorconfig`: espacios, UTF-8, LF, salto de línea final).
4. Añade o actualiza los tests de tu cambio (`pytest`, `bats`, `qmltestrunner` según el área).
5. Verifica en local con los tres comandos de arriba.
6. Abre el PR con: qué cambia, por qué y cómo se probó (salida de los tests).

Un revisor comprobará: cabeceras SPDX, tests en verde, commits con el formato anterior, que no haya assets ni marcas de Apple, y que toda cadena visible al usuario exista en español e inglés.

## Reglas del proyecto

- **Una sola verdad visual.** Todo lo visible lee de `Theme` (el singleton de tokens en `shell/src/Nimbus/Theme.qml`). Nada entra al escritorio sin pasar por los tokens.
- **Cero terminal para el usuario.** Si una tarea normal exige abrir una terminal, es un bug del producto, no una limitación aceptada.
- **ES + EN desde el primer día.** Toda cadena visible al usuario existe en español e inglés (ver "Cómo traducir" abajo).
- **Sin telemetría.** Ningún componente envía datos a ningún sitio.

## Cómo traducir

Hoy las cadenas viven en la tabla de `shell/src/Nimbus/Translations.qml`, con fallback a inglés: si falta una clave en el idioma activo, se devuelve el inglés; si tampoco existe en inglés, se devuelve la propia clave. Para añadir un idioma:

1. Añade su bloque a `table` en `shell/src/Nimbus/Translations.qml` con las mismas claves que `en`.
2. Añade un test en `shell/tests/tst_config.qml` que fije `Config.setLocale("<tu-idioma>")` y compruebe `Config.translated(...)`.
3. Ejecuta el runner QML de arriba y confirma que pasa.

Esta tabla es la infraestructura de traducción disponible hoy (la que la tabla de decisiones del [documento de diseño](docs/superpowers/specs/2026-10-21-nimbus-design.md) pide desde el principio): el instalador usa el mismo patrón con tabla propia en `installer/calamares/nimbus_i18n.py` (función `translated(clave, locale)` con fallback al inglés) y el shell en el singleton `Translations`. Un catálogo gettext completo, que permitirá ampliar idiomas sin tocar el shell, llega más adelante (M5/M6).

## Cómo informar de un bug

Abre un issue con:

- Distro y kernel (`uname -a`), GPU (`lspci | grep -i vga`) y si es portátil o sobremesa.
- Qué esperabas y qué pasó, paso a paso para reproducirlo.
- La salida del paso de verificación relevante (pytest, bats o qmltestrunner) si el bug es del repo; si es de hardware, qué rama de `chwd`/driver usas.
- Si el sistema arranca pero el escritorio no, indica hasta dónde llega (¿consola? ¿greeter?) y adjunta el log relevante. Para depurar existe la sesión de emergencia: `SUPER + MAYÚS + E` abre un terminal a pantalla completa (`kitty --class emergency`, declarado en `dots/hypr/hyprland.lua`).

## Código de conducta

Toda participación está sujeta al [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) (Contributor Covenant v2.1). Mantén un trato respetuoso y profesional en issues, PRs y discusiones.
