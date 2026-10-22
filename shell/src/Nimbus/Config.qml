// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick
import Nimbus

QtObject {
    id: root

    readonly property int schemaVersion: 2

    property string mode: "light"
    property string accent: "007aff"
    property string locale: "es"
    // El tour de bienvenida se marca aqui para no volver a mostrarse.
    //
    // Por defecto esta MARCADO: el tour se abre a peticion (Ipc "tour start")
    // y no solo al arrancar. Motivo: en la sesion live de la ISO (efimera, se
    // reinicia en cada arranque) se repetiria en cada boot y su cartel tapa
    // el escritorio. En un sistema instalado tampoco tiene sentido que
    // aparezca solo: se ofrece desde el menu de la Manzana.
    property bool tourCompleted: true

    function setMode(value) {
        if (value === "light" || value === "dark" || value === "auto")
            mode = value
        Theme.setMode(mode)
    }

    function setAccent(hex) {
        // NOTA: se normaliza a minúsculas (el test espera "ff2d55").
        // Una entrada que no sea cadena se ignora (null/undefined
        // lanzarían TypeError en hex.replace).
        if (typeof hex !== "string")
            return
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
