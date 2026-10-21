// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Menu global de la aplicacion: la parte con datos de la barra superior.
// Es un Item normal (sin Quickshell) a proposito: TopBar es un PanelWindow
// y no puede cargarse sin compositor, asi que TODA la logica pura de la
// barra vive aqui y QtTest la prueba sin el framework. TopBar la reutiliza
// a traves del hijo que incrusta (predicados de items + formato del reloj).
//
// - Dibuja, no decide: las entradas llegan como datos
//   (entries [{title, items:[{label, action, checked, disabled}]}]); sin
//   datos no hay entradas.
// - Se abre al pulsar (openMenu/toggleMenu) y se cierra al seleccionar una
//   entrada valida o al perder el foco (handleFocusLost, que TopBar conecta
//   a la desactivacion de su ventana).
// - Regla de oro: lo que no existe no se dibuja (batteryVisible,
//   bluetoothVisible, networkVisible; volumen y DND no tienen backend en M1
//   y quedan ocultos hasta M2).
Item {
    id: root

    property string appId: ""
    property var entries: []
    property bool menuOpen: false

    // Altura de fila = la de ListRow; el ancho deriva de Theme (sin token
    // propio para menus en M1: 10x la altura de la barra).
    readonly property int rowHeight: Theme.spacing * 7
    readonly property string clockFormatKey: "bar.clock.format"

    signal actionTriggered(string appId, string action)
    signal closed()

    // ---- Predicados puros de los items de estado (los usa TopBar) ----

    function batteryVisible(present) {
        return present === true
    }

    function bluetoothVisible(state) {
        return state === "on" || state === "off"
    }

    function networkVisible(state) {
        return state === "online" || state === "offline"
    }

    // M1: sin backend de volumen (M2: Pipewire) ni estado DND (M2:
    // notificaciones). La regla de oro manda ocultarlos.
    function volumeVisible() {
        return false
    }

    function dndVisible() {
        return false
    }

    // Reloj: el formato sale de Config.translated("bar.clock.format") y el
    // idioma de Config.locale. Si la clave aun no tiene traduccion (el
    // lookup devuelve la propia clave), se usa el formato corto del locale.
    function formatClock(date, localeTag, pattern) {
        var d = (date instanceof Date) ? date : new Date()
        var tag = (typeof localeTag === "string" && localeTag !== "") ? localeTag : "en"
        var loc = Qt.locale(tag)
        if (typeof pattern === "string" && pattern !== "" && pattern !== root.clockFormatKey)
            return d.toLocaleString(loc, pattern)
        return d.toLocaleDateString(loc) + " " + d.toLocaleTimeString(loc)
    }

    // ---- Maquina de estado del menu ----

    function openMenu(id) {
        if (typeof id === "string")
            appId = id
        menuOpen = true
    }

    function closeMenu() {
        if (!menuOpen)
            return
        menuOpen = false
        closed()
    }

    function toggleMenu(id) {
        if (menuOpen)
            closeMenu()
        else
            openMenu(id)
    }

    function handleFocusLost() {
        closeMenu()
    }

    // ---- Acceso defensivo a las entradas (nunca lanza) ----

    function sectionCount() {
        if (!Array.isArray(root.entries))
            return 0
        return root.entries.length
    }

    function _section(s) {
        if (!Array.isArray(root.entries))
            return null
        if (typeof s !== "number" || s < 0 || s >= root.entries.length)
            return null
        var section = root.entries[s]
        return (section !== null && typeof section === "object") ? section : null
    }

    function _item(s, i) {
        var section = root._section(s)
        if (section === null || !Array.isArray(section.items))
            return null
        if (typeof i !== "number" || i < 0 || i >= section.items.length)
            return null
        var entry = section.items[i]
        return (entry !== null && typeof entry === "object") ? entry : null
    }

    function _text(value) {
        return (typeof value === "string") ? value : ""
    }

    function sectionTitle(s) {
        var section = root._section(s)
        return section === null ? "" : root._text(section.title)
    }

    function itemCount(s) {
        var section = root._section(s)
        if (section === null || !Array.isArray(section.items))
            return 0
        return section.items.length
    }

    function itemLabel(s, i) {
        var entry = root._item(s, i)
        return entry === null ? "" : root._text(entry.label)
    }

    function itemAction(s, i) {
        var entry = root._item(s, i)
        return entry === null ? "" : root._text(entry.action)
    }

    function itemChecked(s, i) {
        var entry = root._item(s, i)
        return entry !== null && entry.checked === true
    }

    function isEnabled(s, i) {
        var entry = root._item(s, i)
        return entry !== null && entry.disabled !== true
    }

    function selectItem(s, i) {
        if (!root.isEnabled(s, i))
            return
        root.actionTriggered(root.appId, root.itemAction(s, i))
        root.closeMenu()
    }

    // Vista plana para el Repeater: una fila por cabecera y una por entrada,
    // con los campos ya resueltos para que el delegado no calcule nada.
    function flatRows() {
        var rows = []
        var n = root.sectionCount()
        for (var s = 0; s < n; s += 1) {
            rows.push({ "kind": "header", "s": s, "i": -1, "title": root.sectionTitle(s),
                        "label": "", "action": "", "checked": false, "disabled": false, "h": root.rowHeight })
            var m = root.itemCount(s)
            for (var i = 0; i < m; i += 1)
                rows.push({ "kind": "item", "s": s, "i": i, "title": "",
                            "label": root.itemLabel(s, i), "action": root.itemAction(s, i),
                            "checked": root.itemChecked(s, i), "disabled": !root.isEnabled(s, i),
                            "h": root.rowHeight })
        }
        return rows
    }

    implicitWidth: Theme.barHeight * 10
    implicitHeight: root.flatRows().length * root.rowHeight + Theme.spacing * 2

    Glass {
        anchors.fill: parent
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacing

        Repeater {
            model: root.flatRows()
            delegate: Item {
                id: rowDelegate
                required property var modelData
                property var row: modelData
                property bool isHeader: row !== null && row.kind === "header"
                width: parent.width
                height: row !== null ? row.h : 0

                SectionHeader {
                    anchors.fill: parent
                    visible: rowDelegate.isHeader
                    text: rowDelegate.row !== null ? rowDelegate.row.title : ""
                }

                ListRow {
                    anchors.fill: parent
                    visible: !rowDelegate.isHeader
                    title: rowDelegate.row !== null ? rowDelegate.row.label : ""
                    selected: rowDelegate.row !== null && rowDelegate.row.checked
                    opacity: rowDelegate.row !== null && rowDelegate.row.disabled ? 0.5 : 1.0
                    onActivated: root.selectItem(rowDelegate.row.s, rowDelegate.row.i)
                }
            }
        }
    }
}
