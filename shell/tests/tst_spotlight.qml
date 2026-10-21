// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

// Tests del Spotlight (shell/src/Nimbus/modules/Spotlight.qml).
//
// El componente se carga por URL de fichero en vez de `Spotlight {}` porque
// `shell/src/Nimbus/qmldir` lo gestiona otra pista de la M1 y no se puede
// editar aqui: cuando se registre `Spotlight 1.0 modules/Spotlight.qml`,
// este Loader puede sustituirse por instanciacion directa.
TestCase {
    name: "Spotlight"
    when: true

    Loader {
        id: loader
        source: "../src/Nimbus/modules/Spotlight.qml"
    }

    SignalSpy { id: activatedSpy; signalName: "resultActivated" }
    SignalSpy { id: closedSpy; signalName: "closed" }

    function spot() {
        return loader.item
    }

    function fixtureItems() {
        return [
            { "id": "app-term", "kind": "app", "title": "Term", "subtitle": "Terminal minima", "icon": "terminal" },
            { "id": "app-terminal", "kind": "app", "title": "Terminal", "subtitle": "Emulador de terminal", "icon": "terminal" },
            { "id": "doc-xterm", "kind": "file", "title": "XTerm Manual", "subtitle": "/usr/share/doc/xterm/manual.txt", "icon": "" },
            { "id": "act-shutdown", "kind": "action", "title": "Apagar", "subtitle": "Apagar el equipo", "icon": "" }
        ]
    }

    function fixtureEmoji() {
        return [
            { "char": "😀", "name": "grinning face", "keywords": ["smile", "happy"] },
            { "char": "🍎", "name": "red apple", "keywords": ["fruit", "food"] },
            { "char": "🚀", "name": "rocket", "keywords": ["ship", "launch"] }
        ]
    }

    function fixtureMostUsed() {
        return [
            { "id": "app-terminal", "kind": "app", "title": "Terminal", "subtitle": "Emulador de terminal", "icon": "terminal" },
            { "id": "doc-xterm", "kind": "file", "title": "XTerm Manual", "subtitle": "/usr/share/doc/xterm/manual.txt", "icon": "" }
        ]
    }

    function initTestCase() {
        verify(loader.item !== null, "Spotlight.qml debe cargarse por URL")
        activatedSpy.target = loader.item
        closedSpy.target = loader.item
    }

    function init() {
        var s = spot()
        s.items = fixtureItems()
        s.emojiTable = fixtureEmoji()
        s.mostUsed = fixtureMostUsed()
        s.selectedIndex = 0
        s.query = ""
        activatedSpy.clear()
        closedSpy.clear()
    }

    function test_interface_defaults() {
        var s = spot()
        compare(s.query, "")
        compare(s.maxWidth, Theme.spotlightMaxWidth)
        compare(s.maxWidth, 640)
        compare(s.maxHeight, Theme.spotlightMaxHeight)
        compare(s.maxHeight, 420)
        // Con la consulta vacia se muestran las mas usadas.
        compare(s.results.length, 2)
        compare(s.results[0].id, "app-terminal")
    }

    function test_sorts_exact_prefix_substring() {
        var s = spot()
        var r = s.search("term")
        compare(r.length, 3)
        // Exacto ("Term") > prefijo ("Terminal") > subcadena ("XTerm Manual").
        compare(r[0].id, "app-term")
        compare(r[1].id, "app-terminal")
        compare(r[2].id, "doc-xterm")
    }

    function test_matches_title_and_subtitle_case_insensitive() {
        var s = spot()
        var byTitle = s.search("APAGAR")
        compare(byTitle.length, 1)
        compare(byTitle[0].id, "act-shutdown")
        var bySubtitle = s.search("emulador")
        compare(bySubtitle.length, 1)
        compare(bySubtitle[0].id, "app-terminal")
    }

    function test_calculator_addition_is_first_result() {
        var s = spot()
        compare(s.evaluateCalc("3 + 4"), 7)
        var r = s.search("3 + 4")
        compare(r.length, 1)
        compare(r[0].kind, "calc")
        compare(r[0].title, "7")
    }

    function test_calculator_fraction_two_decimals() {
        var s = spot()
        var v = s.evaluateCalc("1/3")
        verify(v > 0.33 && v < 0.34)
        compare(s.formatNumber(v), "0.33")
        var r = s.search("1/3")
        compare(r[0].kind, "calc")
        compare(r[0].title, "0.33")
    }

    function test_calculator_precedence_and_parens() {
        var s = spot()
        compare(s.evaluateCalc("2 + 3 * 4"), 14)
        compare(s.evaluateCalc("(2 + 3) * 4"), 20)
        compare(s.evaluateCalc("-5 + 3"), -2)
        compare(s.formatNumber(s.evaluateCalc("2.50")), "2.5")
    }

    function test_plain_number_formats_without_trailing_zeros() {
        var s = spot()
        var r = s.search("2.50")
        compare(r[0].kind, "calc")
        compare(r[0].title, "2.5")
    }

    function test_non_expression_never_throws() {
        var s = spot()
        verify(!s.isCalcQuery("hola"))
        verify(s.calcResult("hola") === null)
        verify(isNaN(s.evaluateCalc("hola")))
        verify(isNaN(s.evaluateCalc("")))
        verify(isNaN(s.evaluateCalc("3 +")))
        verify(isNaN(s.evaluateCalc("(2+3")))
        verify(isNaN(s.evaluateCalc("1/0")))
        verify(isNaN(s.evaluateCalc("..")))
    }

    function test_format_number_strips_zeros() {
        var s = spot()
        compare(s.formatNumber(7), "7")
        compare(s.formatNumber(2.5), "2.5")
        compare(s.formatNumber(0.33), "0.33")
        compare(s.formatNumber(0), "0")
        compare(s.formatNumber(-0.001), "0")
        compare(s.formatNumber(NaN), "")
        compare(s.formatNumber(Infinity), "")
    }

    function test_emoji_filter_fake_table() {
        var s = spot()
        var table = fixtureEmoji()
        var r = s.filterEmoji(table, "apple")
        compare(r.length, 1)
        compare(r[0].kind, "emoji")
        compare(r[0].title, "🍎")
        compare(r[0].subtitle, "red apple")
        // Insensible a mayusculas y con consulta vacia no hay resultados.
        compare(s.filterEmoji(table, "ROCKET").length, 1)
        compare(s.filterEmoji(table, "ROCKET")[0].title, "🚀")
        compare(s.filterEmoji(table, "").length, 0)
        // El buscador completo tambien ofrece el emoji.
        var all = s.search("apple")
        compare(all.length, 1)
        compare(all[0].kind, "emoji")
    }

    function test_empty_query_returns_most_used() {
        var s = spot()
        var r = s.search("")
        compare(r.length, 2)
        compare(r[0].id, "app-terminal")
        compare(r[1].id, "doc-xterm")
        // Tambien con espacios en blanco.
        compare(s.search("   ").length, 2)
    }

    function test_constrained_width() {
        var s = spot()
        compare(s.constrainedWidth(1000), 640)
        compare(s.constrainedWidth(500), 400)
        compare(s.constrainedWidth(0), 640)
        compare(s.constrainedWidth("ancho"), 640)
    }

    function test_activate_selected_emits_id() {
        var s = spot()
        s.query = "apagar"
        compare(s.results.length, 1)
        activatedSpy.clear()
        verify(s.activateSelected())
        compare(activatedSpy.count, 1)
        compare(activatedSpy.signalArguments[0][0], "act-shutdown")
    }

    function test_activate_rejects_bad_selection() {
        var s = spot()
        s.query = "apagar"
        s.selectedIndex = 99
        activatedSpy.clear()
        verify(!s.activateSelected())
        compare(activatedSpy.count, 0)
        s.selectedIndex = 0
    }

    function test_close_emits_closed() {
        var s = spot()
        closedSpy.clear()
        s.close()
        compare(closedSpy.count, 1)
    }

    function test_results_follow_query() {
        var s = spot()
        s.query = "apagar"
        compare(s.results.length, 1)
        compare(s.results[0].id, "act-shutdown")
        s.query = ""
        compare(s.results.length, 2)
    }
}
