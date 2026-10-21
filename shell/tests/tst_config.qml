// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Config"
    when: true

    function test_defaults() {
        compare(Config.schemaVersion, 2)
        compare(Config.mode, "light")
        compare(Config.locale, "es")
    }

    function test_falls_back_to_english_for_unknown_locale() {
        Config.setLocale("de")
        compare(Config.locale, "de")
        compare(Config.translated("app.store.title"), "Nimbus Store")
    }

    function test_migrates_older_config_schema() {
        Config.setMode("dark")
        Config.setAccent("#ff2d55")
        Config.migrateFrom(1)
        compare(Config.schemaVersion, 2)
        compare(Config.mode, "dark")
        compare(Config.accent, "ff2d55")
    }
}
