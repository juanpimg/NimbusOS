// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus
import "../src/Nimbus/modules" as Capture

// Capturas (region/ventana/pantalla) y QuickLook (previsualizacion con
// la barra espaciadora).
//
// Nota de alcance: lo que depende de FloatingWindow o de ejecutar las
// herramientas reales (grim/slurp/hyprshot) vive en los .qml y se
// documenta alli como no testeado aqui. El runner de captura se inyecta
// (`runner`) para poder simular fallos de `grim` sin compositor.
TestCase {
    name: "Capture"
    when: true

    Capture.Screenshot { id: shotProbe }
    Capture.QuickLook { id: lookProbe }

    SignalSpy { id: capturedSpy; target: shotProbe; signalName: "captured" }
    SignalSpy { id: cancelledSpy; target: shotProbe; signalName: "cancelled" }
    SignalSpy { id: closedSpy; target: lookProbe; signalName: "closed" }

    function init() {
        shotProbe.mode = "region"
        shotProbe.shown = false
        shotProbe.visible = false
        shotProbe.savedPath = ""
        shotProbe.error = ""
        shotProbe.runner = null
        lookProbe.shown = false
        lookProbe.visible = false
        lookProbe.path = ""
        capturedSpy.clear()
        cancelledSpy.clear()
        closedSpy.clear()
    }

    // --- Screenshot: valores por defecto ---

    function test_default_mode_is_region() {
        compare(shotProbe.mode, "region")
    }

    function test_save_dir_defaults_to_screenshots() {
        verify(shotProbe.saveDir.indexOf("Screenshots") !== -1)
    }

    function test_request_rejects_unknown_mode() {
        verify(!shotProbe.request("panoramica"))
        compare(shotProbe.mode, "region")
    }

    // --- Screenshot: comando por modo ---

    function test_region_uses_grim_plus_slurp() {
        var cmd = shotProbe.commandFor("region", "/tmp/nimbus-region.png")
        verify(cmd.indexOf("grim") !== -1, "region usa grim: " + cmd)
        verify(cmd.indexOf("slurp") !== -1, "region usa slurp: " + cmd)
        verify(cmd.indexOf("/tmp/nimbus-region.png") !== -1)
    }

    function test_screen_uses_grim_without_slurp() {
        var cmd = shotProbe.commandFor("screen", "/tmp/nimbus-screen.png")
        verify(cmd.indexOf("grim") !== -1, "pantalla usa grim: " + cmd)
        verify(cmd.indexOf("slurp") === -1, "pantalla no usa slurp: " + cmd)
    }

    function test_window_uses_hyprland_tool() {
        var cmd = shotProbe.commandFor("window", "/tmp/nimbus-window.png")
        verify(cmd.indexOf("hyprshot") !== -1, "ventana usa la herramienta de Hyprland: " + cmd)
    }

    // --- Screenshot: fallo limpio ---

    function test_grim_throwing_fails_cleanly() {
        shotProbe.request("region")
        verify(shotProbe.shown)
        shotProbe.runner = function (cmd, out) { throw "grim: no se pudo abrir el display" }
        shotProbe.capture()
        verify(shotProbe.error !== "", "el fallo deja un mensaje accionable")
        verify(!shotProbe.shown)
        verify(!shotProbe.visible)
        compare(capturedSpy.count, 0)
    }

    function test_grim_returning_false_fails_cleanly() {
        shotProbe.request("screen")
        shotProbe.runner = function (cmd, out) { return false }
        shotProbe.capture()
        verify(shotProbe.error !== "")
        verify(!shotProbe.shown)
        verify(!shotProbe.visible)
        compare(capturedSpy.count, 0)
    }

    function test_capture_without_runner_fails_cleanly() {
        shotProbe.request("region")
        shotProbe.runner = null
        shotProbe.capture()
        verify(shotProbe.error !== "")
        verify(!shotProbe.shown)
        verify(!shotProbe.visible)
    }

    function test_success_saves_and_signals() {
        shotProbe.request("region")
        shotProbe.runner = function (cmd, out) { return true }
        shotProbe.capture()
        compare(shotProbe.error, "")
        verify(!shotProbe.shown)
        verify(!shotProbe.visible)
        verify(shotProbe.savedPath.indexOf(".png") !== -1)
        compare(capturedSpy.count, 1)
        compare(capturedSpy.signalArguments[0][0], shotProbe.savedPath)
    }

    function test_cancel_emits_cancelled() {
        shotProbe.request("screen")
        verify(shotProbe.shown)
        shotProbe.cancel()
        verify(!shotProbe.shown)
        verify(!shotProbe.visible)
        compare(cancelledSpy.count, 1)
    }

    function test_ipc_screenshot_dispatch_sets_mode() {
        Ipc.call("screenshot", "screen")
        compare(Ipc.lastFunction, "screen")
        compare(shotProbe.mode, "screen")
        Ipc.call("screenshot", "region")
        compare(shotProbe.mode, "region")
    }

    // --- QuickLook: deduccion del kind ---

    function test_kind_image() {
        compare(lookProbe.kindForPath("/tmp/foto.png"), "image")
        compare(lookProbe.kindForPath("/tmp/FOTO.JPG"), "image")
        compare(lookProbe.kindForPath("/tmp/animacion.webp"), "image")
    }

    function test_kind_pdf() {
        compare(lookProbe.kindForPath("/tmp/Informe.PDF"), "pdf")
    }

    function test_kind_text() {
        compare(lookProbe.kindForPath("/tmp/notas.txt"), "text")
        compare(lookProbe.kindForPath("/tmp/README.md"), "text")
    }

    function test_kind_unknown() {
        compare(lookProbe.kindForPath("/tmp/programa.bin"), "unknown")
        compare(lookProbe.kindForPath("/tmp/sin-extension"), "unknown")
        compare(lookProbe.kindForPath(""), "unknown")
    }

    function test_first_lines_trims() {
        compare(lookProbe.firstLines("una\ndos\ntres\ncuatro", 2), "una\ndos")
        compare(lookProbe.firstLines("solo una", 10), "solo una")
        compare(lookProbe.firstLines("", 5), "")
    }

    function test_open_sets_title_kind_and_shows() {
        verify(lookProbe.open("/tmp/Informe.PDF"))
        compare(lookProbe.kind, "pdf")
        compare(lookProbe.title, "Informe.PDF")
        verify(lookProbe.shown)
    }

    function test_open_rejects_empty_path() {
        verify(!lookProbe.open(""))
        verify(!lookProbe.shown)
    }

    function test_space_opens_and_escape_closes() {
        verify(lookProbe.handleKey(Qt.Key_Space, "/tmp/foto.png"))
        verify(lookProbe.shown)
        compare(lookProbe.kind, "image")
        verify(lookProbe.handleKey(Qt.Key_Escape, ""))
        verify(!lookProbe.shown)
        verify(!lookProbe.visible)
        compare(closedSpy.count, 1)
    }

    function test_close_emits_closed() {
        lookProbe.open("/tmp/notas.txt")
        closedSpy.clear()
        lookProbe.close()
        verify(!lookProbe.shown)
        verify(!lookProbe.visible)
        compare(closedSpy.count, 1)
    }

    function test_ipc_quicklook_open_shows() {
        Ipc.call("quicklook", "open")
        verify(lookProbe.shown)
        lookProbe.close()
    }
}
