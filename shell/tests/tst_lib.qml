// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Lib"
    when: true

    Glass { id: glassProbe }
    Glass { id: glassOpaqueProbe; translucent: false }
    Popup { id: popupProbe }
    Icon { id: iconProbe }
    Button { id: buttonProbe }
    Toggle { id: toggleProbe }
    Slider { id: sliderProbe }
    SearchField { id: fieldProbe }
    ListRow { id: rowProbe }
    SectionHeader { id: headerProbe }
    Tooltip { id: tooltipProbe }

    SignalSpy { id: toggledSpy; target: toggleProbe; signalName: "toggled" }
    SignalSpy { id: movedSpy; target: sliderProbe; signalName: "moved" }

    function test_theme_fixed_values() {
        compare(Theme.barHeight, 28)
        compare(Theme.dockSize, 64)
        compare(Theme.radius, 12)
        compare(Theme.spacing, 8)
    }

    function test_theme_animation_and_surface_tokens() {
        compare(Theme.animStandard, 150)
        compare(Theme.animSurface, 200)
        compare(Theme.dockMagnify, 1.25)
        compare(Theme.popupOffset, 24)
        compare(Theme.spotlightMaxWidth, 640)
        compare(Theme.spotlightMaxHeight, 420)
        compare(Theme.spotlightWidthRatio, 0.8)
        compare(Theme.switcherWidth, 800)
        compare(Theme.switcherHeight, 300)
        compare(Theme.notificationWidth, 360)
        compare(Theme.notificationMaxVisible, 3)
    }

    function test_glass_defaults() {
        verify(glassProbe.translucent)
        compare(glassProbe.blurRadius, 40)
        compare(glassProbe.radius, Theme.radius)
        verify(!glassProbe.shaderEnabled)
    }

    function test_glass_opaque_fallback_stays_usable() {
        // Sin compositor la superficie debe seguir siendo legible:
        // color totalmente opaco, nunca pantalla negra. (El flag `visible`
        // no se puede comprobar aqui: en este Qt los hijos de TestCase
        // leen visible=false aunque su valor propio sea true.)
        compare(glassOpaqueProbe.color, Theme.glassOpaque)
        verify(glassOpaqueProbe.color.a === 1.0, "el fallback opaco debe ser totalmente opaco")
    }

    function test_popup_defaults() {
        compare(popupProbe.title, "")
        verify(!popupProbe.modal)
        verify(!popupProbe.visible)
        popupProbe.width = 200
        popupProbe.height = 100
        compare(popupProbe.width, 200)
        compare(popupProbe.height, 100)
    }

    function test_icon_defaults() {
        compare(iconProbe.name, "")
        compare(iconProbe.source, "")
        compare(iconProbe.size, 16)
        compare(iconProbe.color, Theme.text)
    }

    function test_button_defaults() {
        compare(buttonProbe.text, "")
        compare(buttonProbe.icon, "")
        verify(buttonProbe.enabled)
    }

    function test_toggle_emits_on_change() {
        compare(toggleProbe.checked, false)
        toggledSpy.clear()
        toggleProbe.checked = true
        compare(toggledSpy.count, 1)
        toggleProbe.checked = false
        compare(toggledSpy.count, 2)
    }

    function test_slider_defaults_and_clamp() {
        compare(sliderProbe.from, 0)
        compare(sliderProbe.to, 100)
        compare(sliderProbe.value, 0)
        compare(sliderProbe.unit, "")
        movedSpy.clear()
        sliderProbe.setValue(50)
        compare(sliderProbe.value, 50)
        compare(movedSpy.count, 1)
        sliderProbe.setValue(200)
        compare(sliderProbe.value, 100)
        sliderProbe.setValue(-5)
        compare(sliderProbe.value, 0)
    }

    function test_searchfield_defaults() {
        compare(fieldProbe.text, "")
        compare(fieldProbe.placeholder, "")
        verify(!fieldProbe.focused)
        fieldProbe.text = "hola"
        compare(fieldProbe.text, "hola")
        fieldProbe.text = ""
    }

    function test_listrow_defaults() {
        compare(rowProbe.title, "")
        compare(rowProbe.subtitle, "")
        compare(rowProbe.icon, "")
        verify(!rowProbe.selected)
    }

    function test_sectionheader_defaults() {
        compare(headerProbe.text, "")
    }

    function test_tooltip_defaults() {
        compare(tooltipProbe.text, "")
        compare(tooltipProbe.anchorTo, "")
    }

    function test_services_plain_defaults() {
        // Sin D-Bus: todo ausente/desconocido, pero instanciable.
        verify(!Services.notificationsAvailable)
        verify(!Services.statusNotifierAvailable)
        verify(!Services.mprisAvailable)
        verify(!Services.upowerAvailable)
        compare(Services.notificationCount, 0)
        compare(Services.networkState, "unknown")
        compare(Services.bluetoothState, "unknown")
        verify(!Services.batteryPresent)
    }

    function test_services_notify_and_clear() {
        Services.clearNotifications()
        Services.notify("titulo", "cuerpo")
        compare(Services.notificationCount, 1)
        Services.clearNotifications()
        compare(Services.notificationCount, 0)
    }

    function test_polkit_agent_is_defensive() {
        verify(!PolkitAgent.available)
        verify(!PolkitAgent.actionsEnabled)
        verify(PolkitAgent.statusMessage !== "")
        compare(PolkitAgent.requestAuthentication("org.nimbus.test"), false)
    }
}
