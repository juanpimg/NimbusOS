-- SPDX-License-Identifier: GPL-3.0-or-later

-- Layout flotante, de forma nativa (no con hyprctl, no en un .conf aparte).
hl.config({
    general = {
        layout = "floating",
    },
    decoration = {
        rounding = 12,
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
        },
    },
})

-- La sesion de emergencia se abre a pantalla completa.
hl.window_rule({
    name = "nimbus-emergency-fullscreen",
    match = { class = "emergency" },
    fullscreen = true,
})

-- Nimbus live: sin la marca de Hyprland, sin el aviso del wrapper (la
-- sesion usa start-hyprland) y con la base en el oscuro de la paleta.
-- El fondo de Hyprland sale del renderer base integrado, que lee
-- /usr/share/hypr/wall<N>.png: con disable_hyprland_logo no se pinta y la
-- base la pone background_color. El fondo de verdad lo pone swaybg con el
-- arte de Nimbus (ver dots/nimbus/nimbus-start).
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = "rgba(1c1c1eff)",
        force_default_wallpaper = 0,
        disable_watchdog_warning = true,
    },
})

local function shell(action)
    return hl.dsp.exec_cmd("nimbus-shell ipc call " .. action)
end

hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + D", shell("dock toggle"))
hl.bind("SUPER + Space", shell("spotlight toggle"))
hl.bind("SUPER + Tab", shell("switcher next"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + W", hl.dsp.window.close())
hl.bind("SUPER + C", hl.dsp.send_shortcut({ mods = "SUPER", key = "C" }))
hl.bind("SUPER + V", hl.dsp.send_shortcut({ mods = "SUPER", key = "V" }))
hl.bind("SUPER + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("PRINT", shell("screenshot region"))

-- Los bindings de workspace se escriben de forma literal: el test los busca
-- uno a uno y un bucle con tostring() no sería detectable.
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind("SUPER + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind("SUPER + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind("SUPER + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind("SUPER + 9", hl.dsp.focus({ workspace = 9 }))

-- Sesión de emergencia: si el shell de Nimbus falla, este bind abre un
-- terminal a pantalla completa (ver la regla de ventana de arriba) para
-- diagnosticar. Usa el dispatcher directo como el resto de binds: envolverlo
-- en una llamada intermedia romperia la carga de toda la config.
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("kitty --class emergency"))

hl.on("hyprland.start", function()
    hl.exec_cmd("sh /usr/lib/nimbus/dots/nimbus-start")
end)
