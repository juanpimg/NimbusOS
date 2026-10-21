// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Sonido: volumen y silencio.
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    SectionHeader { text: Config.translated("settings.sound.title") }
    SectionHeader { text: Config.translated("settings.sound.volume") }

    Slider {
        id: volumeSlider
        width: parent.width
        from: 0
        to: 100
        unit: Config.translated("settings.displays.percent")
    }

    Row {
        width: parent.width
        spacing: Theme.spacing
        Text {
            width: parent.width - muteToggle.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: Config.translated("settings.sound.mute")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            elide: Text.ElideRight
        }
        Toggle {
            id: muteToggle
            anchors.verticalCenter: parent.verticalCenter
            checked: false
        }
    }
}
