// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Deslizador del shell. `setValue` recorta a [from, to]; cualquier cambio de
// `value` (clic, arrastre o asignacion) emite `moved(value)`.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property string unit: ""

    signal moved(real value)

    onValueChanged: root.moved(root.value)

    function setValue(v) {
        value = Math.max(root.from, Math.min(root.to, v))
    }

    width: Theme.spacing * 25
    height: Theme.spacing * 3
    implicitWidth: Theme.spacing * 25
    implicitHeight: Theme.spacing * 3

    Text {
        id: readout
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        text: String(Math.round(root.value)) + root.unit
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
    }

    Rectangle {
        id: track
        anchors {
            left: parent.left
            right: readout.left
            rightMargin: Theme.spacing
            verticalCenter: parent.verticalCenter
        }
        height: Theme.spacing / 2
        color: Theme.separator
        radius: Theme.radius
    }

    Rectangle {
        anchors {
            left: track.left
            verticalCenter: track.verticalCenter
        }
        width: (root.to > root.from) ? (root.value - root.from) / (root.to - root.from) * track.width : 0
        height: track.height
        color: Theme.accent
        radius: Theme.radius
    }

    Rectangle {
        id: handle
        width: Theme.spacing * 2
        height: Theme.spacing * 2
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.separator
        border.width: 1
        anchors.verticalCenter: track.verticalCenter
        x: (root.to > root.from) ? (root.value - root.from) / (root.to - root.from) * track.width - width / 2 : 0
    }

    MouseArea {
        anchors.fill: parent
        function seek(mouseX) {
            if (track.width <= 0)
                return
            root.setValue(root.from + (mouseX - track.x) / track.width * (root.to - root.from))
        }
        onPressed: function(mouse) { seek(mouse.x) }
        onPositionChanged: function(mouse) { if (pressed) seek(mouse.x) }
    }
}
