// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Nimbus

// Entrada del shell Nimbus (M1 integrado + M4 montaje): monta las superficies
// y las aplicaciones de forma defensiva.
//
// REGLA DE MONTAJE (M4): un `Loader` de QML solo instancia `Item`s, nunca
// ventanas (`QQuickWindow`). Por eso cada superficie que ES una ventana
// (TopBar: `PanelWindow`; Settings: `FloatingWindow`) se crea de forma
// imperativa en `Component.onCompleted` con `loadModule` (`Qt.createComponent`
// + `createObject(null)`); si el componente falla, `moduleFailures` cuenta el
// fallo y el shell sigue arrancando, nunca muere por el. Las superficies que
// son contenido (`Item`) van tras un `Loader` con vigilancia de `status`:
// si uno falla al cargar, `moduleFailures` cuenta el fallo y el shell sigue.
//
// Visibilidad: la barra superior y el Dock estan SIEMPRE visibles (macOS);
// Spotlight, Switcher, QuickLook, Control Center, Notificaciones y la galeria
// de fondos son BAJO DEMANDA (se abren con atajos/IPC via `ShellController`);
// el bloqueo arranca CERRADO. El tour solo se muestra en el primer arranque
// (`!Config.tourCompleted`). El bus `Ipc` llega como
// (`Ipc.call(target, fn)` -> `ShellController.toggle/open/close` o
// `surfaceRequested`; ver `Nimbus/Ipc.qml`).
//
// NOTA DE API (ruling M1): la senal de finalizacion del tour se llama
// `tourFinished()` y la propiedad `finished` se queda (el spec pedia
// `signal finished()` y chocaba con la propiedad: duplicated-name y
// TypeError al emitir).
ShellRoot {
    id: root

    // Contador de fallos de carga de modulos: un modulo roto suma aqui y
    // el shell sigue arrancando, nunca muere por el.
    property int moduleFailures: 0

    // Ventanas montadas de forma imperativa (no pueden ir en un Loader).
    property var topBarWindow: null
    property var settingsWindow: null

    // Bloqueo: `LockScreen.locked` vale true por defecto (el modulo arranca
    // bloqueado), asi que la ventana NO puede depender solo de `item.locked`:
    // el escritorio live apareceria con la pantalla de bloqueo en cada
    // arranque. Este flag arranca en false y solo se activa cuando alguien
    // pide bloquear (`Ipc.call("lock", "lock")` o el Centro de control).
    property bool lockRequested: false

    // Titulo resuelto por i18n (mantiene `Config.translated(` en el entry
    // point que exige el gate de sistema de diseno).
    readonly property string storeTitle: Config.translated("app.store.title")

    function logModuleFailure(moduleName, error) {
        moduleFailures += 1
        console.warn("shell: no se pudo cargar el modulo " + moduleName + ": " + error)
    }

    // Punto de carga imperativa (M0/M1): crea el componente de forma
    // guardada y devuelve null contando el fallo en vez de tumbar el shell.
    // Para ventanas se llama con parent null (una ventana no tiene padre
    // visual); la referencia se guarda en una property para que el GC de
    // QML no la recoja.
    function loadModule(source, parent) {
        var component = Qt.createComponent(source)
        if (component.status !== Component.Ready) {
            logModuleFailure(source, component.errorString())
            return null
        }
        var obj = component.createObject(parent)
        if (obj === null) {
            logModuleFailure(source, component.errorString())
            return null
        }
        return obj
    }

    // Iconos del Dock: aplicaciones reales con nombre traducido y color de
    // baldosa desde Theme (sin literales: la golden rule lo exige tambien
    // aqui). El Dock dibuja, no decide: estos datos entran por `favorites`.
    function defaultDockApps() {
        return [
            { "id": "terminal", "name": Config.translated("app.terminal"), "icon": "terminal", "color": Theme.appGray },
            { "id": "files", "name": Config.translated("app.files"), "icon": "files", "color": Theme.appBlue },
            { "id": "browser", "name": Config.translated("app.browser"), "icon": "browser", "color": Theme.appOrange },
            { "id": "store", "name": Config.translated("app.store"), "icon": "store", "color": Theme.appGreen },
            { "id": "settings", "name": Config.translated("app.settings"), "icon": "settings", "color": Theme.appPurple }
        ]
    }

    function refreshDockFavorites() {
        if (dockLoader.status === Loader.Ready && dockLoader.item)
            dockLoader.item.favorites = root.defaultDockApps()
    }

    Component.onCompleted: {
        // Las ventanas no pueden ir en un Loader: se montan aqui de forma
        // defensiva (un fallo cuenta en moduleFailures, no tumba el shell).
        topBarWindow = loadModule("Nimbus/modules/TopBar.qml", null)
        settingsWindow = loadModule("Nimbus/apps/Settings/Settings.qml", null)
        // Fuerza la instanciacion de los singletons base del shell.
        ShellController.closeAll()
        Services.clearNotifications()
    }

    IpcHandler {
        target: "nimbus"

        // Firmada para IPC: los argumentos sin tipo llegan como QVariant y
        // Quickshell no puede cruzarlos ("cannot be used across IPC").
        function call(target: string, fn: string): void {
            Ipc.call(target, fn)
        }
    }

    // Reapertura del tour y bloqueo: `Ipc.call("tour", "start")` llega como
    // `surfaceRequested("tour", "start")`; `Ipc.call("lock", "lock")` cierra
    // todo y avisa como `surfaceRequested("lock", "lock")`.
    Connections {
        target: ShellController
        function onSurfaceRequested(surface, argument) {
            if (surface === "tour" && argument === "start") {
                if (tourLoader.status === Loader.Ready && tourLoader.item) {
                    tourLoader.item.reset()
                }
            }
            if (surface === "lock") {
                // El bloqueo se pide explicitamente: sin este flag la
                // ventana se abriria en cada arranque (locked = true).
                root.lockRequested = true
                if (lockLoader.status === Loader.Ready && lockLoader.item) {
                    lockLoader.item.lock()
                }
            }
        }
    }

    // Los nombres traducidos del Dock siguen al idioma en caliente.
    Connections {
        target: Config
        function onLocaleChanged() {
            root.refreshDockFavorites()
        }
    }

    // Fondo del escritorio: capa base con el color del sistema.
    PanelWindow {
        id: backgroundWindow
        WlrLayershell.layer: WlrLayer.Background
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Theme.background
    }

    // Dock: PanelWindow inferior con zona exclusiva, SIEMPRE visible (macOS:
    // el Dock no es un overlay bajo demanda). El contenido (Item) va tras un
    // Loader defensivo; los datos entran por `favorites` al cargarse.
    PanelWindow {
        id: dockWindow
        WlrLayershell.layer: WlrLayer.Top
        anchors {
            bottom: true
            left: true
            right: true
        }
        height: Theme.dockSize
        exclusiveZone: Theme.dockSize
        visible: dockLoader.status === Loader.Ready
        Loader {
            id: dockLoader
            anchors.fill: parent
            source: "Nimbus/modules/Dock.qml"
            onLoaded: root.refreshDockFavorites()
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("Dock", "load error")
            }
        }
    }

    // Centro de control: flotante arriba-derecha con margen del spec.
    FloatingWindow {
        id: controlCenterWindow
        width: Theme.spacing * 40
        height: Theme.spacing * 60
        visible: ShellController.controlCenterOpen && controlCenterLoader.status === Loader.Ready
        Loader {
            id: controlCenterLoader
            anchors.fill: parent
            source: "Nimbus/modules/ControlCenter.qml"
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("ControlCenter", "load error")
            }
        }
    }

    // Notificaciones: panel arriba-derecha, sobre las ventanas.
    PanelWindow {
        id: notificationsWindow
        WlrLayershell.layer: WlrLayer.Top
        anchors {
            top: true
            right: true
        }
        width: Theme.notificationWidth
        height: Theme.spacing * 40
        visible: ShellController.notificationsOpen && notificationsLoader.status === Loader.Ready
        Loader {
            id: notificationsLoader
            anchors.fill: parent
            source: "Nimbus/modules/Notifications.qml"
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("Notifications", "load error")
            }
        }
    }

    // Spotlight: flotante centrado con el maximo del spec.
    FloatingWindow {
        id: spotlightWindow
        width: Theme.spotlightMaxWidth
        height: Theme.spotlightMaxHeight
        visible: ShellController.spotlightOpen && spotlightLoader.status === Loader.Ready
        Loader {
            id: spotlightLoader
            anchors.fill: parent
            source: "Nimbus/modules/Spotlight.qml"
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("Spotlight", "load error")
            }
        }
    }

    // Switcher: flotante centrado de 800 x 300.
    FloatingWindow {
        id: switcherWindow
        width: Theme.switcherWidth
        height: Theme.switcherHeight
        visible: ShellController.switcherOpen && switcherLoader.status === Loader.Ready
        Loader {
            id: switcherLoader
            anchors.fill: parent
            source: "Nimbus/modules/Switcher.qml"
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("Switcher", "load error")
            }
        }
    }

    // QuickLook: flotante centrado; el contenido gestiona `shown`.
    FloatingWindow {
        id: quickLookWindow
        width: Theme.spotlightMaxWidth
        height: Theme.spacing * 50
        visible: ShellController.quickLookOpen && quickLookLoader.status === Loader.Ready
        Loader {
            id: quickLookLoader
            anchors.fill: parent
            source: "Nimbus/modules/QuickLook.qml"
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("QuickLook", "load error")
            }
        }
    }

    // Fondos: flotante con la galeria.
    FloatingWindow {
        id: wallpaperWindow
        width: Theme.spacing * 80
        height: Theme.spacing * 50
        visible: ShellController.wallpaperOpen && wallpaperLoader.status === Loader.Ready
        Loader {
            id: wallpaperLoader
            anchors.fill: parent
            source: "Nimbus/modules/Wallpaper.qml"
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("Wallpaper", "load error")
            }
        }
    }

    // Bloqueo: pantalla completa sobre todo mientras `locked` Y se ha
    // pedido bloquear (`root.lockRequested`, false al arrancar).
    FloatingWindow {
        id: lockWindow
        width: Theme.spacing * 100
        height: Theme.spacing * 80
        visible: root.lockRequested && lockLoader.status === Loader.Ready && lockLoader.item && lockLoader.item.locked
        Loader {
            id: lockLoader
            anchors.fill: parent
            source: "Nimbus/modules/LockScreen.qml"
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("LockScreen", "load error")
            }
        }
    }

    // Capturas: overlay a pantalla completa; el contenido gestiona `shown`.
    PanelWindow {
        id: screenshotWindow
        WlrLayershell.layer: WlrLayer.Overlay
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        visible: screenshotLoader.status === Loader.Ready && screenshotLoader.item && screenshotLoader.item.shown
        Loader {
            id: screenshotLoader
            anchors.fill: parent
            source: "Nimbus/modules/Screenshot.qml"
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("Screenshot", "load error")
            }
        }
    }

    // Store: flotante visible con `activeSurface === "store"`.
    FloatingWindow {
        id: storeWindow
        width: Theme.spacing * 120
        height: Theme.spacing * 75
        visible: ShellController.activeSurface === "store" && storeLoader.status === Loader.Ready
        Loader {
            id: storeLoader
            anchors.fill: parent
            source: "Nimbus/apps/Store/Store.qml"
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("Store", "load error")
            }
        }
    }

    // Tour: flotante solo en el primer arranque; `shouldShow()` lee
    // `completed`/`finished` (restaurados desde `Config.tourCompleted`).
    FloatingWindow {
        id: tourWindow
        width: Theme.spacing * 60
        height: Theme.spacing * 40
        visible: !Config.tourCompleted && tourLoader.status === Loader.Ready && tourLoader.item && tourLoader.item.shouldShow()
        Loader {
            id: tourLoader
            anchors.fill: parent
            source: "Nimbus/apps/Tour/Tour.qml"
            onStatusChanged: {
                if (status === Loader.Error)
                    root.logModuleFailure("Tour", "load error")
            }
        }
    }
}
