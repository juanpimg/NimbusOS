// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Selector de fondos del shell.
//
// Contenido (no ventana): en produccion `shell.qml` lo hospeda dentro de un
// `FloatingWindow` (`import Quickshell.Wayland`), que se muestra/oculta con
// `ShellController.wallpaperOpen` y responde a `Ipc.call("wallpaper", ...)`
// (`toggle`/`open`/`close` pasan por el controlador; `next`/`prev` llegan
// como `surfaceRequested("wallpaper", fn)`). Este fichero NO importa
// Quickshell para seguir siendo testeable con Qt Test a secas.
//
// Modelo: `wallpapers` es una lista de `{path, name, dark, light}` donde
// `path` es la variante por defecto (la oscura si existe), `name` el nombre
// base sin sufijo, y `dark`/`light` las variantes (`""` si no existe). Los
// pares claro/oscuro (`nombre-Light.png` / `nombre.png`) se ofrecen como
// UNA sola entrada con dos variantes, nunca como dos entradas sueltas.
//
// Origenes: `refresh(bundled, userNames)` combina las rutas empaquetadas
// (rutas completas) con los ficheros de la carpeta del usuario (`folder`,
// por defecto `~/Pictures/Wallpapers`). La lectura real del directorio
// (fuera de QML puro) la hace `shell.qml` e inyecta los nombres aqui; por
// eso `entriesFromDirectory(dir, names)` recibe el directorio inyectado y
// el test usa uno temporal sin tocar el disco del usuario.
Item {
    id: root

    property var wallpapers: []
    property string selected: ""
    property string folder: "~/Pictures/Wallpapers"
    property var bundledPaths: []

    signal chosen(string path)
    signal closed()

    readonly property var imageExtensions: ["png", "jpg", "jpeg", "webp", "avif", "bmp", "tif", "tiff", "jxl"]

    implicitWidth: Theme.spacing * 75
    implicitHeight: Theme.spacing * 50

    // --- Logica pura (testeada en tst_wallpaper.qml) ---

    function fileName(path) {
        var p = (typeof path === "string") ? path : ""
        var i = p.lastIndexOf("/")
        return (i === -1) ? p : p.slice(i + 1)
    }

    function dirOf(path) {
        var p = (typeof path === "string") ? path : ""
        var i = p.lastIndexOf("/")
        return (i === -1) ? "" : p.slice(0, i)
    }

    function extensionOf(path) {
        var name = fileName(path)
        var i = name.lastIndexOf(".")
        if (i <= 0 || i === name.length - 1)
            return ""
        return name.slice(i + 1).toLowerCase()
    }

    function isImage(path) {
        return imageExtensions.indexOf(extensionOf(path)) !== -1
    }

    function stemOf(path) {
        var name = fileName(path)
        var i = name.lastIndexOf(".")
        if (i <= 0)
            return name
        return name.slice(0, i)
    }

    // Variante clara: el stem termina en "-Light" (insensible a mayusculas).
    function isLightVariant(path) {
        var stem = stemOf(path)
        return stem.length > 6 && stem.slice(-6).toLowerCase() === "-light"
    }

    // Nombre base sin el sufijo de variante clara.
    function baseOf(path) {
        var stem = stemOf(path)
        if (isLightVariant(path))
            return stem.slice(0, -6)
        return stem
    }

    // Agrupa rutas en entradas `{path, name, dark, light}`, una por par
    // claro/oscuro, ordenadas por nombre. Ignora lo que no sea imagen.
    // La clave incluye el directorio para no fusionar homonimos de
    // carpetas distintas (empaquetados frente a usuario).
    function groupPairs(paths) {
        var list = Array.isArray(paths) ? paths : []
        var order = []
        var byKey = ({})
        for (var i = 0; i < list.length; ++i) {
            var p = list[i]
            if (typeof p !== "string" || p === "" || !isImage(p))
                continue
            var key = dirOf(p) + "\n" + baseOf(p).toLowerCase()
            var e = byKey[key]
            if (e === undefined) {
                e = { "path": "", "name": baseOf(p), "dark": "", "light": "" }
                byKey[key] = e
                order.push(e)
            }
            if (isLightVariant(p)) {
                if (e.light === "")
                    e.light = p
            } else {
                if (e.dark === "")
                    e.dark = p
            }
        }
        for (var j = 0; j < order.length; ++j) {
            var en = order[j]
            en.path = (en.dark !== "") ? en.dark : en.light
        }
        order.sort(function (a, b) {
            var an = a.name.toLowerCase()
            var bn = b.name.toLowerCase()
            if (an < bn)
                return -1
            if (an > bn)
                return 1
            if (a.path < b.path)
                return -1
            if (a.path > b.path)
                return 1
            return 0
        })
        return order
    }

    // Construye entradas a partir de un directorio inyectado y sus nombres
    // de fichero. El directorio se inyecta para que el test use uno
    // temporal en lugar de la carpeta real del usuario.
    function entriesFromDirectory(dir, names) {
        if (typeof dir !== "string" || !Array.isArray(names))
            return []
        var prefix = dir
        if (prefix !== "" && prefix.charAt(prefix.length - 1) !== "/")
            prefix += "/"
        var paths = []
        for (var i = 0; i < names.length; ++i) {
            if (typeof names[i] !== "string" || names[i] === "")
                continue
            paths.push(prefix + names[i])
        }
        return groupPairs(paths)
    }

    // Variante preferida de una entrada segun el modo ("light"/"dark"):
    // cae a la variante existente si la pedida no existe.
    function preferredPath(entry, mode) {
        if (!entry || typeof entry.path !== "string")
            return ""
        if (mode === "dark")
            return entry.dark !== "" ? entry.dark : entry.light
        return entry.light !== "" ? entry.light : entry.dark
    }

    function indexOf(path) {
        for (var i = 0; i < wallpapers.length; ++i) {
            if (wallpapers[i].path === path)
                return i
        }
        return -1
    }

    // Recarga la galeria: empaquetados (rutas completas) mas la carpeta del
    // usuario (nombres inyectados por `shell.qml`). Devuelve el total y
    // deja `selected` en una entrada valida. No emite: elegir es explicito.
    function refresh(bundled, userNames) {
        var b = Array.isArray(bundled) ? bundled : root.bundledPaths
        var u = Array.isArray(userNames) ? userNames : []
        var userPaths = []
        var prefix = (typeof folder === "string") ? folder : ""
        if (prefix !== "" && prefix.charAt(prefix.length - 1) !== "/")
            prefix += "/"
        for (var i = 0; i < u.length; ++i) {
            if (typeof u[i] !== "string" || u[i] === "")
                continue
            userPaths.push(prefix + u[i])
        }
        wallpapers = groupPairs(b.slice().concat(userPaths))
        if (wallpapers.length === 0) {
            selected = ""
            return 0
        }
        if (indexOf(selected) === -1)
            selected = wallpapers[0].path
        return wallpapers.length
    }

    function _select(path) {
        selected = path
        chosen(path)
        return path
    }

    // Elige un fondo de la galeria. Emite `chosen(path)`.
    function choose(path) {
        if (typeof path !== "string" || path === "" || indexOf(path) === -1)
            return false
        _select(path)
        return true
    }

    function _step(delta) {
        if (wallpapers.length === 0)
            return ""
        var idx = indexOf(selected)
        var target = 0
        if (idx === -1)
            target = (delta > 0) ? 0 : wallpapers.length - 1
        else
            target = (idx + delta + wallpapers.length) % wallpapers.length
        return _select(wallpapers[target].path)
    }

    // Cambian de fondo (ciclicos) y emiten `chosen(path)`.
    function next() {
        return _step(1)
    }

    function prev() {
        return _step(-1)
    }

    // Cierra el selector. Emite `closed()`; `shell.qml` lo traduce a
    // `ShellController.close("wallpaper")`.
    function close() {
        closed()
    }

    function variantLabel(entry) {
        if (!entry)
            return ""
        var hasDark = entry.dark !== ""
        var hasLight = entry.light !== ""
        if (hasDark && hasLight)
            return Config.translated("wallpaper.light") + " + " + Config.translated("wallpaper.dark")
        if (hasLight)
            return Config.translated("wallpaper.light")
        return Config.translated("wallpaper.dark")
    }

    // --- Vista: galeria con pares agrupados ---

    Column {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.spacing * 2
        spacing: Theme.spacing

        SectionHeader {
            width: parent.width
            text: Config.translated("wallpaper.title")
        }

        Text {
            width: parent.width
            visible: root.wallpapers.length === 0
            text: Config.translated("wallpaper.empty")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            wrapMode: Text.Wrap
        }

        Grid {
            id: gallery
            width: parent.width
            columns: 3
            spacing: Theme.spacing

            Repeater {
                id: entryRepeater
                model: root.wallpapers
                delegate: Rectangle {
                    width: (gallery.width - gallery.spacing * 2) / 3
                    height: Theme.spacing * 12
                    radius: Theme.radius
                    color: Theme.surfaceAlt
                    border.color: modelData.path === root.selected ? Theme.accent : Theme.separator
                    border.width: modelData.path === root.selected ? 2 : 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing
                        spacing: Theme.spacing / 2

                        Text {
                            width: parent.width
                            text: modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.spacing * 2
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.variantLabel(modelData)
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.spacing * 2
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.choose(modelData.path)
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacing

            Button {
                text: Config.translated("wallpaper.previous")
                onClicked: root.prev()
            }

            Button {
                text: Config.translated("wallpaper.next")
                onClicked: root.next()
            }

            Item {
                width: Theme.spacing
                height: 1
            }

            Button {
                text: Config.translated("wallpaper.close")
                onClicked: root.close()
            }
        }
    }
}
