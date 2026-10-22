// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts

// Diapositiva unica del instalador de Nimbus. Sin arte de terceros: el
// fondo es un degradado con los colores de la paleta de Nimbus.
Rectangle {
    id: root
    color: "#1C1C1E"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0A2A6B" }
            GradientStop { position: 0.55; color: "#3B2C8C" }
            GradientStop { position: 1.0; color: "#0B0B12" }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Nimbus"
            color: "#F5F5F7"
            font.pixelSize: 64
            font.weight: Font.Light
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Instalando Nimbus"
            color: "#F5F5F7"
            font.pixelSize: 22
        }
    }
}
