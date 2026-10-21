// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Item del dock: baldosa con el glifo de la aplicacion dibujado con
// formas, indicador de ejecucion, badge numerico y escala de ampliacion.
// Dibuja, no decide: el Dock padre le pasa `itemScale` (calculada con
// Dock.scaleForIndex, interpolacion continua), el color de baldosa y los
// datos planos. `press()` existe para que el click sea testeable sin
// ventana: el MouseArea real lo llama con el boton pulsado. Los glifos son
// formas propias (nada de assets ni de iconos de terceros) y la papelera son
// tres rectangulos.
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

    // Baldosa estilo macOS: color plano con el glifo de la aplicacion
    // encima, en el color de contraste del tema.
    Rectangle {
        id: tile
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.iconBox
        height: root.iconBox
        radius: Theme.dockIconRadius
        color: root.iconColor

        // --- Terminal: prompt ">" y cursor "_" ---
        Item {
            anchors.fill: parent
            visible: root.icon === "terminal"
            Text {
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.22
                anchors.verticalCenter: parent.verticalCenter
                text: ">"
                color: Theme.iconForeground
                font.family: Theme.fontFamily
                font.pixelSize: parent.height * 0.36
                font.bold: true
            }
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.42
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.18
                height: Math.max(2, parent.height * 0.055)
                color: Theme.iconForeground
            }
        }

        // --- Archivos: carpeta (lengueta + cuerpo) ---
        Item {
            anchors.fill: parent
            visible: root.icon === "files"
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.28
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.26
                width: parent.width * 0.24
                height: parent.height * 0.12
                color: Theme.iconForeground
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.24
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.52
                height: parent.height * 0.34
                radius: parent.height * 0.05
                color: Theme.iconForeground
            }
        }

        // --- Navegador: globo (circulo con ecuador y meridiano) ---
        Item {
            anchors.fill: parent
            visible: root.icon === "browser"
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.54
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Theme.iconForeground
                border.width: Math.max(2, parent.height * 0.05)
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.54
                height: Math.max(2, parent.height * 0.05)
                color: Theme.iconForeground
            }
            Rectangle {
                anchors.centerIn: parent
                width: Math.max(2, parent.height * 0.05)
                height: parent.width * 0.54
                color: Theme.iconForeground
            }
        }

        // --- Tienda: bolsa con asa ---
        Item {
            anchors.fill: parent
            visible: root.icon === "store"
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.22
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.46
                height: parent.height * 0.32
                radius: parent.height * 0.05
                color: Theme.iconForeground
            }
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.26
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.24
                height: Math.max(2, parent.height * 0.05)
                color: Theme.iconForeground
            }
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.26
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: -parent.width * 0.11
                width: Math.max(2, parent.height * 0.05)
                height: parent.height * 0.12
                color: Theme.iconForeground
            }
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.26
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: parent.width * 0.11
                width: Math.max(2, parent.height * 0.05)
                height: parent.height * 0.12
                color: Theme.iconForeground
            }
        }

        // --- Ajustes: tres deslizadores con mando ---
        Item {
            anchors.fill: parent
            visible: root.icon === "settings"
            Column {
                anchors.centerIn: parent
                spacing: parent.height * 0.11
                Repeater {
                    model: 3
                    delegate: Item {
                        required property int index
                        width: parent.width * 0.54
                        height: Math.max(2, parent.height * 0.05)
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Theme.iconForeground
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width * (index === 1 ? 0.6 : (index === 2 ? 0.25 : 0.45))
                            width: parent.height * 2.1
                            height: parent.height * 2.1
                            radius: width / 2
                            color: root.iconColor
                            border.color: Theme.iconForeground
                            border.width: Math.max(1, parent.height * 0.5)
                        }
                    }
                }
            }
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
