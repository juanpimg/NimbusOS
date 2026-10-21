// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import Nimbus

// Barra superior del shell (menu bar estilo macOS): PanelWindow anclado
// arriba con zona exclusiva, fondo de cristal, menu Nimbus a la izquierda
// (marca + aplicacion activa) e items de estado + reloj a la derecha.
// Dibuja, no decide:
// - cada item de estado solo es visible si su predicado (helpers puros de
//   TopBarMenu evaluados sobre Services) dice que existe;
// - el reloj se formatea con Config.locale y
//   Config.translated("bar.clock.format");
// - las entradas del menu llegan como datos (menuEntries) y las acciones
//   las consume quien construya esos datos (M2); sin datos se ofrece el menu
//   Nimbus por defecto (Acerca de, Ajustes, Reiniciar, Apagar, Cerrar
//   sesion); la barra solo refleja si el menu esta abierto (menuOpen es
//   alias del estado del menu).
// - los botones de Control Center y Notificaciones abren sus superficies
//   via ShellController; la marca Nimbus se dibuja con formas (sin assets).
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Top
    anchors {
        top: true
        left: true
        right: true
    }
    // La ventana crece cuando el menu esta abierto: el desplegable cae por
    // debajo de la barra y, si la ventana midiese solo `barHeight`, el
    // compositor lo recortaria (el menu se veria cortado por el borde).
    // La zona exclusiva sigue siendo solo la franja de la barra.
    height: root.menuOpen ? Theme.barHeight + appMenu.implicitHeight : Theme.barHeight
    exclusiveZone: Theme.barHeight

    property alias menuOpen: appMenu.menuOpen
    property string currentApp: Config.translated("menu.nimbus.title")
    property var menuEntries: []
    property string logoName: ""
    property string networkIconName: ""
    property string volumeIconName: ""
    property string batteryIconName: ""
    property string bluetoothIconName: ""
    property string dndIconName: ""
    property var now: new Date()

    // Entradas efectivas: las que lleguen como datos o, en su defecto, el
    // menu Nimbus por defecto (macOS: la pieza mas identificativa).
    readonly property var effectiveEntries: (Array.isArray(menuEntries) && menuEntries.length > 0) ? menuEntries : [{
        "title": "",
        "items": [
            { "label": Config.translated("menu.nimbus.about"), "action": "about", "checked": false, "disabled": false },
            { "label": Config.translated("menu.nimbus.settings"), "action": "settings", "checked": false, "disabled": false },
            { "label": Config.translated("menu.nimbus.restart"), "action": "restart", "checked": false, "disabled": false },
            { "label": Config.translated("menu.nimbus.shutdown"), "action": "shutdown", "checked": false, "disabled": false },
            { "label": Config.translated("menu.nimbus.logout"), "action": "logout", "checked": false, "disabled": false }
        ]
    }]

    signal menuRequested(string appId)

    // M2 conecta aqui la desactivacion de la ventana del menu: sin
    // compositor no hay serial de foco que observar, asi que el cierre por
    // perdida de foco entra por esta funcion.
    function handleMenuFocusLost() {
        appMenu.handleFocusLost()
    }

    // Acciones del menu Nimbus por defecto: Ajustes abre su superficie; el
    // resto viaja como `surfaceRequested("session", action)` para que la
    // capa de sesion (M2) los consuma. Nunca lanza.
    function handleMenuAction(action) {
        if (action === "settings") {
            ShellController.open("settings")
            return
        }
        if (typeof action === "string" && action !== "")
            ShellController.surfaceRequested("session", action)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Glass {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        // Solo la franja de la barra es opaca; el resto de la ventana (la
        // zona del desplegable) se queda transparente.
        height: Theme.barHeight
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

            // Marca Nimbus dibujada con formas: baldosa de acento con una N
            // de tres barras (sin assets de terceros ni de Apple).
            Rectangle {
                id: mark
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fontSizeBody + 3
                height: Theme.fontSizeBody + 3
                radius: 4
                color: Theme.accent
                Rectangle {
                    x: 4
                    y: 3
                    width: 2
                    height: parent.height - 6
                    radius: 1
                    color: Theme.background
                }
                Rectangle {
                    x: parent.width - 6
                    y: 3
                    width: 2
                    height: parent.height - 6
                    radius: 1
                    color: Theme.background
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 2
                    height: parent.height - 4
                    radius: 1
                    rotation: 28
                    color: Theme.background
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentApp
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.DemiBold
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
            font.pixelSize: Theme.fontSizeBody
        }

        // Boton Centro de control: tres deslizadores dibujados con formas.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.spacing * 2
            height: Theme.spacing * 2
            Accessible.name: Config.translated("bar.controlcenter")
            Column {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: Theme.spacing * 2
                        height: 2
                        radius: 1
                        color: Theme.text
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: ShellController.toggle("controlcenter")
            }
        }

        // Boton Notificaciones: campana dibujada con formas.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.spacing * 2
            height: Theme.spacing * 2
            Accessible.name: Config.translated("bar.notifications")
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 10
                height: 9
                radius: 4
                color: Theme.text
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4
                height: 4
                radius: 2
                color: Theme.text
            }
            MouseArea {
                anchors.fill: parent
                onClicked: ShellController.toggle("notifications")
            }
        }
    }

    Connections {
        target: appMenu
        function onActionTriggered(appId, action) {
            root.handleMenuAction(action)
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
        entries: root.effectiveEntries
    }
}
