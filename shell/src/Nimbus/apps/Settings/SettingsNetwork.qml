// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Red: estado de la conexión (lee Services.networkState, plano y
// testeable en tst_lib). El cableado a NetworkManager entra en M2.
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    SectionHeader { text: Config.translated("settings.network.title") }
    SectionHeader { text: Config.translated("settings.network.status") }

    ListRow {
        width: parent.width
        title: Config.translated("settings.network.connection")
        subtitle: Config.translated("settings.network.state." + Services.networkState)
    }

    Row {
        width: parent.width
        spacing: Theme.spacing
        Text {
            width: parent.width - wifiToggle.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: Config.translated("settings.network.wifi")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            elide: Text.ElideRight
        }
        Toggle {
            id: wifiToggle
            anchors.verticalCenter: parent.verticalCenter
            checked: Services.networkState !== "unknown"
        }
    }
}
