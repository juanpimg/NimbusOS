// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

// Propietario de que superficie esta abierta. REGLA DE EXCLUSIVIDAD: solo
// una superficie puede estar abierta a la vez; `open(surface)` cierra la
// anterior. Los nombres sin booleano dedicado (p. ej. "settings") se
// gestionan de forma generica via `activeSurface`.
QtObject {
    id: root

    property bool dockOpen: false
    property bool spotlightOpen: false
    property bool controlCenterOpen: false
    property bool switcherOpen: false
    property bool quickLookOpen: false
    property bool wallpaperOpen: false
    property bool notificationsOpen: false
    property string activeSurface: ""

    signal surfaceRequested(string surface, string argument)

    function _apply(surface, open) {
        switch (surface) {
        case "dock":
            dockOpen = open
            break
        case "spotlight":
            spotlightOpen = open
            break
        case "controlcenter":
            controlCenterOpen = open
            break
        case "switcher":
            switcherOpen = open
            break
        case "quicklook":
            quickLookOpen = open
            break
        case "wallpaper":
            wallpaperOpen = open
            break
        case "notifications":
            notificationsOpen = open
            break
        default:
            break
        }
    }

    function _isOpen(surface) {
        switch (surface) {
        case "dock":
            return dockOpen
        case "spotlight":
            return spotlightOpen
        case "controlcenter":
            return controlCenterOpen
        case "switcher":
            return switcherOpen
        case "quicklook":
            return quickLookOpen
        case "wallpaper":
            return wallpaperOpen
        case "notifications":
            return notificationsOpen
        default:
            return surface !== "" && activeSurface === surface
        }
    }

    function open(surface) {
        if (typeof surface !== "string" || surface === "")
            return
        closeAll()
        _apply(surface, true)
        activeSurface = surface
        surfaceRequested(surface, "open")
    }

    function close(surface) {
        if (typeof surface !== "string" || surface === "")
            return
        _apply(surface, false)
        if (activeSurface === surface)
            activeSurface = ""
        surfaceRequested(surface, "close")
    }

    function toggle(surface) {
        if (typeof surface !== "string" || surface === "")
            return
        if (_isOpen(surface))
            close(surface)
        else
            open(surface)
    }

    function closeAll() {
        dockOpen = false
        spotlightOpen = false
        controlCenterOpen = false
        switcherOpen = false
        quickLookOpen = false
        wallpaperOpen = false
        notificationsOpen = false
        activeSurface = ""
    }
}
