// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "ShellController"
    when: true

    function init() {
        ShellController.closeAll()
    }

    function test_only_one_surface_can_be_open() {
        ShellController.open("dock")
        ShellController.open("spotlight")
        verify(!ShellController.dockOpen, "el dock debe cerrarse al abrir el spotlight")
        verify(ShellController.spotlightOpen)
    }

    function test_toggle_flips_the_surface() {
        ShellController.closeAll()
        ShellController.toggle("spotlight")
        verify(ShellController.spotlightOpen)
        ShellController.toggle("spotlight")
        verify(!ShellController.spotlightOpen)
    }

    function test_open_sets_active_surface() {
        ShellController.open("dock")
        compare(ShellController.activeSurface, "dock")
        verify(ShellController.dockOpen)
    }

    function test_close_clears_active_surface() {
        ShellController.open("controlcenter")
        ShellController.close("controlcenter")
        verify(!ShellController.controlCenterOpen)
        compare(ShellController.activeSurface, "")
    }

    function test_close_all_closes_everything() {
        ShellController.open("dock")
        ShellController.open("notifications")
        ShellController.closeAll()
        verify(!ShellController.dockOpen)
        verify(!ShellController.spotlightOpen)
        verify(!ShellController.controlCenterOpen)
        verify(!ShellController.switcherOpen)
        verify(!ShellController.quickLookOpen)
        verify(!ShellController.wallpaperOpen)
        verify(!ShellController.notificationsOpen)
        compare(ShellController.activeSurface, "")
    }
}
