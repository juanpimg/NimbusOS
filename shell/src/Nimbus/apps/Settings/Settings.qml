// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import Nimbus

// Aplicación de Ajustes del sistema (Task 10): FloatingWindow con sidebar
// de secciones y panel de contenido.
//
//   property string section: string — sección visible actualmente.
//   property var sections: [] — lista de {id, titleKey, icon, available}.
//   sectionChanged es la señal implícita (notificador de `section):
//   navegar la emite y el destino se lee en `.section`.
//
// Las secciones sin servicio disponible (p. ej. bluetooth sin adaptador)
// se muestran DESHABILITADAS (atenuadas, no se pueden abrir), nunca
// ocultas. La lógica pura vive en SettingsData (testeable con Qt Test a
// secas); lo que depende de FloatingWindow o de servicios reales va aquí
// y se documenta como no testeado.
//
// Montaje pendiente (coordinación M1): registrar en shell/src/Nimbus/qmldir
// (ver informe) y crear una instancia desde shell.qml vía loadModule,
// visible cuando ShellController.activeSurface === "settings"
// (Ipc.call("settings", "open") la abre).
FloatingWindow {
    id: root

    property string section: store.section
    property var sections: store.sections

    // NOTA: `signal sectionChanged(string id)` no se declara explícita:
    // QML ya genera `sectionChanged` como notificador de `property string
    // section` y la declaración explícita no compila (ver SettingsData).
    // Cuando openSection navega, el binding actualiza `section` y la
    // señal implícita se emite; se lee `.section` tras ella.

    width: Theme.spacing * 120
    height: Theme.spacing * 75
    visible: ShellController.activeSurface === "settings"

    SettingsData {
        id: store
        bluetoothAvailable: Services.bluetoothState !== "unknown"
    }

    function openSection(id) {
        store.setSection(id, store.bluetoothAvailable)
    }

    function pageFor(id) {
        switch (id) {
        case "appearance":
            return "SettingsAppearance.qml"
        case "displays":
            return "SettingsDisplays.qml"
        case "keyboard":
            return "SettingsKeyboard.qml"
        case "network":
            return "SettingsNetwork.qml"
        case "bluetooth":
            return "SettingsBluetooth.qml"
        case "sound":
            return "SettingsSound.qml"
        case "power":
            return "SettingsPower.qml"
        case "users":
            return "SettingsUsers.qml"
        case "software":
            return "SettingsSoftware.qml"
        case "about":
            return "SettingsAbout.qml"
        default:
            return "SettingsAppearance.qml"
        }
    }

    Glass {
        anchors.fill: parent
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacing * 2
        spacing: Theme.spacing * 2

        Row {
            width: parent.width
            spacing: Theme.spacing
            Text {
                width: parent.width - closeButton.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: Config.translated("app.settings.title")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Button {
                id: closeButton
                anchors.verticalCenter: parent.verticalCenter
                text: Config.translated("settings.close")
                onClicked: ShellController.close("settings")
            }
        }

        Row {
            id: bodyRow
            width: parent.width
            height: parent.height - closeButton.height - parent.spacing
            spacing: Theme.spacing * 2

            // El sidebar hace scroll: 10 filas no caben en la altura
            // disponible y ListRow tiene altura fija (Theme.spacing * 7).
            Flickable {
                id: sideScroll
                width: Theme.spacing * 28
                height: parent.height
                contentHeight: sideCol.height
                clip: true
                Column {
                    id: sideCol
                    width: sideScroll.width
                    spacing: Theme.spacing
                    Repeater {
                        model: root.sections
                        delegate: ListRow {
                            width: sideCol.width
                            title: Config.translated(modelData.titleKey)
                            icon: modelData.icon
                            selected: modelData.id === root.section
                            opacity: modelData.available ? 1.0 : 0.4
                            subtitle: modelData.available ? "" : Config.translated("settings.bluetooth.unavailable")
                            onActivated: root.openSection(modelData.id)
                        }
                    }
                }
            }

            Loader {
                id: content
                width: bodyRow.width - sideScroll.width - bodyRow.spacing
                height: bodyRow.height
                source: root.pageFor(root.section)
            }
        }
    }
}
