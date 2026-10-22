// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Envoltorio sobre `Quickshell.Process` (modulo `Quickshell.Io`) para
// invocar los CLI de Nimbus: `nimbus-energy`, `nimbus-update` y
// `nimbus-gaming-tune`.
//
// SIN import estatico de Quickshell a proposito: este fichero lo cargan los
// tests sin compositor ni Quickshell instalado. En produccion (ISO con
// Quickshell 0.3.2) el `Process` real se crea de forma dinamica en
// `_startReal` (`command: list<string>` + `StdioCollector` en
// stdout/stderr + senal `exited(exitCode, exitStatus)`); sin backend emite
// `failed()` con mensaje traducido y nunca lanza ni se cuelga.
//
// Privilegios: lo que necesite privilegios pasa por polkit (`pkexec`),
// el mismo patron que `nimbus-energy` (re-ejecuta con pkexec solo el
// `set`; `get` es lectura y nunca pide privilegios). El llamante decide
// con `privileged`.
//
// Secretos: los args NUNCA deben llevar secretos (irrelevante para los CLI
// de Nimbus, que no reciben ninguno); la salida se recorta a
// `maxOutputChars` para mostrarla y jamas se vuelca a logs.
QtObject {
    id: root

    property string command: ""
    property var args: []
    property bool privileged: false

    // Puente inyectable (tests y otros puentes): objeto con
    // `run(cmdArray) -> {exitCode, stdout, stderr}`. null = Process real.
    property var runner: null

    property bool running: false
    property int lastExitCode: -1
    property string lastStdout: ""
    property string lastStderr: ""
    property string lastError: ""

    readonly property int maxOutputChars: 4096

    signal started()
    signal finished(int exitCode, string stdout, string stderr)
    signal failed(string message)

    // Comando efectivo: con privilegios se antepone `pkexec`.
    function fullCommand() {
        var out = []
        if (privileged)
            out.push("pkexec")
        if (command !== "")
            out.push(command)
        if (Array.isArray(args)) {
            for (var i = 0; i < args.length; ++i)
                out.push(String(args[i]))
        }
        return out
    }

    function _text(value) {
        if (typeof value === "string")
            return value
        if (value === undefined || value === null)
            return ""
        return String(value)
    }

    function _truncate(text) {
        if (text.length > maxOutputChars)
            return text.slice(0, maxOutputChars)
        return text
    }

    // Texto apto para mostrar al usuario (ya recortado al guardar).
    function displayStdout() {
        return _truncate(lastStdout)
    }

    function displayStderr() {
        return _truncate(lastStderr)
    }

    function recordResult(exitCode, stdout, stderr) {
        running = false
        lastExitCode = exitCode
        lastStdout = _truncate(_text(stdout))
        lastStderr = _truncate(_text(stderr))
        lastError = ""
        finished(exitCode, lastStdout, lastStderr)
    }

    function _fail(message) {
        running = false
        lastError = message
        failed(message)
    }

    // Ejecuta el comando. Devuelve false (con `failed()`) si no hay comando
    // o no hay backend disponible; el exito/fallo real viaja por
    // `finished()` y queda en `lastExitCode/lastStdout/lastStderr`.
    function start() {
        if (running) {
            _fail(Config.translated("process.error.busy"))
            return false
        }
        if (command === "") {
            _fail(Config.translated("process.error.empty"))
            return false
        }
        var cmd = fullCommand()
        if (runner !== null && runner !== undefined) {
            running = true
            started()
            try {
                var result = runner.run(cmd)
                var code = (result && result.exitCode !== undefined) ? result.exitCode : -1
                recordResult(code, result ? result.stdout : "", result ? result.stderr : "")
            } catch (e) {
                _fail(String(e))
            }
            return true
        }
        return _startReal(cmd)
    }

    // Camino real (solo ISO con Quickshell): `Process` + `StdioCollector`
    // creados de forma dinamica; al salir se recogen `text` de ambos.
    function _startReal(cmd) {
        var proc = null
        try {
            proc = Qt.createQmlObject(
                        "import Quickshell.Io; Process { stdout: StdioCollector {}; stderr: StdioCollector {} }",
                        root)
        } catch (e) {
            proc = null
        }
        if (proc === null) {
            _fail(Config.translated("process.error.unavailable"))
            return false
        }
        running = true
        started()
        var done = false
        proc.exited.connect(function (exitCode, exitStatus) {
            if (done)
                return
            done = true
            var out = (proc.stdout !== null && proc.stdout !== undefined) ? proc.stdout.text : ""
            var err = (proc.stderr !== null && proc.stderr !== undefined) ? proc.stderr.text : ""
            recordResult(exitCode, out, err)
            proc.destroy()
        })
        proc.command = cmd
        proc.running = true
        return true
    }
}
