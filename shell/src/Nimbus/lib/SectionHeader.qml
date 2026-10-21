// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Cabecera de seccion (agrupa filas en ajustes, centro de control, ...).
Item {
    id: root

    property string text: ""

    implicitHeight: label.implicitHeight
    height: label.implicitHeight

    Text {
        id: label
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        visible: root.text !== ""
        text: root.text
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }
}
