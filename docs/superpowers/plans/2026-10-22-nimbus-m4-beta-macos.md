# Nimbus M4 — Beta "se parece a macOS" · Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que la ISO de Nimbus arranque en un escritorio **estable** que se
vea **claramente macOS** (barra de menú con menú de la Manzana, Dock siempre
visible, overlays al estilo de Spotlight/Control Center), y que el repositorio
esté **organizado y publicable** para que cualquiera pueda aportar.

**Architecture:** el shell es una app **Quickshell 0.3.2** (QML) sobre
**Hyprland 0.56**; cada superficie del shell es una **ventana propia**
(`PanelWindow`/`FloatingWindow` de `Quickshell.Wayland`), montada de forma
**defensiva** (si un módulo falla, el shell sigue arrancando) y visible por
capas del *layer-shell*. La sesión live la abre el **greeter de SDDM** con
autologin del usuario `nimbus`, que es lo que da una sesión de logind real
(necesaria para el asiento y para libseat). Un fondo **propio** de Nimbus,
generado y versionado, sustituye al wallpaper de Hyprland.

**Tech Stack:** QML / Quickshell 0.3.2 / Hyprland 0.56 (config Lua) /
systemd / archiso 91 / Calamares / GPG (firma offline) / pytest / Qt Test.

**Spec:** `docs/superpowers/specs/2026-10-21-nimbus-design.md` (la autoridad).
Planes previos: `docs/superpowers/plans/2026-10-21-nimbus-*.md`.
Referencia de API verificada: `docs/QUICKSHELL-API.md`.

---

## Global Constraints

- **Nada de assets de Apple ni de terceros con licencia incompatible.** Los
  fondos, iconos y temas se **generan o se dibujan**; nada se copia.
- **Sin telemetría.** Ningún componente envía datos fuera del equipo.
- **ES + EN desde el primer día.** Toda cadena visible pasa por
  `Config.translated(key)`; clave ausente → inglés; tampoco está → la propia
  clave (nunca una cadena suelta en pantalla). Las tablas de `Translations.qml`
  y `nimbus_i18n.py` deben quedar **simétricas**.
- **Regla de oro del shell:** todo componente visible lee colores, radios y
  métricas de `Theme`; todo texto visible pasa por `Config.translated`.
- **Nada de terminal para el usuario final.** Un CLI puede existir, pero su
  camino de uso normal debe ser una pantalla.
- **Regla dura de ananicy:** ninguna regla baja la prioridad de un proceso de
  juego ni del sistema de audio.
- **Firma offline y manual.** La CI **nunca** firma.
- **Cabecera SPDX** en todo fichero nuevo (los `.rules` JSON de ananicy son la
  excepción: no admiten comentarios).
- Scripts de shell: `set -euo pipefail`, **nada de `eval`**, quoting correcto.
- **TDD:** cada arreglo empieza por un test que falla (RED), luego el
  arreglo (GREEN).
- La **puerta de readiness** es honesta: `NIMBUS_LIVE_READY` solo se escribe
  cuando el escritorio responde de verdad.

## Review Focus

Cinco modos de fallo que ninguna tarea cubre por sí sola y que son los que
más caro salen:

1. **Una superficie que no se instancia y no se nota.** Un `Loader` sobre un
   `PanelWindow` falla en silencio: el shell arranca, la puerta de readiness
   dice "listo" y **no hay barra ni Dock**. → test estático que lee el QML.
2. **Una capa mal puesta.** La barra en `Overlay` tapa las ventanas; el fondo
   en `Top` tapa todo; `exclusiveZone` incorrecto deja la barra pegada al
   borde o solapada con el Dock. → test estático + captura del guest.
3. **Un fondo que no es de Nimbus.** Si el wallpaper efectivo es el de
   Hyprland (`/usr/share/hypr/wall*.png`), el escritorio parece un Linux
   cualquiera. → captura del guest.
4. **El greeter y el servicio live arrancando a la vez.** Dos
   compositors: el segundo muere y el marcador puede mentir. → la sesión live
   tiene **un único** lanzador.
5. **Un arranque que "funciona" solo en el escritorio del fundador.** La ISO
   live es efímera: todo lo que se hace en la sesión (grupos, contraseña,
   idioma, red) tiene que estar **en la imagen**, no en el estado de la
   máquina donde se construyó.

---

## Estructura de ficheros (quien decide qué)

| Ruta | Responsabilidad |
|---|---|
| `shell/src/shell.qml` | Raíz `ShellRoot`: monta **todas** las superficies y las 3 apps. |
| `shell/src/Nimbus/ShellController.qml` | Estado global: qué superficie está abierta. |
| `shell/src/Nimbus/Theme.qml` | **Todas** las métricas, colores y tipos. |
| `shell/src/Nimbus/Translations.qml` | Tabla ES/EN del shell. |
| `shell/src/Nimbus/modules/*.qml` | Una superficie cada una. Las que son ventana, `PanelWindow`/`FloatingWindow`. |
| `shell/src/Nimbus/lib/*.qml` | Componentes reutilizables sin estado. |
| `shell/src/Nimbus/apps/**` | Ajustes, Store, Tour. |
| `iso/profiles/nimbus/` | Perfil archiso 91: `airootfs/`, `packages.x86_64`, `pacman.conf`, `profiledef.sh`. |
| `packages/nimbus-*/` | Un paquete por subsistema distribuible. |
| `installer/calamares/` | Módulos de Calamares. |
| `tests/` | pytest (estático y de integración), `tests/*.bats`, `shell/tests/` (QML). |
| `docs/` | Documentación para humanos, incluido `docs/QUICKSHELL-API.md`. |

---

## Task 1: Montaje real de las superficies del shell

**Files:**
- Modify: `shell/src/shell.qml`, `shell/src/Nimbus/ShellController.qml`
- Test: `tests/test_shell_entrypoint.py`

**Interfaces:**
- Consumes: la API de `docs/QUICKSHELL-API.md`.
- Produces: `root.moduleFailures` (int) — contador de módulos que no cargaron;
  `ShellController.dockOpen` (bool) — **siempre `true`** salvo que el usuario
  lo cierre explícitamente.

- [ ] Test estático: ninguna superficie que sea ventana se monta dentro de un
      `Loader`; el Dock no depende de un flag en `false`; cada superficie
      declara su `layer`.
- [ ] RED: ejecutar el test y ver que falla.
- [ ] Montar cada superficie como ventana propia con carga defensiva
      (`Qt.createComponent` + `createObject(null)`), conservando
      `root.moduleFailures`.
- [ ] GREEN: test en verde + suite completa.
- [ ] **Verificación en la ISO**: `boot_live.sh` verde y **captura del guest
      con la barra y el Dock visibles**.

## Task 2: La barra de menú, con el menú de la "Manzana"

**Files:** `shell/src/Nimbus/modules/TopBar.qml`, `TopBarMenu.qml`,
`shell/src/Nimbus/Translations.qml`, `shell/src/Nimbus/Theme.qml`
**Tests:** `shell/tests/tst_topbar.qml`, `tests/test_shell_entrypoint.py`

- [ ] El menú de Nimbus (izquierda): Ajustes, Acerca de, Reiniciar, Apagar,
      Cerrar sesión. Es la pieza más identificable de macOS y hoy no existe.
- [ ] Reloj a la derecha con el formato por idioma (ya existe
      `bar.clock.format`: ES `ddd d MMM hh:mm`, EN `ddd MMM d h:mm AP`).
- [ ] Indicadores de estado (red, batería, volumen) y botones de Control
      Center y Notificaciones.
- [ ] Menú contextual con el nombre de la aplicación activa.
- [ ] Altura, pesos y paddings **desde `Theme`**.

## Task 3: El Dock

**Files:** `shell/src/Nimbus/modules/Dock.qml`, `DockItem.qml`, `Theme.qml`
**Tests:** `shell/tests/tst_dock.qml`

- [ ] Iconos de aplicaciones reales, **magnification** al pasar el ratón.
- [ ] Indicador de ejecución (punto bajo el icono) para las apps abiertas.
- [ ] Fondo translúcido, bordes redondeados, `exclusiveZone` = su tamaño.

## Task 4: Spotlight, Switcher y QuickLook

**Files:** `shell/src/Nimbus/modules/Spotlight.qml`, `Switcher.qml`, `QuickLook.qml`
**Tests:** `shell/tests/tst_spotlight.qml`, `tst_switcher.qml`

- [ ] Que se abran con su atajo y con `Ipc.call`, que la búsqueda acepte
      texto y que el resultado se pueda lanzar.
- [ ] `layer: Overlay` y `keyboardFocus: Exclusive` en los hooks de teclado.

## Task 5: Control Center y Notificaciones

**Files:** `shell/src/Nimbus/modules/ControlCenter.qml`, `Notifications.qml`
**Tests:** `shell/tests/tst_controlcenter.qml`, `tst_notifications.qml`

- [ ] Control Center con red, volumen, brillo y energía, **cableados a los
      servicios reales** (`Quickshell.Services.Pipewire`, `.UPower`).
- [ ] Las notificaciones **salen del daemon** (`Notifications` de
      `Quickshell.Services`), no de una lista inventada.

## Task 6: Pantalla de bloqueo y fondo

**Files:** `shell/src/Nimbus/modules/LockScreen.qml`, `Wallpaper.qml`
**Tests:** `shell/tests/tst_wallpaper.qml`

- [ ] El bloqueo cierra todo lo demás y se abre con `Ipc.call("lock", …)`.
- [ ] La galería de fondos **lista los fondos de Nimbus** (ver Task 9).

## Task 7: Theme — métricas, color y tipografía

**Files:** `shell/src/Nimbus/Theme.qml`
**Tests:** `shell/tests/tst_theme.qml`

- [ ] Alturas, tamaños de Dock, radios, grosores, opacidades y **tipografía por
      rol** (título, cuerpo, etiqueta, mono), con pila de fuentes razonable.
- [ ] Colores de macOS ya presentes (`#F5F5F7` / `#1C1C1E`) + los que falten
      para barra semitransparente, acentos, bordes y sombras.

## Task 8: Fondos propios de Nimbus

**Files:** `packages/nimbus-dots/` (o un paquete nuevo `nimbus-backgrounds`),
`iso/profiles/nimbus/airootfs/**`, `dots/hypr/hyprland.lua`
**Tests:** `tests/test_iso_profile.py`

- [ ] **Generar** los fondos (deterministas, versionables, ≥2 variantes) en la
      paleta de macOS. Ni Apple ni terceros.
- [ ] Instalarlos en `/usr/share/nimbus/backgrounds/` y **hacer que la sesión
      live los use** (descubrir cómo se pone el fondo en Hyprland 0.56: el
      paquete trae `/usr/share/hypr/wall*.png`).
- [ ] **Captura del guest**: el fondo visible es de Nimbus.

## Task 9: Greeter de SDDM y sesión de Nimbus

**Files:** `iso/profiles/nimbus/airootfs/etc/sddm.conf.d/**`,
`iso/profiles/nimbus/airootfs/usr/share/wayland-sessions/**`,
tema del greeter (propio), `iso/profiles/nimbus/airootfs/etc/systemd/system/nimbus-live*.service`
**Tests:** `tests/test_iso_profile.py`

- [ ] Configurar SDDM: tema de Nimbus, **autologin** de `nimbus` (el PAM de
      `sddm-autologin` usa `pam_permit`: el autologin no necesita clave).
- [ ] Crear la sesión Wayland de Nimbus que arranque **nuestra** config Lua.
- [ ] **Un único lanzador**: si el greeter arranca la sesión,
      `nimbus-live.service` deja de arrancar el compositor (o se desactiva).
- [ ] La puerta de readiness **sigue siendo honesta**.
- [ ] **Captura del guest**: se ve el greeter (o la sesión) con el tema.

## Task 10: Arranque limpio y estabilidad de la sesión live

**Files:** `iso/profiles/nimbus/airootfs/etc/systemd/system/nimbus-live*.service`,
`dots/hypr/hyprland.lua`
**Tests:** `tests/test_iso_profile.py`, `tests/test_hyprland_config.py`

- [ ] Quitar el banner *"Hyprland was started without start-hyprland"*
      (arrancar con su wrapper, o el mecanismo que el propio Hyprland 0.56
      acepte: **verificar en el binario**, no taparlo).
- [ ] El compositor no entra en bucle si muere (`StartLimitBurst`) y el aviso
      al usuario es entendible.
- [ ] Red y DNS en la sesión live (`systemd-resolved`): funcionando.
- [ ] Idioma por defecto y conmutable.

## Task 11: M3 T2 — la sesión de juegos

**Files:** `packages/nimbus-gaming/**`, `iso/profiles/nimbus/**`
**Tests:** `tests/test_gaming_stack.py`

- [ ] `nimbus-gaming-session`: aplica presets **solo** con un juego en marcha.
- [ ] **VRR por detección**, nunca estático: un flag de VRR en un panel que no
      lo soporta hace que gamescope **no muestre imagen**.
- [ ] `gamescope-vrr-check` dice si el panel lo soporta.

## Task 12: M3 T6 — Ajustes de energía y juegos

**Files:** `shell/src/Nimbus/apps/Settings/SettingsGaming.qml`,
`shell/src/Nimbus/apps/Settings/Settings.qml`, `Translations.qml`
**Tests:** `shell/tests/tst_settings.qml`

- [ ] Sin esta pantalla, energía y gaming son **solo terminal**: rompe la
      promesa del proyecto.
- [ ] La pantalla **llama a los CLI** (`nimbus-energy`, `nimbus-anonicy`) con
      polkit donde haga falta.

## Task 13: Organización del repositorio y estado documentado

**Files:** `docs/ESTADO.md`, `README.md`, `CONTRIBUTING.md`, `SECURITY.md`,
`CHANGELOG.md`, `.github/ISSUE_TEMPLATE/**`, `.github/workflows/**`
**Tests:** el propio repo (enlaces, rutas, comandos)

- [ ] `docs/ESTADO.md`: qué está hecho, qué está verificado y **cómo**,
      qué no, y qué puede coger un contribuidor.
- [ ] Borrar las ramas y worktrees ya fusionados (con la lista de lo
      recuperable por si acaso).
- [ ] Ficheros de comunidad: `SECURITY.md`, `CHANGELOG.md`, plantillas de
      issue y PR, badges reales.
- [ ] Todos los enlaces y rutas documentados **resuelven**.

## Task 14: Publicación de la beta

**Files:** `docs/RELEASE.md`, `.github/workflows/release.yml`
**Tests:** el workflow en modo `dry-run`

- [ ] Rotar la clave de firma (la actual es de bootstrap) — el procedimiento
      de 6 pasos está en `packages/README.md`.
- [ ] ISO con **checksums** y firma; artefactos de la CI.
- [ ] Anuncio con lo que **sí** funciona y lo que no.

---

## Criterio de terminación

1. `bash tests/integration/boot_live.sh --iso out/nimbus-*.iso --timeout 600`
   → `OK: la sesión live de Nimbus está lista`, **sin avisos en pantalla**.
2. Una **captura del guest** muestra: fondo **de Nimbus**, **barra de menú**
   con el menú de la Manzana, y **Dock** visible, con estilo macOS.
3. El greeter de SDDM arranca con el tema de Nimbus y el autologin del
   usuario live; la sesión live no arranca **dos** compositores.
4. Las tres suites en verde (pytest, bats, qmltestrunner) y el SPDX correcto.
5. `docs/ESTADO.md` dice la verdad: lo verificado, **cómo** se verificó, y lo
   que no.
6. El repo tiene `SECURITY.md`, `CHANGELOG.md`, plantillas, y **no** quedan
   ramas ni worktrees fusionados sin borrar.
7. La ISO pesa **< 3 GB** y arranca en **UEFI** y **BIOS**.
8. La **firma de los repos** es offline y manual: la CI no firma.
9. Todo lo que se afirma en la documentación es **verificable** con un comando
   o una captura, o se dice explícitamente que está pendiente de hardware real.
