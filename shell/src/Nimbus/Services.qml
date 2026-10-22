// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

// Adaptador de servicios: expone estado PLANO (bool, string, number, list)
// sin tipos de Quickshell en la API publica, para que los tests no dependan
// del framework. Sin D-Bus todo vale false/"unknown" y el shell arranca
// igual.
//
// Cableado real (M4-func): `probeServices()` intenta conectar DE VERDAD con
// cada backend de Quickshell 0.3.2 mediante creacion dinamica
// (`Qt.createQmlObject`, sin imports estaticos para seguir siendo testeable
// sin compositor). Por servicio registra en `serviceStates`:
//   "unprobed"       = aun no se ha mirado (valor inicial, NO es un estado)
//   "ready"          = backend alcanzado y funcional
//   "unavailable"    = mirado y ausente (estado legitimo: false/unknown)
//   "missing-module" = el modulo Quickshell no esta instalado aqui
// `probeAttempted` distingue "mirado" de "sin mirar"; `quickshellPresent`
// dice si ALGUN modulo respondio (en CI sin Quickshell vale false, y eso es
// un resultado valido, no un defecto).
//
// Correspondencia verificada en los .qmltypes de la ISO (Quickshell 0.3.2):
//   notifications  -> Quickshell.Services.Notifications/NotificationServer
//                     (creable; trackedNotifications; el probe conserva la
//                     instancia: el shell pasa a SER el servidor)
//   statusnotifier -> Quickshell.Services.SystemTray/SystemTray (singleton,
//                     items)
//   mpris          -> Quickshell.Services.Mpris/Mpris (singleton, players)
//   upower         -> Quickshell.Services.UPower/UPower (singleton; devices,
//                     displayDevice.percentage/isPresent, onBattery)
//   network        -> Quickshell.Networking/Networking (singleton;
//                     devices[].connected)
//   bluetooth      -> Quickshell.Bluetooth/Bluetooth (singleton;
//                     adapters[].enabled)
// Lo que sigue sin cablear (necesita imports estaticos o bus real, M2):
//   - actualizaciones EN VIVO (trackedNotificationsChanged,
//     playersChanged...): el probe toma la foto inicial; el cableado
//     continuo entrara con imports estaticos cuando haya CI con Quickshell.
//   - audio (Pipewire.ready) y polkit (PolkitAgent.isRegistered): sin props
//     planas que los consuman hoy; PolkitAgent.qml sigue en false.
QtObject {
    id: root

    property bool notificationsAvailable: false
    property bool statusNotifierAvailable: false
    property bool mprisAvailable: false
    property bool upowerAvailable: false
    property int notificationCount: 0
    property real batteryPercent: 0.0
    property bool batteryPresent: false
    property string networkState: "unknown"
    property string bluetoothState: "unknown"

    // --- Cableado real: constancia de la mirada ---

    property bool probeAttempted: false
    property bool quickshellPresent: false

    readonly property var serviceNames: ["notifications", "statusnotifier", "mpris", "upower", "network", "bluetooth"]
    readonly property var networkStates: ["unknown", "connected", "disconnected"]
    readonly property var bluetoothStates: ["unknown", "on", "off"]

    property var serviceStates: _initialServiceStates()

    // El servidor de notificaciones creado por el probe: conservarlo es lo
    // que registra al shell como servidor (destruirlo lo desregistraria).
    property var _notificationServer: null

    function _initialServiceStates() {
        var out = {}
        for (var i = 0; i < serviceNames.length; ++i)
            out[serviceNames[i]] = "unprobed"
        return out
    }

    function serviceState(name) {
        var st = serviceStates[name]
        return st === undefined ? "unknown-service" : st
    }

    function _setServiceState(name, state) {
        var next = {}
        for (var key in serviceStates)
            next[key] = serviceStates[key]
        next[name] = state
        serviceStates = next
    }

    // Crea un objeto QML dinamico; null si el modulo/tipo no existe.
    // Nunca lanza (el import puede fallar sin Quickshell instalado).
    function _tryCreate(qml) {
        var obj = null
        try {
            obj = Qt.createQmlObject(qml, root)
        } catch (e) {
            obj = null
        }
        return obj
    }

    // El modulo importa (aunque el servicio este caido): distingue
    // "sin Quickshell" de "servicio ausente".
    function _modulePresent(moduleImport) {
        var probe = _tryCreate("import " + moduleImport + "; QtObject {}")
        if (probe === null)
            return false
        quickshellPresent = true
        probe.destroy()
        return true
    }

    function probeServices() {
        _setServiceState("notifications", _probeNotifications())
        _setServiceState("statusnotifier", _probeStatusNotifier())
        _setServiceState("mpris", _probeMpris())
        _setServiceState("upower", _probeUpower())
        _setServiceState("network", _probeNetwork())
        _setServiceState("bluetooth", _probeBluetooth())
        probeAttempted = true
    }

    function _probeNotifications() {
        if (!_modulePresent("Quickshell.Services.Notifications"))
            return "missing-module"
        var srv = _tryCreate("import Quickshell.Services.Notifications; NotificationServer {}")
        if (srv === null)
            return "unavailable"
        _notificationServer = srv
        notificationsAvailable = true
        return "ready"
    }

    function _probeStatusNotifier() {
        if (!_modulePresent("Quickshell.Services.SystemTray"))
            return "missing-module"
        var probe = _tryCreate("import Quickshell.Services.SystemTray; QtObject { property var items: SystemTray.items }")
        if (probe === null)
            return "unavailable"
        var ok = probe.items !== undefined && probe.items !== null
        probe.destroy()
        statusNotifierAvailable = ok
        return ok ? "ready" : "unavailable"
    }

    function _probeMpris() {
        if (!_modulePresent("Quickshell.Services.Mpris"))
            return "missing-module"
        var probe = _tryCreate("import Quickshell.Services.Mpris; QtObject { property var players: Mpris.players }")
        if (probe === null)
            return "unavailable"
        var ok = probe.players !== undefined && probe.players !== null
        probe.destroy()
        mprisAvailable = ok
        return ok ? "ready" : "unavailable"
    }

    function _probeUpower() {
        if (!_modulePresent("Quickshell.Services.UPower"))
            return "missing-module"
        var probe = _tryCreate("import Quickshell.Services.UPower; QtObject {"
                               + " property var display: UPower.displayDevice; "
                               + " property bool battery: UPower.onBattery }")
        if (probe === null)
            return "unavailable"
        var display = probe.display
        var present = display !== undefined && display !== null && display.isPresent === true
        if (present) {
            batteryPresent = true
            batteryPercent = display.percentage
        }
        probe.destroy()
        upowerAvailable = present
        return present ? "ready" : "unavailable"
    }

    function _probeNetwork() {
        if (!_modulePresent("Quickshell.Networking"))
            return "missing-module"
        var probe = _tryCreate("import Quickshell.Networking; QtObject { property var devices: Networking.devices }")
        if (probe === null)
            return "unavailable"
        var found = false
        var up = false
        try {
            var devs = probe.devices
            if (devs !== undefined && devs !== null && devs.length !== undefined) {
                found = devs.length > 0
                for (var i = 0; i < devs.length; ++i) {
                    if (devs[i] && devs[i].connected === true)
                        up = true
                }
            }
        } catch (e) {
            found = false
        }
        probe.destroy()
        if (!found)
            return "unavailable"
        networkState = up ? "connected" : "disconnected"
        return "ready"
    }

    function _probeBluetooth() {
        if (!_modulePresent("Quickshell.Bluetooth"))
            return "missing-module"
        var probe = _tryCreate("import Quickshell.Bluetooth; QtObject { property var adapters: Bluetooth.adapters }")
        if (probe === null)
            return "unavailable"
        var found = false
        var on = false
        try {
            var list = probe.adapters
            if (list !== undefined && list !== null && list.length !== undefined) {
                found = list.length > 0
                for (var i = 0; i < list.length; ++i) {
                    if (list[i] && list[i].enabled === true)
                        on = true
                }
            }
        } catch (e) {
            found = false
        }
        probe.destroy()
        if (!found)
            return "unavailable"
        bluetoothState = on ? "on" : "off"
        return "ready"
    }

    // Fallback local: sin servicio de notificaciones, se cuenta igual para
    // que las superficies (campana, centro) no dependan del backend.
    function notify(title, body) {
        notificationCount += 1
    }

    function clearNotifications() {
        notificationCount = 0
    }
}
