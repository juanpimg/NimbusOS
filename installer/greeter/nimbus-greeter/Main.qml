// SPDX-License-Identifier: GPL-3.0-or-later
// Nimbus greeter theme for SDDM: a plain QtQuick Item.
// Contract: pick a user, type the password, the password is emitted
// through loginRequested() and immediately discarded. A failed attempt
// shows the error inline and keeps the selected user.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string currentUser: ""
    property bool passwordWrong: false
    property bool busy: false
    property date now: new Date()

    signal loginRequested(string user, string password)
    signal rebootRequested()
    signal shutdownRequested()

    // The daemon glue calls this after a failed attempt; it must only
    // flag the error, never clear the selected user.
    function notifyLoginFailed() {
        passwordWrong = true
    }

    function submitLogin() {
        if (currentUser === "" || busy) {
            return
        }
        passwordWrong = false
        loginRequested(currentUser, passwordField.text)
        passwordField.text = ""
    }

    onPasswordWrongChanged: {
        if (passwordWrong) {
            passwordField.forceActiveFocus()
            passwordField.selectAll()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Background: Nimbus gradient artwork with a dark overlay for contrast.
    Image {
        id: backgroundArt
        anchors.fill: parent
        source: config.background
        // theme.conf [General] background.
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.35
    }

    Component.onCompleted: {
        // Preselect the last user SDDM reports, so typing + Enter just works.
        if (typeof userModel !== "undefined" && userModel.count > 0) {
            const lastIndex = userModel.lastIndex >= 0 ? userModel.lastIndex : 0
            const pending = userModel.data(userModel.index(lastIndex, 0), 0)
            if (pending !== undefined && pending !== "") {
                currentUser = pending
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 48
        spacing: 16

        // Nimbus brand mark (original artwork, logo.svg).
        Image {
            id: nimbusLogo
            Layout.alignment: Qt.AlignHCenter
            source: config.logo // theme.conf [General] logo.
            sourceSize.width: 72
            sourceSize.height: 72
            fillMode: Image.PreserveAspectFit
            Accessible.name: qsTr("Nimbus")
        }

        // Big clock, formatted with the system locale.
        // Visible via theme.conf [General] showClock.
        Text {
            id: clockLabel
            Layout.alignment: Qt.AlignHCenter
            visible: config.showClock !== "false"
            text: Qt.formatTime(root.now, Qt.locale(), Locale.ShortFormat)
            color: "white"
            font.family: config.font // theme.conf [General] font (Inter).
            font.pixelSize: 96
            font.weight: Font.Light
            Accessible.name: clockLabel.text
        }

        // Localised date line under the clock.
        // Visible via theme.conf [General] showDate.
        Text {
            id: dateLabel
            Layout.alignment: Qt.AlignHCenter
            visible: config.showDate !== "false"
            text: Qt.formatDate(root.now, Qt.locale(), Locale.LongFormat)
            color: "#e6e6e6"
            font.family: config.font // theme.conf [General] font (Inter).
            font.pixelSize: 28
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        // User list with avatars; a missing avatar falls back to the placeholder.
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
                id: userDelegate
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
                        id: avatarImage
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        source: model.icon !== undefined && model.icon !== "" ? "file://" + model.icon : config.avatarPlaceholder
                        fillMode: Image.PreserveAspectCrop
                        // Never break on a missing avatar: fall back to the placeholder.
                        onStatusChanged: {
                            if (status === Image.Error) {
                                source = config.avatarPlaceholder
                            }
                        }
                        Accessible.name: display
                    }
                    Label {
                        Layout.fillWidth: true
                        text: model.realName !== undefined && model.realName !== "" ? model.realName : display
                        color: "white"
                        font.family: config.font // theme.conf [General] font (Inter).
                        font.pixelSize: 18
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Password prompt for the selected user.
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 360
            spacing: 8
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.currentUser
                color: "#e6e6e6"
                font.family: config.font // theme.conf [General] font (Inter).
                font.pixelSize: 16
                visible: root.currentUser !== ""
            }
            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: qsTr("Enter password")
                echoMode: TextInput.Password
                passwordMaskDelay: 0
                enabled: !root.busy && root.currentUser !== ""
                font.family: config.font // theme.conf [General] font (Inter).
                font.pixelSize: 18
                onAccepted: root.submitLogin()
                onTextChanged: {
                    if (root.passwordWrong) {
                        root.passwordWrong = false
                    }
                }
            }
            // Inline error: shown in place, the user selection is kept.
            Label {
                id: passwordError
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: root.passwordWrong
                text: qsTr("Incorrect password. Try again.")
                color: "#ff8080"
                font.family: config.font // theme.conf [General] font (Inter).
                font.pixelSize: 15
            }
            Button {
                id: loginButton
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Log In")
                enabled: !root.busy && root.currentUser !== "" && passwordField.text !== ""
                font.family: config.font // theme.conf [General] font (Inter).
                onClicked: root.submitLogin()
            }
            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: root.busy
                visible: root.busy
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        // Power actions.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Button {
                text: qsTr("Reboot")
                font.family: config.font // theme.conf [General] font (Inter).
                enabled: !root.busy
                onClicked: root.rebootRequested()
            }
            Button {
                text: qsTr("Shut down")
                font.family: config.font // theme.conf [General] font (Inter).
                enabled: !root.busy
                onClicked: root.shutdownRequested()
            }
        }
    }
}
