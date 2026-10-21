// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Notifications"
    when: true

    Notifications { id: probe }

    SignalSpy { id: dismissedSpy; target: probe; signalName: "dismissed" }
    SignalSpy { id: actionSpy; target: probe; signalName: "actionTriggered" }
    SignalSpy { id: dndSpy; target: probe; signalName: "dndToggled" }

    function makeNotif(id, app, title) {
        return {
            "id": id,
            "app": app,
            "title": title,
            "body": "cuerpo de " + title,
            "timestamp": 1000 + parseInt(id.replace(/\D/g, "") || "0", 10),
            "actions": []
        }
    }

    function init() {
        probe.clearAll()
        probe.setDnd(false)
        dismissedSpy.clear()
        actionSpy.clear()
        dndSpy.clear()
    }

    function test_defaults() {
        compare(probe.maxVisible, 3)
        compare(probe.toastWidth, 360)
        verify(!probe.dnd)
        compare(probe.items.length, 0)
    }

    function test_metrics_come_from_theme() {
        compare(probe.maxVisible, Theme.notificationMaxVisible)
        compare(probe.toastWidth, Theme.notificationWidth)
    }

    function test_groups_by_app_with_counter() {
        var list = [
                    makeNotif("n1", "Terminal", "Aviso 1"),
                    makeNotif("n2", "Terminal", "Aviso 2"),
                    makeNotif("n3", "Musica", "Tema nuevo")
                ]
        var groups = probe.groupByApp(list)
        compare(groups.length, 2)
        compare(groups[0].app, "Terminal")
        compare(groups[0].count, 2)
        compare(groups[1].app, "Musica")
        compare(groups[1].count, 1)
    }

    function test_grouping_empty_list() {
        var groups = probe.groupByApp([])
        compare(groups.length, 0)
    }

    function test_trims_to_three_visible_toasts() {
        var list = [
                    makeNotif("n1", "A", "Uno"),
                    makeNotif("n2", "B", "Dos"),
                    makeNotif("n3", "C", "Tres"),
                    makeNotif("n4", "D", "Cuatro"),
                    makeNotif("n5", "E", "Cinco")
                ]
        var visible = probe.visibleToasts(list)
        compare(visible.length, 3)
        compare(visible[0].id, "n1")
        compare(visible[2].id, "n3")
    }

    function test_visible_toasts_pass_through_short_lists() {
        var list = [makeNotif("n1", "A", "Uno")]
        compare(probe.visibleToasts(list).length, 1)
        compare(probe.visibleToasts([]).length, 0)
    }

    function test_counter_reflects_grouped_total_not_toasts() {
        probe.addNotification(makeNotif("n1", "A", "Uno"))
        probe.addNotification(makeNotif("n2", "A", "Dos"))
        probe.addNotification(makeNotif("n3", "B", "Tres"))
        probe.addNotification(makeNotif("n4", "C", "Cuatro"))
        compare(probe.totalCount(probe.items), 4)
        compare(probe.visibleToasts(probe.items).length, 3)
        var groups = probe.groupByApp(probe.items)
        var sum = 0
        for (var i = 0; i < groups.length; ++i)
            sum += groups[i].count
        compare(sum, probe.totalCount(probe.items))
    }

    function test_dnd_keeps_existing_and_silences_new() {
        probe.addNotification(makeNotif("n1", "A", "Uno"))
        probe.addNotification(makeNotif("n2", "B", "Dos"))
        probe.setDnd(true)
        verify(probe.dnd)
        // Lo existente sigue ahi.
        compare(probe.items.length, 2)
        // Lo nuevo se silencia: no entra.
        var added = probe.addNotification(makeNotif("n3", "C", "Tres"))
        verify(!added)
        compare(probe.items.length, 2)
        // El filtro puro lo confirma.
        var filtered = probe.applyDndFilter(probe.items, [makeNotif("n9", "Z", "Nueva")], true)
        compare(filtered.kept.length, 2)
        compare(filtered.silenced.length, 1)
        compare(filtered.shown.length, 0)
    }

    function test_dnd_off_lets_new_through() {
        probe.setDnd(true)
        probe.setDnd(false)
        verify(probe.addNotification(makeNotif("n1", "A", "Uno")))
        compare(probe.items.length, 1)
        var filtered = probe.applyDndFilter([], [makeNotif("n2", "A", "Dos")], false)
        compare(filtered.shown.length, 1)
        compare(filtered.silenced.length, 0)
    }

    function test_dismiss_removes_and_signals() {
        probe.addNotification(makeNotif("n1", "A", "Uno"))
        probe.addNotification(makeNotif("n2", "B", "Dos"))
        dismissedSpy.clear()
        probe.dismissNotification("n1")
        compare(probe.items.length, 1)
        compare(probe.items[0].id, "n2")
        compare(dismissedSpy.count, 1)
        compare(dismissedSpy.signalArguments[0][0], "n1")
    }

    function test_action_buttons_emit_action_triggered() {
        var n = makeNotif("n1", "A", "Uno")
        n.actions = [{ "id": "reply", "label": "Responder" }]
        probe.addNotification(n)
        actionSpy.clear()
        probe.triggerAction("n1", "reply")
        compare(actionSpy.count, 1)
        compare(actionSpy.signalArguments[0][0], "n1")
        compare(actionSpy.signalArguments[0][1], "reply")
    }

    function test_dnd_toggle_emits_signal() {
        dndSpy.clear()
        probe.setDnd(true)
        compare(dndSpy.count, 1)
        compare(dndSpy.signalArguments[0][0], true)
    }

    function test_clear_empties() {
        probe.addNotification(makeNotif("n1", "A", "Uno"))
        probe.clearAll()
        compare(probe.items.length, 0)
    }

    function test_daemon_failure_keeps_shell_working() {
        // El registro del daemon puede fallar (p. ej. D-Bus ausente):
        // el shell sigue funcionando y lo avisa en daemonError.
        probe.markDaemonAvailable(false, "D-Bus no disponible")
        verify(!probe.daemonAvailable)
        verify(probe.daemonError !== "")
        // Y las funciones puras siguen operativas.
        verify(probe.addNotification(makeNotif("n1", "A", "Uno")))
        compare(probe.items.length, 1)
    }

    function test_daemon_success_marks_available() {
        probe.markDaemonAvailable(true, "")
        verify(probe.daemonAvailable)
        compare(probe.daemonError, "")
    }
}
