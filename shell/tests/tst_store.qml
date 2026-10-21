// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus
import "../src/Nimbus/apps/Store" as StoreApp

TestCase {
    name: "Store"
    when: true

    StoreApp.Store {
        id: storeProbe
    }

    StoreApp.StoreUpdates {
        id: updatesProbe
        updates: [
            { "id": "org.gimp.GIMP", "title": "GIMP", "version": "2.10" }
        ]
    }

    StoreApp.StoreDetail {
        id: detailProbe
    }

    SignalSpy { id: installSpy; target: storeProbe; signalName: "installRequested" }
    SignalSpy { id: uninstallSpy; target: storeProbe; signalName: "uninstallRequested" }
    SignalSpy { id: updateAllSpy; target: storeProbe; signalName: "updateAllRequested" }
    SignalSpy { id: updatesSpy; target: updatesProbe; signalName: "updateAllRequested" }

    // Backend falso inyectable: devuelve datos planos como el backend real.
    function makeBackend(overrides) {
        var backend = {
            "flatpakAvailable": function () { return true },
            "flatpakError": function () { return "" },
            "listApps": function (category) {
                var apps = [
                            { "id": "org.gimp.GIMP", "title": "GIMP", "category": "creative", "origin": "Flathub", "installed": false },
                            { "id": "nimbus.calc", "title": "Calculadora", "category": "utilities", "origin": "Nativo", "installed": true }
                        ]
                if (category === undefined || category === "" || category === "all")
                    return apps
                var out = []
                for (var i = 0; i < apps.length; ++i) {
                    if (apps[i].category === category)
                        out.push(apps[i])
                }
                return out
            },
            "search": function (query) {
                var q = String(query || "").toLowerCase()
                var all = backend.listApps("")
                if (q === "")
                    return all
                var out = []
                for (var i = 0; i < all.length; ++i) {
                    if (String(all[i].title).toLowerCase().indexOf(q) !== -1)
                        out.push(all[i])
                }
                return out
            },
            "getApp": function (appId) {
                var all = backend.listApps("")
                for (var i = 0; i < all.length; ++i) {
                    if (all[i].id === appId)
                        return all[i]
                }
                return null
            },
            "isInstalled": function (appId) {
                var app = backend.getApp(appId)
                return app !== null && app.installed === true
            },
            "install": function (appId) { return { "ok": true, "message": "" } },
            "uninstall": function (appId) { return { "ok": true, "message": "" } },
            "listUpdates": function () {
                return [{ "id": "org.gimp.GIMP", "title": "GIMP", "version": "2.10" }]
            }
        }
        if (overrides !== undefined) {
            for (var key in overrides)
                backend[key] = overrides[key]
        }
        return backend
    }

    function init() {
        storeProbe.backend = null
        storeProbe.view = "home"
        storeProbe.currentCategory = ""
        storeProbe.currentApp = null
        storeProbe.query = ""
        storeProbe.refresh()
        installSpy.clear()
        uninstallSpy.clear()
        updateAllSpy.clear()
        updatesSpy.clear()
    }

    function test_categories_exact_order() {
        var ids = []
        for (var i = 0; i < storeProbe.categories.length; ++i)
            ids.push(storeProbe.categories[i].id)
        compare(ids, ["games", "productivity", "communication", "creative", "media", "development", "utilities"])
    }

    function test_categories_carry_titles() {
        for (var i = 0; i < storeProbe.categories.length; ++i) {
            verify(storeProbe.categories[i].title !== undefined)
            verify(storeProbe.categories[i].title !== "")
        }
    }

    function test_refresh_without_backend_does_not_crash() {
        // Sin backend inyectado la tienda queda vacia pero operativa.
        storeProbe.backend = null
        storeProbe.refresh()
        compare(storeProbe.apps.length, 0)
        compare(storeProbe.updates.length, 0)
        verify(!storeProbe.flatpakAvailable)
        verify(storeProbe.flatpakError !== "")
    }

    function test_refresh_with_backend_lists_apps() {
        storeProbe.backend = makeBackend()
        storeProbe.refresh()
        verify(storeProbe.flatpakAvailable)
        compare(storeProbe.apps.length, 2)
        compare(storeProbe.updates.length, 1)
    }

    function test_category_filter_delegates_to_backend() {
        storeProbe.backend = makeBackend()
        storeProbe.setCategory("creative")
        compare(storeProbe.currentCategory, "creative")
        compare(storeProbe.apps.length, 1)
        compare(storeProbe.apps[0].id, "org.gimp.GIMP")
    }

    function test_search_filters_by_title_case_insensitive() {
        storeProbe.backend = makeBackend()
        storeProbe.refresh()
        var hits = storeProbe.filterApps(storeProbe.apps, "gimp")
        compare(hits.length, 1)
        compare(hits[0].id, "org.gimp.GIMP")
        var upper = storeProbe.filterApps(storeProbe.apps, "GIMP")
        compare(upper.length, 1)
        var mixed = storeProbe.filterApps(storeProbe.apps, "GiMp")
        compare(mixed.length, 1)
    }

    function test_detail_builds_from_app_object() {
        detailProbe.currentApp = {
            "id": "org.gimp.GIMP",
            "title": "GIMP",
            "description": "Editor de imagenes",
            "category": "creative",
            "origin": "Flathub",
            "version": "2.10",
            "screenshots": ["shot1", "shot2"],
            "installed": false
        }
        compare(detailProbe.appTitle, "GIMP")
        compare(detailProbe.appOrigin, Config.translated("store.origin.flathub"))
        compare(detailProbe.screenshotCount, 2)
        verify(!detailProbe.isInstalled)
        compare(detailProbe.actionLabel, Config.translated("store.install"))
    }

    function test_detail_native_origin_and_installed_state() {
        detailProbe.currentApp = {
            "id": "nimbus.calc",
            "title": "Calculadora",
            "description": "Calculadora del sistema",
            "category": "utilities",
            "origin": "Nativo",
            "version": "1.0",
            "screenshots": [],
            "installed": true
        }
        compare(detailProbe.appOrigin, Config.translated("store.origin.native"))
        verify(detailProbe.isInstalled)
        compare(detailProbe.actionLabel, Config.translated("store.uninstall"))
    }

    function test_open_app_navigates_to_detail() {
        storeProbe.backend = makeBackend()
        storeProbe.openApp("org.gimp.GIMP")
        compare(storeProbe.view, "detail")
        verify(storeProbe.currentApp !== null)
        compare(storeProbe.currentApp.id, "org.gimp.GIMP")
        storeProbe.closeDetail()
        compare(storeProbe.view, "home")
    }

    function test_install_emits_signal_with_app_id() {
        storeProbe.backend = makeBackend()
        installSpy.clear()
        storeProbe.installApp("org.gimp.GIMP")
        compare(installSpy.count, 1)
        compare(installSpy.signalArguments[0][0], "org.gimp.GIMP")
    }

    function test_uninstall_emits_signal_with_app_id() {
        storeProbe.backend = makeBackend()
        uninstallSpy.clear()
        storeProbe.uninstallApp("nimbus.calc")
        compare(uninstallSpy.count, 1)
        compare(uninstallSpy.signalArguments[0][0], "nimbus.calc")
    }

    function test_updates_view_single_button_contract() {
        // "Actualizar todo" es el unico boton: una llamada, una senal.
        updatesSpy.clear()
        updatesProbe.requestUpdateAll()
        compare(updatesSpy.count, 1)
    }

    function test_store_update_all_emits_signal() {
        storeProbe.backend = makeBackend()
        updateAllSpy.clear()
        storeProbe.updateAll()
        compare(updateAllSpy.count, 1)
    }

    function test_flatpak_unavailable_state() {
        // Sin Flatpak la tienda no se rompe: lo dice y sigue operativa.
        storeProbe.backend = makeBackend({
                                             "flatpakAvailable": function () { return false },
                                             "flatpakError": function () { return "Flatpak no disponible" },
                                             "listApps": function (category) { return [] },
                                             "listUpdates": function () { return [] }
                                         })
        storeProbe.refresh()
        verify(!storeProbe.flatpakAvailable)
        verify(storeProbe.flatpakError !== "")
        compare(storeProbe.updates.length, 0)
    }
}
