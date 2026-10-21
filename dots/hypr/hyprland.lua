-- SPDX-License-Identifier: GPL-3.0-or-later

local function shell(action)
    return hl.dsp.exec_cmd("nimbus-shell ipc call " .. action)
end

hl.bind("SUPER", "Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER", "D", shell("dock toggle"))
hl.bind("SUPER", "Space", shell("spotlight toggle"))
hl.bind("SUPER", "Tab", shell("switcher next"))
hl.bind("SUPER", "Q", hl.dsp.closewindow())
hl.bind("SUPER", "W", hl.dsp.closewindow())
hl.bind("SUPER", "C", hl.dsp.copy())
hl.bind("SUPER", "V", hl.dsp.paste())
hl.bind("SUPER", "L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("PRINT", shell("screenshot region"))

-- Los bindings de workspace se escriben de forma literal: el test los busca
-- uno a uno y un bucle con tostring() no sería detectable.
hl.bind("SUPER", "1", hl.dsp.workspace(1))
hl.bind("SUPER", "2", hl.dsp.workspace(2))
hl.bind("SUPER", "3", hl.dsp.workspace(3))
hl.bind("SUPER", "4", hl.dsp.workspace(4))
hl.bind("SUPER", "5", hl.dsp.workspace(5))
hl.bind("SUPER", "6", hl.dsp.workspace(6))
hl.bind("SUPER", "7", hl.dsp.workspace(7))
hl.bind("SUPER", "8", hl.dsp.workspace(8))
hl.bind("SUPER", "9", hl.dsp.workspace(9))

-- Sesión de emergencia: si el shell de Nimbus falla, el usuario cae aquí con
-- un terminal a pantalla completa y puede matar el proceso o cambiar de sesión.
local function emergency()
    hl.exec_cmd("kitty --class emergency")
end
hl.bind("SUPER", "Shift", "E", emergency)

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl keyword layout floating")
    hl.exec_cmd("sh /usr/lib/nimbus/dots/nimbus-start")
end)
