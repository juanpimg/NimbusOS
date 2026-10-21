// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../src/Nimbus/apps/Settings" as SettingsApp

// Contrato testeable de Ajustes (Task 10): la lógica pura vive en
// SettingsData (sin FloatingWindow ni servicios reales) para poder
// probarse con Qt Test a secas. Lo que depende de FloatingWindow o de
// servicios reales va en Settings.qml y se documenta como no testeado.
TestCase {
    name: "Settings"
    when: true

    SettingsApp.SettingsData { id: probe }

    SignalSpy { id: sectionSpy; target: probe; signalName: "sectionChanged" }

    readonly property string expectedOrder: "appearance,displays,keyboard,network,bluetooth,sound,power,users,software,about"

    function sectionIds(sections) {
        var ids = []
        for (var i = 0; i < sections.length; ++i)
            ids.push(sections[i].id)
        return ids.join(",")
    }

    function findSection(sections, id) {
        for (var i = 0; i < sections.length; ++i) {
            if (sections[i].id === id)
                return sections[i]
        }
        return null
    }

    function test_section_order_is_exact() {
        compare(probe.sectionOrder().join(","), expectedOrder)
    }

    function test_sections_property_lists_ten_entries_in_order() {
        compare(probe.sections.length, 10)
        compare(sectionIds(probe.sections), expectedOrder)
    }

    function test_sections_carry_title_key_icon_and_availability() {
        var sections = probe.buildSections(false)
        compare(sections.length, 10)
        compare(sectionIds(sections), expectedOrder)
        for (var i = 0; i < sections.length; ++i) {
            verify(sections[i].titleKey !== "", "sin titleKey: " + sections[i].id)
            verify(sections[i].icon !== "", "sin icono: " + sections[i].id)
            verify(sections[i].available !== undefined, "sin available: " + sections[i].id)
        }
    }

    function test_section_without_service_is_disabled_not_hidden() {
        // Sin bluetooth: la entrada se ve pero no se puede abrir.
        var sections = probe.buildSections(false)
        var bt = findSection(sections, "bluetooth")
        verify(bt !== null, "bluetooth debe seguir listada")
        verify(!bt.available, "bluetooth debe quedar deshabilitada sin servicio")
        for (var i = 0; i < sections.length; ++i) {
            if (sections[i].id !== "bluetooth")
                verify(sections[i].available, "sección disponible: " + sections[i].id)
        }
    }

    function test_bluetooth_available_with_service() {
        var sections = probe.buildSections(true)
        var bt = findSection(sections, "bluetooth")
        verify(bt !== null)
        verify(bt.available, "bluetooth disponible con servicio")
    }

    function test_disabled_section_cannot_be_opened() {
        probe.setSection("appearance", false)
        sectionSpy.clear()
        probe.setSection("bluetooth", false)
        compare(probe.section, "appearance")
        compare(sectionSpy.count, 0)
    }

    // NOTA: `sectionChanged` es la señal implícita de `property string
    // section` (QML no permite declararla explícita con payload). El
    // contrato observable se mantiene: navegar emite la señal y el
    // destino se lee en `.section`.
    function test_section_change_emits_signal() {
        probe.setSection("appearance", false)
        sectionSpy.clear()
        probe.setSection("sound", false)
        compare(probe.section, "sound")
        compare(sectionSpy.count, 1)
    }

    function test_unknown_section_is_ignored() {
        probe.setSection("appearance", false)
        sectionSpy.clear()
        probe.setSection("bogus", false)
        compare(probe.section, "appearance")
        compare(sectionSpy.count, 0)
    }

    function test_accent_presets_are_twelve_with_hex() {
        var presets = probe.accentPresets()
        compare(presets.length, 12)
        var seen = ({})
        for (var i = 0; i < presets.length; ++i) {
            verify(presets[i].name !== "", "preajuste sin nombre")
            verify(/^#[0-9a-f]{6}$/.test(presets[i].hex), "hex inválido: " + presets[i].hex)
            verify(!seen[presets[i].hex], "hex duplicado: " + presets[i].hex)
            seen[presets[i].hex] = true
        }
    }

    function test_power_defaults() {
        var d = probe.powerDefaults()
        compare(d.profile, "balanced")
        compare(d.chargeLimit, 80)
        compare(d.graphicsMode, "on-demand")
        compare(probe.defaultPowerProfile, "balanced")
        compare(probe.defaultChargeLimit, 80)
        compare(probe.defaultGraphicsMode, "on-demand")
    }

    function test_update_tool_links_nimbus_update() {
        compare(probe.updateTool, "nimbus-update")
    }

    function test_credits_include_macshell_and_whitesur() {
        var credits = probe.credits()
        var macShell = false
        var whiteSur = false
        for (var i = 0; i < credits.length; ++i) {
            if (credits[i].name === "MacShell" && credits[i].license === "MIT")
                macShell = true
            if (credits[i].name === "WhiteSur" && String(credits[i].license).indexOf("GPL") !== -1)
                whiteSur = true
        }
        verify(macShell, "falta el crédito MacShell/MIT")
        verify(whiteSur, "falta el crédito WhiteSur/GPL")
    }
}
