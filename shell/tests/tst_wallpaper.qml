// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Wallpaper"
    when: true

    // NOTA: `Wallpaper` y `LockScreen` aun no estan registrados en el
    // `qmldir` (lo registra otra pista; ver informe). Se instancian por
    // ruta relativa para que el test no dependa de ese registro.
    property var picker: null
    property var locker: null

    SignalSpy { id: chosenSpy; signalName: "chosen" }
    SignalSpy { id: closedSpy; signalName: "closed" }
    SignalSpy { id: unlockSpy; signalName: "unlockRequested" }
    SignalSpy { id: sessionSpy; signalName: "sessionActionRequested" }
    SignalSpy { id: mediaSpy; signalName: "mediaRequested" }

    function initTestCase() {
        var wallpaperComponent = Qt.createComponent("../src/Nimbus/modules/Wallpaper.qml")
        verify(wallpaperComponent.status === Component.Ready, wallpaperComponent.errorString())
        picker = wallpaperComponent.createObject(this)
        verify(picker !== null)
        var lockComponent = Qt.createComponent("../src/Nimbus/modules/LockScreen.qml")
        verify(lockComponent.status === Component.Ready, lockComponent.errorString())
        locker = lockComponent.createObject(this)
        verify(locker !== null)
        chosenSpy.target = picker
        closedSpy.target = picker
        unlockSpy.target = locker
        sessionSpy.target = locker
        mediaSpy.target = locker
    }

    function samplePaths() {
        return [
            "/usr/share/nimbus/wallpapers/noche.png",
            "/usr/share/nimbus/wallpapers/noche-Light.png",
            "/usr/share/nimbus/wallpapers/dia.png"
        ]
    }

    function init() {
        picker.bundledPaths = []
        picker.folder = "~/Pictures/Wallpapers"
        picker.wallpapers = []
        picker.selected = ""
        chosenSpy.clear()
        closedSpy.clear()
        unlockSpy.clear()
        sessionSpy.clear()
        mediaSpy.clear()
        locker.lock()
        locker.trackTitle = ""
        locker.trackArtist = ""
        locker.playing = false
    }

    function test_default_folder_is_user_wallpapers() {
        compare(picker.folder, "~/Pictures/Wallpapers")
    }

    function test_light_dark_pairs_group_into_single_entry() {
        var entries = picker.groupPairs(samplePaths())
        compare(entries.length, 2)
        var noche = null
        var dia = null
        for (var i = 0; i < entries.length; ++i) {
            if (entries[i].name === "noche")
                noche = entries[i]
            if (entries[i].name === "dia")
                dia = entries[i]
        }
        verify(noche !== null)
        compare(noche.dark, "/usr/share/nimbus/wallpapers/noche.png")
        compare(noche.light, "/usr/share/nimbus/wallpapers/noche-Light.png")
        compare(noche.path, noche.dark)
        verify(dia !== null)
        compare(dia.name, "dia")
        compare(dia.dark, "/usr/share/nimbus/wallpapers/dia.png")
        compare(dia.light, "")
    }

    function test_grouping_ignores_non_image_files() {
        var entries = picker.groupPairs(["/w/a.png", "/w/notas.txt", "/w/sin-extension"])
        compare(entries.length, 1)
        compare(entries[0].name, "a")
    }

    function test_grouping_empty_input() {
        compare(picker.groupPairs([]).length, 0)
        compare(picker.groupPairs(undefined).length, 0)
    }

    function test_entries_from_injected_directory() {
        var entries = picker.entriesFromDirectory("/tmp/nimbus-walls-test", ["a.png", "a-Light.png", "b.jpg"])
        compare(entries.length, 2)
        var a = null
        for (var i = 0; i < entries.length; ++i) {
            if (entries[i].name === "a")
                a = entries[i]
        }
        verify(a !== null)
        compare(a.dark, "/tmp/nimbus-walls-test/a.png")
        compare(a.light, "/tmp/nimbus-walls-test/a-Light.png")
    }

    function test_choose_emits_chosen_and_selects() {
        picker.wallpapers = picker.groupPairs(samplePaths())
        chosenSpy.clear()
        verify(picker.choose("/usr/share/nimbus/wallpapers/dia.png"))
        compare(picker.selected, "/usr/share/nimbus/wallpapers/dia.png")
        compare(chosenSpy.count, 1)
        compare(chosenSpy.signalArguments[0][0], "/usr/share/nimbus/wallpapers/dia.png")
    }

    function test_choose_unknown_path_emits_nothing() {
        picker.wallpapers = picker.groupPairs(samplePaths())
        chosenSpy.clear()
        verify(!picker.choose("/no/existe.png"))
        compare(chosenSpy.count, 0)
    }

    function test_close_emits_closed() {
        picker.close()
        compare(closedSpy.count, 1)
    }

    function test_next_prev_cycle_and_emit() {
        picker.wallpapers = picker.groupPairs(samplePaths())
        // Ordenados por nombre: dia, noche.
        picker.choose(picker.wallpapers[0].path)
        chosenSpy.clear()
        var second = picker.next()
        compare(second, picker.wallpapers[1].path)
        compare(picker.selected, second)
        compare(chosenSpy.count, 1)
        var wrapped = picker.next()
        compare(wrapped, picker.wallpapers[0].path)
        var back = picker.prev()
        compare(back, picker.wallpapers[1].path)
    }

    function test_next_prev_on_empty_list_are_safe() {
        picker.wallpapers = []
        compare(picker.next(), "")
        compare(picker.prev(), "")
        compare(chosenSpy.count, 0)
    }

    function test_preferred_variant_by_mode() {
        var entries = picker.groupPairs(samplePaths())
        var noche = entries[1] // Ordenado: dia, noche.
        compare(noche.name, "noche")
        compare(picker.preferredPath(noche, "dark"), noche.dark)
        compare(picker.preferredPath(noche, "light"), noche.light)
        var dia = entries[0]
        compare(picker.preferredPath(dia, "light"), dia.dark)
    }

    function test_refresh_merges_bundled_and_user_folder() {
        picker.folder = "/tmp/nimbus-walls-test"
        var count = picker.refresh(["/usr/share/nimbus/wallpapers/noche.png"], ["dia.png", "dia-Light.png"])
        compare(count, 2)
        compare(picker.wallpapers.length, 2)
        verify(picker.selected !== "")
    }

    function test_lockscreen_starts_locked_and_idle() {
        verify(locker.locked)
        verify(!locker.busy)
        verify(!locker.passwordWrong)
    }

    function test_attempt_unlock_emits_and_discards_password() {
        locker.passwordText = "s3cr3t"
        unlockSpy.clear()
        verify(locker.attemptUnlock())
        compare(unlockSpy.count, 1)
        compare(unlockSpy.signalArguments[0][0], "s3cr3t")
        verify(locker.busy)
        // La contrasena se emite y se descarta: no queda en ninguna property.
        compare(locker.passwordText, "")
        verify(locker.password === undefined)
    }

    function test_attempt_unlock_with_argument_does_not_retain() {
        verify(locker.attemptUnlock("otra-clave"))
        compare(unlockSpy.count, 1)
        compare(unlockSpy.signalArguments[0][0], "otra-clave")
        compare(locker.passwordText, "")
        verify(locker.password === undefined)
    }

    function test_attempt_unlock_empty_does_not_emit() {
        locker.passwordText = ""
        verify(!locker.attemptUnlock(""))
        compare(unlockSpy.count, 0)
        verify(!locker.busy)
    }

    function test_auth_failure_keeps_locked_and_shows_error() {
        locker.attemptUnlock("mal")
        locker.reportAuthResult(false)
        verify(locker.passwordWrong)
        verify(locker.locked)
        verify(!locker.busy)
        verify(locker.authError !== "")
    }

    function test_auth_success_unlocks_and_clears_error() {
        locker.attemptUnlock("bien")
        verify(locker.reportAuthResult(true))
        verify(!locker.locked)
        verify(!locker.passwordWrong)
        verify(!locker.busy)
        compare(locker.authError, "")
    }

    function test_session_actions_are_validated() {
        verify(locker.requestSessionAction("suspend"))
        compare(sessionSpy.count, 1)
        compare(sessionSpy.signalArguments[0][0], "suspend")
        verify(!locker.requestSessionAction("nuke"))
        compare(sessionSpy.count, 1)
        var valid = ["lock", "suspend", "logout", "reboot", "shutdown"]
        for (var i = 0; i < valid.length; ++i)
            verify(locker.requestSessionAction(valid[i]))
        compare(sessionSpy.count, 1 + valid.length)
    }

    function test_media_actions_are_validated() {
        verify(locker.requestMedia("playpause"))
        compare(mediaSpy.count, 1)
        compare(mediaSpy.signalArguments[0][0], "playpause")
        verify(!locker.requestMedia("subir-volumen"))
        compare(mediaSpy.count, 1)
    }

    function test_now_playing_injection() {
        locker.updateNowPlaying({ "title": "Tema", "artist": "Grupo", "playing": true })
        compare(locker.trackTitle, "Tema")
        compare(locker.trackArtist, "Grupo")
        verify(locker.playing)
    }

    function test_clock_sets_time_and_date() {
        locker.updateClock(new Date(2026, 9, 21, 9, 5, 0))
        verify(locker.time !== "")
        verify(locker.date !== "")
    }
}
