#!/bin/sh
# NimbusOS — shim MacLock/lock-via-ipc.sh (Task ui-flows).
# El upstream MacShell trae MacLock como segunda config Quickshell
# (install.sh instala ~/.config/quickshell/{MacShell,MacLock}); el skel
# NimbusOS solo vendorea MacShell, asi que este helper no existe y el
# bind SUPER+L + el menu Lock/Sleep de MacBar fallaban en silencio.
# Shim honesto: delega directamente en hyprlock, cuya config estilo macOS
# vive en ~/.config/hypr/hyprlock.conf (blur + hora grande). Sin IPC.
# Uso: sh ~/.config/quickshell/MacLock/lock-via-ipc.sh
# Si algun dia se vendorea MacLock completo, sustituir este fichero por el
# helper real del upstream (ver iso.manifest, pin MacShell).
if pgrep -x hyprlock >/dev/null 2>&1; then
    exit 0
fi
exec hyprlock
