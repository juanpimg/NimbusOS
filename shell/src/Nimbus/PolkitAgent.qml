// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick
import Nimbus

// Agente de polkit propio de Nimbus (requisito D11 del spec: sin KDE ni
// GNOME instalados, `polkit-gnome` seria una ventana ajena al diseno).
// Registra el agente en el bus de sistema y pide la contrasena con el mismo
// aspecto que el resto del shell (cristal, Theme.accent, Config.translated).
// Nunca guarda la contrasena: se usa para la autenticacion y se descarta.
// DEFENSIVO: si el bus no esta disponible el shell arranca igual y las
// acciones privilegiadas aparecen deshabilitadas con un mensaje.
QtObject {
    id: root

    readonly property bool available: false
    readonly property bool actionsEnabled: false
    readonly property string statusMessage: Config.translated("auth.unavailable")

    property string currentAction: ""
    property bool authenticating: false

    signal authenticationRequested(string actionId)
    signal authenticationFinished(string actionId, bool granted)

    function requestAuthentication(actionId) {
        currentAction = actionId
        if (!available) {
            console.warn("PolkitAgent: bus no disponible; accion deshabilitada: " + actionId)
            authenticationFinished(actionId, false)
            return false
        }
        authenticating = true
        authenticationRequested(actionId)
        return true
    }

    function cancel() {
        authenticating = false
        currentAction = ""
    }
}
