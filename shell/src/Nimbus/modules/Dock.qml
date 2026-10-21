// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Effects
import Nimbus

// Contenido del dock: fila de iconos con ampliacion continua, indicadores
// de ejecucion, badges y papelera separada al final.
//
// NOTA DE INTEGRACION (no testeada aqui): en produccion este componente se
// instancia dentro de un `PanelWindow` (import Quickshell.Wayland) con
// `anchors.bottom: true` y `height: Theme.dockSize`. El anclaje y la capa de
// Wayland no se pueden probar con Qt Test a secas; todo lo demas (la
// matematica de la ampliacion y el estado visible) son funciones puras
// probadas en tst_dock.qml.
//
// Los datos entran por properties (`favorites`, `running`, `badgeCounts`);
// el componente dibuja, no decide. Cada favorito es
// `{id, name, icon, color}` con el nombre ya traducido (lo pone quien
// instancia, p. ej. shell.qml con `Config.translated`) y el color de baldosa
// desde Theme. La papelera se dibuja con formas (sin assets).
Item {
    id: root

    property var favorites: []
    property var running: []
    property var badgeCounts: ({})
    property bool autoHide: false
    property real magnification: Theme.dockMagnify
    property real hoverX: -1
    property bool cursorOnDock: false
    property bool cursorOnWindow: false

    readonly property real cellWidth: Theme.dockIconSize + Theme.spacing
    readonly property int itemCount: favorites.length + 1
    readonly property int trashIndex: favorites.length
    readonly property string trashId: "trash"
    readonly property bool shouldShow: !autoHide || cursorOnDock || cursorOnWindow

    signal appActivated(string appId)
    signal appContextRequested(string appId)

    width: itemCount * cellWidth + Theme.spacing * 2
    height: Theme.dockSize
    visible: shouldShow

    // Centro del slot i. Los slots son uniformes: el separador se dibuja
    // dentro del margen izquierdo de la papelera, sin desplazar nada.
    function itemCenterX(index) {
        return Theme.spacing + (index + 0.5) * cellWidth
    }

    // Escala continua (cosenoidal): pico `magnification` bajo el cursor,
    // base 1.0 a dos o mas celdas de distancia. Derivada cero en ambos
    // extremos, asi que no hay escalon perceptible. cursorX < 0 es el
    // centinela de "sin cursor" (el tracker pone hoverX = -1 al salir).
    function scaleForIndex(index, cursorX) {
        if (cursorX < 0 || index < 0 || index >= itemCount)
            return 1.0
        var d = Math.abs(itemCenterX(index) - cursorX) / cellWidth
        if (d >= 2.0)
            return 1.0
        return 1.0 + (magnification - 1.0) * (0.5 + 0.5 * Math.cos(Math.PI * d / 2.0))
    }

    function itemSize(index, cursorX) {
        return Theme.dockIconSize * scaleForIndex(index, cursorX)
    }

    function isRunning(appId) {
        return running.indexOf(appId) !== -1
    }

    function badgeFor(appId) {
        var n = Number(badgeCounts[appId])
        if (isNaN(n) || n <= 0)
            return 0
        return Math.floor(n)
    }

    function isTrashIndex(index) {
        return index === trashIndex
    }

    // El separador vive justo antes de la papelera; sin favoritos no hay
    // nada que separar y se omite.
    function separatorBefore(index) {
        return index === trashIndex && trashIndex > 0
    }

    function itemKind(index) {
        return isTrashIndex(index) ? "trash" : "app"
    }

    function entryAt(index) {
        if (index < 0 || index >= favorites.length)
            return null
        return favorites[index]
    }

    function appIdAt(index) {
        if (isTrashIndex(index))
            return trashId
        var entry = entryAt(index)
        return (entry && entry.id) ? String(entry.id) : ""
    }

    function labelAt(index) {
        // La papelera no muestra etiqueta: su tooltip ("app.dock.trash")
        // aun no existe en Translations.qml (pista de otra tarea) y una
        // clave ausente se veria literal. Se declara en el informe.
        if (isTrashIndex(index))
            return ""
        var entry = entryAt(index)
        return (entry && entry.name) ? String(entry.name) : ""
    }

    function iconAt(index) {
        if (isTrashIndex(index))
            return "trash"
        var entry = entryAt(index)
        return (entry && entry.icon) ? String(entry.icon) : ""
    }

    // Color de la baldosa del icono: lo pone quien instancia (shell.qml con
    // Theme.app*); sin color se usa la superficie alternativa.
    function colorAt(index) {
        if (isTrashIndex(index))
            return Theme.surfaceAlt
        var entry = entryAt(index)
        return (entry && entry.color) ? entry.color : Theme.surfaceAlt
    }

    function activate(index) {
        appActivated(appIdAt(index))
    }

    function requestContext(index) {
        appContextRequested(appIdAt(index))
    }

    Glass {
        id: dockBg
        anchors.fill: parent
        radius: Theme.dockRadius
        // Se dibuja a traves del efecto (si ambos fueran visibles saldria
        // doble); sigue recibiendo clicks al ser transparente.
        visible: false
    }

    // Sombra difusa de la franja (dy 4): un unico efecto para toda la banda.
    MultiEffect {
        anchors.fill: dockBg
        source: dockBg
        shadowEnabled: true
        shadowColor: Theme.shadow
        shadowBlur: Theme.shadowBlur
        blurMax: Theme.shadowRadius
        shadowVerticalOffset: Theme.shadowOffsetY
    }

    MouseArea {
        id: tracker
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: function (mouse) { root.hoverX = mouse.x }
        onContainsMouseChanged: {
            root.cursorOnDock = containsMouse
            if (!containsMouse)
                root.hoverX = -1
        }
    }

    Repeater {
        model: root.itemCount

        delegate: DockItem {
            // Alineados abajo: al ampliar crecen hacia arriba, como en macOS.
            x: Theme.spacing + index * root.cellWidth + (root.cellWidth - width) / 2
            y: root.height - height
            appId: root.appIdAt(index)
            icon: root.iconAt(index)
            iconColor: root.colorAt(index)
            label: root.labelAt(index)
            running: root.isRunning(appId)
            badgeCount: root.badgeFor(appId)
            itemScale: root.scaleForIndex(index, root.hoverX)

            Behavior on width {
                NumberAnimation { duration: Theme.animStandard }
            }
            Behavior on height {
                NumberAnimation { duration: Theme.animStandard }
            }

            onActivated: root.activate(index)
            onContextRequested: root.requestContext(index)
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacing * 2
        x: Theme.spacing + root.trashIndex * root.cellWidth - width / 2
        visible: root.separatorBefore(root.trashIndex)
        width: 1
        height: Theme.dockSize - Theme.spacing * 4
        color: Theme.separator
    }
}
