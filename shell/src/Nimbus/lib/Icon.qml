// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Icono del shell: imagen cuando hay `source`, glifo de texto con `name`
// cuando no. Sin literales: el texto visible sale de las propiedades.
Item {
    id: root

    property string name: ""
    property string source: ""
    property int size: 16
    property color color: Theme.text

    width: root.size
    height: root.size
    implicitWidth: root.size
    implicitHeight: root.size

    Image {
        anchors.fill: parent
        visible: root.source !== ""
        source: root.source
        fillMode: Image.PreserveAspectFit
    }

    Text {
        anchors.fill: parent
        visible: root.source === ""
        text: root.name
        color: root.color
        font.family: Theme.fontFamily
        font.pixelSize: root.size
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
