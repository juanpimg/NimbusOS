// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import Nimbus

// Entry point loaded by `qs -c <dir>`: Quickshell looks for shell.qml
// inside the config directory, so this file lives directly in shell/src/
// (the same directory that QML2_IMPORT_PATH points at, because that
// directory is what contains the Nimbus/ module).
//
// M1 (Task 1): esqueleto. Instancia el controlador, el bus IPC y los
// servicios, y registra el IpcHandler con target `nimbus` (asi
// `nimbus-shell ipc call <target> <fn>` despacha a `Ipc.call`). Todavia no
// dibuja la barra ni el dock (Tasks 2 y 3).
ShellRoot {
    id: root

    // Contador de fallos de carga de modulos (Review Focus #4): un modulo
    // roto suma aqui y el shell sigue arrancando, nunca muere por el.
    property int moduleFailures: 0

    function logModuleFailure(moduleName, error) {
        moduleFailures += 1
        console.warn("shell: no se pudo cargar el modulo " + moduleName + ": " + error)
    }

    // Punto de carga defensiva para los modulos de las Tasks 2-12: crea el
    // componente de forma guardada y devuelve null (contando el fallo) en
    // vez de tumbar el shell. No hay `Loader` declarativo en M1 porque aun
    // no existe ningun modulo que cargar y el try/catch no existe en QML.
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

    // M0: the shell has no surfaces yet. The M0 placeholder is a fullscreen
    // window managed by Quickshell, not a loose QtQuick Window: surfaces
    // are created by PanelWindow, not Window.
    PanelWindow {
        id: placeholder
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Theme.background

        Text {
            anchors.centerIn: parent
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            text: Config.translated("app.store.title")
        }
    }
}
