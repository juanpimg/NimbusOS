// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

// Portada de la tienda: buscador, categorias y lista de aplicaciones.
// Presentacional: recibe datos y emite senales; `Store.qml` la cablea.
Item {
    id: root

    property var categories: []
    property string currentCategory: ""
    property var apps: []
    property string query: ""

    signal categorySelected(string category)
    signal appSelected(string appId)
    signal searchChanged(string query)

    Column {
        anchors.fill: parent
        spacing: Theme.spacing

        SearchField {
            id: search
            width: parent.width
            placeholder: Config.translated("store.search.placeholder")
            text: root.query
            onAccepted: function (value) { root.searchChanged(value) }
        }

        SectionHeader {
            width: parent.width
            text: Config.translated("store.categories.title")
        }

        Row {
            width: parent.width
            spacing: Theme.spacing
            Repeater {
                model: root.categories
                delegate: Button {
                    required property var modelData
                    text: modelData.title || ""
                    onClicked: root.categorySelected(modelData.id || "")
                }
            }
        }

        Text {
            width: parent.width
            visible: root.apps.length === 0
            text: Config.translated("store.home.empty")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.spacing * 2
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.apps
            delegate: ListRow {
                required property var modelData
                anchors {
                    left: parent.left
                    right: parent.right
                }
                title: modelData.title || ""
                subtitle: modelData.description || ""
                icon: modelData.icon || ""
                onActivated: root.appSelected(modelData.id || "")
            }
        }
    }
}
