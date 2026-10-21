// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Bluetooth: estado del adaptador (lee Services.bluetoothState).
// La entrada del sidebar queda deshabilitada sin servicio (lógica en
// SettingsData); este panel muestra el aviso correspondiente.
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    property bool available: Services.bluetoothState !== "unknown"

    SectionHeader { text: Config.translated("settings.bluetooth.title") }
    SectionHeader { text: Config.translated("settings.bluetooth.status") }

    ListRow {
        width: parent.width
        title: Config.translated("settings.bluetooth.adapter")
        subtitle: root.available ? Config.translated("settings.bluetooth.state." + Services.bluetoothState) : Config.translated("settings.bluetooth.unavailable")
    }

    Row {
        width: parent.width
        spacing: Theme.spacing
        Text {
            width: parent.width - btToggle.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: Config.translated("settings.bluetooth.enabled")
            color: root.available ? Theme.text : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            elide: Text.ElideRight
        }
        Toggle {
            id: btToggle
            anchors.verticalCenter: parent.verticalCenter
            checked: false
        }
    }
}
