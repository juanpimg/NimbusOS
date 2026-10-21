// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Tarjeta de un paso del tour: presentacion pura, sin logica de avance.
// Todos los textos llegan ya resueltos (Tour los traduce con `tr()`);
// todos los colores, radios y metricas salen de `Theme`.
Glass {
    id: root

    property string titleText: ""
    property string bodyText: ""
    property int position: 1
    property int total: 1
    property string stepProgress: ""
    property bool isFirst: true
    property bool isLast: false
    property string nextText: ""
    property string backText: ""
    property string skipText: ""

    signal nextRequested()
    signal prevRequested()
    signal skipRequested()

    implicitHeight: cardBody.implicitHeight + Theme.spacing * 2

    Column {
        id: cardBody
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.spacing * 2
        }
        spacing: Theme.spacing

        Text {
            width: parent.width
            text: root.titleText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            text: root.bodyText
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            wrapMode: Text.Wrap
        }

        Row {
            width: parent.width
            spacing: Theme.spacing

            Button {
                visible: !root.isFirst
                text: root.backText
                onClicked: root.prevRequested()
            }

            Button {
                text: root.nextText
                onClicked: root.nextRequested()
            }

            Button {
                text: root.skipText
                onClicked: root.skipRequested()
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: root.stepProgress
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
        }
    }
}
