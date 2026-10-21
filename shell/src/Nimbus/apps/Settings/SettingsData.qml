// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// Lógica pura de la aplicación de Ajustes (Task 10).
//
// Todo lo testeable con Qt Test a secas vive aquí, sin FloatingWindow ni
// servicios reales: el orden exacto de las secciones, la disponibilidad
// (una sección sin servicio queda DESHABILITADA, nunca oculta), los 12
// preajustes de acento con sus hex, los valores por defecto de energía,
// la herramienta de actualización y los créditos.
//
// NOTA sobre colores: los hex de `accentPresets()` son DATOS (se aplican
// vía Config.setAccent -> Theme.setAccent, es decir, canalizados por
// Theme). Ningún fichero de interfaz usa literales de color, radio o
// métrica fuera de Theme.
QtObject {
    id: root

    // Sección visible actualmente.
    property string section: "appearance"

    // Disponibilidad del adaptador bluetooth. La fija Settings.qml desde
    // Services.bluetoothState; en tests se pasa a buildSections/setSection.
    property bool bluetoothAvailable: false

    // Entradas del sidebar: [{id, titleKey, icon, available}].
    property var sections: buildSections(bluetoothAvailable)

    // Herramienta de actualización del sistema: `nimbus-update` (prevista
    // en tools/, hito M3; hoy aún no existe — el panel Software la
    // referencia por nombre para hacer el enlace testeable).
    readonly property string updateTool: "nimbus-update"

    // Valores por defecto de energía (contrato testeable).
    readonly property string defaultPowerProfile: "balanced"
    readonly property int defaultChargeLimit: 80
    readonly property string defaultGraphicsMode: "on-demand"

    // NOTA: `sectionChanged` NO se declara explícita: QML genera esa señal
    // como notificador de `property string section` y una declaración
    // explícita `signal sectionChanged(string id)` no compila (clash).
    // setSection asigna la propiedad, lo que emite la señal implícita
    // (precedente en el código: Toggle.checked + signal toggled).
    // Quien navegue lee `.section` tras la señal.

    // Las 10 secciones, en este orden exacto (contrato de la M1).
    function sectionOrder() {
        return ["appearance", "displays", "keyboard", "network", "bluetooth", "sound", "power", "users", "software", "about"]
    }

    function sectionTitleKey(id) {
        return "settings.section." + id
    }

    // Glifos provisionales del sidebar (símbolos, no cadenas traducibles);
    // el cableado a un tema de iconos entra en M2.
    function sectionIcon(id) {
        switch (id) {
        case "appearance":
            return "◐"
        case "displays":
            return "▦"
        case "keyboard":
            return "⌨"
        case "network":
            return "◉"
        case "bluetooth":
            return "◍"
        case "sound":
            return "♪"
        case "power":
            return "⏻"
        case "users":
            return "☺"
        case "software":
            return "⬇"
        case "about":
            return "ⓘ"
        default:
            return "·"
        }
    }

    function isSectionAvailable(id, bluetoothOk) {
        if (sectionOrder().indexOf(id) === -1)
            return false
        if (id === "bluetooth")
            return !!bluetoothOk
        return true
    }

    function buildSections(bluetoothOk) {
        var order = sectionOrder()
        var out = []
        for (var i = 0; i < order.length; ++i) {
            out.push({
                "id": order[i],
                "titleKey": sectionTitleKey(order[i]),
                "icon": sectionIcon(order[i]),
                "available": isSectionAvailable(order[i], bluetoothOk)
            })
        }
        return out
    }

    // Navega a una sección disponible; una sección deshabilitada o
    // desconocida se ignora sin emitir (nunca se oculta, solo no se abre).
    function setSection(id, bluetoothOk) {
        if (sectionOrder().indexOf(id) === -1)
            return
        if (!isSectionAvailable(id, bluetoothOk))
            return
        if (root.section === id)
            return
        // La asignación emite la señal implícita `sectionChanged`.
        root.section = id
    }

    // 12 preajustes de acento (contrato testeable). `name` es clave de
    // traducción; `hex` es el dato que se pasa a Config.setAccent.
    function accentPresets() {
        return [
            { "name": "settings.accent.blue", "hex": "#007aff" },
            { "name": "settings.accent.indigo", "hex": "#5856d6" },
            { "name": "settings.accent.purple", "hex": "#af52de" },
            { "name": "settings.accent.pink", "hex": "#ff2d55" },
            { "name": "settings.accent.red", "hex": "#ff3b30" },
            { "name": "settings.accent.orange", "hex": "#ff9500" },
            { "name": "settings.accent.yellow", "hex": "#ffcc00" },
            { "name": "settings.accent.green", "hex": "#34c759" },
            { "name": "settings.accent.mint", "hex": "#00c7be" },
            { "name": "settings.accent.teal", "hex": "#30b0c7" },
            { "name": "settings.accent.cyan", "hex": "#32ade6" },
            { "name": "settings.accent.graphite", "hex": "#8e8e93" }
        ]
    }

    function powerDefaults() {
        return {
            "profile": root.defaultPowerProfile,
            "chargeLimit": root.defaultChargeLimit,
            "graphicsMode": root.defaultGraphicsMode
        }
    }

    // Créditos/licencias de Acerca de (deben incluir MacShell/MIT y
    // WhiteSur/GPL). Los identificadores de licencia son nombres propios,
    // no se traducen.
    function credits() {
        return [
            { "name": "Nimbus", "license": "GPL-3.0-or-later" },
            { "name": "MacShell", "license": "MIT" },
            { "name": "WhiteSur", "license": "GPL-3.0-or-later" },
            { "name": "Quickshell", "license": "GPL-3.0-or-later" }
        ]
    }
}
