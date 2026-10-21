// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

QtObject {
    property var table: ({
        "es": {
            "app.store.title": "Nimbus Store",
            "app.settings.title": "Ajustes del sistema",
            "app.dock.title": "Dock"
        },
        "en": {
            "app.store.title": "Nimbus Store",
            "app.settings.title": "System Settings",
            "app.dock.title": "Dock"
        }
    })

    function lookup(locale, key) {
        var lang = String(locale || "en").split("-")[0]
        if (table[lang] && table[lang][key] !== undefined)
            return table[lang][key]
        if (table["en"] && table["en"][key] !== undefined)
            return table["en"][key]
        return key
    }
}
