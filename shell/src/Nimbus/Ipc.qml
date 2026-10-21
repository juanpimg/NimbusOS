// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick
import Nimbus

// Bus IPC del shell: `nimbus-shell ipc call <target> <fn>` termina aqui.
// La tabla de targets y funciones validas es el contrato de la M1; ante un
// target o una funcion desconocidos NO lanza: avisa por console.warn y no
// cambia `lastTarget`/`lastFunction`. Un fallo nunca tumba el shell.
QtObject {
    id: root

    property string lastTarget: ""
    property string lastFunction: ""

    readonly property var validCalls: ({
        "dock": ["toggle", "open", "close"],
        "spotlight": ["toggle", "open", "close", "apps", "files"],
        "switcher": ["next", "prev", "commit", "cancel"],
        "screenshot": ["region", "window", "screen"],
        "quicklook": ["toggle", "open", "close"],
        "wallpaper": ["toggle", "open", "close", "next", "prev"],
        "controlcenter": ["toggle", "open", "close"],
        "notifications": ["toggle", "clear"],
        "settings": ["open"],
        "store": ["open"],
        "tour": ["start"],
        "lock": ["lock"]
    })

    function call(target, function_) {
        var fns = validCalls[target]
        if (fns === undefined) {
            console.warn("Ipc: target desconocido: " + target)
            return
        }
        if (fns.indexOf(function_) === -1) {
            console.warn("Ipc: funcion desconocida para " + target + ": " + function_)
            return
        }
        lastTarget = target
        lastFunction = function_
        _dispatch(target, function_)
    }

    // toggle/open/close pasan por el controlador (exclusividad de
    // superficies); las acciones con argumento viajan como
    // `surfaceRequested(target, fn)` y las consumen sus superficies.
    function _dispatch(target, fn) {
        if (fn === "toggle") {
            ShellController.toggle(target)
            return
        }
        if (fn === "open") {
            ShellController.open(target)
            return
        }
        if (fn === "close") {
            ShellController.close(target)
            return
        }
        if (target === "notifications" && fn === "clear") {
            Services.clearNotifications()
            return
        }
        if (target === "lock" && fn === "lock") {
            ShellController.closeAll()
        }
        ShellController.surfaceRequested(target, fn)
    }
}
