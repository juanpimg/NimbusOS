// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Theme"
    when: true

    function init() {
        Theme.setMode("light")
        Theme.resetAccent()
    }

    function test_light_defaults() {
        compare(Theme.background, "#f5f5f7")
        compare(Theme.surface, "#ffffff")
        compare(Theme.surfaceAlt, "#ececee")
        compare(Theme.text, "#1d1d1f")
        compare(Theme.textMuted, "#6e6e73")
        compare(Theme.separator, "#d2d2d7")
        compare(Theme.accent, "#007aff")
        compare(Theme.radius, 12)
        compare(Theme.spacing, 8)
        compare(Theme.barHeight, 24)
        compare(Theme.dockSize, 86)
        compare(Theme.fontFamily, "Inter")
    }

    function test_dark_mode() {
        Theme.setMode("dark")
        compare(Theme.background, "#1c1c1e")
        compare(Theme.surface, "#2c2c2e")
        compare(Theme.surfaceAlt, "#3a3a3c")
        compare(Theme.text, "#f5f5f7")
        compare(Theme.textMuted, "#98989d")
        compare(Theme.separator, "#38383a")
        compare(Theme.accent, "#0a84ff")
        compare(Theme.dark, true)
    }

    function test_accent_is_overridable() {
        Theme.setAccent("#ff2d55")
        compare(Theme.accent, "#ff2d55")
    }

    function test_user_accent_applies_in_dark_mode() {
        Theme.setAccent("#ff2d55")
        compare(Theme.accent, "#ff2d55")
        Theme.setMode("dark")
        compare(Theme.accent, "#ff2d55")
        Theme.resetAccent()
        compare(Theme.accent, "#0a84ff")
        Theme.setMode("light")
        compare(Theme.accent, "#007aff")
    }

    function test_ignores_invalid_mode() {
        Theme.setMode("light")
        Theme.setMode("bogus")
        verify(!Theme.dark)
        Theme.setMode("dark")
        Theme.setMode("bogus")
        verify(Theme.dark)
    }

    function test_glass_has_opaque_fallback() {
        Theme.setMode("light")
        compare(Theme.glass, "#80ffffff")
        verify(Theme.glassOpaque.a === 1.0, "glassOpaque debe ser totalmente opaco")
        Theme.setMode("dark")
        compare(Theme.glass, "#8c1c1c1e")
        verify(Theme.glassOpaque.a === 1.0, "glassOpaque debe ser totalmente opaco")
    }

    function test_m4_bar_and_dock_tokens() {
        // La barra y el Dock no usan numeros sueltos: todo sale de Theme
        // (medidas macOS verificadas: barra 24, franja Dock 86/icono 60).
        compare(Theme.fontSizeSmall, 11)
        compare(Theme.fontSizeBody, 13)
        compare(Theme.fontSizeTitle, 15)
        compare(Theme.dockRadius, 12)
        compare(Theme.dockIconRadius, 10)
        compare(Theme.dockIconSize, 60)
        compare(Theme.runningDotSize, 5)
        compare(Theme.dockMagnify, 1.6)
        compare(Theme.menuWidth, 280)
        verify(Theme.disabledOpacity > 0.0 && Theme.disabledOpacity < 1.0)
        compare(Theme.shadowOffsetY, 4)
        compare(Theme.shadowRadius, 24)
        verify(Theme.shadowBlur > 0.0 && Theme.shadowBlur <= 1.0)
        verify(Theme.shadow.a > 0.0, "la sombra debe ser semitransparente")
        verify(Theme.hairline.a > 0.0 && Theme.hairline.a < 1.0, "hairline debe ser sutil")
        verify(Theme.appBlue.a === 1.0 && Theme.appGreen.a === 1.0)
        verify(Theme.appOrange.a === 1.0 && Theme.appPurple.a === 1.0)
        verify(Theme.appRed.a === 1.0 && Theme.appGray.a === 1.0)
    }
}
