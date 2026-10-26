/* NimbusOS Calamares slideshow — estilo Setup Assistant.
 * slideshowAPI 2: Presentation con 4 slides ("Hello").
 * Reutiliza la paleta #F5F5F7/#1D1D1F/#007AFF + Inter y el wallpaper
 * canonico de Task 1 (/usr/share/backgrounds/nimbus/sequoia-light.jpg,
 * aprovisionado por Task 5; si falta, el fondo liso lo sustituye).
 */
import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        id: advanceTimer
        interval: 15000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#F5F5F7"

            Column {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Hello."
                    font.family: "Inter"
                    font.pixelSize: 64
                    color: "#1D1D1F"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Bienvenido a NimbusOS."
                    font.family: "Inter"
                    font.pixelSize: 24
                    color: "#1D1D1F"
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#F5F5F7"

            Column {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Rápido y familiar."
                    font.family: "Inter"
                    font.pixelSize: 48
                    color: "#1D1D1F"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Hyprland con estética Mac, dock y atajos Super."
                    font.family: "Inter"
                    font.pixelSize: 22
                    color: "#007AFF"
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#F5F5F7"

            Column {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Spaces y Spotlight."
                    font.family: "Inter"
                    font.pixelSize: 48
                    color: "#1D1D1F"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Varios escritorios y búsqueda al instante."
                    font.family: "Inter"
                    font.pixelSize: 22
                    color: "#007AFF"
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#F5F5F7"

            Column {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Sentate y relajate."
                    font.family: "Inter"
                    font.pixelSize: 48
                    color: "#1D1D1F"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Estamos instalando NimbusOS en tu equipo."
                    font.family: "Inter"
                    font.pixelSize: 22
                    color: "#1D1D1F"
                }
            }
        }
    }
}
