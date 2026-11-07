// Main.qml — greeter SDDM Nimbus (F2-T02). Layout centrado estilo login macOS:
// fondo NPS a pantalla completa, reloj arriba, tarjeta glass centrada con
// avatar+usuario, contraseña, selector de sesión/teclado y apagar/reiniciar.
// Tokens: NimbusTokens (copia md5-idéntica de packages/themes/nimbus-tokens).

import QtQuick
import QtQuick.Layouts
import "components"

// NimbusOS Ruling (F2-T02): el tema SOLO usa QtQuick (+Layouts) y tipos
// propios (`components/`). Nada de `SddmComponents 2.0` ni de
// `QtQuick.Controls`: el greeter real resolvía `Button` a un tipo sin
// `contentItem`/`background` y la carga abortaba entera ("Cannot assign to
// non-existent property", línea 158 en VM) => pantalla negra. Botones,
// campo de contraseña y selectores son Rectangle+MouseArea+Text/TextInput.
// Los context properties (`sddm`, `config`, `userModel`, `sessionModel`)
// los inyecta el greeter y no requieren import.
Rectangle {
    id: root

    width: 1920
    height: 1080
    color: "black"

    // Fondo propio NPS (R-APPLE). `config.background` = Background.jpg.
    Image {
        id: bg

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: config.background
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.25
    }

    // Reloj superior (solo visual, como el login macOS).
    LoginClock {
        anchors.top: parent.top
        anchors.topMargin: 64
        anchors.horizontalCenter: parent.horizontalCenter
        clock24h: config.clock24h === "false" ? false : true
        fontFamily: NimbusTokens.fontFamily
        textColor: NimbusTokens.colors(true).label
    }

    // Tarjeta glass centrada.
    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 360
        height: loginLayout.implicitHeight + 48
        radius: NimbusTokens.radii.rLg
        color: NimbusTokens.colors(true).bgElevated
        opacity: 0.78
        border.color: "#EBEBF5"
        border.width: 1

        ColumnLayout {
            id: loginLayout

            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 12

            // Avatar + nombre del usuario actual.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 72
                height: 72
                radius: 36
                color: "#3A3A3C"

                Text {
                    anchors.centerIn: parent
                    text: userList.users.length > 0 ? userList.currentUserName().charAt(0).toUpperCase() : "?"
                    color: "white"
                    font.family: NimbusTokens.fontFamily
                    font.pixelSize: 28
                }
            }

            Text {
                id: userName

                Layout.alignment: Qt.AlignHCenter
                text: userList.users.length > 0 ? userList.currentUserName() : ""
                color: NimbusTokens.colors(true).label
                font.family: NimbusTokens.fontFamily
                font.pixelSize: NimbusTokens.type.t17.size
            }

            // Selector de usuario (userModel del daemon).
            UserSelector {
                id: userList

                function currentUserName() {
                    if (users.length === 0)
                        return "";

                    var u = users[currentIndex];
                    return u.realName || u.name;
                }

                Layout.alignment: Qt.AlignHCenter
                fontFamily: NimbusTokens.fontFamily
                textColor: NimbusTokens.colors(true).label
                Component.onCompleted: {
                    // UserModel (SDDM 0.21): NameRole=UserRole+1, RealNameRole=+2.
                    var arr = [];
                    for (var i = 0; i < userModel.count; i++)
                        arr.push({
                            "name": userModel.data(userModel.index(i, 0), Qt.UserRole + 1),
                            "realName": userModel.data(userModel.index(i, 0), Qt.UserRole + 2)
                        });
                    users = arr;
                }
                onUserSelected: function (i) {
                    userModel.lastIndex = i;
                }
            }

            // Campo de contraseña (TextInput propio, sin Controls).
            Item {
                id: pwField

                property alias text: pwInput.text

                function forceActiveFocus() {
                    pwInput.forceActiveFocus();
                }

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 280
                Layout.preferredHeight: 36

                Rectangle {
                    anchors.fill: parent
                    radius: NimbusTokens.radii.rMd
                    color: "#1C1C1E"
                    opacity: 0.9
                    border.color: pwInput.activeFocus ? NimbusTokens.colors(true).accent : "#38383A"
                    border.width: pwInput.activeFocus ? 2 : 1
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pwInput.text === ""
                    text: "Contraseña"
                    color: "#8E8E93"
                    font.family: NimbusTokens.fontFamily
                    font.pixelSize: NimbusTokens.type.t15.size
                }

                TextInput {
                    id: pwInput

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: "white"
                    font.family: NimbusTokens.fontFamily
                    font.pixelSize: NimbusTokens.type.t15.size
                    focus: true
                    selectByMouse: true
                    onAccepted: loginButton.clicked()
                    // macOS: Esc limpia el campo y devuelve el foco al botón
                    // de login; no interfiere con Enter (onAccepted).
                    Keys.onEscapePressed: {
                        pwInput.text = "";
                        failLabel.text = "";
                        loginButton.forceActiveFocus();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: Qt.IBeamCursor
                    onPressed: function (mouse) {
                        mouse.accepted = false;
                        pwInput.forceActiveFocus();
                    }
                }
            }

            Text {
                id: failLabel

                Layout.alignment: Qt.AlignHCenter
                visible: text !== ""
                color: NimbusTokens.colors(true).destructive
                font.family: NimbusTokens.fontFamily
                font.pixelSize: NimbusTokens.type.t13.size
            }

            NimbusButton {
                id: loginButton

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 280
                Layout.preferredHeight: 36
                text: "Iniciar sesión"
                fontFamily: NimbusTokens.fontFamily
                fontSize: NimbusTokens.type.t15.size
                bg: NimbusTokens.colors(true).accent
                radius: NimbusTokens.radii.rMd
                onClicked: sddm.login(userModel.data(userModel.index(userList.currentIndex, 0), Qt.UserRole + 1), pwField.text, sessionBar.sessionIndex)
            }

            // Sesión + teclado + apagar/reiniciar.
            SessionBar {
                id: sessionBar

                Layout.alignment: Qt.AlignHCenter
                fontFamily: NimbusTokens.fontFamily
                textColor: NimbusTokens.colors(true).label
                Component.onCompleted: {
                    var s = [];
                    for (var i = 0; i < sessionModel.count; i++)
                        s.push({
                            "name": sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 4)
                        });
                    sessions = s;
                    sessionIndex = sessionModel.lastIndex;
                }
                onSessionSelected: function (i) {
                    sessionModel.lastIndex = i;
                }
                onPowerRequested: function (action) {
                    if (action === "reboot")
                        sddm.reboot();
                    else
                        sddm.powerOff();
                }
            }
        }
    }

    Connections {
        function onLoginSucceeded() {
            failLabel.text = "";
        }

        function onLoginFailed() {
            failLabel.text = "Contraseña incorrecta, inténtalo de nuevo";
            pwField.text = "";
            pwField.focus = true;
        }

        target: sddm
    }
}
