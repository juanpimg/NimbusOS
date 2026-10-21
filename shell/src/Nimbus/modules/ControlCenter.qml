// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Centro de Control del shell: red, bluetooth, audio, brillo, tema, acento,
// perfil de energia y acciones de sesion, en ese orden.
//
// Montaje en produccion: este componente es el CONTENIDO del panel; shell.qml
// lo instancia dentro de un `FloatingWindow` (Quickshell.Wayland) anclado a
// la esquina superior derecha con un margen de `edgeMargin` (24 px, valor
// fijo del spec). El anclaje, la capa y la visibilidad ligada a
// `ShellController.controlCenterOpen` dependen de FloatingWindow y solo se
// pueden verificar con compositor: van aqui documentados, no testeados.
//
// Testeable sin compositor: la tabla de secciones, la logica de habilitado
// segun servicios disponibles y todos los setters/señales viven en este
// Item sin importar Quickshell ni Wayland (ver tst_controlcenter.qml).
//
// Señales del contrato: `brightnessChanged`, `volumeChanged`,
// `microphoneMutedChanged`, `airplaneModeChanged`, `powerProfileChanged`,
// `themeModeChanged` y `accentChanged` son las señales implicitas de cada
// property (QML prohibe redeclararlas: qmllint `duplicated-name`). Las
// explicitas son `airplaneToggled(bool)` y `sessionActionRequested(string)`.
//
// Tema y acento se aplican EN CALIENTE: `setThemeMode`/`setAccent` escriben
// en `Config` (`setMode`/`setAccent`), que propaga a `Theme`, y todo el
// shell se actualiza al instante porque todos leen de `Theme`.
//
// Sin servicio, deshabilitado pero visible: aqui la ausencia de una funcion
// se EXPLICA (control deshabilitado con su etiqueta), no se esconde como en
// la barra. `controlState(id, available)` lo demuestra: `label` nunca vacio.
//
// Claves de traduccion usadas (pasan por `Config.translated`; si aun no
// existen en Translations.qml, `lookup` devuelve la propia clave):
//   cc.<seccion>.title (8), cc.theme.light/dark/auto,
//   cc.power.economy/balanced/performance,
//   cc.session.lock/suspend/logout/reboot/shutdown,
//   cc.network.wifi, cc.network.airplane, cc.audio.volume,
//   cc.audio.microphone, cc.brightness.level.
Item {
    id: root

    // Posicion contratada: esquina superior derecha, margen fijo de 24 px.
    readonly property int edgeMargin: 24
    readonly property string anchorCorner: "topRight"

    // Estado del contrato.
    property string brightness: "80"
    property int volume: 50
    property bool microphoneMuted: false
    property bool airplaneMode: false
    property string powerProfile: "balanced"
    // Vinculadas a Config: si otro modulo escribe el modo/acento, el panel
    // lo refleja; si el panel escribe, Config propaga a Theme en caliente.
    property string themeMode: Config.mode
    property string accent: Config.accent

    // Estado interno de la UI (no forma parte del contrato).
    property bool wifiOn: true
    property bool bluetoothOn: false

    // Disponibilidad de servicios en M1. Red/bluetooth se derivan de
    // Services (desconocido = ausente); audio y brillo aun no tienen flag
    // en Services, asi que son true por defecto y reescribibles (tests y M2).
    property bool networkAvailable: Services.networkState !== "unknown"
    property bool bluetoothAvailable: Services.bluetoothState !== "unknown"
    property bool audioAvailable: true
    property bool brightnessAvailable: true

    readonly property real contentWidth: width - Theme.spacing * 2

    signal airplaneToggled(bool on)
    signal sessionActionRequested(string action)

    // Tabla de secciones en el orden del spec.
    function sectionIds() {
        return ["network", "bluetooth", "audio", "brightness",
                "theme", "accent", "power", "session"]
    }

    function sectionTitle(id) {
        return Config.translated("cc." + id + ".title")
    }

    // Disponibilidad efectiva de cada seccion con los servicios actuales.
    function sectionAvailable(id) {
        switch (id) {
        case "network":
            return networkAvailable
        case "bluetooth":
            return bluetoothAvailable
        case "audio":
            return audioAvailable
        case "brightness":
            return brightnessAvailable
        case "theme":
        case "accent":
        case "power":
        case "session":
            return true
        default:
            return false
        }
    }

    // Logica pura "que se habilita segun que servicios hay": recibe la
    // disponibilidad como argumento para poder testearse sin tocar Services.
    // Tema, acento, energia y sesion no dependen de ningun servicio.
    function controlEnabled(controlId, available) {
        switch (controlId) {
        case "network":
        case "bluetooth":
        case "audio":
        case "brightness":
            return !!available
        case "theme":
        case "accent":
        case "power":
        case "session":
            return true
        default:
            return false
        }
    }

    // Estado visible de un control: habilitado o no, pero siempre con
    // etiqueta (deshabilitado, nunca roto ni oculto).
    function controlState(controlId, available) {
        return {
            "enabled": controlEnabled(controlId, available),
            "label": sectionTitle(controlId)
        }
    }

    function sections() {
        var ids = sectionIds()
        var out = []
        for (var i = 0; i < ids.length; i++) {
            out.push({
                "id": ids[i],
                "title": sectionTitle(ids[i]),
                "available": sectionAvailable(ids[i])
            })
        }
        return out
    }

    function themeModes() {
        return ["light", "dark", "auto"]
    }

    function themeModeLabel(mode) {
        return Config.translated("cc.theme." + mode)
    }

    function powerProfiles() {
        return ["economy", "balanced", "performance"]
    }

    function powerProfileLabel(profile) {
        return Config.translated("cc.power." + profile)
    }

    function sessionActions() {
        return ["lock", "suspend", "logout", "reboot", "shutdown"]
    }

    function sessionActionLabel(action) {
        return Config.translated("cc.session." + action)
    }

    function setVolume(v) {
        volume = Math.max(0, Math.min(100, Math.round(v)))
    }

    function setBrightness(value) {
        brightness = String(value)
    }

    function setMicrophoneMuted(muted) {
        microphoneMuted = !!muted
    }

    function setAirplaneMode(on) {
        var next = !!on
        if (airplaneMode === next)
            return
        airplaneMode = next
        airplaneToggled(airplaneMode)
    }

    function setPowerProfile(profile) {
        if (powerProfiles().indexOf(profile) === -1)
            return
        powerProfile = profile
    }

    // Escritura en caliente: Config.setMode propaga a Theme.setMode y todo
    // el shell (que lee de Theme) se actualiza al instante.
    function setThemeMode(mode) {
        if (themeModes().indexOf(mode) === -1)
            return
        Config.setMode(mode)
    }

    // Escritura en caliente: Config.setAccent propaga a Theme.setAccent.
    function setAccent(hex) {
        if (typeof hex !== "string")
            return
        Config.setAccent(hex)
    }

    function requestSessionAction(action) {
        if (sessionActions().indexOf(action) === -1)
            return
        sessionActionRequested(action)
    }

    width: Theme.spacing * 40
    height: content.height + Theme.spacing * 2

    Glass {
        anchors.fill: parent
    }

    Column {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Theme.spacing
        }
        spacing: Theme.spacing

        SectionHeader { text: root.sectionTitle("network"); width: root.contentWidth }
        Row {
            width: root.contentWidth
            spacing: Theme.spacing
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: root.contentWidth - wifiToggle.width - parent.spacing
                text: Config.translated("cc.network.wifi")
                color: root.sectionAvailable("network") ? Theme.text : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                elide: Text.ElideRight
            }
            Toggle {
                id: wifiToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: root.wifiOn
                enabled: root.sectionAvailable("network") && !root.airplaneMode
                onToggled: function(value) { root.wifiOn = value }
            }
        }
        Row {
            width: root.contentWidth
            spacing: Theme.spacing
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: root.contentWidth - airplaneToggle.width - parent.spacing
                text: Config.translated("cc.network.airplane")
                color: root.sectionAvailable("network") ? Theme.text : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                elide: Text.ElideRight
            }
            Toggle {
                id: airplaneToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: root.airplaneMode
                enabled: root.sectionAvailable("network")
                onToggled: function(value) { root.setAirplaneMode(value) }
            }
        }

        SectionHeader { text: root.sectionTitle("bluetooth"); width: root.contentWidth }
        Row {
            width: root.contentWidth
            spacing: Theme.spacing
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: root.contentWidth - btToggle.width - parent.spacing
                text: root.sectionTitle("bluetooth")
                color: root.sectionAvailable("bluetooth") ? Theme.text : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                elide: Text.ElideRight
            }
            Toggle {
                id: btToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: root.bluetoothOn
                enabled: root.sectionAvailable("bluetooth")
                onToggled: function(value) { root.bluetoothOn = value }
            }
        }

        SectionHeader { text: root.sectionTitle("audio"); width: root.contentWidth }
        Text {
            width: root.contentWidth
            text: Config.translated("cc.audio.volume")
            color: root.sectionAvailable("audio") ? Theme.text : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            elide: Text.ElideRight
        }
        Slider {
            width: root.contentWidth
            from: 0
            to: 100
            unit: "%"
            value: root.volume
            enabled: root.sectionAvailable("audio")
            onMoved: function(v) { root.setVolume(Math.round(v)) }
        }
        Row {
            width: root.contentWidth
            spacing: Theme.spacing
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: root.contentWidth - micToggle.width - parent.spacing
                text: Config.translated("cc.audio.microphone")
                color: root.sectionAvailable("audio") ? Theme.text : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                elide: Text.ElideRight
            }
            Toggle {
                id: micToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: root.microphoneMuted
                enabled: root.sectionAvailable("audio")
                onToggled: function(value) { root.setMicrophoneMuted(value) }
            }
        }

        SectionHeader { text: root.sectionTitle("brightness"); width: root.contentWidth }
        Text {
            width: root.contentWidth
            text: Config.translated("cc.brightness.level")
            color: root.sectionAvailable("brightness") ? Theme.text : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            elide: Text.ElideRight
        }
        Slider {
            width: root.contentWidth
            from: 0
            to: 100
            unit: "%"
            value: isNaN(Number(root.brightness)) ? 0 : Number(root.brightness)
            enabled: root.sectionAvailable("brightness")
            onMoved: function(v) { root.setBrightness(String(Math.round(v))) }
        }

        SectionHeader { text: root.sectionTitle("theme"); width: root.contentWidth }
        ListRow {
            width: root.contentWidth
            title: root.themeModeLabel("light")
            selected: root.themeMode === "light"
            onActivated: root.setThemeMode("light")
        }
        ListRow {
            width: root.contentWidth
            title: root.themeModeLabel("dark")
            selected: root.themeMode === "dark"
            onActivated: root.setThemeMode("dark")
        }
        ListRow {
            width: root.contentWidth
            title: root.themeModeLabel("auto")
            selected: root.themeMode === "auto"
            onActivated: root.setThemeMode("auto")
        }

        SectionHeader { text: root.sectionTitle("accent"); width: root.contentWidth }
        // Muestrarios: su color ES el dato elegido (el acento), no cromo;
        // bordes, radios y resaltado de seleccion salen de Theme.
        Row {
            width: root.contentWidth
            spacing: Theme.spacing
            Rectangle {
                width: Theme.spacing * 4
                height: Theme.spacing * 4
                radius: Theme.radius
                color: "#007aff"
                border.color: root.accent === "007aff" ? Theme.text : Theme.separator
                border.width: root.accent === "007aff" ? 2 : 1
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.setAccent("007aff")
                }
            }
            Rectangle {
                width: Theme.spacing * 4
                height: Theme.spacing * 4
                radius: Theme.radius
                color: "#ff2d55"
                border.color: root.accent === "ff2d55" ? Theme.text : Theme.separator
                border.width: root.accent === "ff2d55" ? 2 : 1
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.setAccent("ff2d55")
                }
            }
            Rectangle {
                width: Theme.spacing * 4
                height: Theme.spacing * 4
                radius: Theme.radius
                color: "#34c759"
                border.color: root.accent === "34c759" ? Theme.text : Theme.separator
                border.width: root.accent === "34c759" ? 2 : 1
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.setAccent("34c759")
                }
            }
            Rectangle {
                width: Theme.spacing * 4
                height: Theme.spacing * 4
                radius: Theme.radius
                color: "#ff9500"
                border.color: root.accent === "ff9500" ? Theme.text : Theme.separator
                border.width: root.accent === "ff9500" ? 2 : 1
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.setAccent("ff9500")
                }
            }
            Rectangle {
                width: Theme.spacing * 4
                height: Theme.spacing * 4
                radius: Theme.radius
                color: "#af52de"
                border.color: root.accent === "af52de" ? Theme.text : Theme.separator
                border.width: root.accent === "af52de" ? 2 : 1
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.setAccent("af52de")
                }
            }
        }

        SectionHeader { text: root.sectionTitle("power"); width: root.contentWidth }
        ListRow {
            width: root.contentWidth
            title: root.powerProfileLabel("economy")
            selected: root.powerProfile === "economy"
            onActivated: root.setPowerProfile("economy")
        }
        ListRow {
            width: root.contentWidth
            title: root.powerProfileLabel("balanced")
            selected: root.powerProfile === "balanced"
            onActivated: root.setPowerProfile("balanced")
        }
        ListRow {
            width: root.contentWidth
            title: root.powerProfileLabel("performance")
            selected: root.powerProfile === "performance"
            onActivated: root.setPowerProfile("performance")
        }

        SectionHeader { text: root.sectionTitle("session"); width: root.contentWidth }
        Button {
            width: root.contentWidth
            text: root.sessionActionLabel("lock")
            onClicked: root.requestSessionAction("lock")
        }
        Button {
            width: root.contentWidth
            text: root.sessionActionLabel("suspend")
            onClicked: root.requestSessionAction("suspend")
        }
        Button {
            width: root.contentWidth
            text: root.sessionActionLabel("logout")
            onClicked: root.requestSessionAction("logout")
        }
        Button {
            width: root.contentWidth
            text: root.sessionActionLabel("reboot")
            onClicked: root.requestSessionAction("reboot")
        }
        Button {
            width: root.contentWidth
            text: root.sessionActionLabel("shutdown")
            onClicked: root.requestSessionAction("shutdown")
        }
    }
}
