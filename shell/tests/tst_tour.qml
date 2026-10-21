// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus
import "../src/Nimbus/apps/Tour"

// Tour de bienvenida: guia de 2 minutos del primer arranque.
//
// El contenido (Tour/TourStep) se importa por ruta relativa porque
// `shell/src/Nimbus/qmldir` lo comparten varias pistas y esta tarea no
// puede editarlo: el registro (`Tour 1.0 apps/Tour/Tour.qml`,
// `TourStep 1.0 apps/Tour/TourStep.qml`) queda declarado en el informe.
//
// Lo que depende de `FloatingWindow` o de señalar elementos reales de la
// interfaz vive en el `.qml` y se documenta como no testeado aqui: aqui se
// comprueban pasos, palabras, avance/wraparound puros, emision unica de
// `tourFinished` y que el tour no se repite una vez completado.
TestCase {
    name: "Tour"
    when: true

    Tour { id: probe }

    SignalSpy { id: finishedSpy; target: probe; signalName: "tourFinished" }
    SignalSpy { id: skippedSpy; target: probe; signalName: "skipped" }

    function init() {
        probe.reset()
        finishedSpy.clear()
        skippedSpy.clear()
        Config.setLocale("es")
    }

    function cleanup() {
        Config.setLocale("es")
    }

    function test_step_count_between_seven_and_nine() {
        verify(probe.steps.length >= 7 && probe.steps.length <= 9,
               "el tour debe tener entre 7 y 9 pasos, tiene " + probe.steps.length)
    }

    function test_steps_have_required_shape() {
        for (var i = 0; i < probe.steps.length; ++i) {
            var s = probe.steps[i]
            verify(typeof s.id === "string" && s.id !== "", "paso " + i + " sin id")
            verify(typeof s.title === "string" && s.title !== "", "paso " + i + " sin title")
            verify(typeof s.body === "string" && s.body !== "", "paso " + i + " sin body")
            verify(s.target !== undefined, "paso " + i + " sin target")
            verify(typeof s.anchor === "string" && s.anchor !== "", "paso " + i + " sin anchor")
            verify(s.title.indexOf("tour.") === 0, "title del paso " + i + " debe ser clave de traduccion")
            verify(s.body.indexOf("tour.") === 0, "body del paso " + i + " debe ser clave de traduccion")
        }
    }

    function test_step_ids_cover_first_run_experience() {
        var ids = []
        for (var i = 0; i < probe.steps.length; ++i)
            ids.push(probe.steps[i].id)
        for (var k = 0; k < ["dock", "spotlight", "notifications", "shortcuts", "gameready"].length; ++k)
            verify(ids.indexOf(["dock", "spotlight", "notifications", "shortcuts", "gameready"][k]) !== -1,
                   "el tour debe cubrir el paso requerido")
    }

    function check_all_bodies_fit(locale) {
        Config.setLocale(locale)
        for (var i = 0; i < probe.steps.length; ++i) {
            var body = probe.stepBodyAt(i)
            verify(typeof body === "string" && body !== "" && body !== probe.steps[i].body,
                   "el cuerpo del paso " + i + " debe resolverse (" + locale + ")")
            var n = probe.wordCount(body)
            verify(n > 0, "el cuerpo del paso " + i + " esta vacio (" + locale + ")")
            verify(n <= 30, "el paso " + i + " tiene " + n + " palabras, maximo 30 (" + locale + ")")
        }
    }

    function test_bodies_fit_two_minutes_es() {
        check_all_bodies_fit("es")
    }

    function test_bodies_fit_two_minutes_en() {
        check_all_bodies_fit("en")
    }

    function test_titles_resolve_in_both_locales() {
        var locales = ["es", "en"]
        for (var l = 0; l < locales.length; ++l) {
            Config.setLocale(locales[l])
            for (var i = 0; i < probe.steps.length; ++i) {
                var title = probe.stepTitleAt(i)
                verify(title !== "" && title !== probe.steps[i].title,
                       "el titulo del paso " + i + " debe resolverse (" + locales[l] + ")")
            }
        }
    }

    function test_chrome_labels_resolve() {
        var locales = ["es", "en"]
        for (var l = 0; l < locales.length; ++l) {
            Config.setLocale(locales[l])
            verify(probe.tr("tour.next") !== "tour.next", "tour.next sin traducir (" + locales[l] + ")")
            verify(probe.tr("tour.back") !== "tour.back", "tour.back sin traducir (" + locales[l] + ")")
            verify(probe.tr("tour.skip") !== "tour.skip", "tour.skip sin traducir (" + locales[l] + ")")
            verify(probe.tr("tour.finish") !== "tour.finish", "tour.finish sin traducir (" + locales[l] + ")")
        }
    }

    function test_advance_moves_index() {
        compare(probe.index, 0)
        probe.advance()
        compare(probe.index, 1)
        probe.advance()
        compare(probe.index, 2)
    }

    function test_previous_goes_back_and_clamps() {
        probe.advance()
        probe.advance()
        probe.previous()
        compare(probe.index, 1)
        probe.previous()
        compare(probe.index, 0)
        probe.previous()
        compare(probe.index, 0)
    }

    function test_peek_wraparound_is_pure() {
        var n = probe.steps.length
        compare(probe.peekNext(n - 1), 0)
        compare(probe.peekNext(0), 1)
        compare(probe.peekPrev(0), n - 1)
        compare(probe.peekPrev(1), 0)
        // Puras: el indice no se mueve.
        compare(probe.index, 0)
    }

    function test_enter_key_advances() {
        probe.handleKey(Qt.Key_Return)
        compare(probe.index, 1)
        probe.handleKey(Qt.Key_Enter)
        compare(probe.index, 2)
    }

    function test_unknown_key_is_ignored() {
        verify(!probe.handleKey(Qt.Key_A))
        compare(probe.index, 0)
        compare(finishedSpy.count, 0)
        compare(skippedSpy.count, 0)
    }

    function test_escape_skips_once_and_hides() {
        probe.handleKey(Qt.Key_Escape)
        compare(skippedSpy.count, 1)
        verify(probe.completed)
        verify(!probe.shouldShow())
        // Un segundo Esc no re-emite.
        probe.handleKey(Qt.Key_Escape)
        compare(skippedSpy.count, 1)
        compare(finishedSpy.count, 0)
    }

    function test_finished_emitted_exactly_once() {
        var n = probe.steps.length
        for (var k = 0; k < n; ++k)
            probe.advance()
        compare(finishedSpy.count, 1)
        verify(probe.finished)
        verify(probe.completed)
        verify(!probe.shouldShow())
        // Avanzar de mas no re-emite.
        probe.advance()
        probe.advance()
        compare(finishedSpy.count, 1)
    }

    function test_return_on_last_step_finishes() {
        var n = probe.steps.length
        for (var k = 0; k < n - 1; ++k)
            probe.advance()
        compare(probe.index, n - 1)
        probe.handleKey(Qt.Key_Return)
        compare(finishedSpy.count, 1)
        verify(probe.finished)
    }

    function test_completed_tour_does_not_reshow() {
        verify(probe.shouldShow())
        probe.completed = true
        verify(!probe.shouldShow())
    }

    function test_word_count_helper() {
        compare(probe.wordCount("hola mundo"), 2)
        compare(probe.wordCount(""), 0)
        compare(probe.wordCount("  una   frase  con espacios  "), 4)
        compare(probe.wordCount(null), 0)
        compare(probe.wordCount(undefined), 0)
    }
}
