// SPDX-License-Identifier: GPL-3.0-or-later
// Tema SDDM de Nimbus: pantalla de inicio propia y funcional.
//
// Usa el API real del greeter de SDDM (`sddm.login`, `userModel`,
// `sessionModel`, `config`): nada de senales propias sin daemon. Arte
// original del proyecto (background.svg, logo.svg, avatar-placeholder.svg
// se empaquetan junto a este fichero desde installer/greeter). La
// contrasena se emite a sddm.login y se descarta de inmediato; un intento
// fallido muestra el error en el sitio sin borrar el usuario.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string currentUser: ""
    property int sessionIndex: 0
    property bool passwordWrong: false
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        ignoreUnknownSignals: true
        function onLoginFailed() {
            passwordField.text = ""
            root.passwordWrong = true
        }
    }

    function submitLogin() {
        if (root.currentUser === "" || passwordField.text === "") {
            return
        }
        root.passwordWrong = false
        sddm.login(root.currentUser, passwordField.text, root.sessionIndex)
        passwordField.text = ""
    }

    // Fondo: arte propio de Nimbus con velo oscuro para el contraste.
    Image {
        anchors.fill: parent
        source: typeof config !== "undefined" && config.background !== "" ? config.background : "background.svg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.35
    }

    Component.onCompleted: {
        // Preselecciona al usuario nimbus y su sesion si existen.
        if (typeof userModel !== "undefined" && userModel.count > 0) {
            var lastIndex = userModel.lastIndex >= 0 ? userModel.lastIndex : 0
            var pending = userModel.data(userModel.index(lastIndex, 0), 0)
            if (pending !== undefined && pending !== "") {
                root.currentUser = pending
            }
        }
        if (typeof sessionModel !== "undefined") {
            // Preselecciona la sesion de Nimbus por su nombre visible, sin
            // suponer numeros de rol del modelo (API privada de SDDM).
            var idx = sessionCombo.find("Nimbus")
            if (idx !== -1) {
                sessionCombo.currentIndex = idx
                root.sessionIndex = idx
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 48
        spacing: 16

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "logo.svg"
            sourceSize.width: 72
            sourceSize.height: 72
            fillMode: Image.PreserveAspectFit
            Accessible.name: qsTr("Nimbus")
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(root.now, Qt.locale(), Locale.ShortFormat)
            color: "white"
            font.family: "Inter"
            font.pixelSize: 96
            font.weight: Font.Light
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDate(root.now, Qt.locale(), Locale.LongFormat)
            color: "#e6e6e6"
            font.family: "Inter"
            font.pixelSize: 28
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        ListView {
            id: userList
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 360
            Layout.preferredHeight: Math.min(280, count * 72)
            model: typeof userModel !== "undefined" ? userModel : null
            clip: true
            spacing: 8
            currentIndex: -1
            delegate: ItemDelegate {
                width: userList.width
                height: 64
                highlighted: root.currentUser !== "" && root.currentUser === model.name
                onClicked: {
                    root.currentUser = model.name
                    root.passwordWrong = false
                    passwordField.forceActiveFocus()
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 12
                    Image {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        source: model.icon !== undefined && model.icon !== "" ? "file://" + model.icon : "avatar-placeholder.svg"
                        fillMode: Image.PreserveAspectCrop
                        onStatusChanged: {
                            if (status === Image.Error) {
                                source = "avatar-placeholder.svg"
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: model.realName !== undefined && model.realName !== "" ? model.realName : display
                        color: "white"
                        font.family: "Inter"
                        font.pixelSize: 18
                        elide: Text.ElideRight
                    }
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 360
            spacing: 8
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.currentUser
                color: "#e6e6e6"
                font.family: "Inter"
                font.pixelSize: 16
                visible: root.currentUser !== ""
            }
            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: qsTr("Enter password")
                echoMode: TextInput.Password
                passwordMaskDelay: 0
                enabled: root.currentUser !== ""
                font.family: "Inter"
                font.pixelSize: 18
                onAccepted: root.submitLogin()
                onTextChanged: {
                    if (root.passwordWrong) {
                        root.passwordWrong = false
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: root.passwordWrong
                text: qsTr("Incorrect password. Try again.")
                color: "#ff8080"
                font.family: "Inter"
                font.pixelSize: 15
            }
            ComboBox {
                id: sessionCombo
                Layout.fillWidth: true
                model: typeof sessionModel !== "undefined" ? sessionModel : null
                textRole: "name"
                font.family: "Inter"
                onCurrentIndexChanged: root.sessionIndex = currentIndex
            }
            Button {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Log In")
                enabled: root.currentUser !== "" && passwordField.text !== ""
                font.family: "Inter"
                onClicked: root.submitLogin()
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Button {
                text: qsTr("Reboot")
                font.family: "Inter"
                onClicked: sddm.reboot()
            }
            Button {
                text: qsTr("Shut down")
                font.family: "Inter"
                onClicked: sddm.powerOff()
            }
        }
    }
}
