// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Pantalla de bloqueo del shell.
//
// Contenido (no ventana): en produccion `shell.qml` lo hospeda a pantalla
// completa por encima de todo (capa de bloqueo), visible mientras
// `locked` sea true. Este fichero NO importa Quickshell para seguir siendo
// testeable con Qt Test a secas.
//
// NO TESTEADO AQUI (requiere compositor o servicios reales):
// - La capa de pantalla completa y el atajo `Ctrl+Alt+L` (los monta
//   `shell.qml` sobre Hyprland).
// - La autenticacion PAM (`Quickshell.Services.Pam`): `shell.qml`
//   conecta `unlockRequested(password)` al backend PAM e inyecta el
//   resultado con `reportAuthResult(ok, message)`.
// - Los controles multimedia reales (Mpris esta en
//   `Quickshell.Services`): `shell.qml` inyecta el estado con
//   `updateNowPlaying(info)` y consume `mediaRequested(action)`.
//
// SEGURIDAD: la contrasena NUNCA se guarda. `attemptUnlock(password)`
// la emite via `unlockRequested` y la descarta: vacia el campo y no la
// deja en ninguna property. Tras la llamada, ningun estado del
// componente contiene la contrasena.
//
// Si la autenticacion falla, `reportAuthResult(false)` muestra el error
// en el sitio (`authError`, visible junto al campo) y la pantalla SIGUE
// bloqueada (`locked` no cambia, `passwordWrong` queda en true).
Item {
    id: root

    property bool locked: true
    property bool busy: false
    property bool passwordWrong: false
    property string time: ""
    property string date: ""
    property string authError: ""
    property string trackTitle: ""
    property string trackArtist: ""
    property bool playing: false

    // Texto del campo de contrasena (estado transitorio de la UI, como
    // `SearchField.text`): se vacia al emitir y al bloquear. Nunca se
    // enlaza, registra ni propaga a otro estado.
    property alias passwordText: passwordField.text

    signal unlockRequested(string password)
    signal sessionActionRequested(string action)
    signal mediaRequested(string action)

    readonly property var sessionActions: ["lock", "suspend", "logout", "reboot", "shutdown"]
    readonly property var mediaActions: ["playpause", "next", "previous"]

    implicitWidth: Theme.spacing * 60
    implicitHeight: Theme.spacing * 75

    // --- Logica testeable (tst_wallpaper.qml) ---

    // Emite la contrasena y la descarta. Sin argumento, lee el campo.
    // Devuelve false (sin emitir) si esta vacia. Nunca la retiene.
    function attemptUnlock(password) {
        var pw = (typeof password === "string") ? password : passwordField.text
        passwordField.text = ""
        if (pw === "")
            return false
        passwordWrong = false
        authError = ""
        busy = true
        unlockRequested(pw)
        return true
    }

    // Resultado de PAM (inyectado por `shell.qml`). Con exito desbloquea;
    // con fallo marca `passwordWrong`, muestra el error en el sitio y la
    // pantalla sigue bloqueada.
    function reportAuthResult(ok, message) {
        passwordField.text = ""
        if (ok) {
            busy = false
            passwordWrong = false
            authError = ""
            locked = false
            return true
        }
        busy = false
        passwordWrong = true
        locked = true
        if (typeof message === "string" && message !== "")
            authError = message
        else
            authError = Config.translated("lockscreen.wrongPassword")
        return false
    }

    // Vuelve a bloquear y limpia todo rastro del intento anterior.
    function lock() {
        passwordField.text = ""
        busy = false
        passwordWrong = false
        authError = ""
        locked = true
    }

    // Acciones de sesion validadas: solo emite las conocidas.
    function requestSessionAction(action) {
        if (sessionActions.indexOf(action) === -1)
            return false
        sessionActionRequested(action)
        return true
    }

    // Controles multimedia validados (el cableado Mpris lo pone shell.qml).
    function requestMedia(action) {
        if (mediaActions.indexOf(action) === -1)
            return false
        mediaRequested(action)
        return true
    }

    // Inyecta el estado multimedia (Mpris, via `shell.qml`).
    function updateNowPlaying(info) {
        var data = (info !== undefined && info !== null) ? info : ({})
        trackTitle = (typeof data.title === "string") ? data.title : ""
        trackArtist = (typeof data.artist === "string") ? data.artist : ""
        playing = !!data.playing
    }

    // Reloj. Sin argumento usa la hora actual (el `Timer` de la vista lo
    // llama cada 30 s); con argumento es puro y testeable.
    function updateClock(when) {
        var d = (when instanceof Date) ? when : new Date()
        time = Qt.formatTime(d, "hh:mm")
        date = d.toLocaleDateString()
    }

    function trackLabel() {
        if (trackTitle === "" && trackArtist === "")
            return Config.translated("lockscreen.noTrack")
        if (trackArtist === "")
            return trackTitle
        if (trackTitle === "")
            return trackArtist
        return trackArtist + " — " + trackTitle
    }

    // --- Vista: reloj grande, multimedia, contrasena, acciones ---

    Timer {
        id: clockTimer
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.updateClock(new Date())
    }

    Component.onCompleted: updateClock(new Date())

    Column {
        id: layout
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.spacing * 4, Theme.spacing * 60)
        spacing: Theme.spacing * 2

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.time
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 9
            font.weight: Font.Light
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.date
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.trackLabel()
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            elide: Text.ElideRight
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing

            Button {
                text: Config.translated("lockscreen.previousTrack")
                onClicked: root.requestMedia("previous")
            }

            Button {
                text: root.playing ? Config.translated("lockscreen.pause") : Config.translated("lockscreen.play")
                onClicked: root.requestMedia("playpause")
            }

            Button {
                text: Config.translated("lockscreen.nextTrack")
                onClicked: root.requestMedia("next")
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.spacing * 30
                height: Theme.barHeight
                radius: Theme.radius
                color: Theme.surface
                border.color: root.passwordWrong ? Theme.accent : Theme.separator
                border.width: 1

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacing
                    anchors.rightMargin: Theme.spacing
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.spacing * 2
                    onAccepted: root.attemptUnlock(passwordField.text)
                }
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                text: Config.translated("lockscreen.unlock")
                onClicked: root.attemptUnlock(passwordField.text)
            }
        }

        Text {
            width: parent.width
            visible: root.passwordWrong
            horizontalAlignment: Text.AlignHCenter
            text: root.authError
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            wrapMode: Text.Wrap
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing

            Button {
                text: Config.translated("lockscreen.lock")
                onClicked: root.requestSessionAction("lock")
            }

            Button {
                text: Config.translated("lockscreen.suspend")
                onClicked: root.requestSessionAction("suspend")
            }

            Button {
                text: Config.translated("lockscreen.logout")
                onClicked: root.requestSessionAction("logout")
            }

            Button {
                text: Config.translated("lockscreen.reboot")
                onClicked: root.requestSessionAction("reboot")
            }

            Button {
                text: Config.translated("lockscreen.shutdown")
                onClicked: root.requestSessionAction("shutdown")
            }
        }
    }
}
