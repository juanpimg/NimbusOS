// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Acerca de: versión, kernel, hardware y créditos/licencias
// (incluyen MacShell/MIT y WhiteSur/GPL vía SettingsData.credits()).
// Los valores de versión/kernel/hardware los proveerá un servicio en M2;
// mientras tanto muestran la clave genérica settings.about.unknown.
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    SettingsData { id: store }

    // Copia local: el modelo del Repeater lee una propiedad notificable
    // en vez de llamar a la función en el binding (evita stale reads).
    property var credits: []
    Component.onCompleted: credits = store.credits()

    SectionHeader { text: Config.translated("settings.about.title") }

    ListRow {
        width: parent.width
        title: Config.translated("settings.about.version")
        subtitle: Config.translated("settings.about.unknown")
    }

    ListRow {
        width: parent.width
        title: Config.translated("settings.about.kernel")
        subtitle: Config.translated("settings.about.unknown")
    }

    ListRow {
        width: parent.width
        title: Config.translated("settings.about.hardware")
        subtitle: Config.translated("settings.about.unknown")
    }

    SectionHeader { text: Config.translated("settings.about.credits") }

    Repeater {
        model: credits
        delegate: ListRow {
            width: root.width
            title: modelData.name
            subtitle: Config.translated("settings.about.license") + ": " + modelData.license
        }
    }
}
