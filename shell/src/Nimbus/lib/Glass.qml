// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Superficie de cristal del shell. En M1 usa un color plano (tint cuando hay
// compositor, Theme.glassOpaque como fallback); el punto de extension
// `shaderEnabled` queda reservado para el blur por shader de M2.
// Si no hay compositor (`translucent: false`) la superficie sigue siendo
// legible con Theme.glassOpaque: nunca hay pantalla negra.
Rectangle {
    id: root

    property bool translucent: true
    property int blurRadius: 40
    property color tint: Theme.glass
    property bool shaderEnabled: false
    readonly property bool graphicsAvailable: typeof Qt.application !== "undefined" && Qt.application !== null

    color: root.translucent && root.graphicsAvailable ? root.tint : Theme.glassOpaque
    radius: Theme.radius
    clip: true
}
