// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Energía: perfil, límite de carga de batería y modo de gráficos.
// Los valores por defecto (balanced, 80 %, on-demand) son el contrato
// testeable de SettingsData.powerDefaults().
//
// Llamada real (T6b): cada cambio invoca a `nimbus-energy` de verdad a
// través de un `Process` (T3) y muestra el resultado (perfil aplicado,
// error, etc.). Los `set` exigen privilegios y viajan con `pkexec`
// (polkit, mismo patrón que el propio `nimbus-energy`); `energyRunner`
// inyectable para tests (sin él, fallo con mensaje, nunca silencioso).
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    SettingsData { id: store }

    property string profile: store.defaultPowerProfile
    property string graphicsMode: store.defaultGraphicsMode

    // Resultado de la última invocación (texto ya traducido para la vista).
    property string lastResult: ""
    property string lastError: ""

    // Puente de ejecución inyectable (tests); null = Process real.
    property var energyRunner: null

    // Detalle pendiente de confirmar en el resultado (p. ej. el perfil).
    property string _pendingDetail: ""

    Process {
        id: energy
        runner: root.energyRunner
    }

    Component.onCompleted: {
        energy.finished.connect(_onEnergyFinished)
        energy.failed.connect(_onEnergyFailed)
    }

    function _runEnergy(args, detail) {
        lastResult = ""
        lastError = ""
        _pendingDetail = detail
        if (energy.running) {
            lastError = Config.translated("process.error.busy")
            return false
        }
        energy.command = "nimbus-energy"
        energy.args = args
        energy.privileged = true
        return energy.start()
    }

    function applyProfile(value) {
        profile = value
        return _runEnergy(["profile", "set", value], Config.translated("settings.power.profile") + ": " + value)
    }

    function applyChargeLimit(value) {
        return _runEnergy(["charge-limit", "set", String(Math.round(value))], Config.translated("settings.power.chargeLimit") + ": " + Math.round(value) + "%")
    }

    function applyGraphicsMode(mode) {
        graphicsMode = mode
        return _runEnergy(["gpu", "set", mode], Config.translated("settings.power.graphics") + ": " + mode)
    }

    function _onEnergyFinished(exitCode, stdout, stderr) {
        var detail = ""
        if (exitCode === 0) {
            lastError = ""
            lastResult = Config.translated("settings.power.applied") + (_pendingDetail !== "" ? ": " + _pendingDetail : "")
        } else {
            detail = (typeof stderr === "string" && stderr !== "") ? stderr : ("exit " + exitCode)
            lastResult = ""
            lastError = Config.translated("settings.power.failed") + ": " + detail
        }
        _pendingDetail = ""
    }

    function _onEnergyFailed(message) {
        lastResult = ""
        lastError = (typeof message === "string" && message !== "") ? message : Config.translated("settings.power.failed")
        _pendingDetail = ""
    }

    SectionHeader { text: Config.translated("settings.power.title") }
    SectionHeader { text: Config.translated("settings.power.profile") }

    Row {
        spacing: Theme.spacing
        Button {
            text: Config.translated("settings.power.profile.economy")
            onClicked: root.applyProfile("economy")
        }
        Button {
            text: Config.translated("settings.power.profile.balanced")
            onClicked: root.applyProfile("balanced")
        }
        Button {
            text: Config.translated("settings.power.profile.performance")
            onClicked: root.applyProfile("performance")
        }
    }

    SectionHeader { text: Config.translated("settings.power.chargeLimit") }

    Slider {
        id: chargeSlider
        width: parent.width
        from: 50
        to: 100
        unit: Config.translated("settings.displays.percent")
        Component.onCompleted: setValue(store.defaultChargeLimit)
    }

    Button {
        text: Config.translated("settings.power.apply")
        onClicked: root.applyChargeLimit(chargeSlider.value)
    }

    SectionHeader { text: Config.translated("settings.power.graphics") }

    Row {
        spacing: Theme.spacing
        Button {
            text: Config.translated("settings.power.graphics.auto")
            onClicked: root.applyGraphicsMode("auto")
        }
        Button {
            text: Config.translated("settings.power.graphics.ondemand")
            onClicked: root.applyGraphicsMode("on-demand")
        }
        Button {
            text: Config.translated("settings.power.graphics.always")
            onClicked: root.applyGraphicsMode("always")
        }
    }

    Text {
        id: energyResultLine
        objectName: "energyResult"
        width: parent.width
        visible: root.lastResult !== "" || root.lastError !== ""
        text: root.lastError !== "" ? root.lastError : root.lastResult
        color: root.lastError !== "" ? Theme.appRed : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        wrapMode: Text.Wrap
    }
}
