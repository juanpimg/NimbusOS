// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Interruptor del shell. Emite `toggled(value)` con cada cambio de `checked`,
// venga de un clic o de una asignacion.
Item {
    id: root

    property bool checked: false

    signal toggled(bool value)

    onCheckedChanged: root.toggled(root.checked)

    width: Theme.spacing * 7
    height: Theme.spacing * 4
    implicitWidth: Theme.spacing * 7
    implicitHeight: Theme.spacing * 4

    Rectangle {
        id: track
        anchors.fill: parent
        color: root.checked ? Theme.accent : Theme.separator
        radius: Theme.radius

        Behavior on color {
            ColorAnimation { duration: Theme.animStandard }
        }
    }

    Rectangle {
        id: thumb
        width: track.height - Theme.spacing
        height: track.height - Theme.spacing
        x: root.checked ? track.width - width - Theme.spacing / 2 : Theme.spacing / 2
        y: Theme.spacing / 2
        color: Theme.surface
        radius: Theme.radius

        Behavior on x {
            NumberAnimation { duration: Theme.animStandard }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.checked = !root.checked
    }
}
