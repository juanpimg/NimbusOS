// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell.Wayland
import Nimbus

// Barra superior del shell (menu bar estilo macOS): PanelWindow anclado
// arriba con zona exclusiva, fondo de cristal, menu global a la izquierda
// (logo + aplicacion activa) e items de estado + reloj a la derecha.
// Dibuja, no decide:
// - cada item de estado solo es visible si su predicado (helpers puros de
//   TopBarMenu evaluados sobre Services) dice que existe;
// - el reloj se formatea con Config.locale y
//   Config.translated("bar.clock.format");
// - las entradas del menu llegan como datos (menuEntries) y las acciones
//   las consume quien construya esos datos (M2); la barra solo refleja si
//   el menu esta abierto (menuOpen es alias del estado del menu).
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }
    height: Theme.barHeight
    exclusiveZone: Theme.barHeight

    property alias menuOpen: appMenu.menuOpen
    property string currentApp: ""
    property var menuEntries: []
    property string logoName: ""
    property string networkIconName: ""
    property string volumeIconName: ""
    property string batteryIconName: ""
    property string bluetoothIconName: ""
    property string dndIconName: ""
    property var now: new Date()

    signal menuRequested(string appId)

    // M2 conecta aqui la desactivacion de la ventana del menu: sin
    // compositor no hay serial de foco que observar, asi que el cierre por
    // perdida de foco entra por esta funcion.
    function handleMenuFocusLost() {
        appMenu.handleFocusLost()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Glass {
        anchors.fill: parent
        // Sin redondeo: la barra ocupa todo el ancho (0 = ausencia de radio,
        // no una metrica del sistema de diseno).
        radius: 0
    }

    MouseArea {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: appRow.implicitWidth + Theme.spacing * 2
        onClicked: {
            root.menuRequested(root.currentApp)
            appMenu.openMenu(root.currentApp)
        }

        Row {
            id: appRow
            anchors {
                left: parent.left
                leftMargin: Theme.spacing
                verticalCenter: parent.verticalCenter
            }
            spacing: Theme.spacing

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.logoName !== ""
                name: root.logoName
                size: Theme.spacing * 2
                color: Theme.text
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentApp
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                elide: Text.ElideRight
            }
        }
    }

    Row {
        id: statusRow
        anchors {
            right: parent.right
            rightMargin: Theme.spacing
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.spacing

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: appMenu.networkVisible(Services.networkState)
            name: root.networkIconName
            size: Theme.spacing * 2
            color: Theme.text
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: appMenu.volumeVisible()
            name: root.volumeIconName
            size: Theme.spacing * 2
            color: Theme.text
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: appMenu.batteryVisible(Services.batteryPresent)
            name: root.batteryIconName
            size: Theme.spacing * 2
            color: Theme.text
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: appMenu.bluetoothVisible(Services.bluetoothState)
            name: root.bluetoothIconName
            size: Theme.spacing * 2
            color: Theme.text
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: appMenu.dndVisible()
            name: root.dndIconName
            size: Theme.spacing * 2
            color: Theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: appMenu.formatClock(root.now, Config.locale, Config.translated("bar.clock.format"))
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
        }
    }

    TopBarMenu {
        id: appMenu
        anchors {
            left: parent.left
            leftMargin: Theme.spacing
            top: parent.top
            topMargin: Theme.barHeight
        }
        width: implicitWidth
        height: implicitHeight
        visible: root.menuOpen
        entries: root.menuEntries
    }
}
