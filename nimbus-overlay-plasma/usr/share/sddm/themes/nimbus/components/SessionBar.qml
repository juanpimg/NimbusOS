import QtQuick
import QtQuick.Layouts

// SessionBar — selector de sesión + teclado + apagar/reiniciar (F2-T02).
// `sessions`/`keyboards` inyectables para preview; en SDDM real vienen de
// sessionModel / layouts del daemon.
// Sin QtQuick.Controls: los ComboBox se sustituyen por selectores cíclicos
// (clic = siguiente opción) y los botones por NimbusButton. El `ComboBox`/
// `Button` de Controls rompía la carga en el greeter real.
ColumnLayout {
    id: root

    property var sessions: []
    property var keyboards: []
    property int sessionIndex: 0
    property int keyboardIndex: 0
    property string textColor: "#FFFFFF"
    property string fontFamily: "Inter"

    signal sessionSelected(int index)
    signal powerRequested(string action)

    spacing: 8

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        // Selector de sesión (clic = siguiente).
        Rectangle {
            Layout.preferredWidth: 168
            Layout.preferredHeight: 32
            radius: 8
            color: "#1C1C1E"
            opacity: 0.9
            border.color: "#38383A"
            border.width: 1

            Text {
                anchors.centerIn: parent
                width: parent.width - 16
                text: root.sessions.length > 0 ? (root.sessions[Math.min(root.sessionIndex, root.sessions.length - 1)].name || "") : ""
                color: "white"
                font.family: root.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.sessions.length > 1) {
                        root.sessionIndex = (root.sessionIndex + 1) % root.sessions.length;
                        root.sessionSelected(root.sessionIndex);
                    }
                }
            }
        }

        // Selector de teclado (clic = siguiente; oculto si no hay layouts).
        Rectangle {
            Layout.preferredWidth: 104
            Layout.preferredHeight: 32
            visible: root.keyboards.length > 0
            radius: 8
            color: "#1C1C1E"
            opacity: 0.9
            border.color: "#38383A"
            border.width: 1

            Text {
                anchors.centerIn: parent
                width: parent.width - 16
                text: root.keyboards.length > 0 ? String(root.keyboards[Math.min(root.keyboardIndex, root.keyboards.length - 1)]) : ""
                color: "white"
                font.family: root.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.keyboards.length > 1)
                        root.keyboardIndex = (root.keyboardIndex + 1) % root.keyboards.length;
                }
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        NimbusButton {
            text: "Reiniciar"
            fontFamily: root.fontFamily
            fontSize: 13
            flat: true
            implicitWidth: 90
            implicitHeight: 30
            onClicked: root.powerRequested("reboot")
        }

        NimbusButton {
            text: "Apagar"
            fontFamily: root.fontFamily
            fontSize: 13
            flat: true
            implicitWidth: 90
            implicitHeight: 30
            onClicked: root.powerRequested("poweroff")
        }
    }
}
