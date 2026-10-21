// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Modulo de capturas de pantalla (region, ventana, pantalla completa).
//
// Contenido (no ventana): en produccion `shell.qml` lo hospeda dentro de
// un `FloatingWindow` a pantalla completa, de modo que el overlay atenua
// el escritorio mientras se elige la region; la ejecucion real
// (`QProcess`/`Quickshell.Process` sobre `grim`/`slurp`/`hyprshot`)
// vive en ese hospedaje y se documenta como no testada aqui. Este
// fichero NO importa Quickshell para seguir siendo testeable con Qt
// Test a secas.
//
// Herramientas por modo: `region` usa `grim` + `slurp`, `screen` usa
// `grim`, `window` usa la herramienta de captura de Hyprland
// (`hyprshot -m window`).
//
// El runner de captura se inyecta (`runner`): recibe
// `(command, outputPath)` y devuelve true si guardo, false si fallo, o
// lanza si la herramienta rompio. Sin runner (tests, sin compositor)
// la captura falla de forma limpia: `error` con mensaje accionable,
// `visible === false`, nunca una excepcion sin capturar.
//
// Activacion: `Ipc.call("screenshot", "region"|"window"|"screen")` llega
// como `ShellController.surfaceRequested("screenshot", modo)` y este
// modulo la atiende via `request(modo)`.
Item {
    id: root

    visible: false
    // `shown` es el espejo testeable de `visible`: bajo qmltestrunner
    // los Item sin ventana leen `visible === false` aunque se haya puesto
    // a true, asi que la logica y los tests usan `shown`; en produccion
    // (FloatingWindow con ventana) ambos van a la par.
    property bool shown: false
    property string mode: "region"
    property string savedPath: ""
    property string error: ""
    property string saveDir: "~/Pictures/Screenshots"

    // Funcion inyectada `(command: string, outputPath: string) -> bool`.
    property var runner: null

    signal captured(string path)
    signal cancelled()

    readonly property var validModes: ["region", "window", "screen"]

    // Construye el comando de captura para un modo y un destino. Funcion
    // pura (testeada en tst_capture.qml).
    function commandFor(captureMode, outputPath) {
        var out = (typeof outputPath === "string") ? outputPath : ""
        if (captureMode === "region")
            return "grim -g \"$(slurp)\" \"" + out + "\""
        if (captureMode === "screen")
            return "grim \"" + out + "\""
        if (captureMode === "window")
            return "hyprshot -m window -f \"" + out + "\""
        return ""
    }

    // Ruta de destino `dir/nimbus-<stamp>-<modo>.png`. Funcion pura salvo
    // el `stamp` que en produccion sale de `Date.now()`; en tests se pasa
    // explicito para que sea determinista.
    function outputPathFor(dir, captureMode, stamp) {
        var base = (typeof dir === "string" && dir !== "") ? dir : "~/Pictures/Screenshots"
        if (base.charAt(base.length - 1) === "/")
            base = base.slice(0, -1)
        var tag = (captureMode === "window" || captureMode === "screen") ? captureMode : "region"
        return base + "/nimbus-" + stamp + "-" + tag + ".png"
    }

    // Pide una captura: valida el modo, muestra el overlay y limpia el
    // error anterior. Un modo invalido se ignora (devuelve false) sin
    // tocar el estado, igual que `Theme.setMode`.
    function request(captureMode) {
        if (validModes.indexOf(captureMode) === -1)
            return false
        mode = captureMode
        error = ""
        shown = true
        visible = true
        return true
    }

    function _fail(message) {
        error = message
        shown = false
        visible = false
        return false
    }

    // Ejecuta la captura via el `runner` inyectado. Nunca lanza: cualquier
    // fallo (herramienta ausente, comando roto, runner sin inyectar)
    // deja `error` con mensaje accionable y `visible === false`.
    function capture() {
        var out = outputPathFor(saveDir, mode, Date.now())
        var cmd = commandFor(mode, out)
        if (cmd === "")
            return _fail(Config.translated("screenshot.errorMode"))
        if (typeof runner !== "function")
            return _fail(Config.translated("screenshot.errorTools"))
        var ok = false
        try {
            ok = runner(cmd, out)
        } catch (e) {
            return _fail(Config.translated("screenshot.errorGrim") + ": " + e)
        }
        if (!ok)
            return _fail(Config.translated("screenshot.errorGrim"))
        savedPath = out
        error = ""
        shown = false
        visible = false
        captured(out)
        return true
    }

    // Cancela la captura (p. ej. Esc sobre el overlay).
    function cancel() {
        shown = false
        visible = false
        cancelled()
    }

    // Atiende `Ipc.call("screenshot", modo)`: el bus IPC reemite la
    // peticion como `surfaceRequested("screenshot", modo)`.
    Connections {
        target: ShellController
        function onSurfaceRequested(surface, argument) {
            if (surface === "screenshot")
                root.request(argument)
        }
    }

    // --- Vista: overlay con el modo, error y acciones ---

    Glass {
        anchors.fill: parent
        visible: root.visible

        Column {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.spacing * 2
            }
            spacing: Theme.spacing

            SectionHeader {
                width: parent.width
                text: Config.translated("screenshot.title")
            }

            Text {
                width: parent.width
                text: Config.translated("screenshot." + root.mode)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
            }

            Text {
                width: parent.width
                visible: root.savedPath !== ""
                text: Config.translated("screenshot.saved") + " " + root.savedPath
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                elide: Text.ElideMiddle
            }

            Text {
                width: parent.width
                visible: root.error !== ""
                text: root.error
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                wrapMode: Text.Wrap
            }

            Row {
                spacing: Theme.spacing

                Button {
                    text: Config.translated("screenshot.capture")
                    onClicked: root.capture()
                }

                Button {
                    text: Config.translated("screenshot.cancel")
                    onClicked: root.cancel()
                }
            }
        }
    }
}
