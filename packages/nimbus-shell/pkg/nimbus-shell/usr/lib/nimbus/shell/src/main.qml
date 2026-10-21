// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

Window {
    width: 640
    height: 360
    visible: true
    color: Theme.background
    title: qsTr("Nimbus")
    Text {
        anchors.centerIn: parent
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 16
        text: Config.translated("app.store.title")
    }
}
