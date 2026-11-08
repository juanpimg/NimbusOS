-- =============================================================================
-- NimbusOS — hyprland.lua (sesion canonica Lua, Hyprland >= 0.55)
-- Equivalente 1:1 de hyprland.conf + 10-shortcuts.conf en Lua (API hl.*).
-- Requiere: Hyprland >= 0.56, Quickshell >= 0.3.2, Qt 6.8+.
-- Upstream shell: https://github.com/0-ss/MacShell (main @ 2026-10-23, MIT).
-- Reglas globales: todo flotante, sin atajos con la tecla Control,
--   Alt+Tab=switcher MacShell, esquinas 10px, blur Dual-Kawase.
-- Paleta canonica NimbusOS: #F5F5F7 (claro) / #1D1D1F (oscuro) / #007AFF.
--
-- PRECEDENCIA (Hyprland 0.56.2, verificada con HOME temporal + --verify-config):
--   si ~/.config/hypr/hyprland.lua existe, Hyprland lo usa e IGNORA
--   hyprland.conf ("Using lua config found at ..."). Sin .lua usa el .conf
--   legacy (avisa: hyprlang en desuso desde 0.55 a favor de Lua). El .conf queda
--   como fallback: NO borrar (ver Ruling en el commit).
-- RULING ALT+TAB p2-final (2026-10-26): UNA sola definicion en ambas
--   sesiones (.conf + Lua -> `qs -c MacShell ipc call switcher next`).
--   hyprshell queda en el append ya precompilado (inofensivo) pero sin bind
--   en ninguna sesion; el .conf unificado usa el switcher MacShell.
-- RULING overview (Task ventanas-p0, 2026-10-26): Mission Control REAL via
--   hyprexpo es IMPOSIBLE en 0.56: upstream elimino los plugins no mantenidos
--   (hyprland-plugins commits 046be75/3aa21f2 "drop unmaintained plugins",
--   May-2026; hyprexpo borrado del monorepo) y el repo standalone
--   hyprwm/hyprexpo devuelve 404. `pacman -Si hyprland-plugin-hyprexpo` =
--   no existe en repos oficiales; AUR solo tiene el fork third-party
--   `hyprexpose-git` (r0-1, 0 votos, -git sin pin -> rechazado por
--   reproducibilidad). Sin .so no hay dispatcher `overview` (verify-config:
--   `Invalid dispatcher`). SUPER+W mantiene el fallback ya verificado
--   (switcher visual de MacShell); Alt+Tab queda como switcher.
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
-- macshell/env — lo comprueban install.sh --check y el paso [8/8]).
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
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
    -- Task ui-desktop2: fondo visible al arrancar. hyprpaper DESCARTADO como
    -- daemon (0.8.4 rompe IPC con Hyprland 0.56.2, probado en VM): swaybg.
    hl.exec_cmd("swaybg -i /usr/share/backgrounds/nimbus/sequoia-light.jpg -m fill")
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
-- RULING gestos-verticales fidelidad-macos (2026-10-27): la API Lua 0.56.2
-- solo admite actions nativas (workspace/fullscreen): `dispatcher`/`exec`
-- responden `unknown action` (verificado con --verify-config), asi que el
-- gesto NO puede invocar el switcher como en el .conf. Fallback nativo mas
-- cercano: swipe vertical 3 dedos = cambiar workspace (macOS: Mission Control).
-- Pellizco (mostrar escritorio): sin action valida en NINGUNA sesion (.conf
-- rechaza directions in/out: `Invalid direction`; Lua acepta "pinch" pero su
-- semantica no es verificable) -> SKIP documentado.
hl.gesture({ fingers = 3, direction = "up", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down", action = "workspace" })

-- --- General: flotante por defecto -------------------------------------------
hl.config({
    general = {
        gaps_in     = 4,   -- NimbusOS Ruling fidelidad-macos: 4/8 (eran 8/16), mas compacto estilo Mac
        gaps_out    = 8,
        -- Task ui-win: SIN borde azul (era rgba(007affee)): borde sutil gris
        -- 1px estilo macOS; la sombra suave de `decoration.shadow` da la
        -- separacion (el acento #007AFF queda solo en marca/botones).
        border_size = 1,
        col = {
            active_border   = "rgba(0000004d)",
            inactive_border = "rgba(00000033)",
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

-- --- Task ventanas-p0: dialogos/filechoosers NO heredan 1100x700 -------------
-- La regla `nimbus-size-all` (`class:^(.*)$` -> 1100x700) tambien agranda
-- dialogos y filechoosers. Excepciones compactas 700x500 (las reglas se
-- evaluan en orden: las posteriores ganan para la misma propiedad). Matches:
--   * clase portal (filechoosers del portal xdg + impls hyprland/gtk),
--   * `modal = true` (dialogos modales: "Are you sure?", about, prefs),
--   * titulos open/save/choose/select (EN+ES: live C.UTF-8, instalado es_ES)
--     + autenticacion (polkit). Efectos estaticos: se evaluan al abrir con
--     initialTitle/initialClass (verificado con zenity en Hyprland 0.56.2).
hl.window_rule({ name = "nimbus-dialog-portal", match = { class = "^(org\\.freedesktop\\.impl\\.portal\\.desktop\\.(gtk|hyprland)|[Xx]dg-desktop-portal-gtk)$" }, size = "700 500" })
hl.window_rule({ name = "nimbus-dialog-modal",  match = { modal = true }, size = "700 500" })
hl.window_rule({ name = "nimbus-dialog-titles", match = { title = "^([Oo]pen|[Ss]ave|[Cc]hoose|[Ss]elect|[Ee]xport|[Ii]mport|[Uu]pload|[Aa]ttach|[Aa]brir|[Gg]uardar|[Ee]legir|[Ss]eleccionar|[Ee]xportar|[Ii]mportar|[Aa]djuntar|[Ss]ubir|[Aa]utenticaci|[Aa]uthentication).*" }, size = "700 500" })

-- --- Decoracion macOS: esquinas 10px, sombras suaves, blur ----------------
hl.config({
    decoration = {
        rounding         = 10,   -- NimbusOS Ruling fidelidad-macos: 10 (era 13), radio Mac
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,   -- NimbusOS Ruling fidelidad-macos: 1.0 (era 0.98): ventanas inactivas opacas como en Mac
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
            -- NimbusOS Ruling fidelidad-macos: vibrancy estilo Mac (valores
            -- espejo de hyprlock.conf: vibrancy 0.1696, darkness 0.0;
            -- hyprlock no define `saturation`: no existe tal campo, SKIP).
            vibrancy           = 0.1696,
            vibrancy_darkness  = 0.0,
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
            -- Overlay WindowBar ON (MacBar windowBar:true): el overlay QML
            -- dibuja semaforos 12px + titulo; hyprbars aporta SOLO la tira.
            -- LECCION 2026-10-28: `hyprctl reload` PIERDE los add_button
            -- (solo viven en el arranque); cambios hyprbars exigen reinicio
            -- completo, nunca reload. `hyprctl keyword` no existe en sesion
            -- Lua (non-legacy parser): solo fichero + reinicio.
            bar_title_enabled     = false,
            bar_text_size         = 11,
            bar_text_font         = "Inter",
            bar_padding           = 15,
            bar_button_padding    = 8,
            -- Sin botones hyprbars (los dibuja el overlay WindowBar 12px +
            -- glifo al hover + titulo): la tira aporta fondo+blur+arrastre.
            -- bar_blur esmerila la tira; el tinte exacto por-tema es imposible
            -- (un solo bar_color estatico en la API: se deja el defecto).
            bar_blur              = true, -- tira esmerilada (el overlay dibuja encima)
            -- Task barra-resize: MOVER con la barra = nativo, sin opcion que
            -- activar. Upstream barDeco.cpp: pulsar dentro de la barra arma
            -- drag-pending (handleDownEvent, lineas 212-246) y mover el raton
            -- inicia drag MBIND_MOVE (onMouseMove + handleMovement, lineas
            -- 152-162 y 272-277); soltar lo cierra (handleUpEvent, lineas
            -- 249-270). Toda la barra (titulo + semaforos, salvo click sobre
            -- un boton) agarra la ventana.
            -- REDIMENSIONAR desde la barra = NO soportado por el plugin: la
            -- unica mencion a resize en su codigo es el pre-ajuste tactil al
            -- 50% via resizewindowpixel (onTouchMove, linea 175); no hay
            -- MBIND_RESIZE ni agarre de bordes/esquinas en la barra, ni
            -- opcion que lo active (lista cerrada de opciones en main.cpp,
            -- lineas 214-234; tabla del README). El resize estilo macOS vive
            -- en los BORDES de la ventana: resize_on_border +
            -- extend_border_grab_area 25 (bloque general, sesion Lua y .conf),
            -- SUPER+boton derecho (hl.dsp.window.resize) y SUPER+SHIFT+flechas.
            -- bar_part_of_window explicito (= defecto upstream): la barra
            -- cuenta como parte de la ventana (flag
            -- DECORATION_PART_OF_MAIN_WINDOW, barDeco.cpp lineas 624-626)
            -- y la sombra envuelve barra+ventana en una sola silueta macOS.
            bar_part_of_window    = true,
            -- bar_precedence_over_border explicito (= defecto upstream
            -- false): prioridad 5000 frente a 10005 con true
            -- (getPositioningInfo, barDeco.cpp lineas 61-73); con false el
            -- borde de 1px NO envuelve la barra (README: con true "border
            -- will be around the bar"). Sin cambio visual: solo fija por
            -- escrito el defecto auditado.
            bar_precedence_over_border = false,
            on_double_click       = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
        },
    },
})
-- Semaforos (overlay WindowBar): rojo=cerrar, amarillo=minimizar a
-- special:minimized (RESTAURA con SUPER+M o click en el Dock), verde=ZOOM
-- macOS = maximizar sin tapar barra/dock. Pantalla completa real SOLO en
-- SUPER+F. Acciones en WindowBar.qml close()/minimize()/zoom().
-- (sin add_button: los dibuja el overlay WindowBar; ver nota arriba)

-- Sin doble barra en apps con CSD propio bueno (headerbar/tabs nativos):
-- Nautilus (GTK4 headerbar) y Firefox (tabs en la barra de titulo).
hl.window_rule({ name = "nimbus-hyprbars-no-bar-nautilus", match = { class = "^(org.gnome.Nautilus)$" },              ["hyprbars:no_bar"] = true })
hl.window_rule({ name = "nimbus-hyprbars-no-bar-firefox",  match = { class = "^(firefox)$" },                           ["hyprbars:no_bar"] = true })
hl.window_rule({ name = "nimbus-hyprbars-no-bar-pamac",    match = { class = "^(org.manjaro.pamac.manager|pamac-manager)$" }, ["hyprbars:no_bar"] = true })
-- P1 no_bar ampliado (2026-10-27, corregido Task noobar2 2026-10-27):
-- ventanas con CSD propio que duplicarian la barra de hyprbars:
--   * pamac: DOS clases reales (fallback XWayland + nativo Wayland).
--     XWayland: WM_CLASS=pamac-manager (StartupWMClass del .desktop
--     instalado org.manjaro.pamac.manager.desktop, verificado en live).
--     Wayland nativo (el defecto en Hyprland): app_id =
--     "org.manjaro.pamac.manager" (Gtk.Application application_id en
--     upstream src/manager.vala; libadwaita CSD con headerbar propia).
--     Sin la segunda regla pamac muestra DOBLE barra en Wayland.
--   * dialogos modales (modal=true, propiedad real de Hyprland ya usada en
--     nimbus-dialog-modal): polkit, autenticacion, filechoosers GTK — todos
--     traen su headerbar/botones propios.
--   * Ruling calamares: SKIP clase explicita. El instalador no esta en el
--     host de build y su app_id Qt (CALAMARES_APPLICATION_NAME="Calamares"
--     en el fork CachyOS) no fija la clase Wayland de forma verificable sin
--     ejecutarlo; los dialogos de Calamares caen en la regla modal=true.
-- NOTA nombres unicos: Hyprland solo admite UN match.class por regla y las
-- reglas Lua con el mismo `name` comparten objeto (la segunda definicion
-- pisa o invalida la primera). Por eso pamac lleva UNA sola regla con
-- alternacion (arriba) en vez de dos: el duplicado rompia el no_bar y la
-- doble barra volvia. No volver a dividirla.
hl.window_rule({ name = "nimbus-hyprbars-no-bar-modal", match = { modal = true },                 ["hyprbars:no_bar"] = true })
-- Task botones-nativos: SIN doble juego en ventanas propias de MacShell.
-- Esas ventanas dibujan YA sus semaforos Liquid Glass nativos y hyprbars
-- les pondria una SEGUNDA barra+botones encima:
--   * AboutApp.qml:170-204 (solo Close activo, como el About de un Mac),
--   * ClockApp.qml:390-450 (Close + zoom; minimizar grisado, no hace nada),
--   * MacDock.qml prefsWindow "macshell Settings":1055-1127 (igual),
--   * Installer.qml:151-175 (huérfano: no lo instancia shell.qml, pero el
--     título queda cubierto por si aguas arriba lo reutiliza).
-- Clase `org.quickshell`: app_id Wayland real del proceso `qs -c MacShell`,
-- verificado en VM live (ISO 10.27) con `hyprctl clients`: About, Clock y
-- Settings listan class=org.quickshell. Titulos exactos verificados en
-- codigo: AboutApp.qml:93 "About This Linux", ClockApp.qml:343 "Clock",
-- Installer.qml:112 "Install Dependencies", MacDock.qml:624
-- "macshell Settings". La clase cubre las 4 (+ futuras ventanas MacShell);
-- los titulos documentan cada caso y protegen si la clase cambiase aguas
-- arriba.
hl.window_rule({ name = "nimbus-hyprbars-no-bar-macshell", match = { class = "^(org\\.quickshell)$" }, ["hyprbars:no_bar"] = true })
hl.window_rule({ name = "nimbus-hyprbars-no-bar-macshell-titles", match = { title = "^(About This Linux|Clock|Install Dependencies|macshell Settings)$" }, ["hyprbars:no_bar"] = true })

-- --- Animaciones: curvas Bezier suaves estilo macOS ---------------------------
hl.curve("nimbus",    { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.curve("nimbusOut", { type = "bezier", points = { { 0.4, 0.0 },  { 0.2, 1 } } })

hl.animation({ leaf = "windows",          enabled = true, speed = 5, bezier = "nimbus",    style = "slide" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 5, bezier = "nimbus",    style = "slide" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 4, bezier = "nimbusOut", style = "slide" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 4, bezier = "nimbus",    style = "slide" })
hl.animation({ leaf = "fade",             enabled = true, speed = 5, bezier = "nimbus" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "nimbus",    style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "nimbus",    style = "slidevert" })
hl.animation({ leaf = "layers",           enabled = true, speed = 4, bezier = "nimbus",    style = "fade" })

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
-- ALT+TAB = switcher con preview de MacShell (RULING p2-final: UNA sola
-- definicion, identica a 10-shortcuts.conf; hyprshell sin uso en Lua).
hl.bind("ALT + TAB", hl.dsp.exec_cmd(qs .. "switcher next"))
-- Task ventanas-p0: SUPER+W mantiene el switcher (Ruling overview: hyprexpo
-- muerto upstream, sin dispatcher `overview`; ver cabecera del fichero).
hl.bind("SUPER + W", hl.dsp.exec_cmd(qs .. "switcher next"))
-- Task ventanas-p0 Launchpad: MacShell SI tiene vista de apps (MacBar
-- appsPanel: grid de 5 columnas por categoria + buscador; IpcHandler
-- `spotlight apps` -> spotOpen("apps")). Equivale al Launchpad de macOS.
hl.bind("SUPER + A", hl.dsp.exec_cmd(qs .. "spotlight apps"))
-- Task ventanas-p0 minimizar: el amarillo manda a special:minimized
-- (follow=false: el shelf queda oculto). SUPER+M = toggle inteligente
-- (nimbus-minimize-toggle): si la ventana activa vive en special:minimized
-- la devuelve al workspace visible (el compositor auto-oculta el shelf al vaciarse);
-- si no, abre/cierra el shelf. El click en el Dock enfoca (abre el shelf
-- con la ventana activa: `tl.activate()` ~= `focuswindow`).
hl.bind("SUPER + M", hl.dsp.exec_cmd("nimbus-minimize-toggle"))
hl.bind("PRINT",     hl.dsp.exec_cmd(qs .. "screenshot region"))
-- Task fidelidad-macos: capturas estilo Mac (nimbus-screenshot: grim+slurp).
-- CONFLICTO documentado: SUPER+SHIFT+3/4/5 eran "llevar ventana al workspace
-- N". macOS los reserva a capturas, asi que capturas GANAN y el loop de
-- movetoworkspace abajo salta 3/4/5 (SUPER+3/4/5 = ir al workspace intacto;
-- mover a 3/4/5 por teclado no disponible, por raton si).
hl.bind("SUPER + SHIFT + 3", hl.dsp.exec_cmd("nimbus-screenshot full"))
hl.bind("SUPER + SHIFT + 4", hl.dsp.exec_cmd("nimbus-screenshot area"))
hl.bind("SUPER + SHIFT + 5", hl.dsp.exec_cmd("nimbus-screenshot window"))
-- Task fidelidad-macos: SUPER+H oculta la ventana (dispatcher real
-- `movetoworkspace special:hidden`, verificado con --verify-config; via
-- exec passthrough porque el nombre del dsp Lua no es introspectable).
hl.bind("SUPER + H", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace special:hidden"))
-- Task fidelidad-macos: SUPER+` cicla ventanas (dispatcher real `cyclenext`,
-- verificado; "grave" sigue el precedente de "period"/"Space" en este fichero).
hl.bind("SUPER + grave", hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))

-- MacLock (pantalla de bloqueo Liquid Glass, proceso separado).
hl.bind("SUPER + L", hl.dsp.exec_cmd("sh ~/.config/quickshell/MacLock/lock-via-ipc.sh"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))

-- Task ui-flows: teclas hardware (volumen/brillo) -> OSD interno de MacBar.
-- Sin swayosd/avizo (duplicarian el OSD). `repeating` = repite al mantener.
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(qs .. "hardware volumeUp"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(qs .. "hardware volumeDown"), { repeating = true, locked = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(qs .. "hardware mute"), { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(qs .. "hardware micMute"), { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(qs .. "hardware brightnessUp"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(qs .. "hardware brightnessDown"), { repeating = true, locked = true })

-- Task workflow-mac: Spaces / Mission Control / zoom+fullscreen.
-- Sin atajos con Control (macOS usa Control+flechas; aqui SUPER+LEFT/RIGHT).
for i = 1, 9 do
    hl.bind("SUPER + " .. i,         hl.dsp.focus({ workspace = i }))
    -- (fidelidad-macos: 3/4/5 reservados a capturas, ver arriba)
    if i ~= 3 and i ~= 4 and i ~= 5 then
        hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
    end
end
hl.bind("SUPER + left",  hl.dsp.focus({ workspace = -1 }))
hl.bind("SUPER + right", hl.dsp.focus({ workspace = 1 }))
-- Boton verde = zoom macOS (maximizar); SUPER+F = pantalla completa real.
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
