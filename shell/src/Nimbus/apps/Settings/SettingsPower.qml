// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Energía: perfil, límite de carga de batería y modo de gráficos.
// Los valores por defecto (balanced, 80 %, on-demand) son el contrato
// testeable de SettingsData.powerDefaults().
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    SettingsData { id: store }

    property string profile: store.defaultPowerProfile
    property string graphicsMode: store.defaultGraphicsMode

    SectionHeader { text: Config.translated("settings.power.title") }
    SectionHeader { text: Config.translated("settings.power.profile") }

    Row {
        spacing: Theme.spacing
        Button {
            text: Config.translated("settings.power.profile.powersaver")
            onClicked: root.profile = "powersaver"
        }
        Button {
            text: Config.translated("settings.power.profile.balanced")
            onClicked: root.profile = "balanced"
        }
        Button {
            text: Config.translated("settings.power.profile.performance")
            onClicked: root.profile = "performance"
        }
    }

    SectionHeader { text: Config.translated("settings.power.chargeLimit") }

    Slider {
        id: chargeSlider
        width: parent.width
        from: 50
        to: 100
        unit: Config.translated("settings.displays.percent")
        Component.onCompleted: setValue(store.defaultChargeLimit)
    }

    SectionHeader { text: Config.translated("settings.power.graphics") }

    Row {
        spacing: Theme.spacing
        Button {
            text: Config.translated("settings.power.graphics.auto")
            onClicked: root.graphicsMode = "auto"
        }
        Button {
            text: Config.translated("settings.power.graphics.ondemand")
            onClicked: root.graphicsMode = "on-demand"
        }
        Button {
            text: Config.translated("settings.power.graphics.always")
            onClicked: root.graphicsMode = "always"
        }
    }
}
