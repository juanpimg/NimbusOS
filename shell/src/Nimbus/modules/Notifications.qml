// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Centro de notificaciones del shell.
//
// Contenido (no ventana): en produccion `shell.qml` lo hospeda dentro de un
// `PanelWindow` anclado arriba a la derecha (o un `FloatingWindow`), de modo
// que los toasts se apilan en esa esquina con `toastWidth` de ancho y como
// maximo `maxVisible` visibles; el resto queda accesible en el centro
// (lista agrupada por aplicacion). Este fichero NO importa Quickshell para
// seguir siendo testeable con Qt Test a secas.
//
// Daemon (NO testeado aqui): el shell es el daemon de notificaciones:
// registra `org.freedesktop.Notifications` y desregistra el daemon del
// sistema si lo hay (como hace MacShell). El cableado real al
// `NotificationServer` de `Quickshell.Services.Notifications` vive en
// `shell.qml`, que inyecta el backend via `registerDaemon(backend)`; si el
// registro falla, `daemonAvailable` queda en false con el motivo en
// `daemonError` y el shell sigue funcionando.
//
// Modelo: `items` es una lista de `{id, app, title, body, timestamp,
// actions}` con la mas reciente primero. `actions` es una lista de
// `{id, label}` que se dibuja como botones; pulsarlos emite
// `actionTriggered(id, actionId)`.
Item {
    id: root

    property var items: []
    property bool dnd: false
    property int maxVisible: Theme.notificationMaxVisible
    property int toastWidth: Theme.notificationWidth

    // Estado del registro como daemon (ver cabecera: no testeado aqui).
    property bool daemonAvailable: false
    property string daemonStatus: "unavailable"
    property string daemonError: ""

    signal dismissed(string id)
    signal actionTriggered(string id, string actionId)
    signal dndToggled(bool on)

    width: toastWidth

    // --- Logica pura (testeada en tst_notifications.qml) ---

    // Agrupa una lista de notificaciones por aplicacion, en orden de primera
    // aparicion. Cada grupo es `{app, count, title, body, timestamp,
    // notifications}` donde title/body/timestamp son los del aviso mas
    // reciente del grupo y `count` es el contador que se muestra.
    function groupByApp(list) {
        if (!Array.isArray(list) || list.length === 0)
            return []
        var groups = []
        var indexByApp = ({})
        for (var i = 0; i < list.length; ++i) {
            var n = list[i]
            if (!n || typeof n.app !== "string")
                continue
            var g = indexByApp[n.app]
            if (g === undefined) {
                g = {
                    "app": n.app,
                    "count": 0,
                    "title": "",
                    "body": "",
                    "timestamp": 0,
                    "notifications": []
                }
                indexByApp[n.app] = groups.length
                groups.push(g)
                g = groups[groups.length - 1]
            } else {
                g = groups[g]
            }
            g.notifications.push(n)
            g.count = g.notifications.length
            g.title = n.title || ""
            g.body = n.body || ""
            g.timestamp = n.timestamp || 0
        }
        return groups
    }

    // Recorta una lista a los toasts visibles (los `maxVisible` primeros,
    // que son los mas recientes porque `items` ordena asi).
    function visibleToasts(list) {
        if (!Array.isArray(list) || list.length === 0)
            return []
        return list.slice(0, Math.max(0, maxVisible))
    }

    // Aplica el filtro No molestar: con DND activado las nuevas se silencian
    // (`shown` vacio, `silenced` con las entrantes) pero las existentes se
    // conservan intactas en `kept`. Con DND apagado todo pasa a `shown`.
    function applyDndFilter(existing, incoming, dndOn) {
        var kept = Array.isArray(existing) ? existing.slice() : []
        var next = Array.isArray(incoming) ? incoming.slice() : []
        var silenced = (dndOn === undefined) ? root.dnd : dndOn
        if (silenced)
            return { "kept": kept, "shown": [], "silenced": next }
        return { "kept": kept, "shown": next, "silenced": [] }
    }

    // Contador total: refleja las agrupadas (todas), no los toasts visibles.
    // Se sincroniza con `Services.notificationCount` en cada mutacion.
    function totalCount(list) {
        if (!Array.isArray(list))
            return 0
        return list.length
    }

    // --- Mutaciones de estado ---

    function _syncCounter() {
        Services.notificationCount = totalCount(items)
    }

    // Anade una notificacion; con DND activado se silencia (devuelve false)
    // y lo existente no se toca. Devuelve true si entro.
    function addNotification(n) {
        if (!n || typeof n.id !== "string" || n.id === "")
            return false
        if (root.dnd)
            return false
        var entry = {
            "id": n.id,
            "app": (typeof n.app === "string" && n.app !== "") ? n.app : "unknown",
            "title": n.title || "",
            "body": n.body || "",
            "timestamp": (n.timestamp !== undefined) ? n.timestamp : Date.now(),
            "actions": Array.isArray(n.actions) ? n.actions : []
        }
        var next = items.slice()
        next.unshift(entry)
        items = next
        _syncCounter()
        return true
    }

    function dismissNotification(id) {
        var next = []
        var found = false
        for (var i = 0; i < items.length; ++i) {
            if (items[i].id === id)
                found = true
            else
                next.push(items[i])
        }
        if (!found)
            return false
        items = next
        _syncCounter()
        dismissed(id)
        return true
    }

    function clearAll() {
        items = []
        _syncCounter()
    }

    function setDnd(on) {
        var value = !!on
        if (root.dnd === value)
            return
        root.dnd = value
        dndToggled(value)
    }

    function triggerAction(id, actionId) {
        actionTriggered(id, actionId)
    }

    // --- Registro como daemon (NO testeado: requiere Quickshell/D-Bus) ---

    // `backend` es el NotificationServer real inyectado por `shell.qml`
    // (duck-typing: `register(name)` / `unregisterSystem()`). Sin backend
    // (tests, sin D-Bus) queda como no disponible y el shell sigue
    // funcionando. Nunca lanza.
    function registerDaemon(backend) {
        daemonStatus = "registering"
        daemonError = ""
        if (backend === undefined || backend === null) {
            daemonAvailable = false
            daemonStatus = "unavailable"
            return false
        }
        if (typeof backend.register !== "function") {
            markDaemonAvailable(false, Config.translated("notifications.daemonUnavailable"))
            return false
        }
        var ok = backend.register("org.freedesktop.Notifications")
        if (!ok) {
            markDaemonAvailable(false, Config.translated("notifications.daemonUnavailable"))
            return false
        }
        if (typeof backend.unregisterSystem === "function")
            backend.unregisterSystem()
        markDaemonAvailable(true, "")
        return true
    }

    function markDaemonAvailable(ok, error) {
        daemonAvailable = !!ok
        daemonStatus = daemonAvailable ? "active" : "failed"
        daemonError = (typeof error === "string") ? error : ""
        return daemonAvailable
    }

    // --- Vista: toasts arriba a la derecha + centro agrupado ---

    Column {
        id: layout
        anchors {
            top: parent.top
            right: parent.right
        }
        width: root.toastWidth
        spacing: Theme.spacing

        SectionHeader {
            width: parent.width
            text: Config.translated("notifications.title")
        }

        Row {
            width: parent.width
            spacing: Theme.spacing

            Toggle {
                id: dndToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: root.dnd
                onToggled: function (value) { root.setDnd(value) }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Config.translated("notifications.dnd")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
            }

            Item { width: Theme.spacing; height: 1 }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                text: Config.translated("notifications.clear")
                onClicked: root.clearAll()
            }
        }

        Text {
            width: parent.width
            visible: root.daemonError !== "" && !root.daemonAvailable
            text: root.daemonError
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            wrapMode: Text.Wrap
        }

        // Toasts: como maximo `maxVisible`, apilados bajo la cabecera.
        Repeater {
            id: toastRepeater
            model: root.visibleToasts(root.items)
            delegate: Glass {
                width: root.toastWidth
                implicitHeight: toastBody.implicitHeight + Theme.spacing * 2
                property string notifId: modelData.id

                Column {
                    id: toastBody
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Theme.spacing
                    }
                    spacing: Theme.spacing / 2

                    Text {
                        width: parent.width
                        text: modelData.app + " — " + modelData.title
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.spacing * 2
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: modelData.body !== ""
                        text: modelData.body
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.spacing * 2
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: Theme.spacing
                        visible: modelData.actions.length > 0
                        Repeater {
                            model: modelData.actions
                            delegate: Button {
                                text: modelData.label || ""
                                onClicked: root.triggerAction(notifId, modelData.id || "")
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: root.dismissNotification(modelData.id)
                }
            }
        }

        Text {
            width: parent.width
            visible: root.items.length === 0
            text: Config.translated("notifications.empty")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
        }

        // Desbordamiento: lo que no cabe en los toasts sigue en el centro.
        Row {
            width: parent.width
            visible: root.items.length > root.maxVisible
            spacing: Theme.spacing

            Text {
                text: Config.translated("notifications.more")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
            }

            Text {
                text: "" + (root.items.length - root.maxVisible)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
            }
        }

        // Centro: una entrada por aplicacion con su contador.
        Repeater {
            id: groupRepeater
            model: root.groupByApp(root.items)
            delegate: ListRow {
                width: root.toastWidth
                title: modelData.app + " (" + modelData.count + ")"
                subtitle: modelData.title
            }
        }
    }
}
