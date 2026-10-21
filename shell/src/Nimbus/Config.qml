// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick
import Nimbus

QtObject {
    id: root

    readonly property int schemaVersion: 2

    property string mode: "light"
    property string accent: "007AFF"
    property string locale: "es"

    function setMode(value) {
        if (value === "light" || value === "dark" || value === "auto")
            mode = value
        Theme.setMode(mode)
    }

    function setAccent(hex) {
        // NOTA: se normaliza a minúsculas (el test espera "ff2d55").
        accent = hex.replace("#", "").toLowerCase()
        Theme.setAccent("#" + accent)
    }

    function setLocale(tag) {
        locale = tag
    }

    function migrateFrom(oldVersion) {
        if (oldVersion < 2) {
            // v1 usaba "accentColor" y no distinguía el acento claro del oscuro.
            mode = mode === "auto" ? "light" : mode
        }
    }

    function translated(key) {
        return Translations.lookup(locale, key)
    }
}
