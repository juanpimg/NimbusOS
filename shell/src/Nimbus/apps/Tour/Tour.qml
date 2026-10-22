// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Tour de bienvenida (primer arranque): la guia de 2 minutos.
//
// Contenido (no ventana): en produccion `shell.qml` lo hospeda dentro de un
// `FloatingWindow` centrado, que ademas dibuja el resaltado del `target`
// del paso actual; por eso este fichero NO importa Quickshell y sigue
// siendo testeable con Qt Test a secas. El montaje en ventana real vive en
// `shell.qml` (ver informe de Task 12) y se documenta como no testeado.
//
// Modelo: `steps` es una lista de `{id, title, body, target, anchor}`
// donde `title`/`body` son claves de traduccion. `tr()` resuelve primero
// con `Config.translated` y, si la clave aun no esta en
// `Translations.qml`, con la tabla local ES/EN de respaldo
// (`localStrings`); las claves a registrar en `Translations.qml` y en el
// `qmldir` estan declaradas en el informe de Task 12.
//
// Persistencia: al terminar o saltar, el tour se marca en la propiedad
// local `completed` y, si existe, en `Config.tourCompleted` (acceso
// protegido porque `Config` aun no declara la clave; ver informe). Con
// `completed` en true, `shouldShow()` es false y el tour no se repite.
//
// NOTA DE API: el spec pide `property bool finished` y `signal finished()`;
// ambos nombres no pueden coexistir en QML (la emision `finished()`
// resuelve a la propiedad y lanza `TypeError`, y qmllint avisa
// duplicated-name). Se mantiene la propiedad `finished` y la señal de
// finalizacion se llama `tourFinished()`; `skipped()` conserva su nombre.
Item {
    // Tamano FIJO: la ventana flotante toma el del contenido, y el contenido
    // no se ancla a la ventana (si se anclara, la circularidad haria que la
    // ventana creciera hasta el tamano de la pantalla).
    width: Theme.tourCardWidth
    height: Theme.tourCardHeight
    implicitWidth: Theme.tourCardWidth
    implicitHeight: Theme.tourCardHeight

    id: root

    // Ocho pasos: dock, Spotlight, menu superior, Centro de Control,
    // notificaciones, atajos de teclado, modo juego y cierre.
    property var steps: [
        { "id": "dock", "title": "tour.step.dock.title", "body": "tour.step.dock.body", "target": "dock", "anchor": "bottom" },
        { "id": "spotlight", "title": "tour.step.spotlight.title", "body": "tour.step.spotlight.body", "target": "spotlight", "anchor": "center" },
        { "id": "menubar", "title": "tour.step.menubar.title", "body": "tour.step.menubar.body", "target": "bar", "anchor": "top" },
        { "id": "controlcenter", "title": "tour.step.controlcenter.title", "body": "tour.step.controlcenter.body", "target": "controlcenter", "anchor": "topRight" },
        { "id": "notifications", "title": "tour.step.notifications.title", "body": "tour.step.notifications.body", "target": "notifications", "anchor": "topRight" },
        { "id": "shortcuts", "title": "tour.step.shortcuts.title", "body": "tour.step.shortcuts.body", "target": "", "anchor": "center" },
        { "id": "gameready", "title": "tour.step.gameready.title", "body": "tour.step.gameready.body", "target": "", "anchor": "center" },
        { "id": "goodbye", "title": "tour.step.goodbye.title", "body": "tour.step.goodbye.body", "target": "", "anchor": "center" }
    ]
    property int index: 0
    property bool finished: false
    property bool completed: false

    // Guardas de emision unica (testeadas en tst_tour.qml).
    property bool _finishedEmitted: false
    property bool _skippedEmitted: false

    signal tourFinished()
    signal skipped()

    // Respaldo ES/EN hasta que `Translations.qml` incluya estas claves.
    // Cada cuerpo tiene 16 palabras o menos (limite del spec: 30).
    property var localStrings: ({
        "es": {
            "tour.step.dock.title": "El Dock, tu base",
            "tour.step.dock.body": "El Dock guarda tus apps favoritas. Haz clic para abrir y arrastra para añadir o quitar.",
            "tour.step.spotlight.title": "Busca con Spotlight",
            "tour.step.spotlight.body": "Pulsa Cmd Espacio para buscar apps, archivos y ajustes al instante desde Spotlight.",
            "tour.step.menubar.title": "El menú superior",
            "tour.step.menubar.body": "El menú superior muestra la hora, la red y la batería. Haz clic para ver detalles.",
            "tour.step.controlcenter.title": "Centro de Control",
            "tour.step.controlcenter.body": "El Centro de Control reúne wifi, sonido y brillo en un solo panel rápido.",
            "tour.step.notifications.title": "Notificaciones",
            "tour.step.notifications.body": "Las notificaciones aparecen arriba a la derecha. Ábrelas desde la campana del menú.",
            "tour.step.shortcuts.title": "Atajos de teclado",
            "tour.step.shortcuts.body": "Cambia de app con Cmd Tab y de escritorio con Ctrl Flechas. Rápido y sin ratón.",
            "tour.step.gameready.title": "Modo juego",
            "tour.step.gameready.body": "El modo juego prioriza tu partida con baja latencia y máximo rendimiento automático.",
            "tour.step.goodbye.title": "Listo para empezar",
            "tour.step.goodbye.body": "Ya estás listo. Explora Nimbus a tu ritmo y vuelve al tour desde Ajustes.",
            "tour.next": "Siguiente",
            "tour.back": "Atrás",
            "tour.skip": "Saltar tour",
            "tour.finish": "Terminar"
        },
        "en": {
            "tour.step.dock.title": "Meet the Dock",
            "tour.step.dock.body": "The Dock holds your favourite apps. Click to open, drag to add or remove.",
            "tour.step.spotlight.title": "Search with Spotlight",
            "tour.step.spotlight.body": "Press Cmd Space to instantly search apps, files and settings with Spotlight.",
            "tour.step.menubar.title": "The top menu",
            "tour.step.menubar.body": "The top menu shows time, network and battery. Click any icon for details.",
            "tour.step.controlcenter.title": "Control Center",
            "tour.step.controlcenter.body": "Control Center puts wifi, sound and brightness together in one quick panel.",
            "tour.step.notifications.title": "Notifications",
            "tour.step.notifications.body": "Notifications appear at the top right. Open them from the menu bell.",
            "tour.step.shortcuts.title": "Keyboard shortcuts",
            "tour.step.shortcuts.body": "Switch apps with Cmd Tab and desktops with Ctrl Arrows. Fast without a mouse.",
            "tour.step.gameready.title": "Game mode",
            "tour.step.gameready.body": "Game mode boosts your play with low latency and automatic peak performance.",
            "tour.step.goodbye.title": "Ready to go",
            "tour.step.goodbye.body": "You are ready. Explore Nimbus at your pace and revisit the tour from Settings.",
            "tour.next": "Next",
            "tour.back": "Back",
            "tour.skip": "Skip tour",
            "tour.finish": "Finish"
        }
    })

    focus: true
    Keys.onEscapePressed: function (event) { handleKey(Qt.Key_Escape); event.accepted = true }
    Keys.onReturnPressed: function (event) { handleKey(Qt.Key_Return); event.accepted = true }
    Keys.onEnterPressed: function (event) { handleKey(Qt.Key_Enter); event.accepted = true }
    Keys.onSpacePressed: function (event) { handleKey(Qt.Key_Space); event.accepted = true }

    Component.onCompleted: loadPersisted()

    // --- Texto (testeado en tst_tour.qml) ---

    function localeTag() {
        return String(Config.locale || "es").split("-")[0]
    }

    // Primero `Config.translated` (gana cuando `Translations.qml`
    // incluya las claves); si devuelve la clave tal cual, respaldo local.
    function tr(key) {
        var via = Config.translated(key)
        if (via !== key)
            return via
        var tag = localeTag()
        var table = localStrings[tag]
        if (table === undefined)
            table = localStrings["en"]
        if (table !== undefined && table[key] !== undefined)
            return table[key]
        if (table !== localStrings["en"] && localStrings["en"][key] !== undefined)
            return localStrings["en"][key]
        return key
    }

    function stepTitleAt(i) {
        if (typeof i !== "number" || i < 0 || i >= steps.length)
            return ""
        return tr(steps[i].title)
    }

    function stepBodyAt(i) {
        if (typeof i !== "number" || i < 0 || i >= steps.length)
            return ""
        return tr(steps[i].body)
    }

    function wordCount(text) {
        if (typeof text !== "string")
            return 0
        var parts = text.split(/\s+/)
        var n = 0
        for (var k = 0; k < parts.length; ++k)
            if (parts[k] !== "")
                n += 1
        return n
    }

    // --- Avance puro (testeado en tst_tour.qml) ---

    function peekNext(from) {
        if (!Array.isArray(steps) || steps.length === 0)
            return 0
        var f = (typeof from === "number" && from >= 0) ? Math.floor(from) % steps.length : index
        return (f + 1) % steps.length
    }

    function peekPrev(from) {
        if (!Array.isArray(steps) || steps.length === 0)
            return 0
        var n = steps.length
        var f = (typeof from === "number" && from >= 0) ? Math.floor(from) % n : index
        return (f - 1 + n) % n
    }

    function isLast() {
        return steps.length > 0 && index >= steps.length - 1
    }

    function shouldShow() {
        return !completed && !finished
    }

    function nextLabel() {
        return isLast() ? tr("tour.finish") : tr("tour.next")
    }

    function progressText() {
        return (index + 1) + " / " + steps.length
    }

    // --- Mutaciones de estado ---

    // Avanza; en el ultimo paso finaliza (emite `tourFinished` una vez).
    function advance() {
        if (_finishedEmitted || finished)
            return false
        if (steps.length === 0 || index >= steps.length - 1) {
            finish()
            return true
        }
        index = peekNext(index)
        return true
    }

    function previous() {
        if (finished || _finishedEmitted)
            return false
        if (index > 0)
            index -= 1
        return true
    }

    // `Esc`: salta el tour y emite `skipped()` una sola vez.
    function skip() {
        if (_skippedEmitted)
            return false
        _skippedEmitted = true
        markCompleted()
        visible = false
        skipped()
        return true
    }

    function finish() {
        if (_finishedEmitted)
            return false
        _finishedEmitted = true
        finished = true
        markCompleted()
        visible = false
        tourFinished()
        return true
    }

    // Entrada de teclado testeable (`Esc` salta, `Enter` avanza).
    function handleKey(key) {
        if (key === Qt.Key_Escape) {
            skip()
            return true
        }
        if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
            advance()
            return true
        }
        return false
    }

    // Marca el tour como completado: estado local siempre y, si existe,
    // `Config.tourCompleted` (acceso protegido hasta que `Config`
    // declare la clave; ver informe). Nunca lanza.
    function markCompleted() {
        completed = true
        try {
            if (typeof Config.tourCompleted !== "undefined")
                Config.tourCompleted = true
        } catch (e) {
        }
    }

    function loadPersisted() {
        var v = undefined
        try {
            v = Config.tourCompleted
        } catch (e) {
            v = undefined
        }
        if (v === true) {
            completed = true
            visible = false
        }
    }

    // Ayuda de aislamiento para los tests (no usada en produccion).
    function reset() {
        index = 0
        finished = false
        completed = false
        _finishedEmitted = false
        _skippedEmitted = false
        visible = true
    }

    // --- Vista: tarjeta centrada del paso actual ---

    TourStep {
        id: card
        anchors.centerIn: parent
        width: Theme.notificationWidth
        titleText: root.stepTitleAt(root.index)
        bodyText: root.stepBodyAt(root.index)
        position: root.index + 1
        total: root.steps.length
        stepProgress: root.progressText()
        isFirst: root.index === 0
        isLast: root.isLast()
        nextText: root.nextLabel()
        backText: root.tr("tour.back")
        skipText: root.tr("tour.skip")
        onNextRequested: root.advance()
        onPrevRequested: root.previous()
        onSkipRequested: root.skip()
    }
}
