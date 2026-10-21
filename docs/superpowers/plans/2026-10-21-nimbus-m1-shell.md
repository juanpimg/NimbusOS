# Nimbus M1 — Shell v0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir el shell de escritorio de Nimbus: la barra de menú superior, el dock, el Spotlight, el Centro de Control, las notificaciones, el switcher, las capturas, el QuickLook, el selector de fondos, la pantalla de bloqueo, los Ajustes del sistema, la Nimbus Store y el tour de bienvenida — todos escritos desde cero en QML/Quickshell sobre los tokens de diseño de la Task 4, con un único lenguaje visual.

**Architecture:** Un único proceso Quickshell (`shell.qml`) que instancia una biblioteca de componentes reutilizables (`Nimbus/lib/`), un controlador de estado (`ShellController`) que es la única fuente de verdad, y un bus IPC (`Nimbus/Ipc.qml`) que traduce `nimbus-shell ipc call <target> <function>` en acciones del shell. Las superficies (barra, dock) son `PanelWindow`; los popups (Spotlight, Centro de Control, notificaciones) son `FloatingWindow`. Ningún componente lee color, radio o métrica directamente: todo pasa por `Theme`.

**Tech Stack:** QML / Qt Quick 6.12 · Quickshell 0.3.2 · Hyprland 0.56.2 · `qt6-shadertools` (shader de cristal) · QML Test (`qmltestrunner`) · Python 3.14 (backend de la Store)

**Spec:** [`../specs/2026-10-21-nimbus-design.md`](../specs/2026-10-21-nimbus-design.md) — §4.3 (escritorio), §4.8 (Nimbus Store), §4.3.3 (fundamentos compartidos), §3 (procedencia y licencias).

---

## Global Constraints

- **Licencias:** todo fichero de código fuente fuera de `third_party/` lleva SPDX `GPL-3.0-or-later`. El shell completo es **GPL-3.0** (obligatorio: vendorizamos código GPL-3.0 de Mainstream OS / end-4 y porque Calamares y archiso ya lo son).
- **Procedencia:** el shell es **código nuestro**, no código ajeno instalado. Se puede tomar la implementación de referencia de MacShell (MIT) **vendorizándola** en nuestro repo con su historial de licencias intacto, e integrándola en nuestros tokens. **Nunca** se instala el shell de otro proyecto tal cual, y Nimbus **no depende en runtime** de ningún repositorio externo.
- **Un solo lenguaje visual:** todo componente visible lee sus colores, radios, espaciados y tipografía de `Theme`. Si un componente no pasa por `Theme`, no entra.
- **Idiomas:** toda cadena visible al usuario pasa por `Config.translated(key)` y existe en **español e inglés** desde el primer día. Ninguna cadena incrustada directamente en el QML.
- **Sin telemetría:** ningún componente hace peticiones de red.
- **Layout del módulo QML:** el `qmldir` va en `shell/src/Nimbus/`, **nunca** en `shell/src/`. Con `QML2_IMPORT_PATH=shell/src`, `import Nimbus` resuelve. Un `qmldir` plano en `shell/src/` **no** funciona (QML resuelve un módulo buscando un *directorio* con ese nombre).
- **Punto de entrada:** `qs -c <dir>` espera `shell.qml` en `<dir>`. El entry point es `shell/src/shell.qml` y el directorio de import es `shell/src`. Ambos son el mismo directorio.
- **SinAssets de Apple:** prohibido usar el logo de Apple, SF Pro, capturas de macOS, o los nombres "Finder"/"Spotlight" para nuestros componentes. Los nombres de Nimbus son **Spotlight** sí (descripción genérica de una función), pero **Finder** no.
- **Compromisos de git:** mensajes en inglés con estilo convencional (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`).
- **Entorno:** todo se hace en el worktree de la tarea; nunca se modifica la instalación CachyOS actual del fundador. `pytest` no está en el PATH: usar `/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v`.
- **Tests QML:** `QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests`.

---

## Review Focus

Cinco clases de entrada o modo de fallo que el spec implica y que ninguna task debe dejar sin cubrir. Cada línea tiene su test en la task que es dueña del código.

1. **La GPU no soporta el shader de cristal, o no hay aceleración.** La interfaz debe seguir siendo usable con un desenfoque simple; el shader es una mejora, nunca un requisito. → **Task 1**
2. **El usuario cambia de idioma o de tema con la aplicación abierta.** El cambio debe aplicarse en caliente, sin reiniciar el shell, y sin dejar la interfaz a medias (colores a medio cambiar, textos a medio traducir). → **Task 1**
3. **El idioma del sistema no es ES ni EN.** El shell debe caer a inglés sin mostrar claves sin traducir. → **Task 1**
4. **Un componente se registra dos veces o falla al cargar.** El shell debe continuar funcionando con lo que haya podido cargar, y dejar constancia del fallo, no quedarse en negro. → **Task 1**
5. **El usuario tiene una configuración con un esquema de versión anterior.** El shell debe migrarla o resetearla con seguridad, nunca fallar al arrancar. → **Task 1**

---

## Estructura de ficheros

```
shell/src/
  shell.qml                    Entry point de Quickshell (qs -c <dir>)
  main.qml                     Ventana de prueba (M0); en M1 pasa a ser el fallback
  Nimbus/
    qmldir                     Registro del módulo
    Theme.qml                  (M0, no se toca)
    Config.qml                 (M0, no se toca)
    Translations.qml           (M0, no se toca)
    ShellController.qml        Singleton: estado y superficies del shell
    Ipc.qml                    Singleton: bus IPC
    Services.qml               Singleton: servicios Quickshell (notificaciones, tray, Mpris, UPower)
    lib/                       Biblioteca de componentes
      Glass.qml                Superficie de cristal (blur + shader opcional)
      Popup.qml                Base de los popups
      Icon.qml                 Icono SVG con fallback
      Button.qml  Toggle.qml  Slider.qml  SearchField.qml
      ListRow.qml  SectionHeader.qml  Tooltip.qml
    modules/
      TopBar.qml  TopBarMenu.qml
      Dock.qml  DockItem.qml
      ControlCenter.qml
      Notifications.qml
      Spotlight.qml
      Switcher.qml
      Screenshot.qml
      QuickLook.qml
      Wallpaper.qml
      LockScreen.qml
    apps/
      Settings/Settings.qml  SettingsAppearance.qml  SettingsDisplays.qml
      Settings/SettingsKeyboard.qml  SettingsNetwork.qml  SettingsPower.qml
      Settings/SettingsUsers.qml  SettingsSoftware.qml  SettingsAbout.qml
      Store/Store.qml  StoreHome.qml  StoreDetail.qml  StoreUpdates.qml
      Tour/Tour.qml
shell/tests/
  tst_lib.qml  tst_ipc.qml  tst_controller.qml
  tst_topbar.qml  tst_dock.qml  tst_controlcenter.qml  tst_notifications.qml
  tst_spotlight.qml  tst_switcher.qml  tst_capture.qml  tst_wallpaper.qml
  tst_settings.qml  tst_store.qml  tst_tour.qml
```

---

## Olas de ejecución

Las tareas de una misma ola **toca ficheros disjuntos** y pueden ejecutarse en paralelo en worktrees separados. Solo la Task 1 es secuencial: define la biblioteca y el bus de los que dependen todas las demás.

```
Ola 0 (secuencial)     Task 1
Ola A (4 en paralelo)   Task 2 (TopBar) · Task 3 (Dock) · Task 4 (ControlCenter) · Task 5 (Notificaciones)
Ola B (4 en paralelo)   Task 6 (Spotlight) · Task 7 (Switcher) · Task 8 (Capturas+QuickLook) · Task 9 (Fondos+Bloqueo)
Ola C (3 en paralelo)   Task 10 (Ajustes) · Task 11 (Store) · Task 12 (Tour)
```

---

### Task 1: Cimientos del shell — biblioteca de componentes, IPC, controlador y servicios

**Files:**
- Create: `shell/src/shell.qml`
- Create: `shell/src/Nimbus/ShellController.qml`
- Create: `shell/src/Nimbus/Ipc.qml`
- Create: `shell/src/Nimbus/Services.qml`
- Create: `shell/src/Nimbus/PolkitAgent.qml`
- Create: `shell/src/Nimbus/lib/Glass.qml`
- Create: `shell/src/Nimbus/lib/Popup.qml`
- Create: `shell/src/Nimbus/lib/Icon.qml`
- Create: `shell/src/Nimbus/lib/Button.qml`
- Create: `shell/src/Nimbus/lib/Toggle.qml`
- Create: `shell/src/Nimbus/lib/Slider.qml`
- Create: `shell/src/Nimbus/lib/SearchField.qml`
- Create: `shell/src/Nimbus/lib/ListRow.qml`
- Create: `shell/src/Nimbus/lib/SectionHeader.qml`
- Create: `shell/src/Nimbus/lib/Tooltip.qml`
- Modify: `shell/src/Nimbus/qmldir`
- Create: `shell/tests/tst_lib.qml`
- Create: `shell/tests/tst_ipc.qml`
- Create: `shell/tests/tst_controller.qml`

**Interfaces — este es el contrato del que dependen las 11 tareas siguientes:**

`Nimbus.Ipc` (singleton):
```
property string lastTarget: string      // "" si no hay ninguna
property string lastFunction: string
function call(target: string, function_: string): void
```
Targets y funciones exactos (el resto se ignora y se registra como error, nunca revienta):
| target | funciones válidas |
|--------|-------------------|
| `dock` | `toggle`, `open`, `close` |
| `spotlight` | `toggle`, `open`, `close`, `apps`, `files` |
| `switcher` | `next`, `prev`, `commit`, `cancel` |
| `screenshot` | `region`, `window`, `screen` |
| `quicklook` | `toggle`, `open`, `close` |
| `wallpaper` | `toggle`, `open`, `close`, `next`, `prev` |
| `controlcenter` | `toggle`, `open`, `close` |
| `notifications` | `toggle`, `clear` |
| `settings` | `open` |
| `store` | `open` |
| `tour` | `start` |
| `lock` | `lock` |

`Nimbus.ShellController` (singleton):
```
property bool dockOpen: bool
property bool spotlightOpen: bool
property bool controlCenterOpen: bool
property bool switcherOpen: bool
property bool quickLookOpen: bool
property bool wallpaperOpen: bool
property bool notificationsOpen: bool
property string activeSurface: string   // "" | "dock" | "spotlight" | ...
function toggle(surface: string): void
function open(surface: string): void
function close(surface: string): void
function closeAll(): void
signal surfaceRequested(string surface, string argument)
```
**Regla de exclusividad:** solo una superficie puede estar abierta a la vez. `open(surface)` cierra la anterior. `toggle(surface)` alterna. Esto es lo que da la sensación de "un solo sistema" y no de cuatro ventanas sueltas.

`Nimbus.PolkitAgent` (singleton): **el agente de polkit propio de Nimbus** (requisito D11
del spec: sin KDE ni GNOME instalados, `polkit-gnome` sería una ventana ajena al diseño).
Registra el agente en el bus de sistema y pide la contraseña con el **mismo aspecto que el
resto del shell**: ventana de cristal, `Theme.accent`, y los textos por `Config.translated`.
Nunca guarda la contraseña: la usa para la autenticación y la descarta. Debe ser
**defensivo**: si el bus de polkit no está disponible, el shell arranca igual y las
acciones privilegiadas aparecen deshabilitadas con un mensaje.

`Nimbus.Services` (singleton): envuelve los servicios de Quickshell y expone estado **plano**, sin tipos de Quickshell en la API pública, para que los tests no dependan del framework:
```
property bool notificationsAvailable: bool
property bool statusNotifierAvailable: bool
property bool mprisAvailable: bool
property bool upowerAvailable: bool
property int notificationCount: int
property real batteryPercent: real
property bool batteryPresent: bool
property string networkState: string     // "unknown" | "offline" | "online"
property string bluetoothState: string   // "unknown" | "off" | "on"
function notify(title: string, body: string): void
function clearNotifications(): void
```

`Nimbus.lib.*` — cada componente expone una interfaz fija:
- `Glass`: `property bool translucent: true`, `property int blurRadius: int` (40), `property color tint: color`, `property int radius: int` (usa `Theme.radius`), `property bool shaderEnabled: bool` (auto-detecta), y **debe** tener un fallback a desenfoque simple si el shader no está disponible.
- `Popup`: `property bool visible: bool`, `property string title: string`, `property int width: int`, `property int height: int`, `signal closed()`, `property bool modal: bool`.
- `Icon`: `property string name: string`, `property string source: string`, `property int size: int` (16), `property color color: color` (por defecto `Theme.text`).
- `Button`: `property string text: string`, `property string icon: string`, `property bool enabled: bool`, `signal clicked()`.
- `Toggle`: `property bool checked: bool`, `signal toggled(bool value)`.
- `Slider`: `property real value: real`, `property real from: real`, `property real to: real`, `property string unit: string`, `signal moved(real value)`.
- `SearchField`: `property string text: string`, `property string placeholder: string`, `signal accepted(string text)`, `property bool focused: bool`.
- `ListRow`: `property string title: string`, `property string subtitle: string`, `property string icon: string`, `property bool selected: bool`, `signal activated()`.
- `SectionHeader`: `property string text: string`.
- `Tooltip`: `property string text: string`, `property string anchorTo: string`.

**Valores fijos** (no se negocian; el test los fija):
- Animación estándar **150 ms**; apertura/cierre de superficie **200 ms**; dock magnification **1.25**.
- `Theme.barHeight` = 28, `Theme.dockSize` = 64, `Theme.radius` = 12, `Theme.spacing` = 8.
- Los popups aparecen a **24 px** de distancia del borde (excepto el Spotlight, centrado).
- El Spotlight mide **640 × 420** como máximo, y **80 %** del ancho de la pantalla.
- El switcher mide **800 × 300**, centrado.
- Las notificaciones miden **360** de ancho, se apilan arriba a la derecha, máximo **3** visibles a la vez.

- [ ] **Step 1: Escribe los tests que fallan**

Crea `shell/tests/tst_lib.qml` (asserts sobre `Theme` y los valores fijos de la biblioteca), `shell/tests/tst_ipc.qml` (la tabla de targets y funciones) y `shell/tests/tst_controller.qml` (la exclusividad de superficies).

El test del IPC debe comprobar **la tabla completa**, no un par de casos:
```qml
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Ipc"
    when: true

    function test_known_targets_are_accepted() {
        Ipc.call("dock", "toggle")
        compare(Ipc.lastTarget, "dock")
        compare(Ipc.lastFunction, "toggle")
    }

    function test_unknown_target_is_rejected_without_throwing() {
        Ipc.call("noexiste", "toggle")
        compare(Ipc.lastTarget, "")
    }

    function test_unknown_function_for_a_known_target_is_rejected() {
        Ipc.call("dock", "volando")
        compare(Ipc.lastFunction, "")
    }

    function test_every_documented_target_is_present() {
        var targets = ["dock","spotlight","switcher","screenshot","quicklook","wallpaper",
                       "controlcenter","notifications","settings","store","tour","lock"]
        for (var i = 0; i < targets.length; i++) {
            Ipc.call(targets[i], "toggle")
            compare(Ipc.lastTarget, targets[i], "target desconocido: " + targets[i])
        }
    }
}
```

Y el del controlador:
```qml
    function test_only_one_surface_can_be_open() {
        Controller.open("dock")
        Controller.open("spotlight")
        verify(!Controller.dockOpen, "el dock debe cerrarse al abrir el spotlight")
        verify(Controller.spotlightOpen)
    }

    function test_toggle_flips_the_surface() {
        Controller.closeAll()
        Controller.toggle("spotlight")
        verify(Controller.spotlightOpen)
        Controller.toggle("spotlight")
        verify(!Controller.spotlightOpen)
    }
```

- [ ] **Step 2: Ejecuta los tests para verificar que fallan**

Run: `QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests`
Expected: FAIL — `Cannot find module "Nimbus"` para los singletons nuevos, o `Ipc is not defined`.

- [ ] **Step 3: Implementa la biblioteca de componentes**

Crea los 11 componentes en `shell/src/Nimbus/lib/`. Reglas comunes a todos:
- Header SPDX `// SPDX-License-Identifier: GPL-3.0-or-later` como primera línea.
- `import Nimbus` para leer `Theme`.
- Ningún color, radio o espaciado escritos a mano: todo desde `Theme`.
- Ninguna cadena de texto incrustada: nada de `text: "Settings"`; el texto llega por propiedad.
- `Glass.qml` implementa el fallback: si `Qt.application` es null, o el shader no se puede compilar, o la GPU no lo soporta, usa `MultiEffect` con blur simple. El shader opcional (una `ShaderEffect` con un `.frag` propio) entra **solo** si el proyecto decide vendorizarlo; en M1 el shell usa blur simple y el shader se planifica para M2. Deja el punto de extensión (`property bool shaderEnabled`) pero no lo actives.

`Glass.qml` en concreto:
```qml
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Effects
import Nimbus

Rectangle {
    id: root
    property bool translucent: true
    property int blurRadius: 40
    property color tint: Theme.glass
    property int radius: Theme.radius
    color: translucent ? tint : Theme.glassOpaque
    radius: root.radius
    clip: true

    // Fallback: si no hay compositor, la superficie es opaca y no se rompe.
    property bool graphicsAvailable: (typeof Qt.application !== "undefined")
                                      && Qt.application !== null
                                      && Qt.application !== undefined
    visible: root.translucent && root.graphicsAvailable
}
```
La superficie de cristal **debe** seguir siendo legible con `translucent: false`: ese es el camino de fallback que usa el Review Focus #1.

- [ ] **Step 4: Implementa `ShellController.qml`, `Ipc.qml` y `Services.qml`**

`ShellController.qml` es un singleton `QtObject` con las propiedades y funciones del contrato, y la regla de exclusividad. La superficie visible se decide con `property string activeSurface`, y `open()`/`close()` la actualizan.

`Ipc.qml` mantiene la tabla de targets y funciones válidas en una constante y expone `call(target, function_)`. Ante un target o una función desconocidos: **no lanza**, no cambia `lastTarget`/`lastFunction`, y emite un aviso por `console.warn`. Esa es la regla del Review Focus #4 (un fallo no puede Tumbar el shell).

`Services.qml` envuelve los servicios de Quickshell (`Notifications`, `StatusNotifier`, `Mpris`, `UPower`) con **guards** de disponibilidad: cada propiedad vale `false`/`"unknown"` si el servicio no está. En un entorno sin D-Bus, `Services` debe seguir instanciándose sin error.

- [ ] **Step 5: Implementa `shell.qml` y actualiza `qmldir`**

`shell/src/shell.qml` es el entry point de Quickshell. Debe:
- Instanciar `ShellController`, `Ipc` y `Services`.
- Registrar el `IpcHandler` de Quickshell con target `nimbus`, que despacha a `Ipc.call(target, function_)`.
- **Cargar cada módulo de forma defensiva**: si un módulo falla al cargar, el shell sigue arrancando y registra el fallo. Esto es el Review Focus #4. Como QML no tiene `try/catch`, hazlo con un `Loader` por módulo y su propiedad `status`, más un contador de fallos.
- No debe dibujar todavía la barra ni el dock (eso son las Tasks 2 y 3); en M1 la Task 1 entrega el esqueleto y el Review Focus #2/#3.

`qmldir` debe registrar los nuevos singletons y componentes:
```
module Nimbus
singleton Theme 1.0 Theme.qml
singleton Config 1.0 Config.qml
singleton Translations 1.0 Translations.qml
singleton ShellController 1.0 ShellController.qml
singleton Ipc 1.0 Ipc.qml
singleton Services 1.0 Services.qml
singleton PolkitAgent 1.0 PolkitAgent.qml
Glass 1.0 lib/Glass.qml
Popup 1.0 lib/Popup.qml
Icon 1.0 lib/Icon.qml
Button 1.0 lib/Button.qml
Toggle 1.0 lib/Toggle.qml
Slider 1.0 lib/Slider.qml
SearchField 1.0 lib/SearchField.qml
ListRow 1.0 lib/ListRow.qml
SectionHeader 1.0 lib/SectionHeader.qml
Tooltip 1.0 lib/Tooltip.qml
```

- [ ] **Step 6: Ejecuta los tests para verificar que pasan**

Run: `QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests`
Expected: PASS — los 3 test files nuevos en verde y los de M0 (Theme, Config) siguen en verde.

- [ ] **Step 7: Verifica que el shell arranca de verdad**

Run: `QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" timeout 10 /usr/lib/qt6/bin/qmlscene6 shell/src/shell.qml; echo "exit=$?"`
Expected: exit 124 (el proceso sigue vivo) y **stderr vacío**. Si hay warnings de QML, no están bien: el output del test debe ser pristine.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: shell foundations - component library, IPC bus, controller and services"
```

---

### Task 2: Barra superior y menú global de aplicación

**Files:**
- Create: `shell/src/Nimbus/modules/TopBar.qml`
- Create: `shell/src/Nimbus/modules/TopBarMenu.qml`
- Create: `shell/tests/tst_topbar.qml`
- Modify: `shell/src/shell.qml` (montar la barra)

**Interfaces:**
- Consumes: `Theme`, `Config`, `Translations`, `ShellController`, `Services`, `lib/*`.
- Produces:
  - `TopBar` — `PanelWindow` con `anchors.top`, `height: Theme.barHeight`, `exclusiveZone: Theme.barHeight`.
    `property bool menuOpen: bool`, `property string currentApp: string`, `signal menuRequested(string appId)`.
  - `TopBarMenu` — `property string appId: string`, `property var entries: []` (lista de `{title, items:[{label, action, checked, disabled}]}`), `signal actionTriggered(string appId, string action)`.
- **Comportamiento:**
  - Izquierda: logo de Nimbus + nombre de la aplicación activa.
  - Derecha: items de estado (red, volumen, batería, bluetooth, DND) + reloj.
  - El reloj usa `Config.translated` para el formato y el idioma.
  - Altura exacta `Theme.barHeight` (28). Fondo de cristal con `lib/Glass`.
  - Si no hay batería (`Services.batteryPresent === false`), **no** se muestra el item de batería. Si no hay bluetooth, no se muestra su item. Esa es la regla del "todo parece nativo": lo que no existe, no se dibuja.

- [ ] **Step 1**: Escribe `shell/tests/tst_topbar.qml` con asserts sobre: la altura es `Theme.barHeight`; los items se filtran según `Services.batteryPresent` / `Services.bluetoothState`; el formato del reloj cambia con el locale.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `TopBar.qml` y `TopBarMenu.qml`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta la barra en `shell.qml` de forma defensiva (con `Loader`).
- [ ] **Step 6**: Verifica que el shell sigue arrancando sin warnings (mismo comando del Step 7 de la Task 1).
- [ ] **Step 7**: Commit — `feat: top bar with global application menu and status items`.

---

### Task 3: Dock

**Files:**
- Create: `shell/src/Nimbus/modules/Dock.qml`
- Create: `shell/src/Nimbus/modules/DockItem.qml`
- Create: `shell/tests/tst_dock.qml`
- Modify: `shell/src/shell.qml`

**Interfaces:**
- Produces:
  - `Dock` — `PanelWindow` con `anchors.bottom`, `height: Theme.dockSize`.
    `property var favorites: []` (lista de `{id, name, icon}`), `property var running: []`, `property bool autoHide: bool` (por defecto `false`), `property real magnification: real` (1.25).
    `signal appActivated(string appId)`, `signal appContextRequested(string appId)`.
  - `DockItem` — `property string appId: string`, `property string icon: string`, `property string label: string`, `property bool running: bool`, `property int badgeCount: int`, `property bool magnified: bool`, `signal activated()`, `signal contextRequested()`.
- **Comportamiento:**
  - El tamaño escalado de un item es `Theme.dockSize * magnification` en el eje cercano al cursor, con interpolación suave.
  - Indicador de app en ejecución: un punto bajo el icono.
  - Badge: número en la esquina superior derecha, oculto si es 0.
  - La papelera va al final, separada por un separador.
  - Con `autoHide: true`, el dock se oculta cuando el cursor no está sobre él o sobre una ventana; con `false` (por defecto) siempre visible.

- [ ] **Step 1**: Escribe `shell/tests/tst_dock.qml`: la escala del item magnificado es `dockSize * magnification`; el badge es 0 → oculto; el separador de la papelera está al final; `autoHide` por defecto `false`.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `Dock.qml` y `DockItem.qml`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta el dock en `shell.qml` de forma defensiva.
- [ ] **Step 6**: Verifica que el shell arranca sin warnings.
- [ ] **Step 7**: Commit — `feat: dock with magnification, running indicators and badges`.

---

### Task 4: Centro de Control

**Files:**
- Create: `shell/src/Nimbus/modules/ControlCenter.qml`
- Create: `shell/tests/tst_controlcenter.qml`
- Modify: `shell/src/shell.qml`

**Interfaces:**
- Produces: `ControlCenter` — `FloatingWindow`, `property bool visible`, `property string brightness: string`, `property int volume: int`, `property bool microphoneMuted: bool`, `property bool airplaneMode: bool`, `property string powerProfile: string` ("economy" | "balanced" | "performance"), `property string themeMode: string` ("light" | "dark" | "auto"), `property string accent: string`.
  Señales: `brightnessChanged(string value)`, `volumeChanged(int value)`, `airplaneToggled(bool on)`, `powerProfileChanged(string profile)`, `themeModeChanged(string mode)`, `accentChanged(string hex)`, `sessionActionRequested(string action)` con `action` ∈ {"lock", "suspend", "logout", "reboot", "shutdown"}.
- **Comportamiento:**
  - Se abre en la esquina superior derecha, **24 px** de distancia del borde (valor fijo).
  - Los toggles de tema y acento escriben en `Config` a través de `Config.setMode` / `Config.setAccent`, de modo que el cambio se aplique **en caliente** (Review Focus #2).
  - El brillo, el volumen y el wifi se **leen** de `Services`; si un servicio no está disponible, el control aparece deshabilitado, no roto.
  - Todas las etiquetas por `Config.translated`.

- [ ] **Step 1**: Escribe `shell/tests/tst_controlcenter.qml`: posición a 24 px del borde; `themeModeChanged` escribe en `Config`; un control sin servicio aparece deshabilitado; las acciones de sesión emiten la señal correcta.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `ControlCenter.qml`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta en `shell.qml`.
- [ ] **Step 6**: Verifica arranque sin warnings.
- [ ] **Step 7**: Commit — `feat: control center with live theme, accent and power profile controls`.

---

### Task 5: Notificaciones

**Files:**
- Create: `shell/src/Nimbus/modules/Notifications.qml`
- Create: `shell/tests/tst_notifications.qml`
- Modify: `shell/src/Nimbus/Services.qml` (integrar el servicio de notificaciones)
- Modify: `shell/src/shell.qml`

**Interfaces:**
- Produces: `Notifications` — `FloatingWindow` (o `PanelWindow` anclado arriba a la derecha), `property var items: []` (lista de `{id, app, title, body, timestamp, actions}`), `property bool dnd: bool`, `property int maxVisible: int` (3), `property int toastWidth: int` (360).
  Señales: `dismissed(string id)`, `actionTriggered(string id, string actionId)`, `dndToggled(bool on)`.
- **Comportamiento:**
  - Las notificaciones llegan como **toasts** que se acumulan arriba a la derecha; máximo **3** visibles; el resto se apila.
  - Las notificaciones del **mismo app se agrupan** bajo una sola entrada con un contador.
  - El contador `Services.notificationCount` refleja el total (grupado), no el de toasts.
  - DND silencia las notificaciones nuevas pero **no** borra las existentes.
  - El shell **debe ser el daemon de notificaciones** (registra `org.freedesktop.Notifications`), desregistrando el del sistema si lo hay, como hace MacShell.

- [ ] **Step 1**: Escribe `shell/tests/tst_notifications.qml`: agrupación por app; máximo 3 toasts visibles; DND no borra existentes; el contador refleja los agrupados.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `Notifications.qml` e integra el servicio en `Services.qml`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta en `shell.qml`.
- [ ] **Step 6**: Verifica arranque sin warnings.
- [ ] **Step 7**: Commit — `feat: notification centre with grouping, DND and toast stacking`.

---

### Task 6: Spotlight

**Files:**
- Create: `shell/src/Nimbus/modules/Spotlight.qml`
- Create: `shell/tests/tst_spotlight.qml`
- Modify: `shell/src/shell.qml`

**Interfaces:**
- Produces: `Spotlight` — `FloatingWindow`, `property bool visible`, `property string query: string`, `property var results: []` (lista de `{id, kind, title, subtitle, icon, action}` con `kind` ∈ {"app", "file", "action", "calc", "clipboard", "emoji"}), `property int maxWidth: int` (80 % del ancho de pantalla), `property int maxHeight: int` (420).
  Señales: `resultActivated(string id)`, `closed()`.
- **Comportamiento:**
  - Centrado en pantalla, como máximo **640 × 420** y **80 %** del ancho.
  - La búsqueda filtra por `title` **y** `subtitle`, sin distinguir mayúsculas, y ordena por: coincidencia exacta > coincidencia por prefijo > coincidencia por subcadena.
  - **Calculadora:** si la consulta parece una expresión aritmética, el primer resultado es el resultado numérico. Formato: hasta 2 decimales, sin ceros a la derecha (`3 + 4` → `7`, `1/3` → `0.33`).
  - **Emoji:** la consulta se busca en la tabla de emoji de Unicode (unicode-emoji en el paquete `unicode-emoji` de Arch) y se ofrecen coincidencias.
  - `Enter` activa el resultado seleccionado; `Esc` cierra.
  - Con la consulta vacía, muestra las aplicaciones más usadas.

- [ ] **Step 1**: Escribe `shell/tests/tst_spotlight.qml`: el filtrado ordena por prefijo antes que por subcadena; la calculadora devuelve `7` para `3 + 4` y `0.33` para `1/3`; una consulta vacía devuelve las apps más usadas.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `Spotlight.qml`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta en `shell.qml`.
- [ ] **Step 6**: Verifica arranque sin warnings.
- [ ] **Step 7**: Commit — `feat: spotlight with fuzzy search, calculator and emoji`.

---

### Task 7: Switcher de aplicaciones

**Files:**
- Create: `shell/src/Nimbus/modules/Switcher.qml`
- Create: `shell/tests/tst_switcher.qml`
- Modify: `shell/src/shell.qml`

**Interfaces:**
- Produces: `Switcher` — `FloatingWindow`, `property bool visible`, `property var entries: []` (lista de `{appId, title, icon}`), `property int index: int`, `property int width: int` (800), `property int height: int` (300).
  Señales: `committed(string appId)`, `cancelled()`.
- **Comportamiento:**
  - `Alt+Tab` / `Cmd+Tab`cicla hacia delante; `Shift` invierte el sentido.
  - Centrado, 800 × 300.
  - `next` / `prev` mueven el índice con wraparound; `commit` activa; `cancel` cierra sin activar.

- [ ] **Step 1**: Escribe `shell/tests/tst_switcher.qml`: el wraparound del índice; `commit` emite `appId`; `cancel` no activa nada.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `Switcher.qml`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta en `shell.qml`.
- [ ] **Step 6**: Verifica arranque sin warnings.
- [ ] **Step 7**: Commit — `feat: application switcher with cmd-tab semantics`.

---

### Task 8: Capturas de pantalla y QuickLook

**Files:**
- Create: `shell/src/Nimbus/modules/Screenshot.qml`
- Create: `shell/src/Nimbus/modules/QuickLook.qml`
- Create: `shell/tests/tst_capture.qml`
- Modify: `shell/src/shell.qml`

**Interfaces:**
- Produces:
  - `Screenshot` — `property bool visible`, `property string mode: string` ("region" | "window" | "screen"), `property string savedPath: string`, `property string error: string`.
    Señales: `captured(string path)`, `cancelled()`.
  - `QuickLook` — `property bool visible`, `property string path: string`, `property string title: string`, `property string kind: string` ("image" | "text" | "pdf" | "unknown").
    Señales: `closed()`.
- **Comportamiento:**
  - La captura de región usa `grim` + `slurp`; la de pantalla, `grim`; la de ventana, la herramienta de captura de Hyprland.
  - Sin red, la captura **falla de forma limpia**: `error` con un mensaje accionable, nunca una excepción.
  - QuickLook se abre con la **barra espaciadora** sobre un archivo del gestor de archivos, y se cierra con `Esc`.
  - QuickLook para un PDF usa el visor de PDF del sistema; para texto, previsualiza las primeras líneas; para imágenes, la imagen.

- [ ] **Step 1**: Escribe `shell/tests/tst_capture.qml`: el modo por defecto es `region`; un fallo de `grim` deja `error` con mensaje y `visible === false`; QuickLook deduce el `kind` a partir de la extensión.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `Screenshot.qml` y `QuickLook.qml`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta en `shell.qml`.
- [ ] **Step 6**: Verifica arranque sin warnings.
- [ ] **Step 7**: Commit — `feat: screenshot capture and quick look`.

---

### Task 9: Selector de fondos y pantalla de bloqueo

**Files:**
- Create: `shell/src/Nimbus/modules/Wallpaper.qml`
- Create: `shell/src/Nimbus/modules/LockScreen.qml`
- Create: `shell/tests/tst_wallpaper.qml`
- Modify: `shell/src/shell.qml`

**Interfaces:**
- Produces:
  - `Wallpaper` — `FloatingWindow`, `property bool visible`, `property var wallpapers: []` (lista de `{path, name, dark, light}`), `property string selected: string`, `property string folder: string` (por defecto `~/Pictures/Wallpapers`).
    Señales: `chosen(string path)`, `closed()`.
  - `LockScreen` — `property bool visible`, `property string time: string`, `property string date: string`, `property bool locked: bool`.
    Señales: `unlockRequested(string password)`, `sessionActionRequested(string action)`.
- **Comportamiento:**
  - El selector lista los fondos empaquetados y los de la carpeta del usuario; los pares claro/oscuro se ofrecen como una sola entrada con dos variantes.
  - La pantalla de bloqueo muestra reloj, fecha y los controles multimedia; acepta la contraseña por PAM (el mecanismo lo aporta `hyprlock`); **nunca** almacena la contraseña.
  - `Ctrl+Alt+L` bloquea.

- [ ] **Step 1**: Escribe `shell/tests/tst_wallpaper.qml`: los pares claro/oscuro se agrupan en una entrada; la carpeta por defecto es `~/Pictures/Wallpapers`; la pantalla de bloqueo emite `unlockRequested` con la contraseña y no la conserva.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `Wallpaper.qml` y `LockScreen.qml`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta en `shell.qml`.
- [ ] **Step 6**: Verifica arranque sin warnings.
- [ ] **Step 7**: Commit — `feat: wallpaper picker and lock screen`.

---

### Task 10: Ajustes del sistema

**Files:**
- Create: `shell/src/Nimbus/apps/Settings/Settings.qml`
- Create: `shell/src/Nimbus/apps/Settings/SettingsAppearance.qml`
- Create: `shell/src/Nimbus/apps/Settings/SettingsDisplays.qml`
- Create: `shell/src/Nimbus/apps/Settings/SettingsKeyboard.qml`
- Create: `shell/src/Nimbus/apps/Settings/SettingsNetwork.qml`
- Create: `shell/src/Nimbus/apps/Settings/SettingsBluetooth.qml`
- Create: `shell/src/Nimbus/apps/Settings/SettingsSound.qml`
- Create: `shell/src/Nimbus/apps/Settings/SettingsPower.qml`
- Create: `shell/src/Nimbus/apps/Settings/SettingsUsers.qml`
- Create: `shell/src/Nimbus/apps/Settings/SettingsSoftware.qml`
- Create: `shell/src/Nimbus/apps/Settings/SettingsAbout.qml`
- Create: `shell/tests/tst_settings.qml`
- Modify: `shell/src/shell.qml`

**Interfaces:**
- Produces: `Settings` — `FloatingWindow` con sidebar de secciones y panel de contenido.
  `property string section: string`, `property var sections: []` (lista de `{id, title, icon}`), `signal sectionChanged(string id)`.
  Secciones exactas, en este orden: `appearance`, `displays`, `keyboard`, `network`, `bluetooth`, `sound`, `power`, `users`, `software`, `about`.
- **Comportamiento:**
  - Las secciones sin servicio disponible (por ejemplo `bluetooth` sin `bluez`) se muestran **deshabilitadas**, no ocultas ni rotas.
  - `SettingsSoftware` muestra el estado de las actualizaciones y enlaza con `nimbus-update`.
  - `SettingsAbout` muestra versión, kernel, hardware y los créditos/licencias (que deben incluir la entrada de MacShell/MIT).

- [ ] **Step 1**: Escribe `shell/tests/tst_settings.qml`: el orden exacto de las 10 secciones; una sección sin servicio aparece deshabilitada; cambiar de sección emite `sectionChanged`.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `Settings.qml` y las 10 secciones.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta en `shell.qml`.
- [ ] **Step 6**: Verifica arranque sin warnings.
- [ ] **Step 7**: Commit — `feat: system settings application`.

---

### Task 11: Nimbus Store

**Files:**
- Create: `shell/src/Nimbus/apps/Store/Store.qml`
- Create: `shell/src/Nimbus/apps/Store/StoreHome.qml`
- Create: `shell/src/Nimbus/apps/Store/StoreDetail.qml`
- Create: `shell/src/Nimbus/apps/Store/StoreUpdates.qml`
- Create: `shell/src/Nimbus/apps/Store/store_backend.py`
- Create: `shell/tests/tst_store.qml`
- Modify: `shell/src/shell.qml`

**Interfaces:**
- Produces:
  - `Store` — `FloatingWindow`, `property string view: string` ("home" | "detail" | "updates"), `property var categories: []` (lista de `{id, title}`), `property string currentCategory: string`, `property var currentApp: object`.
    Señales: `installRequested(string appId)`, `uninstallRequested(string appId)`, `updateAllRequested()`.
  - `StoreHome.qml`, `StoreDetail.qml`, `StoreUpdates.qml` — las tres vistas.
  - `store_backend.py` — módulo Python **independiente de la GUI**, con una API de alto nivel y easily testeable:
    ```
    FLATPAK_REMOTE = "flathub"
    def list_apps(category: str = "") -> list[dict]
    def search(query: str) -> list[dict]
    def get_app(app_id: str) -> dict
    def is_installed(app_id: str) -> bool
    def install(app_id: str) -> tuple[bool, str]
    def uninstall(app_id: str) -> tuple[bool, str]
    def list_updates() -> list[dict]
    ```
    Cada función devuelve datos **planos** (dict/list/str/bool), nunca objetos de libflatpak, para que el QML pueda consumirlos y los tests puedan ejercitarlos sin Flatpak instalado.
- **Comportamiento:**
  - Categorías exactas: `games`, `productivity`, `communication`, `creative`, `media`, `development`, `utilities`.
  - La ficha de app muestra: icono, capturas, descripción, **origen** (`Flathub` o `Nativo`) y el botón instalar/desinstalar.
  - La pestaña de actualizaciones lista las pendientes y ofrece "Actualizar todo" — **un solo botón**, que es la regla del spec ("el único botón que el usuario tiene que pulsar").
  - Si Flatpak no está disponible, la Store **no se rompe**: lo dice con un mensaje y ofrece solo las apps nativas.
  - El backend debe distinguir "no instalado" de "error", y el error debe llegar a la UI como texto, no como excepción sin capturar.

- [ ] **Step 1**: Escribe `shell/tests/tst_store.qml` y un test de pytest para `store_backend.py`:
  - el backend no lanza con Flatpak ausente; devuelve listas vacías y un mensaje de error legible;
  - `search` filtra por título sin distinguir mayúsculas;
  - las 7 categorías exactas;
  - la señal `updateAllRequested` se emite desde la vista de actualizaciones.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa el backend Python y las cuatro vistas QML.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta en `shell.qml`.
- [ ] **Step 6**: Verifica arranque sin warnings.
- [ ] **Step 7**: Commit — `feat: Nimbus Store with flatpak backend and native fallback`.

---

### Task 12: Tour de bienvenida

**Files:**
- Create: `shell/src/Nimbus/apps/Tour/Tour.qml`
- Create: `shell/src/Nimbus/apps/Tour/TourStep.qml`
- Create: `shell/tests/tst_tour.qml`
- Modify: `shell/src/shell.qml`

**Interfaces:**
- Produces: `Tour` — `FloatingWindow`, `property bool visible`, `property var steps: []` (lista de `{id, title, body, target, anchor}`), `property int index: int`, `property bool finished: bool`.
  Señales: `finished()`, `skipped()`.
- **Comportamiento:**
  - **7 a 9 pasos**, los mismos que el spec describe para la experiencia de primer uso: dock, Spotlight, menú superior, Centro de Control, notificaciones, atajos de teclado, gameready, y un cierre.
  - Duración total ≤ **2 minutos**: cada paso tiene un texto de **máximo 30 palabras**.
  - `Esc` salta; `Enter`/clic avanza. Al terminar, `finished` se emite **una sola vez** y el tour **no vuelve a aparecer** (se marca en `Config`).
  - El texto va por `Config.translated` y **existe en ES y EN**.

- [ ] **Step 1**: Escribe `shell/tests/tst_tour.qml`: entre 7 y 9 pasos; ningún texto de paso supera las 30 palabras; `Esc` emite `skipped` y no vuelve a mostrarse; `finished` se emite una sola vez.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `Tour.qml` y `TourStep.qml`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Monta en `shell.qml`.
- [ ] **Step 6**: Verifica arranque sin warnings.
- [ ] **Step 7**: Commit — `feat: first-run onboarding tour`.

---

## Criterio de terminación de M1

M1 está completo cuando **todas** estas condiciones se cumplen:

1. `QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests` pasa entero.
2. `qmlscene6 shell/src/shell.qml` arranca **sin un solo warning** en stderr.
3. Los 13 módulos del shell están montados en `shell.qml` y cada uno se carga con `Loader.status === Loader.Ready`.
4. La tabla de IPC del Task 1 está completa y `nimbus-shell ipc call <target> <fn>` llega a cada superficie.
5. Todas las cadenas visibles existen en **español e inglés**; ninguna está incrustada en el QML.
6. Ningún componente lee un color o una métrica fuera de `Theme`.
7. `/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v` sigue en verde.
8. `python tools/check_spdx.py --root .` pasa.

Cuando las ocho se cumplan, M1 está cerrado y el **Plan 3 (instalador)** puede arrancar.
