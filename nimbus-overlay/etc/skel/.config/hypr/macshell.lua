-- =============================================================================
-- NimbusOS — macshell.lua (snippet para sesiones Hyprland >= 0.55 con Lua)
-- Fiel al upstream https://github.com/0-ss/MacShell (main @ 2026-10-23):
-- autostart via hyprland.start + layer rules. SIN binds: todos los atajos
-- viven en el hermano `hyprland.lua` (mismo directorio), que hace
-- `dofile(.../macshell.lua)` al final — asi ningun bind se registra dos veces
-- (Ruling sesion-lua: ALT+TAB = switcher MacShell via qs ipc, UNA sola vez).
-- Uso: desde `~/.config/hypr/hyprland.lua` -> `dofile(os.getenv("HOME") ..
--   "/.config/hypr/macshell.lua")`. El instalador de Task 5 lo referencia.
-- NOTA: NO cargar `~/.config/quickshell/MacShell/macshell.lua` (mismo nombre,
--   resto del install.sh UPSTREAM de MacShell, no del nuestro): registra los
--   mismos binds (SUPER+ESPACIO, ALT+TAB, SUPER+V, PRINT, SUPER+L, XF86* ->
--   doble-disparo), trae `CTRL+ALT+W` (Ctrl prohibido), invoca
--   `MacLock/enable-sleep-lock.sh` (inexistente: solo hay lock-via-ipc.sh) y
--   exige `awww/playerctl/wpctl` (fuera del manifest). Este snippet lo sustituye.
-- NOTA: no se bindea CTRL-* (Ctrl intacto). Sin bind de wallpapers con CTRL.
-- =============================================================================

-- Autostart (macshell-start: espera al compositor, single-instance, restart).
-- Quitar otras barras/docks/daemons de notificaciones antes (waybar,
-- hyprpanel, ags, dunst, mako, swaync): MacBar posee Notifications.
hl.on("hyprland.start", function()
    hl.exec_cmd("sh $HOME/.local/bin/macshell-start")
end)

-- Layer rules: blur para las superficies Liquid Glass.
-- (Equivalen 1:1 a los `layer_rule` del .conf: macdock/macspot/macbarbg con
-- blur+ignorealpha, macshot solo noanim.)
hl.layer_rule({ name = "macdock",  match = { namespace = "macdock"  }, blur = true, ignore_alpha = 0.2,  no_anim = true })
hl.layer_rule({ name = "macspot",  match = { namespace = "macspot"  }, blur = true, ignore_alpha = 0.05, no_anim = true })
hl.layer_rule({ name = "macbarbg", match = { namespace = "macbarbg" }, blur = true, ignore_alpha = 0.05, no_anim = true })
hl.layer_rule({ name = "macshot",  match = { namespace = "macshot"  }, no_anim = true })
