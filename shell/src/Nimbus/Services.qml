// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

// Adaptador de servicios: expone estado PLANO (bool, string, number, list)
// sin tipos de Quickshell en la API publica, para que los tests no dependan
// del framework. Sin D-Bus todo vale false/"unknown" y el shell arranca
// igual; el cableado a los servicios reales (Notifications, StatusNotifier,
// Mpris, UPower) entra en M2 detras de estos mismos `...Available`.
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

    // Fallback local: sin servicio de notificaciones, se cuenta igual para
    // que las superficies (campana, centro) no dependan del backend.
    function notify(title, body) {
        notificationCount += 1
    }

    function clearNotifications() {
        notificationCount = 0
    }
}
