// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import Nimbus

// Entry point loaded by `qs -c <dir>`: Quickshell looks for shell.qml
// inside the config directory, so this file lives directly in shell/src/
// (the same directory that QML2_IMPORT_PATH points at, because that
// directory is what contains the Nimbus/ module).
ShellRoot {
    id: root

    // M0: the shell has no surfaces yet. The M0 placeholder is a fullscreen
    // window managed by Quickshell, not a loose QtQuick Window: surfaces
    // are created by PanelWindow, not Window.
    PanelWindow {
        id: placeholder
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Theme.background

        Text {
            anchors.centerIn: parent
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            text: Config.translated("app.store.title")
        }
    }
}
