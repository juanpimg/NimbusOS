// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Pestana de actualizaciones: lista las pendientes y ofrece un unico boton,
// "Actualizar todo", que es la regla del spec: el unico que hay que pulsar.
Item {
    id: root

    property var updates: []

    readonly property int updateCount: Array.isArray(root.updates) ? root.updates.length : 0

    signal updateAllRequested()

    function requestUpdateAll() {
        updateAllRequested()
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacing

        SectionHeader {
            width: parent.width
            text: Config.translated("store.updates.title")
        }

        Button {
            id: updateAllButton
            text: Config.translated("store.updates.updateAll")
            enabled: root.updateCount > 0
            onClicked: root.requestUpdateAll()
        }

        Text {
            width: parent.width
            visible: root.updateCount === 0
            text: Config.translated("store.updates.empty")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.updates
            delegate: ListRow {
                required property var modelData
                anchors {
                    left: parent.left
                    right: parent.right
                }
                title: modelData.title || ""
                subtitle: modelData.version || ""
                icon: modelData.icon || ""
            }
        }
    }
}
