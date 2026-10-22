// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus
import "../src/Nimbus/apps/Settings" as SettingsApp

// Contrato de Ajustes->Energía y juegos (Task T6): la página llama a los CLI
// reales (`nimbus-energy`, `nimbus-anonicy`, `upower`, `gamescope-vrr-check`)
// a través de `Process` con patrón pkexec para los `set`, y muestra el
// resultado o el error con texto traducido. Nada de console.info: todo
// resultado visible viaja por `lastResult`/`lastError` y los textos de
// estado. Runners inyectables; sin ellos, fallo con mensaje, nunca
// silencioso. La página es un `Column` puro (sin ventanas) para poder
// probarse sin compositor.
TestCase {
    name: "SettingsGaming"
    when: true

    QtObject {
        id: fakeEnergy
        property var calls: []
        property int exitCode: 0
        property string stderrText: ""
        function run(cmd) {
            calls.push(cmd)
            return {"exitCode": exitCode, "stdout": "", "stderr": stderrText}
        }
        function reset() {
            calls = []
            exitCode = 0
            stderrText = ""
        }
    }

    QtObject {
        id: fakeAnonicy
        property var calls: []
        property string stdoutText: "disabled: rige el conjunto de reglas por defecto.\n"
        function run(cmd) {
            calls.push(cmd)
            return {"exitCode": 0, "stdout": stdoutText, "stderr": ""}
        }
        function reset() {
            calls = []
            stdoutText = "disabled: rige el conjunto de reglas por defecto.\n"
        }
    }

    QtObject {
        id: fakeBattery
        property var calls: []
        property string stdoutText: ""
        function run(cmd) {
            calls.push(cmd)
            return {"exitCode": 0, "stdout": stdoutText, "stderr": ""}
        }
        function reset() { calls = []; stdoutText = "" }
    }

    QtObject {
        id: fakeVrr
        property var calls: []
        property string stdoutText: "connector: unknown\nvrr: unsupported\nrate: unknown\n"
        function run(cmd) {
            calls.push(cmd)
            return {"exitCode": 0, "stdout": stdoutText, "stderr": ""}
        }
        function reset() {
            calls = []
            stdoutText = "connector: unknown\nvrr: unsupported\nrate: unknown\n"
        }
    }

    readonly property string upowerSample: "Device: /org/freedesktop/UPower/devices/battery_BAT0\n  native-path: BAT0\n  percentage: 78%\n  state: discharging\n"

    SettingsApp.SettingsGaming {
        id: gaming
        energyRunner: fakeEnergy
        anonicyRunner: fakeAnonicy
        batteryRunner: fakeBattery
        vrrRunner: fakeVrr
    }
    SettingsApp.SettingsGaming { id: gamingAlone }

    function test_apply_profile_calls_nimbus_energy_privileged() {
        fakeEnergy.reset()
        gaming.lastResult = ""
        gaming.lastError = ""
        gaming.applyProfile("performance")
        compare(gaming.profile, "performance")
        compare(fakeEnergy.calls.length, 1)
        compare(fakeEnergy.calls[0].join(","), "pkexec,nimbus-energy,profile,set,performance")
        verify(gaming.lastResult !== "")
        compare(gaming.lastError, "")
    }

    function test_apply_charge_limit_calls_nimbus_energy() {
        fakeEnergy.reset()
        gaming.applyChargeLimit(60)
        compare(fakeEnergy.calls.length, 1)
        compare(fakeEnergy.calls[0].join(","), "pkexec,nimbus-energy,charge-limit,set,60")
        verify(gaming.lastResult !== "")
    }

    function test_apply_charge_limit_off_is_supported() {
        fakeEnergy.reset()
        gaming.applyChargeLimit("off")
        compare(fakeEnergy.calls.length, 1)
        compare(fakeEnergy.calls[0].join(","), "pkexec,nimbus-energy,charge-limit,set,off")
    }

    function test_apply_graphics_mode_calls_nimbus_energy() {
        fakeEnergy.reset()
        gaming.applyGraphicsMode("always")
        compare(gaming.graphicsMode, "always")
        compare(fakeEnergy.calls.length, 1)
        compare(fakeEnergy.calls[0].join(","), "pkexec,nimbus-energy,gpu,set,always")
    }

    function test_ananicy_enable_goes_through_polkit() {
        fakeAnonicy.reset()
        gaming.setAnanicy(true)
        compare(fakeAnonicy.calls.length, 1)
        compare(fakeAnonicy.calls[0].join(","), "pkexec,nimbus-anonicy,enable")
        verify(gaming.lastResult !== "")
        compare(gaming.lastError, "")
    }

    function test_ananicy_disable_goes_through_polkit() {
        fakeAnonicy.reset()
        gaming.setAnanicy(false)
        compare(fakeAnonicy.calls.length, 1)
        compare(fakeAnonicy.calls[0].join(","), "pkexec,nimbus-anonicy,disable")
    }

    function test_ananicy_status_needs_no_privileges_and_updates_state() {
        fakeAnonicy.reset()
        fakeAnonicy.stdoutText = "enabled: las reglas de rendimiento están activas.\n"
        gaming.refreshAnanicyStatus()
        compare(fakeAnonicy.calls.length, 1)
        compare(fakeAnonicy.calls[0].join(","), "nimbus-anonicy,status")
        compare(gaming.ananicyState, "enabled")
        verify(gaming.ananicyStatusText() !== "")
    }

    function test_ananicy_unknown_state_has_translated_text() {
        gaming.ananicyState = "unknown"
        verify(gaming.ananicyStatusText() !== "")
        verify(gaming.ananicyStatusText() !== "ananicyState")
    }

    function test_battery_parses_upower_dump() {
        fakeBattery.reset()
        fakeBattery.stdoutText = upowerSample
        gaming.refreshBattery()
        compare(fakeBattery.calls.length, 1)
        compare(fakeBattery.calls[0][0], "upower")
        compare(gaming.batteryLevel, 78)
        compare(gaming.batteryState, "discharging")
        verify(gaming.batteryStatusText().indexOf("78") !== -1)
    }

    function test_battery_without_battery_shows_translated_none() {
        fakeBattery.reset()
        fakeBattery.stdoutText = "Device: /org/freedesktop/UPower/devices/line_power_AC\n  native-path: AC\n  online: yes\n"
        gaming.refreshBattery()
        compare(gaming.batteryLevel, -1)
        compare(gaming.batteryStatusText(), Config.translated("settings.gaming.battery.none"))
    }

    function test_vrr_supported_shows_rate() {
        fakeVrr.reset()
        fakeVrr.stdoutText = "connector: HDMI-A-1\nvrr: supported\nrate: 144\n"
        gaming.refreshVrr()
        compare(fakeVrr.calls.length, 1)
        compare(fakeVrr.calls[0][0], "gamescope-vrr-check")
        verify(gaming.vrrSupported)
        compare(gaming.vrrRate, "144")
        verify(gaming.vrrStatusText().indexOf("144") !== -1)
    }

    function test_vrr_unsupported_has_translated_text() {
        fakeVrr.reset()
        gaming.refreshVrr()
        verify(!gaming.vrrSupported)
        compare(gaming.vrrStatusText(), Config.translated("settings.gaming.vrr.unsupported"))
    }

    function test_energy_failure_shows_translated_error() {
        fakeEnergy.reset()
        fakeEnergy.exitCode = 1
        fakeEnergy.stderrText = "boom"
        gaming.lastResult = ""
        gaming.lastError = ""
        gaming.applyProfile("economy")
        compare(gaming.lastResult, "")
        verify(gaming.lastError !== "")
        verify(gaming.lastError.indexOf("boom") !== -1)
    }

    function test_without_runners_fails_gracefully() {
        gamingAlone.lastError = ""
        gamingAlone.lastResult = ""
        gamingAlone.applyProfile("balanced")
        compare(gamingAlone.lastResult, "")
        verify(gamingAlone.lastError !== "")
        gamingAlone.refreshVrr()
        verify(gamingAlone.lastError !== "")
    }

    function test_status_texts_are_wired_in_the_view() {
        var want = ["gamingResult", "gamingBattery", "gamingVrr", "gamingAnanicy"]
        var found = ({})
        var kids = gaming.children
        for (var i = 0; i < kids.length; ++i) {
            if (kids[i].objectName !== "")
                found[kids[i].objectName] = true
        }
        for (var j = 0; j < want.length; ++j)
            verify(found[want[j]] === true, "falta el texto " + want[j])
    }
}
