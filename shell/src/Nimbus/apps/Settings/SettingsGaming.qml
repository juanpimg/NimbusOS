// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Panel Energía y juegos: perfil de energía, límite de carga, gráficos
// híbridos, reglas de rendimiento (ananicy), batería (UPower) y VRR.
//
// Cada acción invoca a su CLI de verdad a través de un `Process` (los `set`
// con `privileged: true`, es decir, via `pkexec`/polkit; las lecturas sin
// privilegios) y muestra el resultado o el error traducido en la vista.
// `energyRunner`/`anonicyRunner`/`batteryRunner`/`vrrRunner` inyectables
// para tests (sin ellos, fallo con mensaje, nunca silencioso).
// La lógica pura (parseo de `upower -d`, del check VRR y del estado de
// ananicy) vive en funciones testeables sin compositor; este `Column` no
// instancia ventanas.
Column {
    id: root

    anchors.fill: parent
    spacing: Theme.spacing * 2

    SettingsData { id: store }

    property string profile: store.defaultPowerProfile
    property int chargeLimit: store.defaultChargeLimit
    property string graphicsMode: store.defaultGraphicsMode
    property string ananicyState: "unknown"
    property int batteryLevel: -1
    property string batteryState: "unknown"
    property bool vrrSupported: false
    property string vrrRate: ""
    property string vrrConnector: ""

    // Resultado de la última invocación (texto ya traducido para la vista).
    property string lastResult: ""
    property string lastError: ""

    // Puentes de ejecución inyectables (tests); null = Process real.
    property var energyRunner: null
    property var anonicyRunner: null
    property var batteryRunner: null
    property var vrrRunner: null

    // Detalle pendiente de confirmar en el resultado (p. ej. el perfil).
    property string _pendingDetail: ""

    Process {
        id: energy
        runner: root.energyRunner
    }

    Process {
        id: anonicy
        runner: root.anonicyRunner
    }

    Process {
        id: battery
        runner: root.batteryRunner
    }

    Process {
        id: vrr
        runner: root.vrrRunner
    }

    Component.onCompleted: {
        energy.finished.connect(_onEnergyFinished)
        energy.failed.connect(_onEnergyFailed)
        anonicy.finished.connect(_onAnonicyFinished)
        anonicy.failed.connect(_onAnonicyFailed)
        battery.finished.connect(_onBatteryFinished)
        battery.failed.connect(_onBatteryFailed)
        vrr.finished.connect(_onVrrFinished)
        vrr.failed.connect(_onVrrFailed)
    }

    function _runCli(proc, command, args, privileged, detail) {
        lastResult = ""
        lastError = ""
        _pendingDetail = detail
        if (proc.running) {
            lastError = Config.translated("process.error.busy")
            return false
        }
        proc.command = command
        proc.args = args
        proc.privileged = privileged
        return proc.start()
    }

    function applyProfile(value) {
        profile = value
        return _runCli(energy, "nimbus-energy", ["profile", "set", value], true, Config.translated("settings.power.profile") + ": " + value)
    }

    function applyChargeLimit(value) {
        var v = (value === "off") ? "off" : String(Math.round(value))
        if (v !== "off")
            chargeLimit = Math.round(value)
        return _runCli(energy, "nimbus-energy", ["charge-limit", "set", v], true, Config.translated("settings.power.chargeLimit") + ": " + v)
    }

    function applyGraphicsMode(mode) {
        graphicsMode = mode
        return _runCli(energy, "nimbus-energy", ["gpu", "set", mode], true, Config.translated("settings.power.graphics") + ": " + mode)
    }

    function setAnanicy(on) {
        var action = on ? "enable" : "disable"
        return _runCli(anonicy, "nimbus-anonicy", [action], true, Config.translated("settings.gaming.ananicy") + ": " + action)
    }

    function refreshAnanicyStatus() {
        return _runCli(anonicy, "nimbus-anonicy", ["status"], false, "")
    }

    function refreshBattery() {
        return _runCli(battery, "upower", ["-d"], false, "")
    }

    function refreshVrr() {
        return _runCli(vrr, "gamescope-vrr-check", [], false, "")
    }

    // `nimbus-anonicy status` informa `enabled: ...` o `disabled: ...`.
    function _parseAnanicyStatus(stdout) {
        var text = String(stdout !== undefined && stdout !== null ? stdout : "")
        if (/^\s*enabled:/m.test(text))
            return "enabled"
        if (/^\s*disabled:/m.test(text))
            return "disabled"
        return "unknown"
    }

    // `upower -d` vuelca todos los dispositivos; el bloque `Device:
    // ...battery_BAT*` trae `percentage:` y `state:`.
    function _parseUpowerDump(stdout) {
        var lines = String(stdout !== undefined && stdout !== null ? stdout : "").split("\n")
        var inBattery = false
        var level = -1
        var state = "unknown"
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i]
            if (/^\s*Device:/.test(line)) {
                inBattery = /^Device:.*battery_/i.test(line)
                continue
            }
            if (/^\s*Daemon:/.test(line)) {
                inBattery = false
                continue
            }
            if (!inBattery)
                continue
            var pct = /percentage:\s*([0-9]+)%/.exec(line)
            if (pct !== null)
                level = parseInt(pct[1], 10)
            var st = /state:\s*([A-Za-z-]+)/.exec(line)
            if (st !== null)
                state = st[1]
        }
        return {"level": level, "state": state}
    }

    // `gamescope-vrr-check` informa `KEY: VALUE` (connector/vrr/rate).
    function _parseVrrOutput(stdout) {
        var out = {"supported": false, "rate": "", "connector": ""}
        var lines = String(stdout !== undefined && stdout !== null ? stdout : "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var m = /^\s*(connector|vrr|rate)\s*:\s*(\S+)/.exec(lines[i])
            if (m === null)
                continue
            if (m[1] === "vrr")
                out.supported = (m[2] === "supported")
            else if (m[1] === "rate" && /^[0-9]+$/.test(m[2]))
                out.rate = m[2]
            else if (m[1] === "connector")
                out.connector = m[2]
        }
        return out
    }

    function batteryStatusText() {
        if (batteryLevel < 0)
            return Config.translated("settings.gaming.battery.none")
        var st = batteryState
        if (st === "charging")
            st = Config.translated("settings.gaming.battery.charging")
        else if (st === "discharging")
            st = Config.translated("settings.gaming.battery.discharging")
        else if (st === "fully-charged")
            st = Config.translated("settings.gaming.battery.full")
        return batteryLevel + "% · " + st
    }

    function vrrStatusText() {
        if (!vrrSupported)
            return Config.translated("settings.gaming.vrr.unsupported")
        var text = Config.translated("settings.gaming.vrr.supported")
        if (vrrRate !== "")
            text += " · " + vrrRate + " Hz"
        if (vrrConnector !== "")
            text += " (" + vrrConnector + ")"
        return text
    }

    function ananicyStatusText() {
        if (ananicyState === "enabled")
            return Config.translated("settings.gaming.ananicy.enabled")
        if (ananicyState === "disabled")
            return Config.translated("settings.gaming.ananicy.disabled")
        return Config.translated("settings.gaming.ananicy.unknown")
    }

    function _appliedDetail() {
        return Config.translated("settings.power.applied") + (_pendingDetail !== "" ? ": " + _pendingDetail : "")
    }

    function _failedDetail(stderr, exitCode) {
        var detail = (typeof stderr === "string" && stderr !== "") ? stderr : ("exit " + exitCode)
        return Config.translated("settings.power.failed") + ": " + detail
    }

    function _failMessage(message) {
        return (typeof message === "string" && message !== "") ? message : Config.translated("settings.power.failed")
    }

    function _onEnergyFinished(exitCode, stdout, stderr) {
        if (exitCode === 0) {
            lastError = ""
            lastResult = _appliedDetail()
        } else {
            lastResult = ""
            lastError = _failedDetail(stderr, exitCode)
        }
        _pendingDetail = ""
    }

    function _onEnergyFailed(message) {
        lastResult = ""
        lastError = _failMessage(message)
        _pendingDetail = ""
    }

    function _onAnonicyFinished(exitCode, stdout, stderr) {
        if (exitCode === 0) {
            ananicyState = _parseAnanicyStatus(stdout)
            lastError = ""
            lastResult = _pendingDetail !== "" ? _appliedDetail() : ananicyStatusText()
        } else {
            lastResult = ""
            lastError = _failedDetail(stderr, exitCode)
        }
        _pendingDetail = ""
    }

    function _onAnonicyFailed(message) {
        lastResult = ""
        lastError = _failMessage(message)
        _pendingDetail = ""
    }

    function _onBatteryFinished(exitCode, stdout, stderr) {
        if (exitCode === 0) {
            var parsed = _parseUpowerDump(stdout)
            batteryLevel = parsed.level
            batteryState = parsed.state
            lastError = ""
            lastResult = batteryStatusText()
        } else {
            lastResult = ""
            lastError = _failedDetail(stderr, exitCode)
        }
        _pendingDetail = ""
    }

    function _onBatteryFailed(message) {
        lastResult = ""
        lastError = _failMessage(message)
        _pendingDetail = ""
    }

    function _onVrrFinished(exitCode, stdout, stderr) {
        if (exitCode === 0) {
            var parsed = _parseVrrOutput(stdout)
            vrrSupported = parsed.supported
            vrrRate = parsed.rate
            vrrConnector = parsed.connector
            lastError = ""
            lastResult = vrrStatusText()
        } else {
            lastResult = ""
            lastError = _failedDetail(stderr, exitCode)
        }
        _pendingDetail = ""
    }

    function _onVrrFailed(message) {
        lastResult = ""
        lastError = _failMessage(message)
        _pendingDetail = ""
    }

    SectionHeader { text: Config.translated("settings.gaming.title") }
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
        from: 40
        to: 80
        unit: Config.translated("settings.displays.percent")
        Component.onCompleted: setValue(store.defaultChargeLimit)
    }

    Row {
        spacing: Theme.spacing
        Button {
            text: Config.translated("settings.power.apply")
            onClicked: root.applyChargeLimit(chargeSlider.value)
        }
        Button {
            text: Config.translated("settings.gaming.chargeUnlimited")
            onClicked: root.applyChargeLimit("off")
        }
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

    SectionHeader { text: Config.translated("settings.gaming.ananicy") }

    Row {
        spacing: Theme.spacing
        Button {
            text: Config.translated("settings.gaming.ananicy.enable")
            onClicked: root.setAnanicy(true)
        }
        Button {
            text: Config.translated("settings.gaming.ananicy.disable")
            onClicked: root.setAnanicy(false)
        }
        Button {
            text: Config.translated("settings.gaming.ananicy.refresh")
            onClicked: root.refreshAnanicyStatus()
        }
    }

    Text {
        id: ananicyLine
        objectName: "gamingAnanicy"
        width: parent.width
        text: root.ananicyStatusText()
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        wrapMode: Text.Wrap
    }

    SectionHeader { text: Config.translated("settings.gaming.battery") }

    Button {
        text: Config.translated("settings.gaming.battery.refresh")
        onClicked: root.refreshBattery()
    }

    Text {
        id: batteryLine
        objectName: "gamingBattery"
        width: parent.width
        text: root.batteryStatusText()
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        wrapMode: Text.Wrap
    }

    SectionHeader { text: Config.translated("settings.gaming.vrr") }

    Button {
        text: Config.translated("settings.gaming.vrr.refresh")
        onClicked: root.refreshVrr()
    }

    Text {
        id: vrrLine
        objectName: "gamingVrr"
        width: parent.width
        text: root.vrrStatusText()
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        wrapMode: Text.Wrap
    }

    Text {
        id: gamingResultLine
        objectName: "gamingResult"
        width: parent.width
        visible: root.lastResult !== "" || root.lastError !== ""
        text: root.lastError !== "" ? root.lastError : root.lastResult
        color: root.lastError !== "" ? Theme.appRed : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
        wrapMode: Text.Wrap
    }
}
