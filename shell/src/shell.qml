// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Entry point loaded by `qs -c <dir>`: Quickshell looks for shell.qml
// inside the config directory, so this file must live directly in
// shell/src/ (the same directory that QML2_IMPORT_PATH points at,
// because that directory is what contains the Nimbus/ module).
Item {
    id: root
    width: 640
    height: 360

    // Design tokens come from Theme, never hardcoded here.
    property color background: Theme.background
    property int gap: Theme.spacing
    property int cornerRadius: Theme.radius

    // M0 visible window. main.qml is lowercase so it is loaded by path,
    // not as a type; Loader keeps this entry point alive even if the
    // window file ever fails to load.
    Loader {
        id: mainLoader
        source: "main.qml"
    }

    // Shell process label. Invisible in M0; routed via Config so this
    // file holds no user-facing literal.
    Text {
        id: shellLabel
        visible: false
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 16
        text: Config.translated("app.store.title")
    }
}
