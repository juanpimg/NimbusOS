// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Ventana flotante del shell sobre fondo de cristal. Oculta por defecto;
// las superficies futuras la muestran y posicionan (offset Theme.popupOffset).
Item {
    id: root

    property string title: ""
    property bool modal: false
    default property alias content: body.children

    signal closed()

    visible: false

    Glass {
        anchors.fill: parent
    }

    Text {
        id: titleLabel
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Theme.spacing
        }
        visible: root.title !== ""
        text: root.title
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        elide: Text.ElideRight
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: Theme.spacing
        anchors.topMargin: titleLabel.visible ? titleLabel.height + Theme.spacing * 2 : Theme.spacing
    }

    Behavior on opacity {
        NumberAnimation { duration: Theme.animSurface }
    }
}
