// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "ControlCenter"
    when: true

    ControlCenter { id: cc }

    SignalSpy { id: airplaneSpy; target: cc; signalName: "airplaneToggled" }
    SignalSpy { id: powerSpy; target: cc; signalName: "powerProfileChanged" }
    SignalSpy { id: themeSpy; target: cc; signalName: "themeModeChanged" }
    SignalSpy { id: accentSpy; target: cc; signalName: "accentChanged" }
    SignalSpy { id: sessionSpy; target: cc; signalName: "sessionActionRequested" }
    SignalSpy { id: volumeSpy; target: cc; signalName: "volumeChanged" }
    SignalSpy { id: brightnessSpy; target: cc; signalName: "brightnessChanged" }

    function init() {
        Config.setLocale("es")
        Config.setMode("light")
        Config.setAccent("#007AFF")
        cc.setVolume(50)
        cc.setBrightness("80")
        cc.setMicrophoneMuted(false)
        cc.setAirplaneMode(false)
        cc.setPowerProfile("balanced")
        cc.wifiOn = true
        airplaneSpy.clear()
        powerSpy.clear()
        themeSpy.clear()
        accentSpy.clear()
        sessionSpy.clear()
        volumeSpy.clear()
        brightnessSpy.clear()
    }

    function cleanup() {
        Config.setLocale("es")
        Config.setMode("light")
        Config.setAccent("#007AFF")
    }

    function test_opens_at_a_fixed_24px_margin() {
        // El panel se monta arriba a la derecha, a 24 px del borde.
        compare(cc.edgeMargin, 24)
        compare(cc.anchorCorner, "topRight")
        compare(Theme.popupOffset, 24)
    }

    function test_sections_follow_the_spec_order() {
        var ids = cc.sectionIds()
        compare(ids.join(","), "network,bluetooth,audio,brightness,theme,accent,power,session")
        var sections = cc.sections()
        compare(sections.length, 8)
        for (var i = 0; i < ids.length; i++)
            compare(sections[i].id, ids[i])
    }

    function test_section_titles_come_from_translated() {
        var sections = cc.sections()
        for (var i = 0; i < sections.length; i++) {
            var id = sections[i].id
            compare(sections[i].title, Config.translated("cc." + id + ".title"),
                    "titulo sin pasar por Config.translated: " + id)
        }
    }

    function test_section_titles_follow_the_locale() {
        Config.setLocale("en")
        compare(cc.sectionTitle("theme"), Config.translated("cc.theme.title"))
        Config.setLocale("es")
        compare(cc.sectionTitle("theme"), Config.translated("cc.theme.title"))
    }

    function test_control_enabled_logic() {
        // Sin servicio -> deshabilitado. Tema, acento, energia y sesion
        // no dependen de ningun servicio: siempre habilitados.
        verify(!cc.controlEnabled("network", false))
        verify(cc.controlEnabled("network", true))
        verify(!cc.controlEnabled("bluetooth", false))
        verify(cc.controlEnabled("bluetooth", true))
        verify(!cc.controlEnabled("audio", false))
        verify(cc.controlEnabled("audio", true))
        verify(!cc.controlEnabled("brightness", false))
        verify(cc.controlEnabled("brightness", true))
        verify(cc.controlEnabled("theme", false))
        verify(cc.controlEnabled("accent", false))
        verify(cc.controlEnabled("power", false))
        verify(cc.controlEnabled("session", false))
        verify(!cc.controlEnabled("bogus", true))
    }

    function test_disabled_control_keeps_its_visible_label() {
        // A diferencia de la barra (lo ausente se esconde), aqui la
        // ausencia se explica: deshabilitado, nunca roto ni oculto.
        var off = cc.controlState("bluetooth", false)
        verify(!off.enabled)
        verify(off.label !== "")
        compare(off.label, Config.translated("cc.bluetooth.title"))
        var on = cc.controlState("bluetooth", true)
        verify(on.enabled)
        verify(on.label !== "")
    }

    function test_theme_change_applies_hot_through_config() {
        cc.setThemeMode("dark")
        compare(Config.mode, "dark")
        verify(Theme.dark)
        compare(themeSpy.count, 1)
        cc.setThemeMode("light")
        compare(Config.mode, "light")
        verify(!Theme.dark)
    }

    function test_accent_change_applies_hot_through_config() {
        cc.setAccent("#FF2D55")
        compare(Config.accent, "ff2d55")
        compare(Theme.accent, "#ff2d55")
        compare(accentSpy.count, 1)
    }

    function test_invalid_theme_mode_is_ignored() {
        cc.setThemeMode("bogus")
        compare(Config.mode, "light")
        verify(!Theme.dark)
        compare(themeSpy.count, 0)
    }

    function test_invalid_power_profile_is_ignored() {
        cc.setPowerProfile("turbo")
        compare(cc.powerProfile, "balanced")
        compare(powerSpy.count, 0)
    }

    function test_airplane_toggle_emits() {
        cc.setAirplaneMode(true)
        compare(airplaneSpy.count, 1)
        compare(airplaneSpy.signalArguments[0][0], true)
        verify(cc.airplaneMode)
        cc.setAirplaneMode(false)
        compare(airplaneSpy.count, 2)
        compare(airplaneSpy.signalArguments[1][0], false)
    }

    function test_power_profile_change_emits() {
        cc.setPowerProfile("performance")
        compare(cc.powerProfile, "performance")
        compare(powerSpy.count, 1)
    }

    function test_power_profile_table() {
        compare(cc.powerProfiles().join(","), "economy,balanced,performance")
    }

    function test_session_actions_emit_in_order() {
        var actions = cc.sessionActions()
        compare(actions.join(","), "lock,suspend,logout,reboot,shutdown")
        for (var i = 0; i < actions.length; i++) {
            cc.requestSessionAction(actions[i])
            compare(sessionSpy.count, i + 1)
            compare(sessionSpy.signalArguments[i][0], actions[i])
        }
    }

    function test_unknown_session_action_is_ignored() {
        cc.requestSessionAction("warp")
        compare(sessionSpy.count, 0)
    }

    function test_volume_is_clamped() {
        cc.setVolume(200)
        compare(cc.volume, 100)
        cc.setVolume(-5)
        compare(cc.volume, 0)
        cc.setVolume(70)
        compare(cc.volume, 70)
        verify(volumeSpy.count > 0)
    }

    function test_brightness_value_signal() {
        cc.setBrightness("60")
        compare(cc.brightness, "60")
        compare(brightnessSpy.count, 1)
    }

    function test_microphone_mute_flips() {
        cc.setMicrophoneMuted(true)
        verify(cc.microphoneMuted)
        cc.setMicrophoneMuted(false)
        verify(!cc.microphoneMuted)
    }
}
