// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Pantallas: escala, frecuencia y disposición.
// El cableado a la salida real (RandR vía Hyprland) entra en M2; aquí vive
// la estructura con controles del design system.
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    SectionHeader { text: Config.translated("settings.displays.title") }
    SectionHeader { text: Config.translated("settings.displays.scale") }

    Slider {
        id: scaleSlider
        width: parent.width
        from: 100
        to: 200
        unit: Config.translated("settings.displays.percent")
    }

    SectionHeader { text: Config.translated("settings.displays.rate") }

    ListRow {
        width: parent.width
        title: Config.translated("settings.displays.rate")
        subtitle: Config.translated("settings.displays.unknown")
    }

    SectionHeader { text: Config.translated("settings.displays.layout") }

    ListRow {
        width: parent.width
        title: Config.translated("settings.displays.layout")
        subtitle: Config.translated("settings.displays.arrangement")
    }
}
