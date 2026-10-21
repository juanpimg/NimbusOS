// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Item del dock: baldosa con letra o papelera dibujada, indicador de
// ejecucion, badge numerico y escala de ampliacion. Dibuja, no decide: el
// Dock padre le pasa `itemScale` (calculada con Dock.scaleForIndex,
// interpolacion continua), el color de baldosa y los datos planos. `press()`
// existe para que el click sea testeable sin ventana: el MouseArea real lo
// llama con el boton pulsado. La letra es la inicial de la etiqueta
// traducida y la papelera son tres rectangulos (sin assets).
Item {
    id: root

    property string appId: ""
    property string icon: ""
    property color iconColor: Theme.surfaceAlt
    property string label: ""
    property bool running: false
    property int badgeCount: 0
    property bool magnified: false
    property real itemScale: 1.0

    signal activated()
    signal contextRequested()

    // Caja del icono (escala con magnification) + franja fija para el punto
    // de ejecucion: el punto mide siempre Theme.runningDotSize.
    readonly property real iconBox: Theme.dockIconSize * itemScale

    width: iconBox
    height: iconBox + Theme.runningDotSize + Theme.spacing / 2

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

    // Baldosa estilo macOS: color plano con la inicial de la etiqueta.
    Rectangle {
        id: tile
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.iconBox
        height: root.iconBox
        radius: Theme.dockIconRadius
        color: root.iconColor

        Text {
            id: letter
            anchors.centerIn: parent
            visible: root.appId !== "trash" && root.label !== ""
            text: root.label.length > 0 ? root.label.charAt(0).toUpperCase() : ""
            color: Theme.background
            font.family: Theme.fontFamily
            font.pixelSize: parent.height * 0.45
            font.weight: Font.Bold
        }

        // Papelera dibujada con formas: cuerpo, tapa y asa.
        Item {
            id: bin
            anchors.centerIn: parent
            visible: root.appId === "trash"
            width: parent.width * 0.42
            height: parent.height * 0.52
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.8
                height: parent.height * 0.72
                radius: 2
                color: Theme.textMuted
            }
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 3
                radius: 1.5
                color: Theme.textMuted
            }
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: -3
                anchors.horizontalCenter: parent.horizontalCenter
                width: 8
                height: 3
                radius: 1.5
                color: Theme.textMuted
            }
        }
    }

    Rectangle {
        id: runningDot
        anchors.top: tile.bottom
        anchors.topMargin: Theme.spacing / 2
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.running
        width: Theme.runningDotSize
        height: Theme.runningDotSize
        radius: width / 2
        color: Theme.accent
    }

    Rectangle {
        id: badge
        anchors.top: tile.top
        anchors.right: tile.right
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
