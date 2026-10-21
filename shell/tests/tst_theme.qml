// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Theme"
    when: true

    function init() {
        Theme.setMode("light")
        Theme.setAccent("#007AFF")
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
        compare(Theme.barHeight, 28)
        compare(Theme.dockSize, 64)
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

    function test_glass_has_opaque_fallback() {
        Theme.setMode("light")
        verify(Theme.glassOpaque.a === 1.0, "glassOpaque debe ser totalmente opaco")
        Theme.setMode("dark")
        verify(Theme.glassOpaque.a === 1.0, "glassOpaque debe ser totalmente opaco")
    }
}
