import QtQuick
import QtQuick.Layouts

// NimbusButton — botón propio sin QtQuick.Controls (F2-T02).
// NimbusOS Ruling: el greeter real resolvía `Button` a un tipo sin
// `contentItem`/`background` (pantalla negra); Rectangle+MouseArea+Text
// no depende de ningún módulo salvo QtQuick.
Item {
    id: root

    property string text: ""
    property string fontFamily: "Inter"
    property int fontSize: 15
    property color bg: "#0A84FF"
    property color fg: "white"
    property int radius: 10
    property bool flat: false

    signal clicked

    implicitWidth: 280
    implicitHeight: 36
    // Hacerlo visible para qmllint (Layout lo dimensiona igual).
    width: implicitWidth
    height: implicitHeight
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.flat ? "transparent" : root.bg
        opacity: root.flat ? 1 : (pressArea.pressed ? 0.75 : (pressArea.containsMouse ? 0.9 : 1))
        border.color: root.flat ? "transparent" : root.bg
    }

    Text {
        anchors.centerIn: parent
        text: root.text
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: pressArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
