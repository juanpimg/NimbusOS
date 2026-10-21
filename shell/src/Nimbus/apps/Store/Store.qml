// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Tienda de aplicaciones Nimbus (contenido, no ventana: `shell.qml` la
// hospeda dentro de un `FloatingWindow`; este fichero no importa Quickshell
// para seguir siendo testeable con Qt Test a secas).
//
// El backend es inyectable (`backend`): un objeto con `listApps(category)`,
// `search(query)`, `getApp(appId)`, `isInstalled(appId)`,
// `install(appId)`/`uninstall(appId)` (devuelven `{ok, message}`),
// `listUpdates()`, `flatpakAvailable()` y `flatpakError()`. En produccion lo
// cablea `shell.qml` contra `store_backend.py`; en tests se pasa un falso.
// Sin backend la tienda queda vacia pero operativa (caso Flatpak ausente:
// lo dice con un mensaje y ofrece lo que haya).
Item {
    id: root

    property string view: "home" // "home" | "detail" | "updates"
    property var categories: []
    property string currentCategory: ""
    property var currentApp: null
    property var apps: []
    property var updates: []
    property string query: ""
    property bool flatpakAvailable: true
    property string flatpakError: ""
    property string lastError: ""
    property var backend: null

    signal installRequested(string appId)
    signal uninstallRequested(string appId)
    signal updateAllRequested()

    readonly property var categoryIds: ["games", "productivity", "communication", "creative", "media", "development", "utilities"]

    Component.onCompleted: {
        buildCategories()
    }

    // --- Catalogo y navegación ---

    // Las 7 categorias exactas del spec, en orden, con titulo traducido.
    function buildCategories() {
        var out = []
        for (var i = 0; i < categoryIds.length; ++i) {
            out.push({
                         "id": categoryIds[i],
                         "title": Config.translated("store.category." + categoryIds[i])
                     })
        }
        categories = out
    }

    function _hasBackend() {
        return backend !== null && backend !== undefined
    }

    // Recarga estado desde el backend. Sin backend (o con error) deja la
    // tienda vacia con el motivo en `flatpakError`/`lastError`: nunca lanza.
    function refresh() {
        lastError = ""
        if (!_hasBackend()) {
            apps = []
            updates = []
            flatpakAvailable = false
            flatpakError = Config.translated("store.flatpak.unavailable")
            return false
        }
        try {
            flatpakAvailable = backend.flatpakAvailable()
            flatpakError = backend.flatpakError()
            apps = backend.listApps(currentCategory)
            updates = backend.listUpdates()
            return true
        } catch (e) {
            apps = []
            updates = []
            flatpakAvailable = false
            flatpakError = String(e)
            lastError = String(e)
            return false
        }
    }

    function setCategory(category) {
        currentCategory = (category === undefined || category === null) ? "" : String(category)
        query = ""
        view = "home"
        if (!_hasBackend()) {
            apps = []
            return
        }
        try {
            apps = backend.listApps(currentCategory)
        } catch (e) {
            apps = []
            lastError = String(e)
        }
    }

    // Filtro puro por titulo sin distinguir mayusculas (se usa como
    // respaldo sin backend y lo ejercitan los tests directamente).
    function filterApps(list, q) {
        if (!Array.isArray(list))
            return []
        var needle = String(q === undefined || q === null ? "" : q).toLowerCase()
        if (needle === "")
            return list.slice()
        var out = []
        for (var i = 0; i < list.length; ++i) {
            var item = list[i]
            if (item && String(item.title || "").toLowerCase().indexOf(needle) !== -1)
                out.push(item)
        }
        return out
    }

    function searchApps(q) {
        query = (q === undefined || q === null) ? "" : String(q)
        view = "home"
        if (!_hasBackend()) {
            apps = filterApps(apps, query)
            return
        }
        try {
            if (query === "")
                apps = backend.listApps(currentCategory)
            else
                apps = backend.search(query)
        } catch (e) {
            apps = []
            lastError = String(e)
        }
    }

    function openApp(appId) {
        lastError = ""
        if (!_hasBackend())
            return false
        try {
            var app = backend.getApp(appId)
            if (app === null || app === undefined || app.id === undefined)
                return false
            currentApp = app
            view = "detail"
            return true
        } catch (e) {
            lastError = String(e)
            return false
        }
    }

    function closeDetail() {
        view = "home"
        currentApp = null
    }

    function showUpdates() {
        view = "updates"
    }

    function updateCount() {
        if (!Array.isArray(updates))
            return 0
        return updates.length
    }

    // --- Acciones: ejecutan el backend y avisan con senales ---

    function installApp(appId) {
        lastError = ""
        if (!_hasBackend()) {
            lastError = Config.translated("store.flatpak.unavailable")
            return false
        }
        try {
            var result = backend.install(appId)
            if (result === null || result === undefined || result.ok !== true) {
                lastError = (result !== null && result !== undefined && result.message) ? String(result.message) : String(appId)
                return false
            }
            installRequested(appId)
            refresh()
            if (currentApp !== null && currentApp !== undefined && currentApp.id !== undefined)
                currentApp = backend.getApp(currentApp.id)
            return true
        } catch (e) {
            lastError = String(e)
            return false
        }
    }

    function uninstallApp(appId) {
        lastError = ""
        if (!_hasBackend()) {
            lastError = Config.translated("store.flatpak.unavailable")
            return false
        }
        try {
            var result = backend.uninstall(appId)
            if (result === null || result === undefined || result.ok !== true) {
                lastError = (result !== null && result !== undefined && result.message) ? String(result.message) : String(appId)
                return false
            }
            uninstallRequested(appId)
            refresh()
            if (currentApp !== null && currentApp !== undefined && currentApp.id !== undefined)
                currentApp = backend.getApp(currentApp.id)
            return true
        } catch (e) {
            lastError = String(e)
            return false
        }
    }

    function updateAll() {
        updateAllRequested()
        if (!_hasBackend())
            return
        try {
            updates = backend.listUpdates()
        } catch (e) {
            lastError = String(e)
        }
    }

    // --- Vista: cabecera + la vista activa ---

    Column {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: Theme.spacing

        Row {
            width: parent.width
            spacing: Theme.spacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Config.translated("app.store.title")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 3
                font.weight: Font.DemiBold
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                text: Config.translated("store.updates.title") + " (" + root.updateCount() + ")"
                onClicked: root.showUpdates()
            }
        }

        Text {
            width: parent.width
            visible: !root.flatpakAvailable && root.flatpakError !== ""
            text: root.flatpakError
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            visible: root.lastError !== ""
            text: root.lastError
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            wrapMode: Text.Wrap
        }
    }

    StoreHome {
        anchors {
            top: header.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            topMargin: Theme.spacing
        }
        visible: root.view === "home"
        categories: root.categories
        currentCategory: root.currentCategory
        apps: root.apps
        query: root.query
        onCategorySelected: function (category) { root.setCategory(category) }
        onAppSelected: function (appId) { root.openApp(appId) }
        onSearchChanged: function (text) { root.searchApps(text) }
    }

    StoreDetail {
        anchors {
            top: header.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            topMargin: Theme.spacing
        }
        visible: root.view === "detail"
        currentApp: root.currentApp
        onInstallRequested: function (appId) { root.installApp(appId) }
        onUninstallRequested: function (appId) { root.uninstallApp(appId) }
    }

    StoreUpdates {
        anchors {
            top: header.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            topMargin: Theme.spacing
        }
        visible: root.view === "updates"
        updates: root.updates
        onUpdateAllRequested: function () { root.updateAll() }
    }
}
