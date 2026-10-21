// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Boton del shell. `enabled` es el heredado de Item (true por defecto);
// deshabilitado se atenua pero sigue siendo legible.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""

    signal clicked()

    color: root.enabled ? Theme.surfaceAlt : Theme.surface
    radius: Theme.radius
    border.color: Theme.separator
    border.width: 1
    opacity: root.enabled ? 1.0 : 0.5

    implicitWidth: label.implicitWidth + Theme.spacing * 4
    implicitHeight: Theme.barHeight

    Behavior on opacity {
        NumberAnimation { duration: Theme.animStandard }
    }

    Row {
        id: label
        anchors.centerIn: parent
        spacing: Theme.spacing

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: Theme.spacing * 2
            color: Theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
