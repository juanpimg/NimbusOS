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

    function test_translates_to_spanish() {
        Config.setLocale("es")
        compare(Config.translated("app.settings.title"), "Ajustes del sistema")
    }

    function test_returns_key_for_missing_translation() {
        Config.setLocale("es")
        compare(Config.translated("missing.key.xyz"), "missing.key.xyz")
    }

    function test_translations_lookup_falls_back_to_english() {
        compare(Translations.lookup("fr", "app.settings.title"), "System Settings")
    }

    function test_setAccent_ignores_non_string() {
        Config.setAccent("#aabbcc")
        compare(Config.accent, "aabbcc")
        Config.setAccent(null)
        Config.setAccent(undefined)
        compare(Config.accent, "aabbcc")
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
