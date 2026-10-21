// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

QtObject {
    property var table: ({
        "es": {
            "app.store.title": "Nimbus Store",
            "app.settings.title": "Ajustes del sistema",
            "app.dock.title": "Dock",
            "app.dock.trash": "Papelera",
            "auth.title": "Autenticación",
            "auth.prompt": "Escribe tu contraseña",
            "auth.unavailable": "Autenticación no disponible",
            "notifications.title": "Notificaciones",
            "notifications.empty": "No hay notificaciones",
            "notifications.clear": "Limpiar",
            "notifications.dnd": "No molestar",
            "notifications.more": "Más",
            "notifications.dismiss": "Descartar",
            "notifications.daemonUnavailable": "Servicio de notificaciones no disponible"
        },
        "en": {
            "app.store.title": "Nimbus Store",
            "app.settings.title": "System Settings",
            "app.dock.title": "Dock",
            "app.dock.trash": "Trash",
            "auth.title": "Authentication",
            "auth.prompt": "Enter your password",
            "auth.unavailable": "Authentication unavailable",
            "notifications.title": "Notifications",
            "notifications.empty": "No notifications",
            "notifications.clear": "Clear",
            "notifications.dnd": "Do not disturb",
            "notifications.more": "More",
            "notifications.dismiss": "Dismiss",
            "notifications.daemonUnavailable": "Notification service unavailable"
        }
    })

    function lookup(locale, key) {
        var lang = String(locale || "en").split("-")[0]
        if (table[lang] && table[lang][key] !== undefined)
            return table[lang][key]
        if (table["en"] && table["en"][key] !== undefined)
            return table["en"][key]
        return key
    }
}
