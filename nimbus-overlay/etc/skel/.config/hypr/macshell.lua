-- =============================================================================
-- NimbusOS — macshell.lua (snippet para sesiones Hyprland >= 0.55 con Lua)
-- Fiel al upstream https://github.com/0-ss/MacShell (main @ 2026-10-23):
-- autostart via hyprland.start + layer rules + keybinds qs ipc + MacLock.
-- Uso: desde `~/.config/hypr/hyprland.lua` -> `dofile(os.getenv("HOME") ..
--   "/.config/hypr/macshell.lua")`. El instalador de Task 5 lo referencia.
-- NOTA: no se bindea CTRL-* (Ctrl intacto). Sin bind de wallpapers con CTRL.
-- =============================================================================

-- Autostart (macshell-start: espera al compositor, single-instance, restart).
-- Quitar otras barras/docks/daemons de notificaciones antes (waybar,
-- hyprpanel, ags, dunst, mako, swaync): MacBar posee Notifications.
hl.on("hyprland.start", function()
    hl.exec_cmd("sh $HOME/.local/bin/macshell-start")
end)

-- Layer rules: blur para las superficies Liquid Glass.
hl.layer_rule({ name = "macdock",  match = { namespace = "macdock"  }, blur = true, ignore_alpha = 0.2,  no_anim = true })
hl.layer_rule({ name = "macspot",  match = { namespace = "macspot"  }, blur = true, ignore_alpha = 0.05, no_anim = true })
hl.layer_rule({ name = "macbarbg", match = { namespace = "macbarbg" }, blur = true, ignore_alpha = 0.05, no_anim = true })
hl.layer_rule({ name = "macshot",  match = { namespace = "macshot"  }, no_anim = true })

-- Keybinds (el nombre tras -c es el nombre de la carpeta del config).
local qs = "qs -c MacShell ipc call "

hl.bind("SUPER + V",     hl.dsp.exec_cmd(qs .. "spotlight clipboard"))
hl.bind("SUPER + period", hl.dsp.exec_cmd(qs .. "spotlight emoji"))
hl.bind("SUPER + Space", hl.dsp.exec_cmd(qs .. "spotlight toggle"))
hl.bind("ALT + TAB",     hl.dsp.exec_cmd(qs .. "switcher next"))
hl.bind("PRINT",         hl.dsp.exec_cmd(qs .. "screenshot region"))

-- MacLock (pantalla de bloqueo Liquid Glass, proceso separado).
hl.bind("SUPER + L", hl.dsp.exec_cmd("sh ~/.config/quickshell/MacLock/lock-via-ipc.sh"))
