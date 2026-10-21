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

    // M4 (Task shell-mounting): la barra y el Dock leen TODO de aqui, sin
    // numeros sueltos en los componentes.
    // Tipografia por rol (macOS: cuerpo 13, pequeno 11, titulo 15).
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeBody: 13
    readonly property int fontSizeTitle: 15
    // Radios por superficie.
    readonly property int dockRadius: 20
    readonly property int dockIconRadius: 12
    readonly property int menuWidth: 280
    // Opacidad del contenido deshabilitado (items no disponibles).
    readonly property real disabledOpacity: 0.4
    // Linea fina de borde y sombra de superficies flotantes.
    readonly property color hairline: dark ? "#33FFFFFF" : "#1A000000"
    readonly property color shadow: "#40000000"
    // Baldosas del Dock: hues del sistema macOS (iguales en ambos modos).
    readonly property color appBlue: "#0A84FF"
    readonly property color appGreen: "#30D158"
    readonly property color appOrange: "#FF9F0A"
    readonly property color appPurple: "#BF5AF2"
    readonly property color appRed: "#FF453A"
    readonly property color appGray: "#8E8E93"

    // M1 (Task 1): valores fijos del contrato de superficies y animaciones.
    // Las tareas 2-12 los usan tal cual; no se negocian.
    readonly property int animStandard: 150
    readonly property int animSurface: 200
    readonly property real dockMagnify: 1.25
    readonly property int popupOffset: 24
    readonly property int spotlightMaxWidth: 640
    readonly property int spotlightMaxHeight: 420
    readonly property real spotlightWidthRatio: 0.8
    readonly property int switcherWidth: 800
    readonly property int switcherHeight: 300
    readonly property int notificationWidth: 360
    readonly property int notificationMaxVisible: 3

    readonly property color _accentLight: "#007AFF"
    readonly property color _accentDark: "#0A84FF"
    // NOTA: _userAccent es string (no color) porque "" no es un
    // inicializador válido para color; "" = el usuario no ha elegido.
    // En el binding de `accent` la rama string se convierte a color.
    property string _userAccent: ""
    readonly property color accent: _userAccent !== "" ? _userAccent
                                                       : (dark ? _accentDark : _accentLight)

    function setMode(mode) {
        // Un modo inválido no hace nada (antes caía en la rama "auto").
        if (mode !== "light" && mode !== "dark" && mode !== "auto")
            return
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
