// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool _dark: false
    readonly property bool dark: _dark

    readonly property color background: dark ? "#1C1C1E" : "#F5F5F7"
    readonly property color surface: dark ? "#2C2C2E" : "#FFFFFF"
    readonly property color surfaceAlt: dark ? "#3A3A3C" : "#ECECEE"
    readonly property color text: dark ? "#F5F5F7" : "#1D1D1F"
    readonly property color textMuted: dark ? "#98989D" : "#6E6E73"
    readonly property color separator: dark ? "#38383A" : "#D2D2D7"
    readonly property color glass: dark ? "#8C1C1C1E" : "#80FFFFFF"
    readonly property color glassOpaque: dark ? "#3A3A3C" : "#ECECEE"

    readonly property int radius: 12
    readonly property int spacing: 8
    readonly property int barHeight: 28
    readonly property int dockSize: 64
    readonly property string fontFamily: "Inter"

    property color _accentLight: "#007AFF"
    property color _accentDark: "#0A84FF"
    // NOTA: _userAccent es string (no color) porque "" no es un
    // inicializador válido para color; "" = el usuario no ha elegido.
    // En el binding de `accent` la rama string se convierte a color.
    property string _userAccent: ""
    readonly property color accent: _userAccent !== "" ? _userAccent
                                                       : (dark ? _accentDark : _accentLight)

    function setMode(mode) {
        if (mode === "dark") {
            _dark = true
            return
        }
        if (mode === "light") {
            _dark = false
            return
        }
        // "auto": se resuelve con el esquema de color del sistema. La
        // comprobación es defensiva porque Qt.application (o styleHints)
        // puede ser null bajo qmltestrunner, y acceder a una propiedad
        // sobre null lanzaría TypeError; por eso se usa truthiness (!app)
        // en lugar de comparar solo contra undefined. También se evita
        // tocar Qt.Dark si el enum no existe en esta versión de Qt.
        var app = (typeof Qt !== "undefined") ? Qt.application : undefined
        if (!app || !app.styleHints || app.styleHints.colorScheme === undefined)
            _dark = false
        else if (typeof Qt.Dark === "undefined")
            _dark = false
        else
            _dark = (app.styleHints.colorScheme === Qt.Dark)
    }

    // El acento elegido por el usuario gana en ambos modos; sin override
    // se usan los valores por defecto de cada modo (#007AFF / #0A84FF).
    function setAccent(value) {
        _userAccent = value
    }

    function resetAccent() {
        _userAccent = ""
    }
}
