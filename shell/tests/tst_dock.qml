// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Dock"
    when: true

    Dock {
        id: dockProbe
        favorites: [
            { "id": "files", "name": "Archivos", "icon": "files" },
            { "id": "store", "name": "Store", "icon": "store" },
            { "id": "settings", "name": "Ajustes", "icon": "settings" }
        ]
        running: ["store"]
        badgeCounts: { "store": 3 }
    }

    Dock { id: emptyProbe }

    DockItem { id: itemProbe }

    SignalSpy { id: activatedSpy; target: dockProbe; signalName: "appActivated" }
    SignalSpy { id: contextSpy; target: dockProbe; signalName: "appContextRequested" }
    SignalSpy { id: itemActivatedSpy; target: itemProbe; signalName: "activated" }
    SignalSpy { id: itemContextSpy; target: itemProbe; signalName: "contextRequested" }

    function test_defaults() {
        compare(emptyProbe.autoHide, false)
        compare(emptyProbe.magnification, 1.6)
        compare(emptyProbe.magnification, Theme.dockMagnify)
        compare(emptyProbe.hoverX, -1)
        verify(!emptyProbe.cursorOnDock)
        verify(!emptyProbe.cursorOnWindow)
    }

    function test_data_comes_from_properties() {
        compare(dockProbe.favorites.length, 3)
        compare(dockProbe.itemCount, 4)
        compare(dockProbe.trashIndex, 3)
        compare(dockProbe.trashId, "trash")
    }

    function test_magnified_scale_is_docksize_times_magnification() {
        var center = dockProbe.itemCenterX(1)
        var peak = dockProbe.itemSize(1, center)
        fuzzyCompare(peak, Theme.dockIconSize * dockProbe.magnification, 0.001)
    }

    function test_far_items_stay_at_base_size() {
        var far = dockProbe.itemSize(0, dockProbe.itemCenterX(2) + dockProbe.cellWidth * 10)
        fuzzyCompare(far, Theme.dockIconSize, 0.001)
        var none = dockProbe.itemSize(0, -1)
        fuzzyCompare(none, Theme.dockIconSize, 0.001)
    }

    function test_magnification_is_continuous_not_a_step() {
        // Sin cursor sobre el item 2, barre el cursor en pasos de 1px y
        // exige que ningun paso salte: un escalon se notaria mucho.
        // (El barrrido usa x >= 0: hoverX == -1 es el centinela de "sin
        // cursor" que pone el tracker al salir, no una posicion real.)
        var c = dockProbe.itemCenterX(2)
        var y0 = c - dockProbe.cellWidth * 2
        var y1 = c + dockProbe.cellWidth * 2
        var prev = dockProbe.scaleForIndex(2, y0)
        for (var x = y0 + 1; x <= y1; x += 1) {
            var s = dockProbe.scaleForIndex(2, x)
            verify(Math.abs(s - prev) < 0.02, "salto en la escala en x=" + x + ": " + prev + " -> " + s)
            prev = s
        }
        // Y el punto medio queda estrictamente entre base y pico.
        var mid = dockProbe.scaleForIndex(2, c + dockProbe.cellWidth * 0.5)
        verify(mid > 1.0 && mid < dockProbe.magnification)
    }

    function test_badge_hidden_when_zero() {
        itemProbe.badgeCount = 0
        verify(!itemProbe.badgeVisible())
        itemProbe.badgeCount = 5
        verify(itemProbe.badgeVisible())
        compare(itemProbe.badgeText(), "5")
        itemProbe.badgeCount = 0
    }

    function test_trash_separator_is_at_the_end() {
        verify(dockProbe.isTrashIndex(dockProbe.trashIndex))
        verify(dockProbe.separatorBefore(dockProbe.trashIndex))
        verify(!dockProbe.separatorBefore(0))
        verify(!dockProbe.separatorBefore(1))
        compare(dockProbe.itemKind(dockProbe.trashIndex), "trash")
        compare(dockProbe.itemKind(0), "app")
        compare(dockProbe.appIdAt(dockProbe.trashIndex), "trash")
        compare(dockProbe.appIdAt(0), "files")
    }

    function test_running_and_badge_state() {
        verify(dockProbe.isRunning("store"))
        verify(!dockProbe.isRunning("files"))
        verify(!dockProbe.isRunning("trash"))
        compare(dockProbe.badgeFor("store"), 3)
        compare(dockProbe.badgeFor("files"), 0)
        compare(dockProbe.badgeFor("unknown-id"), 0)
    }

    function test_activate_emits_app_id() {
        activatedSpy.clear()
        dockProbe.activate(0)
        compare(activatedSpy.count, 1)
        compare(activatedSpy.signalArguments[0][0], "files")
    }

    function test_context_request_emits_app_id() {
        contextSpy.clear()
        dockProbe.requestContext(1)
        compare(contextSpy.count, 1)
        compare(contextSpy.signalArguments[0][0], "store")
    }

    function test_autohide_defaults_to_always_visible() {
        verify(!emptyProbe.autoHide)
        verify(emptyProbe.shouldShow)
    }

    function test_autohide_hides_only_when_cursor_is_away() {
        emptyProbe.autoHide = true
        emptyProbe.cursorOnDock = false
        emptyProbe.cursorOnWindow = false
        verify(!emptyProbe.shouldShow)
        emptyProbe.cursorOnDock = true
        verify(emptyProbe.shouldShow)
        emptyProbe.cursorOnDock = false
        emptyProbe.cursorOnWindow = true
        verify(emptyProbe.shouldShow)
        emptyProbe.autoHide = false
        emptyProbe.cursorOnWindow = false
        verify(emptyProbe.shouldShow)
    }

    function test_dockitem_contract() {
        compare(itemProbe.appId, "")
        compare(itemProbe.icon, "")
        compare(itemProbe.label, "")
        verify(!itemProbe.running)
        compare(itemProbe.badgeCount, 0)
        verify(!itemProbe.magnified)
        fuzzyCompare(itemProbe.itemScale, 1.0, 0.001)
    }

    function test_dockitem_click_emits_signals() {
        // Sin ventana no hay entrega de eventos de raton (los hijos de
        // TestCase leen visible=false en este Qt), asi que se prueba
        // `press()`: el MouseArea real lo llama con el boton pulsado.
        itemActivatedSpy.clear()
        itemProbe.press(Qt.LeftButton)
        compare(itemActivatedSpy.count, 1)
        itemContextSpy.clear()
        itemProbe.press(Qt.RightButton)
        compare(itemContextSpy.count, 1)
    }
}
