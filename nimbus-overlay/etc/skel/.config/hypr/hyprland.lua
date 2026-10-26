-- =============================================================================
-- NimbusOS — hyprland.lua (sesion canonica Lua, Hyprland >= 0.55)
-- Equivalente 1:1 de hyprland.conf + 10-shortcuts.conf en Lua (API hl.*).
-- Requiere: Hyprland >= 0.55, Quickshell >= 0.3.2, Qt 6.8+.
-- Upstream shell: https://github.com/0-ss/MacShell (main @ 2026-10-23, MIT).
-- Reglas globales: todo flotante, sin atajos con la tecla Control,
--   Alt+Tab=switcher MacShell, esquinas 12-14px, blur Dual-Kawase.
-- Paleta canonica NimbusOS: #F5F5F7 (claro) / #1D1D1F (oscuro) / #007AFF.
--
-- PRECEDENCIA (Hyprland 0.56.2, verificada con HOME temporal + --verify-config):
--   si ~/.config/hypr/hyprland.lua existe, Hyprland lo usa e IGNORA
--   hyprland.conf ("Using lua config found at ..."). Sin .lua usa el .conf
--   legacy (avisa: soporte .conf se elimina en Hyprland 0.57). El .conf queda
--   como fallback: NO borrar (ver Ruling en el commit).
-- RULING ALT+TAB (divergencia .conf vs Lua, resuelta a UNA sola):
--   sesion Lua -> switcher de MacShell via qs ipc (`switcher next`).
--   La linea `hyprshell switch` del .conf NO se porta (hyprshell sobra en la
--   sesion Lua; el .conf queda intacto como fallback legacy).
-- RULING overview: ni MacShell (ipc: spotlight/switcher/...) ni Hyprland 0.56
--   core traen dispatcher `overview` (seria plugin externo hyprexpo); SUPER+W
--   abre el switcher visual de MacShell (lo mas cercano a Mission Control).
-- =============================================================================

-- --- Monitor -----------------------------------------------------------------
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- --- Entorno -----------------------------------------------------------------
-- (mismos valores que hyprland.conf; QS_ICON_THEME debe coincidir con
-- macshell/env — lo comprueba verify-macshell.sh).
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland")
-- Task menu-tienda: el modulo GTK exporta el menu por D-Bus (com.canonical.AppMenu).
hl.env("GTK_MODULES", "appmenu-gtk-module")
hl.env("QS_ICON_THEME", "WhiteSur")
hl.env("XCURSOR_THEME", "capitaine-cursors-light")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "capitaine-cursors-light")
hl.env("HYPRCURSOR_SIZE", "24")

-- --- Autostart ---------------------------------------------------------------
-- macshell va via dofile(macshell.lua) al final (single-instance, espera al
-- compositor, auto-restart). MacBar posee org.freedesktop.Notifications: NO
-- dunst/mako/swaync ni otras barras/docks (waybar, hyprpanel, ags, nwg-dock).
-- Task 3 (USB plug&play): agente polkit + automontaje udiskie (udiskie --notify
-- usa MacBar; sin swaynotificationcenter para no duplicar el daemon).
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("udiskie --automount --notify --smart-tray")
end)

-- --- Input: gestos 1:1 estilo Mission Control ---------------------------------
hl.config({
    input = {
        kb_layout   = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll     = true,
            tap_to_click       = true,
            clickfinger_behavior = true,
        },
    },
    gestures = {
        workspace_swipe_distance = 300,
        workspace_swipe_touch    = true,
        workspace_swipe_forever  = true,
    },
})
-- Swipe 3 dedos horizontal = cambiar workspace.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- --- General: flotante por defecto -------------------------------------------
hl.config({
    general = {
        gaps_in     = 8,
        gaps_out    = 16,
        border_size = 2,
        col = {
            active_border   = "rgba(007affee)",
            inactive_border = "rgba(1d1d1f33)",
        },
        layout       = "dwindle",
        allow_tearing = false,

        -- Task ventanas-raton: redimension con borde (estilo Mac/Windows) + snap.
        resize_on_border       = true,
        extend_border_grab_area = 25,

        snap = {
            enabled     = true,
            window_gap  = 10,
            monitor_gap = 10,
        },
    },
})

-- TODA ventana flotante por defecto + centrada + tamano Mac (1100x700: cabe en
-- 1366x768, proporcionado en 4K). Mismo orden de evaluacion que el .conf.
hl.window_rule({ name = "nimbus-float-all",  match = { class = ".*" }, float  = true })
hl.window_rule({ name = "nimbus-center-all", match = { class = ".*" }, center = true })
hl.window_rule({ name = "nimbus-size-all",   match = { class = ".*" }, size   = "1100 700" })

-- --- Decoracion macOS: esquinas 12-14px, sombras suaves, blur ----------------
hl.config({
    decoration = {
        rounding         = 13,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.98,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 30,
            render_power = 3,
            color        = "rgba(00000066)",
        },

        blur = {
            enabled            = true,
            size               = 8,
            passes             = 3,
            new_optimizations  = true,
            xray               = false,
        },
    },
})

-- --- hyprbars: titlebars NATIVAS (plugin oficial hyprwm/hyprland-plugins) -----
-- Sustituye al overlay WindowBar.qml (revertido: MacShell queda pristine,
-- sin bifurcar; shell.qml upstream nunca instanciaba WindowBar).
-- Plugin: hyprland-plugin-hyprbars (AUR -> repo local [nimbus]).
-- Carga explicita OBLIGATORIA y PRIMERA: sin el .so, `hl.plugin.hyprbars.*`
-- y el efecto `hyprbars:no_bar` son desconocidos y --verify-config falla.
-- Path verificado en el PKGBUILD AUR (x70b1, split hyprland-plugins):
-- package_hyprbars instala hyprbars.so en /usr/lib/libhyprbars.so.
hl.plugin.load("/usr/lib/libhyprbars.so")
-- Sintaxis Lua verificada contra el README del monorepo (tag v0.56.0) y el
-- codigo fuente (main.cpp newLuaButton, barDeco.cpp):
--   * `hl.config({ plugin = { hyprbars = { ... } } })` para opciones.
--   * `hl.plugin.hyprbars.add_button({...})` por boton. ORDEN = de fuera
--     hacia dentro desde el borde: con alignment "left" el primero es el
--     mas a la izquierda (close, minimize, fullscreen como en macOS).
--   * fg_color OBLIGATORIO en Lua (el parser falla sin el); icon = ""
--     dibuja el circulo liso estilo macOS (sin glifo).
--   * `["hyprbars:no_bar"] = true` en window_rule desactiva la barra
--     (efecto dinamico registrado por el plugin; el bool Lua viaja como
--     "true" y truthy() lo oculta). Sin el plugin cargado, verify-config
--     rechaza el campo desconocido -> el plugin es requisito (ver commit).
hl.config({
    plugin = {
        hyprbars = {
            bar_height            = 28,
            bar_buttons_alignment = "left",
            bar_title_enabled     = true,
            bar_text_size         = 11,
            bar_text_font         = "Inter",
            bar_padding           = 10,
            bar_button_padding    = 6,
            on_double_click       = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })']],
        },
    },
})
-- Rojo cerrar / amarillo minimizar a special:minimized / verde fullscreen.
hl.plugin.hyprbars.add_button({ bg_color = "rgb(FF5F57)", fg_color = "rgb(FF5F57)", size = 13, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(FEBE2E)", fg_color = "rgb(FEBE2E)", size = 13, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:minimized", follow = false })']] })
hl.plugin.hyprbars.add_button({ bg_color = "rgb(28C840)", fg_color = "rgb(28C840)", size = 13, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })']] })

-- Sin doble barra en apps con CSD propio bueno (headerbar/tabs nativos):
-- Nautilus (GTK4 headerbar) y Firefox (tabs en la barra de titulo).
hl.window_rule({ name = "nimbus-hyprbars-no-bar-nautilus", match = { class = "^(org.gnome.Nautilus)$" }, ["hyprbars:no_bar"] = true })
hl.window_rule({ name = "nimbus-hyprbars-no-bar-firefox",  match = { class = "^(firefox)$" },              ["hyprbars:no_bar"] = true })

-- --- Animaciones: curvas Bezier suaves estilo macOS ---------------------------
hl.curve("nimbus",    { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.curve("nimbusOut", { type = "bezier", points = { { 0.4, 0.0 },  { 0.2, 1 } } })

hl.animation({ leaf = "windows",     enabled = true, speed = 5, bezier = "nimbus",    style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 5, bezier = "nimbus",    style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 4, bezier = "nimbusOut", style = "slide" })
hl.animation({ leaf = "fade",        enabled = true, speed = 5, bezier = "nimbus" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5, bezier = "nimbus",    style = "slide" })
hl.animation({ leaf = "layers",      enabled = true, speed = 4, bezier = "nimbus",    style = "fade" })

-- --- Misc --------------------------------------------------------------------
hl.config({
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms  = true,
        key_press_enables_dpms   = true,
    },
})

-- --- Binds -------------------------------------------------------------------
-- PROHIBIDO usar la tecla Control en atajos (portapapeles intacto).
-- Super / Super+Espacio = Spotlight - Alt+Tab = switcher MacShell con preview.
local qs = "qs -c MacShell ipc call "

-- Launcher / Spotlight (macshell).
hl.bind("SUPER + Space",  hl.dsp.exec_cmd(qs .. "spotlight toggle"))
hl.bind("SUPER + V",      hl.dsp.exec_cmd(qs .. "spotlight clipboard"))
hl.bind("SUPER + period", hl.dsp.exec_cmd(qs .. "spotlight emoji"))
-- ALT+TAB = switcher con preview de MacShell (Ruling: UNA sola definicion; la
-- variante `hyprshell switch` del .conf no se porta a la sesion Lua).
hl.bind("ALT + TAB", hl.dsp.exec_cmd(qs .. "switcher next"))
-- Mission Control (SUPER+W): sin `overview` en MacShell ni en core 0.56
-- (seria plugin hyprexpo); fallback al switcher visual de MacShell.
hl.bind("SUPER + W", hl.dsp.exec_cmd(qs .. "switcher next"))
hl.bind("PRINT",     hl.dsp.exec_cmd(qs .. "screenshot region"))

-- MacLock (pantalla de bloqueo Liquid Glass, proceso separado).
hl.bind("SUPER + L", hl.dsp.exec_cmd("sh ~/.config/quickshell/MacLock/lock-via-ipc.sh"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))

-- Task ui-flows: teclas hardware (volumen/brillo) -> OSD interno de MacBar.
-- Sin swayosd/avizo (duplicarian el OSD). `repeating` = repite al mantener.
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(qs .. "hardware volumeUp"), { repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(qs .. "hardware volumeDown"), { repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(qs .. "hardware mute"))
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(qs .. "hardware micMute"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(qs .. "hardware brightnessUp"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(qs .. "hardware brightnessDown"), { repeating = true })

-- Task workflow-mac: Spaces / Mission Control / fullscreen.
-- Sin atajos con Control (macOS usa Control+flechas; aqui SUPER+LEFT/RIGHT).
for i = 1, 9 do
    hl.bind("SUPER + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind("SUPER + left",  hl.dsp.focus({ workspace = -1 }))
hl.bind("SUPER + right", hl.dsp.focus({ workspace = 1 }))
-- Boton verde = pantalla completa; SUPER+SHIFT+F = flotante.
hl.bind("SUPER + F",         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))

-- Task ventanas-raton: mover/redimensionar con raton (estilo Mac/Windows).
-- (bindm: la tecla ya codifica el boton + `{ mouse = true }` lo registra como
-- bind de raton — forma del ejemplo upstream hyprwm/Hyprland example/hyprland.lua;
-- `hl.dsp.window.drag/resize` lleva la semantica movewindow/resizewindow.)
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Task resize-teclado: redimensionar con teclado (sin raton).
-- Equivalente Lua del `resizeactive ±40px` del .conf (`binde` repetible):
-- `hl.dsp.window.resize({ relative = true })` + `{ repeating = true }`
-- (forma documentada en wiki Binds Lua + ejemplo real macroexpansion/hypr).
-- SUPER+SHIFT+LEFT/RIGHT/UP/DOWN estan libres (Spaces usa SUPER+LEFT/RIGHT y
-- SUPER+SHIFT+1..9; sin Control en ningun atajo).
hl.bind("SUPER + SHIFT + left",  hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + right", hl.dsp.window.resize({ x = 40,  y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + down",  hl.dsp.window.resize({ x = 0, y = 40,  relative = true }), { repeating = true })

-- --- MacShell: autostart + layer rules (sin binds: todos viven arriba) -------
dofile(os.getenv("HOME") .. "/.config/hypr/macshell.lua")
