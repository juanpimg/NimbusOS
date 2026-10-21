# Contribuir a Nimbus

> **Note for English-speaking contributors:** this guide is written in Spanish first. An English version will follow. Commit messages and code stay in English.

Gracias por querer contribuir a Nimbus. Este proyecto está en M0 (cimientos): las reglas básicas importan más que las features. Si nunca has contribuido a una distribución Linux, esta guía te lleva de cero a tu primer pull request.

## Configuración en un comando

Nimbus se construye sobre CachyOS (Arch) x86-64. Instala las dependencias con:

```bash
sudo pacman -S --needed base-devel archiso quickshell hyprland qt6-declarative \
  qt6-wayland qt6-shadertools repo bats python-pytest lua yamllint actionlint \
  shellcheck qemu-desktop
```

> No verificado en este entorno: requiere CachyOS y root. Lo que sí está verificado aquí son los tres comandos de tests de abajo.

Qué es cada cosa: `base-devel` y `repo` para compilar e indexar paquetes; `archiso` para construir la ISO; `quickshell`, `hyprland` y las librerías `qt6-*` para el shell; `bats`, `python-pytest` y `qmltestrunner` (viene con `qt6-declarative`) para los tests; `lua` para validar la config de Hyprland; `yamllint`, `actionlint` y `shellcheck` para el lint de CI; `qemu-desktop` para probar la ISO en VM.

Versiones mínimas (del documento de diseño): `quickshell >= 0.3.2`, `hyprland >= 0.56.2`, `qt6 >= 6.12` con `qt6-shadertools`, `archiso >= 91`, `calamares >= 3.4.2`.

## Los tres comandos de tests

Ejecútalos siempre antes de abrir un PR. Cubren cosas distintas:

```bash
python -m pytest tests -v
```

Cubre la lógica en Python: cabeceras SPDX, configuración de Hyprland, perfil de la ISO y ajustes de Calamares (según existan en tu rama; hoy solo existe el test SPDX). En este contenedor `pytest` no está en el PATH: usa `/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v`.

```bash
PATH="$HOME/.local/bin:$PATH" bats tests/*.bats
```

Cubre los scripts de la cadena de firma: generación del keyring, firma de la DB, promoción `testing` → `stable` y verificación del repo.

```bash
QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests
```

Cubre los singletons QML (`Theme`, `Config`, `Translations`). Usa el runner de **Qt6** (`/usr/lib/qt6/bin`); el `qmltestrunner` de `/usr/bin` es Qt5 y no sirve. `QT_QPA_PLATFORM=offscreen` permite correrlos sin sesión gráfica. `QML2_IMPORT_PATH` debe apuntar a `shell/src`, que es el directorio que contiene la carpeta del módulo `Nimbus/` (no a `shell/src/Nimbus/`).

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

La infraestructura gettext definitiva (que permitirá ampliar idiomas sin tocar el shell) llega en M5/M6; hasta entonces, este es el mecanismo.

## Cómo informar de un bug

Abre un issue con:

- Distro y kernel (`uname -a`), GPU (`lspci | grep -i vga`) y si es portátil o sobremesa.
- Qué esperabas y qué pasó, paso a paso para reproducirlo.
- La salida del paso de verificación relevante (pytest, bats o qmltestrunner) si el bug es del repo; si es de hardware, qué rama de `chwd`/driver usas.
- Si el sistema arranca pero el escritorio no, indica hasta dónde llega (¿consola? ¿greeter?) y adjunta el log relevante. La sesión de emergencia con terminal llegará con la configuración de Hyprland (M0, Task 5); hasta entonces no existe.

## Código de conducta

Toda participación está sujeta al [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) (Contributor Covenant v2.1). Mantén un trato respetuoso y profesional en issues, PRs y discusiones.
