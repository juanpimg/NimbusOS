import QtQuick
import QtQuick.Layouts

// UserSelector — lista de usuarios (F2-T02). En SDDM real se alimenta de
// userModel (role name/realName/icon); `users` es inyectable para preview.
// Sin QtQuick.Controls: el delegado es Rectangle+MouseArea (el `Button` de
// Controls/SddmComponents rompía la carga en el greeter real).
ColumnLayout {
    id: root

    property var users: []
    property int currentIndex: 0
    property string textColor: "#FFFFFF"
    property string fontFamily: "Inter"

    signal userSelected(int index)

    spacing: 8

    Repeater {
        model: root.users

        delegate: Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
            Layout.preferredHeight: 44
            radius: 10
            color: index === root.currentIndex ? "#0A84FF" : "transparent"
            opacity: (index === root.currentIndex ? 0.9 : 1) - (pressArea.pressed ? 0.15 : 0)
            border.color: "#EBEBF5"
            border.width: index === root.currentIndex ? 0 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: "#2C2C2E"
                    opacity: 0.85

                    Text {
                        anchors.centerIn: parent
                        text: (modelData.realName || modelData.name || "?").charAt(0).toUpperCase()
                        color: "#FFFFFF"
                        font.family: root.fontFamily
                        font.pixelSize: 15
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.realName || modelData.name || ""
                    color: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: pressArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.currentIndex = index;
                    root.userSelected(index);
                }
            }
        }
    }
}
