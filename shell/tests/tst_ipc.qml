// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Ipc"
    when: true

    function test_known_targets_are_accepted() {
        Ipc.call("dock", "toggle")
        compare(Ipc.lastTarget, "dock")
        compare(Ipc.lastFunction, "toggle")
    }

    function test_unknown_target_is_rejected_without_throwing() {
        // Regla documentada: un target desconocido no lanza y no cambia
        // lastTarget/lastFunction. Se fija primero un estado bueno para
        // poder comprobar que no cambia (comparar contra "" solo seria
        // valido si el bus partiese de vacio, cosa que el runner no garantiza).
        Ipc.call("dock", "toggle")
        Ipc.call("noexiste", "toggle")
        compare(Ipc.lastTarget, "dock")
        compare(Ipc.lastFunction, "toggle")
    }

    function test_unknown_function_for_a_known_target_is_rejected() {
        Ipc.call("dock", "toggle")
        Ipc.call("dock", "volando")
        compare(Ipc.lastTarget, "dock")
        compare(Ipc.lastFunction, "toggle")
    }

    function test_every_documented_target_is_present() {
        // NOTA: el ejemplo del brief llama a "toggle" en los 12 targets,
        // pero la tabla solo admite "toggle" en 6 de ellos. Aqui se comprueba
        // cada target con una de SUS funciones validas; la tabla completa
        // funcion por funcion se comprueba en test_full_function_table.
        var valid = {
            "dock": "toggle",
            "spotlight": "toggle",
            "switcher": "next",
            "screenshot": "region",
            "quicklook": "toggle",
            "wallpaper": "next",
            "controlcenter": "toggle",
            "notifications": "toggle",
            "settings": "open",
            "store": "open",
            "tour": "start",
            "lock": "lock"
        }
        var targets = ["dock", "spotlight", "switcher", "screenshot", "quicklook", "wallpaper",
                       "controlcenter", "notifications", "settings", "store", "tour", "lock"]
        for (var i = 0; i < targets.length; i++) {
            Ipc.call(targets[i], valid[targets[i]])
            compare(Ipc.lastTarget, targets[i], "target desconocido: " + targets[i])
            compare(Ipc.lastFunction, valid[targets[i]])
        }
    }

    function test_full_function_table_is_accepted() {
        var table = {
            "dock": ["toggle", "open", "close"],
            "spotlight": ["toggle", "open", "close", "apps", "files"],
            "switcher": ["next", "prev", "commit", "cancel"],
            "screenshot": ["region", "window", "screen"],
            "quicklook": ["toggle", "open", "close"],
            "wallpaper": ["toggle", "open", "close", "next", "prev"],
            "controlcenter": ["toggle", "open", "close"],
            "notifications": ["toggle", "clear"],
            "settings": ["open"],
            "store": ["open"],
            "tour": ["start"],
            "lock": ["lock"]
        }
        var targets = ["dock", "spotlight", "switcher", "screenshot", "quicklook", "wallpaper",
                       "controlcenter", "notifications", "settings", "store", "tour", "lock"]
        for (var i = 0; i < targets.length; i++) {
            var fns = table[targets[i]]
            for (var j = 0; j < fns.length; j++) {
                Ipc.call(targets[i], fns[j])
                compare(Ipc.lastTarget, targets[i])
                compare(Ipc.lastFunction, fns[j])
            }
        }
    }
}
