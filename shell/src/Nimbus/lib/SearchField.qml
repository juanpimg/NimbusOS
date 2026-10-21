// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Campo de busqueda del shell. `text`, `placeholder` y `focused` son alias
// del TextInput interno; Enter emite `accepted(text)`.
Item {
    id: root

    property alias text: field.text
    property string placeholder: ""
    property alias focused: field.focus

    signal accepted(string text)

    width: Theme.spacing * 30
    height: Theme.barHeight
    implicitWidth: Theme.spacing * 30
    implicitHeight: Theme.barHeight

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.radius
        border.color: field.activeFocus ? Theme.accent : Theme.separator
        border.width: 1

        Behavior on border.color {
            ColorAnimation { duration: Theme.animStandard }
        }
    }

    TextInput {
        id: field
        anchors.fill: parent
        anchors.margins: Theme.spacing
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        onAccepted: root.accepted(field.text)
    }

    Text {
        anchors.fill: field
        verticalAlignment: Text.AlignVCenter
        visible: field.text === "" && root.placeholder !== ""
        text: root.placeholder
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        elide: Text.ElideRight
    }
}
