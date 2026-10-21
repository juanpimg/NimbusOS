// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Ficha de aplicacion: icono, descripcion completa, capturas, origen
// (Flathub o Nativo) y el boton instalar/desinstalar. Presentacional:
// recibe `currentApp` y emite senales; `Store.qml` ejecuta la accion.
Item {
    id: root

    property var currentApp: null

    readonly property string appId: (currentApp !== null && currentApp !== undefined && currentApp.id !== undefined) ? String(currentApp.id) : ""
    readonly property string appTitle: (currentApp !== null && currentApp !== undefined && currentApp.title !== undefined) ? String(currentApp.title) : ""
    readonly property string appDescription: (currentApp !== null && currentApp !== undefined && currentApp.description !== undefined) ? String(currentApp.description) : ""
    readonly property string appVersion: (currentApp !== null && currentApp !== undefined && currentApp.version !== undefined) ? String(currentApp.version) : ""
    readonly property string appIcon: (currentApp !== null && currentApp !== undefined && currentApp.icon !== undefined) ? String(currentApp.icon) : ""
    readonly property bool isInstalled: (currentApp !== null && currentApp !== undefined && currentApp.installed === true)
    readonly property int screenshotCount: (currentApp !== null && currentApp !== undefined && Array.isArray(currentApp.screenshots)) ? currentApp.screenshots.length : 0
    readonly property string appOrigin: (currentApp !== null && currentApp !== undefined && String(currentApp.origin || "") === "Flathub") ? Config.translated("store.origin.flathub") : Config.translated("store.origin.native")
    readonly property string actionLabel: root.isInstalled ? Config.translated("store.uninstall") : Config.translated("store.install")

    signal installRequested(string appId)
    signal uninstallRequested(string appId)

    function requestInstall() {
        if (root.appId !== "")
            installRequested(root.appId)
    }

    function requestUninstall() {
        if (root.appId !== "")
            uninstallRequested(root.appId)
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacing

        Row {
            width: parent.width
            spacing: Theme.spacing * 2

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.appIcon
                size: Theme.spacing * 6
                color: Theme.text
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.spacing * 8
                spacing: 0

                Text {
                    width: parent.width
                    text: root.appTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.spacing * 3
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.appOrigin + (root.appVersion !== "" ? " — " + root.appVersion : "")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.spacing * 2
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            width: parent.width
            visible: root.appDescription !== ""
            text: root.appDescription
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            text: Config.translated("store.detail.screenshots") + ": " + root.screenshotCount
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
        }

        Button {
            text: root.actionLabel
            enabled: root.appId !== ""
            onClicked: {
                if (root.isInstalled)
                    root.requestUninstall()
                else
                    root.requestInstall()
            }
        }
    }
}
