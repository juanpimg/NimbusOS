# Referencia de la API de Quickshell 0.3.2 (y Hyprland 0.56)

<!-- La versión en inglés seguirá. -->

Esta página recoge la **API real** que usa Nimbus, verificada leyendo los
`.qmltypes` del paquete `quickshell` (0.3.2) y del paquete `hyprland` (0.56.2)
**dentro de la ISO ya construida**, no de memoria ni de la documentación en
línea. Cuando una versión cambie, esta tabla hay que volver a sacarla:

```bash
CH=iso/work/x86_64/airootfs      # el chroot que deja la build
find "$CH/usr/lib/qt6/qml/Quickshell" -name '*.qmltypes'
```

## La trampa que más caro ha salido: `Loader` no instancia ventanas

`PanelWindow` y `FloatingWindow` derivan de `QQuickWindow`, **no** de
`QQuickItem`. Un `Loader` de QML solo puede instanciar `Item`s, así que

```qml
Loader { source: "Nimbus/modules/TopBar.qml" }   // NO FUNCIONA
```

carga un `PanelWindow` y **falla en silencio**: el shell arranca, la puerta de
readiness dice que todo está bien, y **no se ve ninguna superficie**. Por eso
las superficies se montan **como ventanas propias** y, cuando hace falta carga
defensiva, con creación imperativa:

```qml
// Comprobación de disponibilidad antes de instanciar
var component = Qt.createComponent("Nimbus", "TopBar")   // por TIPO
if (component.status === Component.Ready) {
    var win = component.createObject(null)                 // null = sin padre
}
```

o, si el componente está registrado como singleton en
`shell/src/Nimbus/qmldir`, se usa directamente el tipo.

**Todo componente que sea ventana tiene que comprobarse en el `qmldir`**:
mira cómo está registrado cada uno antes de cambiar su forma de montaje.

## La raíz: `ShellRoot`

```qml
import Quickshell
ShellRoot { ... }
```

`ShellRoot` es la raíz de **toda** config de Quickshell. No es `Item`, no es
`Window`: si la raíz no es `ShellRoot`, `qs -c` muere al instante.

## `Quickshell.Wayland`

### `PanelWindow` — superficies ancladas (barra, Dock, notificaciones)

| Propiedad | Tipo | Para qué |
|---|---|---|
| `anchors` | `{left, right, top, bottom}` (bool) | a qué bordes se ancla |
| `margins` | `Margins` | separación respecto al borde |
| `exclusiveZone` | `int` | píxeles que se **reservan** (la barra reserva su alto; el Dock, su franja) |
| `exclusionMode` | `Normal` \| `Ignore` \| `Auto` | cómo se comporta la zona reservada |
| `aboveWindows` | `bool` | si se pinta por encima de las ventanas normales |
| `focusable` | `bool` | si puede recibir el foco del teclado |
| `layer` | `Background` \| `Bottom` \| `Top` \| `Overlay` | **capa del layer-shell** |
| `namespace` | `QString` | nombre con el que aparece en `wlrctl`/la Wayback Machine |
| `keyboardFocus` | `None` \| `Exclusive` \| `OnDemand` | política de foco |

Reparto por capa en Nimbus:

| Superficie | `layer` | `exclusiveZone` |
|---|---|---|
| Fondo del escritorio | `Background` | 0 |
| Barra de menú | `Top` | su altura (reserva espacio) |
| Dock | `Bottom` | su tamaño (reserva espacio) |
| Notificaciones | `Top` | 0 |
| Spotlight, Switcher, QuickLook, Ajustes, Store, Tour | `Overlay` | 0 |

### `FloatingWindow` — ventanas libres (dialogos, paneles)

| Propiedad | Tipo |
|---|---|
| `title` | `QString` |
| `minimumSize` / `maximumSize` | `QSize` |
| `minimized` / `maximized` / `fullscreen` | `bool` |
| `parentWindow` | `QObject` |
| `startSystemMove()` / `startSystemResize(edges)` | métodos |

### Base común (`WindowInterface`)

`visible`, `width`, `height`, `implicitWidth`, `implicitHeight`,
`color` (`QColor`), `mask` (`PendingRegion`), `surfaceFormat`
(`QsSurfaceFormat` con `opaque`), `contentItem`, `screen`,
`devicePixelRatio`, `updatesEnabled`, `data`.

## `Quickshell.Services`

Los servicios que usa el shell de Nimbus:

| Módulo | Tipo | Qué da |
|---|---|---|
| `Notifications` | `NotificationServerQml` | `trackedNotifications` (modelo), `persistenceSupported`, `bodySupported`, `actionsSupported` |
| `Mpris` | `MprisQml` | `players` (modelo); cada `MprisPlayer` con `trackTitle`, `trackArtist`, `playbackState`, `volume`… |
| `Polkit` | `PolkitAgent` | `flow` (`AuthFlow`: `message`, `identities`, `selectedIdentity`, `isResponseRequired`), `isRegistered` |
| `SystemTray` | `SystemTray` | `items` (modelo de `StatusNotifierItem`: `icon`, `status`, `menu`) |
| `UPower` | `UPowerQml` | `onBattery`, `devices` (porcentaje, salud), `displayDevice` |
| `Pipewire` | `Pipewire` | `defaultAudioSink`, `nodes`, `links`, `ready` |
| `Pam` | `PamContext` | `start()`, `responseRequired`, `responseVisible` |
| `Greetd` | `Greetd` | `state`, `user`, `cancelSession()` |

## `Quickshell.Hyprland` (para el compositor)

- `HyprlandIpcQml`: `focusedWorkspace`, `focusedMonitor`, `activeToplevel`,
  `monitors`, `workspaces`, `toplevels`, `refreshToplevels()`…
- `HyprlandToplevel`: `title`, `activated`, `urgent`, `workspace`, `monitor`,
  `wayland`.
- `HyprlandWorkspace`: `id`, `name`, `active`, `focused`, `toplevels`.
- `HyprlandWindow` (extensiones de superficie): `opacity`, `visibleMask`.
- `GlobalShortcut` (atajos globales del compositor): `pressed`, `appid`, `name`.

## La API de Lua de Hyprland 0.56 es **otra** y no se mezcla con Quickshell

Hyprland 0.56 acepta una config **Lua** (`hyprland.lua`), con su propio
vocabulario, que **no** es el de QML:

```lua
hl.config({ general = { layout = "floating" } })
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = 1 }))
hl.on("hyprland.start", function() ... end)
```

| En Lua de Hyprland | En QML de Quickshell |
|---|---|
| `hl.bind` | `GlobalShortcut` / `HyprlandIpcQml` |
| `hl.dsp.*` | IPC de Hyprland (`hyprctl dispatch`) |
| `hl.on("hyprland.start")` | evento de Quickshell |

**No mezcles las dos**: `dots/hypr/hyprland.lua` es config de **Hyprland** y
`shell/src/**` es QML de **Quickshell**. La config de Hyprland es la que
arranca el shell (`hl.on("hyprland.start")` → `nimbus-start` → `nimbus-shell`).

## Cómo se ejecuta el shell

`shell/nimbus-shell` (instalado en `/usr/bin/nimbus-shell`):

```bash
export QML2_IMPORT_PATH="/usr/lib/nimbus/shell/src:${QML2_IMPORT_PATH}"
exec qs -c /usr/lib/nimbus/shell/src "$@"
```

`QML2_IMPORT_PATH` debe apuntar al **padre** del directorio del módulo: el
`qmldir` de Nimbus está en `shell/src/Nimbus/qmldir` y el import path es
`shell/src`. QML resuelve un módulo buscando un **directorio** con ese nombre.

## Probar el shell sin compositor

Los tests QML **no pueden instanciar `PanelWindow` ni `FloatingWindow`**
(necesitan un compositor). Por eso la lógica de cada superficie vive en un
`Item` puro aparte (`TopBarMenu`, `DockItem`…) que sí se puede testear, y el
montaje se comprueba con **tests estáticos** que leen el QML como texto
(`tests/test_shell_entrypoint.py`).

Para probar la superficie de verdad hace falta la ISO:

```bash
bash tests/integration/boot_live.sh --iso out/nimbus-<fecha>-x86_64.iso --timeout 600
```

Y para **ver** el escritorio, la captura del guest vía el monitor de QEMU
(el `screendump` del monitor; la ventana GTK depende del gestor de ventanas del
host y puede estar en otro plano):

```bash
printf 'screendump /tmp/opencode/shot.ppm\n' | socat - UNIX-CONNECT:/tmp/opencode/mon.sock
convert /tmp/opencode/shot.ppm /tmp/opencode/shot.png
```
