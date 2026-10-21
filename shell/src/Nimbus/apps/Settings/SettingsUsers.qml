// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Usuarios: gestión de usuarios del sistema.
// El cableado a cuentas reales (accountsservice) entra en M2; aquí vive
// la estructura con controles del design system.
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    SectionHeader { text: Config.translated("settings.users.title") }

    ListRow {
        width: parent.width
        title: Config.translated("settings.users.current")
        subtitle: Config.translated("settings.users.administrator")
    }

    Row {
        spacing: Theme.spacing
        Button {
            text: Config.translated("settings.users.add")
            onClicked: console.info("settings: añadir usuario (M2: accountsservice)")
        }
        Button {
            text: Config.translated("settings.users.remove")
            onClicked: console.info("settings: quitar usuario (M2: accountsservice)")
        }
    }
}
