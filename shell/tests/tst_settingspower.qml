// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus
import "../src/Nimbus/apps/Settings" as SettingsApp

// Contrato de Ajustes->Energia (Task T6b): los botones no solo mutan QML,
// llaman a `nimbus-energy` de verdad a traves de un `Process` (T3) con
// patron pkexec, y muestran el resultado (perfil aplicado, error, etc.)
// con texto traducido. `energyRunner` inyectable; sin el, fallo con
// mensaje (nunca silencioso, nunca inventado).
TestCase {
    name: "SettingsPowerExec"
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

    SettingsApp.SettingsPower { id: powerOk; energyRunner: fakeEnergy }
    SettingsApp.SettingsPower { id: powerAlone }

    function test_apply_profile_calls_nimbus_energy_privileged() {
        fakeEnergy.reset()
        powerOk.lastResult = ""
        powerOk.lastError = ""
        powerOk.applyProfile("performance")
        compare(powerOk.profile, "performance")
        compare(fakeEnergy.calls.length, 1)
        compare(fakeEnergy.calls[0].join(","), "pkexec,nimbus-energy,profile,set,performance")
        verify(powerOk.lastResult !== "")
        compare(powerOk.lastError, "")
    }

    function test_apply_charge_limit_calls_nimbus_energy() {
        fakeEnergy.reset()
        powerOk.applyChargeLimit(80)
        compare(fakeEnergy.calls.length, 1)
        compare(fakeEnergy.calls[0].join(","), "pkexec,nimbus-energy,charge-limit,set,80")
        verify(powerOk.lastResult !== "")
    }

    function test_apply_graphics_mode_calls_nimbus_energy() {
        fakeEnergy.reset()
        powerOk.applyGraphicsMode("always")
        compare(powerOk.graphicsMode, "always")
        compare(fakeEnergy.calls.length, 1)
        compare(fakeEnergy.calls[0].join(","), "pkexec,nimbus-energy,gpu,set,always")
    }

    function test_energy_failure_shows_translated_error() {
        fakeEnergy.reset()
        fakeEnergy.exitCode = 1
        fakeEnergy.stderrText = "boom"
        powerOk.lastResult = ""
        powerOk.lastError = ""
        powerOk.applyProfile("economy")
        compare(powerOk.lastResult, "")
        verify(powerOk.lastError !== "")
        verify(powerOk.lastError.indexOf("boom") !== -1)
    }

    function test_without_runner_fails_gracefully() {
        powerAlone.lastError = ""
        powerAlone.lastResult = ""
        powerAlone.applyProfile("balanced")
        compare(powerAlone.lastResult, "")
        verify(powerAlone.lastError !== "")
    }

    function test_result_line_is_wired_in_the_view() {
        // La ultima Text visible de la pagina muestra resultado o error.
        var found = false
        var kids = powerOk.children
        for (var i = 0; i < kids.length; ++i) {
            if (kids[i].objectName === "energyResult") {
                found = true
                break
            }
        }
        verify(found)
    }
}
