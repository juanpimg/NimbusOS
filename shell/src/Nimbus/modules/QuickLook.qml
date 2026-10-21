// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// QuickLook: previsualizacion de archivos del gestor.
// Se abre con la barra espaciadora sobre un archivo y se cierra con Esc.
//
// Contenido (no ventana): en produccion `shell.qml` lo hospeda dentro
// de un `FloatingWindow` centrado; el visor de PDF del sistema y la
// carga real de imagenes viven en ese hospedaje y se documentan como
// no testados aqui. Este fichero NO importa Quickshell para seguir
// siendo testeable con Qt Test a secas.
//
// `kind` se deduce de la extension (funcion pura `kindForPath`) y los
// textos se recortan a las primeras lineas (funcion pura `firstLines`):
// imagen y PDF muestran previsualizacion, texto muestra las primeras
// lineas, `unknown` muestra un mensaje con el nombre del archivo.
Item {
    id: root

    visible: false
    // `shown` es el espejo testeable de `visible`: bajo qmltestrunner
    // los Item sin ventana leen `visible === false` aunque se haya puesto
    // a true, asi que la logica y los tests usan `shown`; en produccion
    // (FloatingWindow con ventana) ambos van a la par.
    property bool shown: false
    property string path: ""
    property string title: ""
    property string kind: "unknown"
    property string textPreview: ""
    property int previewMaxLines: 20

    signal closed()

    readonly property var imageExtensions: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "tif", "tiff", "ico", "heic", "avif"]
    readonly property var textExtensions: ["txt", "md", "markdown", "log", "json", "yaml", "yml", "toml", "ini", "cfg", "conf", "csv", "tsv", "sh", "py", "js", "ts", "qml", "c", "h", "hpp", "cpp", "rs", "go", "lua", "css", "html", "xml", "tex"]

    // Nombre base de una ruta. Funcion pura.
    function fileNameFor(filePath) {
        if (typeof filePath !== "string" || filePath === "")
            return ""
        var clean = filePath.charAt(filePath.length - 1) === "/" ? filePath.slice(0, -1) : filePath
        var slash = clean.lastIndexOf("/")
        return slash === -1 ? clean : clean.slice(slash + 1)
    }

    // Deduce el kind por extension (insensible a mayusculas). Sin
    // extension o con extension desconocida devuelve "unknown".
    // Funcion pura (testeada en tst_capture.qml).
    function kindForPath(filePath) {
        if (typeof filePath !== "string" || filePath === "")
            return "unknown"
        var name = fileNameFor(filePath)
        var dot = name.lastIndexOf(".")
        if (dot === -1 || dot === name.length - 1)
            return "unknown"
        var ext = name.slice(dot + 1).toLowerCase()
        if (ext === "pdf")
            return "pdf"
        if (imageExtensions.indexOf(ext) !== -1)
            return "image"
        if (textExtensions.indexOf(ext) !== -1)
            return "text"
        return "unknown"
    }

    // Recorta un texto a sus primeras `maxLines` lineas. Funcion pura
    // (testeada en tst_capture.qml).
    function firstLines(content, maxLines) {
        if (typeof content !== "string" || content === "")
            return ""
        var limit = (maxLines === undefined) ? previewMaxLines : maxLines
        if (!(limit > 0))
            return ""
        var lines = content.split("\n")
        var kept = []
        for (var i = 0; i < lines.length && i < limit; ++i)
            kept.push(lines[i].replace(/\r$/, ""))
        return kept.join("\n")
    }

    // Guarda la previsualizacion de un texto (ya recortada).
    function setTextContent(content) {
        textPreview = firstLines(content, previewMaxLines)
    }

    // Abre la previsualizacion de un archivo. Una ruta vacia se ignora
    // (devuelve false) sin tocar el estado.
    function open(filePath) {
        if (typeof filePath !== "string" || filePath === "")
            return false
        path = filePath
        title = fileNameFor(filePath)
        kind = kindForPath(filePath)
        if (kind !== "text")
            textPreview = ""
        shown = true
        visible = true
        return true
    }

    // Cierra la previsualizacion y emite `closed()`.
    function close() {
        if (!shown)
            return false
        shown = false
        visible = false
        closed()
        return true
    }

    // Teclado del gestor de archivos: Espacio abre sobre el archivo
    // enfocado, Esc cierra. Devuelve true si consumo la tecla.
    function handleKey(key, focusedPath) {
        if (key === Qt.Key_Space && typeof focusedPath === "string" && focusedPath !== "")
            return open(focusedPath)
        if (key === Qt.Key_Escape && shown) {
            close()
            return true
        }
        return false
    }

    // Atiende `Ipc.call("quicklook", ...)`: toggle/open muestran,
    // close cierra.
    Connections {
        target: ShellController
        function onSurfaceRequested(surface, argument) {
            if (surface !== "quicklook")
                return
            if (argument === "close")
                root.close()
            else if (argument === "toggle") {
                if (root.shown)
                    root.close()
                else {
                    root.shown = true
                    root.visible = true
                }
            } else if (argument === "open") {
                root.shown = true
                root.visible = true
            }
        }
    }

    // --- Vista: tarjeta centrada con la previsualizacion ---

    Glass {
        anchors.centerIn: parent
        visible: root.visible
        // Sin token propio en Theme (M1), se reutiliza el ancho maximo de
        // dialogo centrado; el resto de metricas salen de Theme.spacing.
        width: Math.min(parent.width - Theme.spacing * 4, Theme.spotlightMaxWidth)
        implicitHeight: previewBody.implicitHeight + Theme.spacing * 2

        Column {
            id: previewBody
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.spacing
            }
            spacing: Theme.spacing

            SectionHeader {
                width: parent.width
                text: root.title !== "" ? root.title : Config.translated("quicklook.title")
            }

            Image {
                width: parent.width
                visible: root.kind === "image" && root.path !== ""
                source: root.kind === "image" && root.path !== "" ? "file://" + root.path : ""
                fillMode: Image.PreserveAspectFit
            }

            Text {
                width: parent.width
                visible: root.kind === "pdf"
                text: Config.translated("quicklook.pdfHint")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.kind === "text"
                text: root.textPreview !== "" ? root.textPreview : Config.translated("quicklook.textEmpty")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.kind === "unknown"
                text: Config.translated("quicklook.unknownHint") + " " + root.title
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: root.path !== "" && root.kind !== "unknown"
                text: Config.translated("quicklook.openHint")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.spacing * 2
                elide: Text.ElideMiddle
            }

            Button {
                text: Config.translated("quicklook.close")
                onClicked: root.close()
            }
        }
    }
}
