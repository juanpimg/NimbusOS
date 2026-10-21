// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Switcher"
    when: true

    Switcher { id: probe }

    SignalSpy { id: committedSpy; target: probe; signalName: "committed" }
    SignalSpy { id: cancelledSpy; target: probe; signalName: "cancelled" }

    function makeEntries() {
        return [
            { "appId": "org.gnome.Terminal", "title": "Terminal", "icon": "terminal" },
            { "appId": "org.mozilla.Firefox", "title": "Firefox", "icon": "firefox" },
            { "appId": "org.gnome.Music", "title": "Musica", "icon": "music" }
        ]
    }

    function init() {
        probe.entries = []
        probe.index = 0
        committedSpy.clear()
        cancelledSpy.clear()
    }

    function test_defaults() {
        compare(probe.entries.length, 0)
        compare(probe.index, 0)
        compare(probe.entryCount(), 0)
        compare(probe.currentAppId(), "")
        verify(probe.currentEntry() === null)
    }

    function test_dimensions_come_from_theme() {
        compare(probe.width, 800)
        compare(probe.height, 300)
        compare(probe.width, Theme.switcherWidth)
        compare(probe.height, Theme.switcherHeight)
    }

    function test_entries_are_shown_as_given() {
        probe.entries = makeEntries()
        compare(probe.entryCount(), 3)
        compare(probe.entries.length, 3)
        compare(probe.entries[1].appId, "org.mozilla.Firefox")
        compare(probe.entries[1].title, "Firefox")
        compare(probe.entries[1].icon, "firefox")
        compare(probe.currentAppId(), "org.gnome.Terminal")
    }

    function test_next_advances_and_wraps() {
        probe.entries = makeEntries()
        probe.next()
        compare(probe.index, 1)
        probe.next()
        compare(probe.index, 2)
        probe.next()
        compare(probe.index, 0)
    }

    function test_prev_goes_back_and_wraps() {
        probe.entries = makeEntries()
        probe.prev()
        compare(probe.index, 2)
        probe.prev()
        compare(probe.index, 1)
    }

    function test_single_entry_stays_put() {
        probe.entries = [{ "appId": "org.gnome.Terminal", "title": "Terminal", "icon": "terminal" }]
        probe.next()
        compare(probe.index, 0)
        probe.prev()
        compare(probe.index, 0)
    }

    function test_empty_list_navigation_is_noop() {
        probe.next()
        compare(probe.index, 0)
        probe.prev()
        compare(probe.index, 0)
    }

    function test_select_clamps_into_range() {
        probe.entries = makeEntries()
        probe.select(2)
        compare(probe.index, 2)
        probe.select(99)
        compare(probe.index, 2)
        probe.select(-5)
        compare(probe.index, 0)
    }

    function test_index_clamps_when_entries_shrink() {
        probe.entries = makeEntries()
        probe.index = 2
        probe.entries = makeEntries().slice(0, 2)
        compare(probe.index, 1)
        probe.entries = []
        compare(probe.index, 0)
    }

    function test_commit_emits_selected_app_id() {
        probe.entries = makeEntries()
        probe.index = 1
        committedSpy.clear()
        cancelledSpy.clear()
        var ok = probe.commit()
        verify(ok)
        compare(committedSpy.count, 1)
        compare(committedSpy.signalArguments[0][0], "org.mozilla.Firefox")
        compare(cancelledSpy.count, 0)
    }

    function test_commit_with_no_entries_emits_nothing() {
        var ok = probe.commit()
        verify(!ok)
        compare(committedSpy.count, 0)
        compare(cancelledSpy.count, 0)
    }

    function test_cancel_emits_cancelled_without_committing() {
        probe.entries = makeEntries()
        probe.index = 1
        committedSpy.clear()
        cancelledSpy.clear()
        probe.cancel()
        compare(cancelledSpy.count, 1)
        compare(committedSpy.count, 0)
    }
}
