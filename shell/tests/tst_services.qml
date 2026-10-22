// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

// Contrato del cableado real de servicios (Task T4): `probeServices()`
// intenta conectar DE VERDAD con cada backend de Quickshell 0.3.2 y deja
// constancia por servicio (`ready` / `unavailable` / `missing-module`).
// `false`/`unknown` tras el probe es "mirado y ausente" (legitimo), nunca
// el valor por defecto sin mirar (`unprobed`).
TestCase {
    name: "ServicesProbe"
    when: true

    readonly property var expectedServices: ["notifications", "statusnotifier", "mpris", "upower", "network", "bluetooth"]

    function test_service_names_are_the_documented_ones() {
        compare(Services.serviceNames.join(","), expectedServices.join(","))
    }

    function test_state_domains_match_the_settings_keys() {
        compare(Services.networkStates.join(","), "unknown,connected,disconnected")
        compare(Services.bluetoothStates.join(","), "unknown,on,off")
    }

    function test_unknown_service_name_never_throws() {
        compare(Services.serviceState("noexiste"), "unknown-service")
    }

    function test_probe_marks_attempt_and_resolves_every_service() {
        Services.probeServices()
        verify(Services.probeAttempted)
        for (var i = 0; i < expectedServices.length; ++i) {
            var st = Services.serviceState(expectedServices[i])
            verify(st === "ready" || st === "unavailable" || st === "missing-module",
                   expectedServices[i] + " quedo en " + st)
        }
    }

    function test_probe_result_is_consistent_with_the_environment() {
        Services.probeServices()
        if (!Services.quickshellPresent) {
            // Sin Quickshell instalado: todo "missing-module" y los planos
            // intactos (ausencia legitima, ningun dato inventado).
            for (var i = 0; i < expectedServices.length; ++i)
                compare(Services.serviceState(expectedServices[i]), "missing-module")
            verify(!Services.notificationsAvailable)
            verify(!Services.statusNotifierAvailable)
            verify(!Services.mprisAvailable)
            verify(!Services.upowerAvailable)
            compare(Services.networkState, "unknown")
            compare(Services.bluetoothState, "unknown")
            verify(!Services.batteryPresent)
        } else {
            // Con Quickshell: al menos un backend real responde.
            var seen = false
            for (var j = 0; j < expectedServices.length; ++j) {
                if (Services.serviceState(expectedServices[j]) === "ready")
                    seen = true
            }
            verify(seen, "quickshell presente pero ningun servicio ready")
        }
    }
}
