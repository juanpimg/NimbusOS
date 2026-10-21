// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Apariencia: tema claro/oscuro/auto, color de acento (12
// preajustes) y fuente. Cambiar el tema o el acento se aplica EN CALIENTE
// escribiendo en Config (setMode / setAccent), sin reiniciar.
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    // Solo lectura de datos estáticos; el estado vivo está en Config/Theme.
    SettingsData { id: store }

    // Copia local: el modelo del Repeater lee una propiedad notificable
    // en vez de llamar a la función en el binding (evita stale reads).
    property var presets: []
    Component.onCompleted: presets = store.accentPresets()

    SectionHeader { text: Config.translated("settings.appearance.title") }
    SectionHeader { text: Config.translated("settings.appearance.theme") }

    Text {
        width: parent.width
        text: Config.translated("settings.appearance.current") + ": " + Config.translated("settings.appearance.mode." + Config.mode)
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        elide: Text.ElideRight
    }

    Row {
        spacing: Theme.spacing
        Button {
            text: Config.translated("settings.appearance.mode.light")
            onClicked: Config.setMode("light")
        }
        Button {
            text: Config.translated("settings.appearance.mode.dark")
            onClicked: Config.setMode("dark")
        }
        Button {
            text: Config.translated("settings.appearance.mode.auto")
            onClicked: Config.setMode("auto")
        }
    }

    SectionHeader { text: Config.translated("settings.appearance.accent") }

    Grid {
        columns: 6
        spacing: Theme.spacing
        Repeater {
            model: presets
            delegate: Rectangle {
                width: Theme.spacing * 5
                height: Theme.spacing * 5
                radius: Theme.radius
                color: Theme.surfaceAlt
                border.color: Theme.accent
                border.width: Config.accent === modelData.hex.replace("#", "") ? Theme.spacing / 4 : 0
                Text {
                    anchors.centerIn: parent
                    text: Config.translated(modelData.name).charAt(0)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.spacing * 2
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Config.setAccent(modelData.hex)
                }
            }
        }
    }

    SectionHeader { text: Config.translated("settings.appearance.font") }

    Text {
        width: parent.width
        text: Theme.fontFamily
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        elide: Text.ElideRight
    }
}
