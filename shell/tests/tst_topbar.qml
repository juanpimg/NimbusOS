// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

// Contratos de la barra superior y el menu global (Task 2):
// - la altura de la barra es Theme.barHeight (el PanelWindow la fija con ese
//   token; aqui se fija el valor del contrato);
// - regla de oro: sin bateria, sin bluetooth o sin red conocidos no hay item
//   (predicados puros evaluados sobre Services);
// - el reloj respeta Config.locale y Config.translated("bar.clock.format");
// - el menu son datos: entries [{title, items:[{label, action, checked,
//   disabled}]}]; dibuja, no decide; se abre al pulsar y se cierra al
//   seleccionar una entrada o al perder el foco.
// NOTA: TopBar es un PanelWindow (importa Quickshell.Wayland) y no puede
// instanciarse sin compositor; su logica vive en TopBarMenu (un Item puro
// sin dependencias de framework) y es la que se prueba aqui. Los bindings
// del PanelWindow (height, exclusiveZone, anchors) se verifican con qmllint
// mas revision del diff.
TestCase {
    name: "TopBar"
    when: true

    TopBarMenu {
        id: menuProbe
    }

    property string lastActionApp: ""
    property string lastActionName: ""
    property int actionCount: 0
    property int closedCount: 0

    function handleAction(appId, action) {
        lastActionApp = appId
        lastActionName = action
        actionCount += 1
    }

    function handleClosed() {
        closedCount += 1
    }

    function initTestCase() {
        menuProbe.actionTriggered.connect(handleAction)
        menuProbe.closed.connect(handleClosed)
    }

    function sampleEntries() {
        return [
            {
                "title": "Archivo",
                "items": [
                    { "label": "Nuevo", "action": "new", "checked": false, "disabled": false },
                    { "label": "Salir", "action": "quit", "checked": false, "disabled": true }
                ]
            },
            {
                "title": "Ver",
                "items": [
                    { "label": "Siempre visible", "action": "pin", "checked": true, "disabled": false }
                ]
            }
        ]
    }

    function init() {
        Config.setLocale("es")
        Services.batteryPresent = false
        Services.bluetoothState = "unknown"
        Services.networkState = "unknown"
        menuProbe.appId = ""
        menuProbe.entries = []
        if (menuProbe.menuOpen)
            menuProbe.closeMenu()
        lastActionApp = ""
        lastActionName = ""
        actionCount = 0
        closedCount = 0
    }

    function cleanup() {
        Config.setLocale("es")
        Services.batteryPresent = false
        Services.bluetoothState = "unknown"
        Services.networkState = "unknown"
        menuProbe.appId = ""
        menuProbe.entries = []
    }

    function test_menu_defaults() {
        compare(menuProbe.appId, "")
        compare(menuProbe.sectionCount(), 0)
        verify(!menuProbe.menuOpen)
        compare(menuProbe.rowHeight, Theme.spacing * 7)
        compare(menuProbe.implicitWidth, Theme.menuWidth)
    }

    function test_bar_height_is_theme_bar_height() {
        // Contrato que TopBar.qml fija como height y exclusiveZone del
        // PanelWindow. El PanelWindow necesita compositor y no se instancia
        // bajo qmltestrunner; el binding se verifica con qmllint + revision.
        compare(Theme.barHeight, 24)
    }

    function test_battery_item_hidden_without_battery() {
        verify(!menuProbe.batteryVisible(Services.batteryPresent))
        Services.batteryPresent = true
        verify(menuProbe.batteryVisible(Services.batteryPresent))
    }

    function test_bluetooth_item_hidden_when_unknown() {
        verify(!menuProbe.bluetoothVisible(Services.bluetoothState))
        verify(!menuProbe.bluetoothVisible("zzz"))
        Services.bluetoothState = "off"
        verify(menuProbe.bluetoothVisible(Services.bluetoothState))
        Services.bluetoothState = "on"
        verify(menuProbe.bluetoothVisible(Services.bluetoothState))
    }

    function test_network_item_hidden_when_unknown() {
        verify(!menuProbe.networkVisible(Services.networkState))
        Services.networkState = "offline"
        verify(menuProbe.networkVisible(Services.networkState))
        Services.networkState = "online"
        verify(menuProbe.networkVisible(Services.networkState))
    }

    function test_volume_and_dnd_have_no_backend_in_m1() {
        // Sin servicio de volumen ni estado DND en Services (M1): la regla
        // de oro manda no dibujar. M2 los cablea a Pipewire/Notificaciones.
        verify(!menuProbe.volumeVisible())
        verify(!menuProbe.dndVisible())
    }

    function test_entries_are_data_not_decisions() {
        menuProbe.entries = sampleEntries()
        compare(menuProbe.sectionCount(), 2)
        compare(menuProbe.itemCount(0), 2)
        compare(menuProbe.itemCount(1), 1)
        compare(menuProbe.sectionTitle(0), "Archivo")
        compare(menuProbe.itemLabel(0, 0), "Nuevo")
        compare(menuProbe.itemAction(0, 0), "new")
        verify(!menuProbe.isEnabled(0, 1))
        verify(menuProbe.isEnabled(0, 0))
        verify(menuProbe.itemChecked(1, 0))
        // La altura del menu deriva del contenido con metricas de Theme.
        compare(menuProbe.implicitHeight, menuProbe.flatRows().length * menuProbe.rowHeight + Theme.spacing * 2)
    }

    function test_flat_rows_carry_resolved_fields() {
        menuProbe.entries = sampleEntries()
        var rows = menuProbe.flatRows()
        compare(rows.length, 5)
        compare(rows[0].kind, "header")
        compare(rows[0].title, "Archivo")
        compare(rows[1].kind, "item")
        compare(rows[1].label, "Nuevo")
        compare(rows[1].action, "new")
        verify(!rows[1].disabled)
        verify(rows[2].disabled)
        compare(rows[3].title, "Ver")
        verify(rows[4].checked)
        compare(rows[4].h, menuProbe.rowHeight)
    }

    function test_defensive_with_malformed_entries() {
        menuProbe.entries = null
        compare(menuProbe.sectionCount(), 0)
        menuProbe.entries = [{}, { "title": "Solo" }]
        compare(menuProbe.sectionCount(), 2)
        compare(menuProbe.itemCount(0), 0)
        compare(menuProbe.itemCount(1), 0)
        compare(menuProbe.itemLabel(0, 0), "")
        compare(menuProbe.itemAction(9, 9), "")
        verify(!menuProbe.isEnabled(0, 0))
        verify(!menuProbe.itemChecked(0, 0))
        menuProbe.openMenu("app")
        menuProbe.selectItem(9, 9)
        menuProbe.selectItem(-1, 0)
        compare(actionCount, 0)
        compare(closedCount, 0)
        verify(menuProbe.menuOpen)
    }

    function test_select_emits_action_and_closes() {
        menuProbe.entries = sampleEntries()
        menuProbe.openMenu("finder")
        menuProbe.selectItem(0, 0)
        compare(actionCount, 1)
        compare(lastActionApp, "finder")
        compare(lastActionName, "new")
        verify(!menuProbe.menuOpen)
        compare(closedCount, 1)
    }

    function test_disabled_entry_does_not_fire() {
        menuProbe.entries = sampleEntries()
        menuProbe.openMenu("finder")
        menuProbe.selectItem(0, 1)
        compare(actionCount, 0)
        compare(closedCount, 0)
        verify(menuProbe.menuOpen)
    }

    function test_menu_closes_on_focus_loss() {
        menuProbe.openMenu("finder")
        verify(menuProbe.menuOpen)
        menuProbe.handleFocusLost()
        verify(!menuProbe.menuOpen)
        compare(closedCount, 1)
        menuProbe.handleFocusLost()
        compare(closedCount, 1)
    }

    function test_toggle_menu() {
        menuProbe.toggleMenu("store")
        verify(menuProbe.menuOpen)
        compare(menuProbe.appId, "store")
        compare(closedCount, 0)
        menuProbe.toggleMenu("store")
        verify(!menuProbe.menuOpen)
        compare(closedCount, 1)
    }

    function test_open_menu_updates_appid() {
        menuProbe.openMenu("store")
        compare(menuProbe.appId, "store")
        verify(menuProbe.menuOpen)
    }

    function test_clock_format_follows_locale() {
        var fixed = new Date(2026, 9, 21, 14, 30, 0)
        Config.setLocale("es")
        var esClock = menuProbe.formatClock(fixed, Config.locale, Config.translated("bar.clock.format"))
        Config.setLocale("en")
        var enClock = menuProbe.formatClock(fixed, Config.locale, Config.translated("bar.clock.format"))
        verify(esClock !== "")
        verify(enClock !== "")
        verify(esClock !== enClock, "el reloj debe cambiar con el locale (es=" + esClock + " en=" + enClock + ")")
    }

    function test_clock_honors_explicit_pattern() {
        var fixed = new Date(2026, 9, 21, 14, 30, 0)
        var patterned = menuProbe.formatClock(fixed, "es", "hh:mm")
        compare(patterned, fixed.toLocaleString(Qt.locale("es"), "hh:mm"))
        var fallback = menuProbe.formatClock(fixed, "es", "bar.clock.format")
        verify(fallback !== patterned, "sin traduccion de bar.clock.format se usa el formato local por defecto")
        verify(fallback.indexOf("2026") !== -1 || fallback.indexOf("21") !== -1)
    }
}
