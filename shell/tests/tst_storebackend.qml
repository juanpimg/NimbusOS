// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus
import "../src/Nimbus/apps/Store" as StoreApp

// Contrato del backend REAL de la Store (Task T6a): `StoreBackend` delega
// en `store_backend.py` (el mismo fichero que ejercitan los tests del
// backend) invocandolo por CLI JSON a traves de un ejecutor inyectable.
// Las lecturas se sirven desde la cache (sincronas, como espera
// `Store.qml`); escrituras y recargas viajan por `installNow`/
// `uninstallNow`/`refreshNow` y avisan con `dataChanged`/`actionFinished`.
TestCase {
    name: "StoreBackend"
    when: true

    // Doble de ejecutor: responde JSON enlatado segun la operacion pedida.
    QtObject {
        id: fakeRunner
        property var calls: []
        property bool flatpak: false
        function run(cmd) {
            calls.push(cmd)
            var op = ""
            var j = cmd.indexOf("--json")
            if (j >= 0 && j + 1 < cmd.length)
                op = cmd[j + 1]
            if (op === "list-apps")
                return {"exitCode": 0, "stdout": fakeCatalogJson(), "stderr": ""}
            if (op === "flatpak")
                return {"exitCode": 0, "stdout": flatpakJson(), "stderr": ""}
            if (op === "install" || op === "uninstall")
                return {"exitCode": 0, "stdout": "{\"ok\": true, \"message\": \"\"}", "stderr": ""}
            return {"exitCode": 1, "stdout": "", "stderr": "op desconocida"}
        }
        function reset() { calls = [] }
        function fakeCatalogJson() {
            return "[{\"id\": \"nimbus.notes\", \"title\": \"Notas\", \"category\": \"productivity\","
                + " \"origin\": \"Nativo\", \"installed\": true},"
                + " {\"id\": \"org.gimp.GIMP\", \"title\": \"GIMP\", \"category\": \"creative\","
                + " \"origin\": \"Flathub\", \"installed\": false}]"
        }
        function flatpakJson() {
            if (flatpak)
                return "{\"available\": true, \"error\": \"\"}"
            return "{\"available\": false, \"error\": \"Flatpak no disponible\"}"
        }
    }

    StoreApp.StoreBackend { id: backendOk; processRunner: fakeRunner }
    SignalSpy { id: dataSpy; target: backendOk; signalName: "dataChanged" }
    SignalSpy { id: actionSpy; target: backendOk; signalName: "actionFinished" }

    function test_refresh_loads_catalog_and_flatpak_state() {
        fakeRunner.flatpak = false
        fakeRunner.reset()
        dataSpy.clear()
        backendOk.refreshNow()
        compare(dataSpy.count, 1)
        compare(backendOk.catalog.length, 2)
        verify(!backendOk.flatpakAvailable())
        verify(backendOk.flatpakError() !== "")
    }

    function test_sync_reads_serve_from_cache_like_the_real_backend() {
        fakeRunner.flatpak = false
        backendOk.refreshNow()
        compare(backendOk.listApps("productivity").length, 1)
        compare(backendOk.listApps("desconocida").length, 0)
        compare(backendOk.search("gimp").length, 1)
        compare(backendOk.search("").length, 2)
        verify(backendOk.isInstalled("nimbus.notes"))
        verify(!backendOk.isInstalled("org.gimp.GIMP"))
        // Sin Flatpak no hay actualizaciones (igual que store_backend.py).
        compare(backendOk.listUpdates().length, 0)
    }

    function test_sync_install_of_native_app_succeeds() {
        backendOk.refreshNow()
        var result = backendOk.install("nimbus.notes")
        verify(result.ok)
    }

    function test_sync_install_of_flathub_without_flatpak_fails_honestly() {
        fakeRunner.flatpak = false
        backendOk.refreshNow()
        var result = backendOk.install("org.gimp.GIMP")
        verify(!result.ok)
        verify(result.message !== "")
    }

    function test_sync_install_of_unknown_app_fails() {
        backendOk.refreshNow()
        var result = backendOk.install("no.existe.Tal")
        verify(!result.ok)
    }

    function test_async_install_delegates_to_the_real_cli() {
        fakeRunner.flatpak = true
        backendOk.refreshNow()
        actionSpy.clear()
        backendOk.installNow("org.gimp.GIMP")
        compare(actionSpy.count, 1)
        compare(actionSpy.signalArguments[0][0], "org.gimp.GIMP")
        compare(actionSpy.signalArguments[0][1], true)
        verify(backendOk.isInstalled("org.gimp.GIMP"))
    }

    function test_async_install_without_flatpak_reports_without_exec() {
        fakeRunner.flatpak = false
        backendOk.refreshNow()
        var before = fakeRunner.calls.length
        actionSpy.clear()
        backendOk.installNow("org.gimp.GIMP")
        compare(actionSpy.count, 1)
        compare(actionSpy.signalArguments[0][1], false)
        compare(fakeRunner.calls.length, before)
    }
}
