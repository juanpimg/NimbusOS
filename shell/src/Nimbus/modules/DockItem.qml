// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Item del dock: icono con indicador de ejecucion, badge numerico y escala
// de ampliacion. Dibuja, no decide: el Dock padre le pasa `itemScale`
// (calculada con Dock.scaleForIndex, interpolacion continua) y los datos
// planos. `press()` existe para que el click sea testeable sin ventana:
// el MouseArea real lo llama con el boton pulsado.
Item {
    id: root

    property string appId: ""
    property string icon: ""
    property string label: ""
    property bool running: false
    property int badgeCount: 0
    property bool magnified: false
    property real itemScale: 1.0

    signal activated()
    signal contextRequested()

    width: Theme.dockSize * itemScale
    height: Theme.dockSize * itemScale

    function badgeVisible() {
        return badgeCount > 0
    }

    function badgeText() {
        if (badgeCount > 99)
            return "99+"
        return String(badgeCount)
    }

    function targetScale() {
        return magnified ? Theme.dockMagnify : 1.0
    }

    function press(button) {
        if (button === Qt.RightButton)
            contextRequested()
        else
            activated()
    }

    Icon {
        id: glyph
        anchors.centerIn: parent
        // Se deja aire para el punto de ejecucion bajo el icono.
        size: Math.max(16, Math.min(root.width, root.height) - Theme.spacing * 2)
        name: root.icon
        color: Theme.text
    }

    Rectangle {
        id: runningDot
        anchors.top: glyph.bottom
        anchors.topMargin: Theme.spacing / 2
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.running
        width: Theme.spacing / 2
        height: Theme.spacing / 2
        radius: width / 2
        color: Theme.accent
    }

    Rectangle {
        id: badge
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.spacing / 2
        anchors.rightMargin: Theme.spacing / 2
        visible: root.badgeVisible()
        implicitWidth: Math.max(badgeLabel.implicitWidth + Theme.spacing, height)
        implicitHeight: Theme.spacing * 2
        width: implicitWidth
        height: implicitHeight
        radius: height / 2
        color: Theme.text

        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: root.badgeText()
            color: Theme.background
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 1.5
            font.bold: true
        }
    }

    Tooltip {
        anchors.bottom: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.label !== "" && hover.containsMouse
        text: root.label
        anchorTo: root.appId
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onContainsMouseChanged: root.magnified = containsMouse
        onClicked: function (mouse) { root.press(mouse.button) }
    }
}
