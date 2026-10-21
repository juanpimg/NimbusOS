// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Spotlight: el buscador del shell (Super+Espacio).
//
// Contenido (no ventana): en produccion `shell.qml` lo hospeda dentro de un
// `FloatingWindow` de `Quickshell.Wayland` centrado en pantalla, con
// `maxWidth: constrainedWidth(Screen.desktopAvailableWidth)` (80 % del
// ancho, tope 640) y `maxHeight` como alto (tope 420). Este fichero NO
// importa Quickshell para seguir siendo testeable con Qt Test a secas; el
// anclaje, la capa y el centrado viven en `shell.qml` y no se testean aqui.
//
// Datos: `items` es el indice buscable (lista de `{id, kind, title,
// subtitle, icon}` con `kind` en {"app", "file", "action", "calc",
// "clipboard", "emoji"}); `emojiTable` es la tabla Unicode (lista de
// `{char, name, keywords?}`, `keywords` cadena o lista); `mostUsed` son las
// aplicaciones mas usadas (mismo formato que `items`) y se muestran con la
// consulta vacia.
//
// Teclado (no testeado aqui: requiere foco de ventana real): Enter/Return
// activa el resultado seleccionado, Escape cierra, Arriba/Abajo mueve la
// seleccion. El campo de busqueda reenvia su `accepted` a
// `activateSelected()` por la misma razon.
Item {
    id: root

    property string query: ""
    property var results: []
    property var items: []
    property var emojiTable: []
    property var mostUsed: []
    property int selectedIndex: 0
    property int maxWidth: Theme.spotlightMaxWidth
    property int maxHeight: Theme.spotlightMaxHeight

    signal resultActivated(string id)
    signal closed()

    width: maxWidth
    height: maxHeight
    focus: true

    // --- Logica pura (testeada en shell/tests/tst_spotlight.qml) ---

    // 0 = coincidencia exacta, 1 = prefijo, 2 = subcadena, -1 = sin
    // coincidencia. Mira `title` y `subtitle` y se queda con la mejor.
    // `q` debe venir ya en minusculas y sin espacios laterales.
    function matchRank(title, subtitle, q) {
        var fields = [
            (title === undefined || title === null) ? "" : String(title).toLowerCase(),
            (subtitle === undefined || subtitle === null) ? "" : String(subtitle).toLowerCase()
        ]
        var best = -1
        for (var i = 0; i < fields.length; ++i) {
            if (fields[i] === q)
                return 0
            var rank = -1
            if (fields[i] !== "" && q !== "") {
                if (fields[i].indexOf(q) === 0)
                    rank = 1
                else if (fields[i].indexOf(q) !== -1)
                    rank = 2
            }
            if (rank !== -1 && (best === -1 || rank < best))
                best = rank
        }
        return best
    }

    // Filtra por `title`/`subtitle` (insensible a mayusculas) y ordena por
    // rango exacto > prefijo > subcadena, estable dentro de cada rango.
    function filterAndSort(list, query) {
        if (!Array.isArray(list) || list.length === 0)
            return []
        var q = (query === undefined || query === null) ? "" : String(query).toLowerCase().trim()
        if (q === "")
            return []
        var scored = []
        for (var i = 0; i < list.length; ++i) {
            var item = list[i]
            if (!item)
                continue
            var rank = matchRank(item.title, item.subtitle, q)
            if (rank !== -1)
                scored.push({ "item": item, "rank": rank, "idx": i })
        }
        scored.sort(function (a, b) {
            if (a.rank !== b.rank)
                return a.rank - b.rank
            return a.idx - b.idx
        })
        var out = []
        for (var k = 0; k < scored.length; ++k)
            out.push(scored[k].item)
        return out
    }

    // Parecido sintactico a expresion aritmetica: solo digitos, operadores,
    // parentesis, punto, porcentaje y espacios, con al menos un digito. No
    // garantiza que evalue (eso lo decide `evaluateCalc`).
    function isCalcQuery(text) {
        if (typeof text !== "string")
            return false
        var s = text.trim()
        if (s === "" || s.length > 200)
            return false
        if (!/^[0-9+\-*/().\s%]+$/.test(s))
            return false
        return /\d/.test(s)
    }

    // Evalua `+ - * / ( )` con precedencia, unarios y `%` como porcentaje
    // posfijo (`50%` = 0.5). Nunca lanza: cualquier entrada invalida (o la
    // division por cero) devuelve NaN en vez de un error.
    function evaluateCalc(text) {
        if (!isCalcQuery(text))
            return NaN
        var s = text.trim()
        var tokens = []
        var i = 0
        while (i < s.length) {
            var c = s[i]
            if (c === " " || c === "\t" || c === "\n") {
                i += 1
                continue
            }
            if ((c >= "0" && c <= "9") || c === ".") {
                var j = i
                var dots = 0
                while (j < s.length && ((s[j] >= "0" && s[j] <= "9") || s[j] === ".")) {
                    if (s[j] === ".")
                        dots += 1
                    j += 1
                }
                if (dots > 1)
                    return NaN
                var numStr = s.slice(i, j)
                if (numStr === "." || numStr === "")
                    return NaN
                tokens.push({ "t": "n", "v": parseFloat(numStr) })
                i = j
                continue
            }
            if ("+-*/()%".indexOf(c) !== -1) {
                tokens.push({ "t": c })
                i += 1
                continue
            }
            return NaN
        }
        if (tokens.length === 0)
            return NaN
        var pos = 0
        function peek() {
            return pos < tokens.length ? tokens[pos] : null
        }
        function consume() {
            pos += 1
        }
        function parseExpr() {
            var v = parseTerm()
            while (true) {
                var t = peek()
                if (!t || (t.t !== "+" && t.t !== "-"))
                    return v
                consume()
                var rhs = parseTerm()
                if (isNaN(v) || isNaN(rhs))
                    return NaN
                v = (t.t === "+") ? v + rhs : v - rhs
            }
        }
        function parseTerm() {
            var v = parseFactor()
            while (true) {
                var t = peek()
                if (!t || (t.t !== "*" && t.t !== "/"))
                    return v
                consume()
                var rhs = parseFactor()
                if (isNaN(v) || isNaN(rhs))
                    return NaN
                if (t.t === "*") {
                    v = v * rhs
                } else {
                    if (rhs === 0)
                        return NaN
                    v = v / rhs
                }
            }
        }
        function parseFactor() {
            var sign = 1
            var t = peek()
            while (t && (t.t === "+" || t.t === "-")) {
                if (t.t === "-")
                    sign = -sign
                consume()
                t = peek()
            }
            var v = parsePrimary()
            if (isNaN(v))
                return NaN
            v = sign * v
            t = peek()
            while (t && t.t === "%") {
                consume()
                v = v / 100
                t = peek()
            }
            return v
        }
        function parsePrimary() {
            var t = peek()
            if (!t)
                return NaN
            if (t.t === "n") {
                consume()
                return t.v
            }
            if (t.t === "(") {
                consume()
                var v = parseExpr()
                var closing = peek()
                if (!closing || closing.t !== ")")
                    return NaN
                consume()
                return v
            }
            return NaN
        }
        var result = parseExpr()
        if (isNaN(result))
            return NaN
        if (peek() !== null)
            return NaN
        if (!isFinite(result))
            return NaN
        return result
    }

    // Hasta 2 decimales, sin ceros a la derecha (`7` -> "7", `2.5` -> "2.5",
    // `0.333` -> "0.33"). No finito -> "".
    function formatNumber(value) {
        if (typeof value !== "number" || !isFinite(value))
            return ""
        var rounded = Math.round(value * 100) / 100
        if (rounded === 0)
            rounded = 0
        var s = rounded.toFixed(2)
        s = s.replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "")
        if (s === "-0")
            s = "0"
        return s
    }

    // Primer resultado cuando la consulta es una expresion valida; null si
    // no hay nada que calcular.
    function calcResult(text) {
        var v = evaluateCalc(text)
        if (typeof v !== "number" || isNaN(v) || !isFinite(v))
            return null
        var label = formatNumber(v)
        if (label === "")
            return null
        var raw = (text === undefined || text === null) ? "" : String(text).trim()
        return {
            "id": "calc:" + raw,
            "kind": "calc",
            "title": label,
            "subtitle": Config.translated("spotlight.calc"),
            "icon": ""
        }
    }

    // Filtra la tabla Unicode por nombre/palabras clave (insensible a
    // mayusculas). Devuelve resultados `{id, kind: "emoji", ...}`.
    function filterEmoji(table, query) {
        if (!Array.isArray(table) || table.length === 0)
            return []
        var q = (query === undefined || query === null) ? "" : String(query).toLowerCase().trim()
        if (q === "")
            return []
        var out = []
        for (var i = 0; i < table.length; ++i) {
            var entry = table[i]
            if (!entry || typeof entry.char !== "string" || entry.char === "")
                continue
            var name = (typeof entry.name === "string") ? entry.name : ""
            var hay = name.toLowerCase()
            if (typeof entry.keywords === "string")
                hay += " " + entry.keywords.toLowerCase()
            else if (Array.isArray(entry.keywords))
                hay += " " + entry.keywords.join(" ").toLowerCase()
            if (hay.indexOf(q) !== -1 || entry.char === q)
                out.push({
                    "id": "emoji:" + entry.char,
                    "kind": "emoji",
                    "title": entry.char,
                    "subtitle": name,
                    "icon": entry.char
                })
        }
        return out
    }

    // Aplicaciones mas usadas (consulta vacia): copia defensiva.
    function mostUsedApps() {
        if (!Array.isArray(mostUsed))
            return []
        return mostUsed.slice()
    }

    // Busqueda completa: calculadora primero, luego el indice, luego emoji.
    // Con la consulta vacia, las mas usadas.
    function search(queryText) {
        var q = (queryText === undefined || queryText === null) ? "" : String(queryText)
        if (q.trim() === "")
            return mostUsedApps()
        var out = []
        var calc = calcResult(q)
        if (calc !== null)
            out.push(calc)
        var hits = filterAndSort(items, q)
        for (var i = 0; i < hits.length; ++i)
            out.push(hits[i])
        var emojis = filterEmoji(emojiTable, q)
        for (var j = 0; j < emojis.length; ++j)
            out.push(emojis[j])
        return out
    }

    // Ancho efectivo: 80 % del disponible con tope 640. `shell.qml` lo usa
    // como `constrainedWidth(Screen.desktopAvailableWidth)`.
    function constrainedWidth(availableWidth) {
        var cap = Theme.spotlightMaxWidth
        if (typeof availableWidth !== "number" || !isFinite(availableWidth) || availableWidth <= 0)
            return cap
        return Math.min(cap, Math.floor(availableWidth * Theme.spotlightWidthRatio))
    }

    function updateResults() {
        results = search(query)
        if (results.length === 0)
            selectedIndex = -1
        else if (selectedIndex < 0 || selectedIndex >= results.length)
            selectedIndex = 0
    }

    function moveSelection(delta) {
        if (results.length === 0) {
            selectedIndex = -1
            return
        }
        var next = selectedIndex + delta
        if (next < 0)
            next = 0
        if (next >= results.length)
            next = results.length - 1
        selectedIndex = next
    }

    function activate(id) {
        if (typeof id !== "string" || id === "")
            return false
        resultActivated(id)
        return true
    }

    function activateSelected() {
        if (selectedIndex < 0 || selectedIndex >= results.length)
            return false
        var item = results[selectedIndex]
        if (!item || typeof item.id !== "string" || item.id === "")
            return false
        resultActivated(item.id)
        return true
    }

    function close() {
        closed()
    }

    onQueryChanged: updateResults()
    onItemsChanged: updateResults()
    onEmojiTableChanged: updateResults()
    onMostUsedChanged: updateResults()
    Component.onCompleted: updateResults()

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateSelected()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            root.moveSelection(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.moveSelection(-1)
            event.accepted = true
        }
    }

    // --- Vista: campo + resultados ---

    Glass {
        anchors.fill: parent
    }

    SearchField {
        id: field
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Theme.spacing
        }
        placeholder: Config.translated("spotlight.placeholder")
        Component.onCompleted: text = root.query
        onTextChanged: {
            if (root.query !== text)
                root.query = text
        }
        onAccepted: root.activateSelected()
    }

    SectionHeader {
        id: sectionHeader
        anchors {
            top: field.bottom
            left: parent.left
            right: parent.right
            margins: Theme.spacing
        }
        text: root.query.trim() === "" ? Config.translated("spotlight.mostUsed") : Config.translated("spotlight.results")
    }

    ListView {
        id: list
        anchors {
            top: sectionHeader.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: Theme.spacing
        }
        topMargin: Theme.spacing
        clip: true
        model: root.results
        delegate: ListRow {
            width: list.width
            title: modelData.title || ""
            subtitle: modelData.subtitle || ""
            icon: modelData.icon || ""
            selected: index === root.selectedIndex
            onActivated: root.activate(modelData.id)
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.results.length === 0
        text: Config.translated("spotlight.empty")
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.spacing * 2
    }
}
