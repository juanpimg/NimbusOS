// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Software: estado de las actualizaciones y acceso a la
// actualización. Enlaza con la herramienta `nimbus-update` (prevista en
// tools/, hito M3; hoy aún no existe): el nombre del comando vive en
// SettingsData.updateTool para hacerlo testeable; la invocación real
// entra con la herramienta.
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    SettingsData { id: store }

    SectionHeader { text: Config.translated("settings.software.title") }
    SectionHeader { text: Config.translated("settings.software.status") }

    ListRow {
        width: parent.width
        title: Config.translated("settings.software.system")
        subtitle: Config.translated("settings.software.uptodate")
    }

    Row {
        spacing: Theme.spacing
        Button {
            text: Config.translated("settings.software.check")
            onClicked: console.info("settings: comprobar actualizaciones vía " + store.updateTool)
        }
        Button {
            text: Config.translated("settings.software.update")
            onClicked: console.info("settings: actualizar vía " + store.updateTool)
        }
    }
}
