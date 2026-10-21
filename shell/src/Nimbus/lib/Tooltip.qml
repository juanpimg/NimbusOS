// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Globo de ayuda del shell. `anchorTo` guarda el nombre del elemento ancla;
// el posicionado lo decide la superficie que lo muestra.
Item {
    id: root

    property string text: ""
    property string anchorTo: ""

    width: label.implicitWidth + Theme.spacing * 2
    height: label.implicitHeight + Theme.spacing

    Glass {
        anchors.fill: parent
    }

    Text {
        id: label
        anchors.centerIn: parent
        visible: root.text !== ""
        text: root.text
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
    }
}
