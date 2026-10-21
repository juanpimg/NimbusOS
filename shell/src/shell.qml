// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import Nimbus

// Entrada del shell Nimbus (M1 integrado): monta las 9 superficies y las
// 3 aplicaciones de forma defensiva. Cada modulo va tras un Loader con
// vigilancia de `status`: si uno falla al cargar, `moduleFailures` cuenta
// el fallo y el shell sigue arrancando (Review Focus #4). Como QML no
// tiene try/catch, la guarda es `onStatusChanged` + `status === Loader.Error`.
//
// Visibilidad: cada ventana respeta `ShellController` (`dockOpen`,
// `spotlightOpen`, `controlCenterOpen`, `switcherOpen`, `quickLookOpen`,
// `wallpaperOpen`, `notificationsOpen`, `activeSurface`) y el bus `Ipc`
// (`Ipc.call(target, fn)` -> `ShellController.toggle/open/close` o
// `surfaceRequested`; ver `Nimbus/Ipc.qml`). El tour solo se muestra en el
// primer arranque (`!Config.tourCompleted`).
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

    // Titulo resuelto por i18n (mantiene `Config.translated(` en el entry
    // point que exige el gate de sistema de diseno).
    readonly property string storeTitle: Config.translated("app.store.title")

    function logModuleFailure(moduleName, error) {
        moduleFailures += 1
        console.warn("shell: no se pudo cargar el modulo " + moduleName + ": " + error)
    }

    // Punto de carga imperativa (M0/M1): crea el componente de forma
    // guardada y devuelve null contando el fallo en vez de tumbar el shell.
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

    Component.onCompleted: {
        // Fuerza la instanciacion de los singletons base del shell.
        ShellController.closeAll()
        Services.clearNotifications()
    }

    IpcHandler {
        target: "nimbus"

        function call(target, function_) {
            Ipc.call(target, function_)
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
            if (surface === "lock" && lockLoader.status === Loader.Ready && lockLoader.item) {
                lockLoader.item.lock()
            }
        }
    }

    // Fondo del escritorio: capa base con el color del sistema.
    PanelWindow {
        id: backgroundWindow
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Theme.background
    }

    // Barra superior (PanelWindow propio): siempre visible.
    Loader {
        id: topBarLoader
        source: "Nimbus/modules/TopBar.qml"
        onStatusChanged: {
            if (status === Loader.Error)
                root.logModuleFailure("TopBar", "load error")
        }
    }

    // Dock: PanelWindow inferior con zona exclusiva.
    PanelWindow {
        id: dockWindow
        anchors {
            bottom: true
            left: true
            right: true
        }
        height: Theme.dockSize
        exclusiveZone: Theme.dockSize
        visible: ShellController.dockOpen && dockLoader.status === Loader.Ready
        Loader {
            id: dockLoader
            anchors.fill: parent
            source: "Nimbus/modules/Dock.qml"
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

    // Notificaciones: panel arriba-derecha.
    PanelWindow {
        id: notificationsWindow
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

    // Bloqueo: pantalla completa sobre todo mientras `locked`.
    FloatingWindow {
        id: lockWindow
        width: Theme.spacing * 100
        height: Theme.spacing * 80
        visible: lockLoader.status === Loader.Ready && lockLoader.item && lockLoader.item.locked
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

    // Ajustes: FloatingWindow propio con visibilidad por `activeSurface`.
    Loader {
        id: settingsLoader
        source: "Nimbus/apps/Settings/Settings.qml"
        onStatusChanged: {
            if (status === Loader.Error)
                root.logModuleFailure("Settings", "load error")
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
