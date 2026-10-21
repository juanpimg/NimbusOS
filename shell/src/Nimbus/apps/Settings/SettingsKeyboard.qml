// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Teclado: disposición y atajos.
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    SectionHeader { text: Config.translated("settings.keyboard.title") }
    SectionHeader { text: Config.translated("settings.keyboard.layout") }

    ListRow {
        width: parent.width
        title: Config.translated("settings.keyboard.layout")
        subtitle: Config.translated("settings.keyboard.current")
    }

    SectionHeader { text: Config.translated("settings.keyboard.shortcuts") }

    ListRow {
        width: parent.width
        title: Config.translated("settings.keyboard.shortcut.spotlight")
        subtitle: Config.translated("settings.keyboard.shortcut.spotlight.keys")
    }

    ListRow {
        width: parent.width
        title: Config.translated("settings.keyboard.shortcut.switcher")
        subtitle: Config.translated("settings.keyboard.shortcut.switcher.keys")
    }

    ListRow {
        width: parent.width
        title: Config.translated("settings.keyboard.shortcut.screenshot")
        subtitle: Config.translated("settings.keyboard.shortcut.screenshot.keys")
    }
}
