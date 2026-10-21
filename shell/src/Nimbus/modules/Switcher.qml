// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Switcher de aplicaciones (el `Cmd+Tab` de macOS).
//
// Contenido (no ventana): en produccion `shell.qml` lo hospeda dentro de un
// `FloatingWindow` (import Quickshell.Wayland) centrado de 800 x 300
// (`Theme.switcherWidth` / `Theme.switcherHeight`), visible solo cuando
// `ShellController.switcherOpen` es true. La ventana anfitriona retiene el
// foco mientras esta abierta; `Alt+Tab` / `Cmd+Tab` llegan como
// `Ipc.call("switcher", "next" | "prev" | "commit" | "cancel")` (ver
// `Ipc.validCalls`) y el backend real (Hyprland via `Quickshell.Hyprland` o
// `Quickshell.WindowManager`) se conecta despues inyectando la lista de
// ventanas abiertas via `entries`. Este componente solo dibuja, no decide.
//
// Modelo: `entries` es una lista de `{appId, title, icon}`. `index` es la
// entrada seleccionada: `next` / `prev` la mueven con wraparound (con una
// sola entrada se quedan donde estan); `commit` emite `committed(appId)` y
// `cancel` emite `cancelled()` sin activar nada.
//
// NO testeado aqui (requiere compositor): el `FloatingWindow` anfitrion, el
// centrado en pantalla, la retencion del foco a nivel de ventana y el
// backend de Hyprland. Todo eso vive en `shell.qml` (ver informe de tarea).
Item {
    id: root

    property var entries: []
    property int index: 0

    signal committed(string appId)
    signal cancelled()

    width: Theme.switcherWidth
    height: Theme.switcherHeight
    implicitWidth: Theme.switcherWidth
    implicitHeight: Theme.switcherHeight

    // El foco queda en el switcher mientras esta abierto: la ventana
    // anfitriona lo retiene y estas teclas operan sobre la seleccion.
    focus: true

    onEntriesChanged: _clampIndex()

    // --- Logica pura (testeada en tst_switcher.qml) ---

    function entryCount() {
        return Array.isArray(entries) ? entries.length : 0
    }

    function currentEntry() {
        var n = entryCount()
        if (n === 0 || index < 0 || index >= n)
            return null
        return entries[index]
    }

    function currentAppId() {
        var entry = currentEntry()
        if (!entry || typeof entry.appId !== "string")
            return ""
        return entry.appId
    }

    function select(i) {
        var n = entryCount()
        if (n === 0) {
            index = 0
            return
        }
        if (typeof i !== "number" || isNaN(i))
            return
        index = Math.min(Math.max(0, Math.floor(i)), n - 1)
    }

    function next() {
        var n = entryCount()
        if (n <= 1)
            return
        index = (index + 1) % n
    }

    function prev() {
        var n = entryCount()
        if (n <= 1)
            return
        index = (index - 1 + n) % n
    }

    function commit() {
        var id = currentAppId()
        if (id === "")
            return false
        committed(id)
        return true
    }

    function cancel() {
        cancelled()
    }

    function _clampIndex() {
        var n = entryCount()
        if (n === 0) {
            if (index !== 0)
                index = 0
            return
        }
        if (index < 0)
            index = 0
        else if (index >= n)
            index = n - 1
    }

    Keys.onEscapePressed: root.cancel()
    Keys.onReturnPressed: root.commit()
    Keys.onEnterPressed: root.commit()

    // --- Vista: tira de miniaturas 800 x 300 ---

    Glass {
        anchors.fill: parent
    }

    Column {
        id: layout
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Theme.spacing * 2
        }
        spacing: Theme.spacing

        SectionHeader {
            width: parent.width
            text: Config.translated("switcher.title")
        }

        // Tira de miniaturas, una tarjeta por entrada; la seleccionada se
        // resalta con Theme.accent (misma convencion que ListRow).
        Row {
            id: strip
            visible: root.entryCount() > 0
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing

            Repeater {
                id: cards
                model: root.entries
                delegate: Rectangle {
                    width: Theme.spacing * 16
                    height: Theme.spacing * 15
                    color: root.index === index ? Theme.accent : Theme.surface
                    radius: Theme.radius

                    Behavior on color {
                        ColorAnimation { duration: Theme.animStandard }
                    }

                    Column {
                        anchors {
                            fill: parent
                            margins: Theme.spacing
                        }
                        spacing: Theme.spacing / 2

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: modelData.icon || ""
                            size: Theme.spacing * 6
                            color: root.index === index ? Theme.surface : Theme.text
                        }

                        Text {
                            width: parent.width
                            text: modelData.title || ""
                            color: root.index === index ? Theme.surface : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.spacing * 2
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: modelData.appId || ""
                            color: root.index === index ? Theme.surface : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.spacing * 2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.select(index)
                            root.commit()
                        }
                    }
                }
            }
        }

        Text {
            visible: root.entryCount() === 0
            width: parent.width
            text: Config.translated("switcher.empty")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            text: Config.translated("switcher.hint")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
