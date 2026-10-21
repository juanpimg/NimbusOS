// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Backend REAL de la Nimbus Store para `Store.qml` (lo monta `shell.qml`;
// sin backend la tienda queda vacia en modo "sin backend").
//
// Delega en `store_backend.py` (el mismo fichero que ejercitan los tests
// del backend) invocandolo por su CLI JSON (`--json ...`) a traves de un
// `Process` (T3). Las lecturas se sirven desde la cache: son sincronas,
// como espera `Store.qml` (`listApps`, `search`, `getApp`, `isInstalled`,
// `listUpdates`, `flatpakAvailable`, `flatpakError`). Las recargas y
// escrituras viajan por `refreshNow`/`installNow`/`uninstallNow` y avisan
// con `dataChanged`/`actionFinished` (Store.qml las consume si existen y,
// si no, usa el camino sincrono de toda la vida).
//
// `processRunner` inyectable (tests): objeto con
// `run(cmdArray) -> {exitCode, stdout, stderr}`. Sin el, `Process` real.
//
// Limite honesto: cada invocacion CLI es un proceso fresco (el backend es
// en memoria), asi que tras un `installNow` con exito se actualiza la
// cache local en vez de reconsultar; la transaccion Flathub real
// (PackageKit/libflatpak, spec 4.8) entra en M2.
Item {
    id: root

    // Objeto de logica, nunca visualizado (Item y no QtObject porque
    // hospeda el `Process` trabajador como hijo declarativo).

    property var processRunner: null
    property string python: "python3"

    property var catalog: []
    property bool flatpakCache: false
    property string flatpakErrorCache: ""
    property string lastError: ""
    property bool busy: false

    signal dataChanged()
    signal actionFinished(string appId, bool ok, string message)

    Process {
        id: worker
        runner: root.processRunner
    }

    // Resuelve store_backend.py junto a este fichero: vale en desarrollo
    // (arbol de fuentes) y en instalado (/usr/lib/nimbus/shell/src/...).
    function scriptPath() {
        var url = String(Qt.resolvedUrl("store_backend.py"))
        if (url.indexOf("file://") === 0)
            url = url.slice(7)
        var i = url.lastIndexOf("/store_backend.py")
        if (i >= 0)
            return url
        return url
    }

    // --- Lecturas sincronas sobre la cache (misma semantica que el backend) ---
    // Devuelven copias planas (como `_with_state` en Python), nunca
    // referencias internas: la cache solo cambia por refresh/acciones.

    function _copy(item) {
        var out = {}
        for (var key in item) {
            if (key === "screenshots" && Array.isArray(item[key]))
                out[key] = item[key].slice()
            else
                out[key] = item[key]
        }
        return out
    }

    function listApps(category) {
        var cat = (category === undefined || category === null) ? "" : String(category)
        if (cat !== "" && ["games", "productivity", "communication", "creative", "media", "development", "utilities"].indexOf(cat) === -1)
            return []
        var out = []
        for (var i = 0; i < catalog.length; ++i) {
            if (cat === "" || catalog[i].category === cat)
                out.push(_copy(catalog[i]))
        }
        return out
    }

    function search(query) {
        var needle = String(query === undefined || query === null ? "" : query).toLowerCase()
        if (needle === "")
            return listApps("")
        var out = []
        for (var i = 0; i < catalog.length; ++i) {
            var item = catalog[i]
            if (String(item.title || "").toLowerCase().indexOf(needle) !== -1
                    || String(item.id || "").toLowerCase().indexOf(needle) !== -1)
                out.push(_copy(item))
        }
        return out
    }

    function getApp(appId) {
        for (var i = 0; i < catalog.length; ++i) {
            if (catalog[i].id === appId)
                return _copy(catalog[i])
        }
        return null
    }

    function isInstalled(appId) {
        var app = getApp(appId)
        return app !== null && app.installed === true
    }

    function listUpdates() {
        // Igual que el backend: sin Flatpak no hay actualizaciones.
        if (!flatpakCache)
            return []
        var out = []
        for (var i = 0; i < catalog.length; ++i) {
            if (catalog[i].origin === "Flathub" && catalog[i].installed === true)
                out.push(_copy(catalog[i]))
        }
        return out
    }

    function flatpakAvailable() {
        return flatpakCache
    }

    function flatpakError() {
        return flatpakErrorCache
    }

    // Camino sincrono para `Store.qml`: nativas (preinstaladas) se
    // resuelven aqui con la misma semantica del backend; lo que exige
    // ejecucion real viaja por installNow/uninstallNow.
    function install(appId) {
        var app = getApp(appId)
        if (app === null)
            return {"ok": false, "message": "Aplicación no encontrada: " + appId + "."}
        if (app.origin === "Flathub" && !flatpakCache)
            return {"ok": false, "message": flatpakErrorCache !== "" ? flatpakErrorCache : "Flatpak no disponible."}
        if (app.origin !== "Flathub") {
            _setInstalled(appId, true)
            return {"ok": true, "message": ""}
        }
        installNow(appId)
        return {"ok": false, "message": ""}
    }

    function uninstall(appId) {
        var app = getApp(appId)
        if (app === null)
            return {"ok": false, "message": "Aplicación no encontrada: " + appId + "."}
        if (!isInstalled(appId))
            return {"ok": false, "message": String(app.title || appId) + " no está instalada."}
        if (app.origin !== "Flathub") {
            _setInstalled(appId, false)
            return {"ok": true, "message": ""}
        }
        uninstallNow(appId)
        return {"ok": false, "message": ""}
    }

    function _setInstalled(appId, installed) {
        var next = []
        for (var i = 0; i < catalog.length; ++i) {
            var entry = {}
            for (var key in catalog[i])
                entry[key] = catalog[i][key]
            if (entry.id === appId)
                entry.installed = installed
            next.push(entry)
        }
        catalog = next
    }

    // --- Camino asincrono (ejecucion real del backend) ---

    property var _pending: null

    function _workerDone() {
        if (worker.lastExitCode !== 0) {
            var err = worker.displayStderr() !== "" ? worker.displayStderr() : ("exit " + worker.lastExitCode)
            return {"ok": false, "message": err, "data": null}
        }
        try {
            return {"ok": true, "message": "", "data": JSON.parse(worker.lastStdout)}
        } catch (e) {
            return {"ok": false, "message": "respuesta no valida del backend", "data": null}
        }
    }

    function _startWorker(args, pending) {
        if (busy)
            return false
        busy = true
        lastError = ""
        _pending = pending
        worker.command = python
        worker.args = [scriptPath(), "--json"].concat(args)
        worker.privileged = false
        if (!worker.start()) {
            busy = false
            lastError = worker.lastError
            var kind = _pending ? _pending.kind : ""
            var id = _pending && _pending.appId ? _pending.appId : ""
            _pending = null
            if (kind === "install" || kind === "uninstall")
                actionFinished(id, false, lastError)
            else
                dataChanged()
            return false
        }
        return true
    }

    function refreshNow() {
        return _startWorker(["list-apps"], {"kind": "refresh"})
    }

    function installNow(appId) {
        if (getApp(appId) !== null && getApp(appId).origin === "Flathub" && !flatpakCache) {
            actionFinished(appId, false, flatpakErrorCache)
            return true
        }
        return _startWorker(["install", appId], {"kind": "install", "appId": appId})
    }

    function uninstallNow(appId) {
        return _startWorker(["uninstall", appId], {"kind": "uninstall", "appId": appId})
    }

    Component.onCompleted: {
        worker.finished.connect(_onWorkerFinished)
        worker.failed.connect(_onWorkerFailed)
    }

    function _onWorkerFinished(exitCode, stdout, stderr) {
        var pending = _pending
        _pending = null
        busy = false
        var parsed = _workerDone()
        if (!parsed.ok) {
            lastError = parsed.message
            if (pending !== null && (pending.kind === "install" || pending.kind === "uninstall"))
                actionFinished(pending.appId, false, parsed.message)
            else
                dataChanged()
            return
        }
        if (pending === null)
            return
        if (pending.kind === "refresh") {
            catalog = Array.isArray(parsed.data) ? parsed.data : []
            _startWorker(["flatpak"], {"kind": "flatpak"})
        } else if (pending.kind === "flatpak") {
            flatpakCache = !!(parsed.data && parsed.data.available)
            flatpakErrorCache = (parsed.data && parsed.data.error) ? String(parsed.data.error) : ""
            dataChanged()
        } else if (pending.kind === "install" || pending.kind === "uninstall") {
            var ok = !!(parsed.data && parsed.data.ok)
            var message = (parsed.data && parsed.data.message) ? String(parsed.data.message) : ""
            if (ok)
                _setInstalled(pending.appId, pending.kind === "install")
            else
                lastError = message
            actionFinished(pending.appId, ok, message)
        }
    }

    function _onWorkerFailed(message) {
        var pending = _pending
        _pending = null
        busy = false
        lastError = message
        if (pending !== null && (pending.kind === "install" || pending.kind === "uninstall"))
            actionFinished(pending.appId, false, message)
        else
            dataChanged()
    }
}
