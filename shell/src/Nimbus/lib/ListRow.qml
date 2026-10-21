// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Fila seleccionable (resultados, listas de ajustes). `selected` la resalta
// con Theme.accent; un clic emite `activated()`.
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool selected: false

    signal activated()

    color: root.selected ? Theme.accent : Theme.surface
    radius: Theme.radius

    implicitHeight: Theme.spacing * 7
    height: Theme.spacing * 7

    Behavior on color {
        ColorAnimation { duration: Theme.animStandard }
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        Icon {
            id: rowIcon
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: Theme.spacing * 3
            color: root.selected ? Theme.surface : Theme.text
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (rowIcon.visible ? rowIcon.width + parent.spacing : 0)
            spacing: 0

            Text {
                width: parent.width
                visible: root.title !== ""
                text: root.title
                color: root.selected ? Theme.surface : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                color: root.selected ? Theme.surface : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.activated()
    }
}
