# NimbusOS — capa theming global macOS (Task 1, solo repos existentes)
#
# Que instala cada pieza (nada creado desde cero):
# - GTK: WhiteSur-gtk-theme      -> AUR whitesur-gtk-theme (verificado AUR)
# - Iconos: WhiteSur-icon-theme   -> AUR whitesur-icon-theme (verificado AUR)
#           + MacOS-Like (recomendado upstream MacShell,
#           https://github.com/Scrimas/MacOS-Like, instalacion manual Task 5:
#           sin paquete repo-nativo ni AUR a 2026-10-23)
# - Cursores: capitaine-cursors-light (extra, estilo macOS, repo-nativo).
#   WhiteSur-cursors NO tiene paquete AUR verificado (busqueda AUR vacia
#   2026-10-23); queda como sustitucion manual opcional post-instalacion.
# - Fuentes: inter-font + noto-fonts(+emoji) (extra). "SF" solo como
#   fallback nominal en fontconfig si el usuario aporta SF Pro.
# - Terminal: kitty (extra/cachyos) con kitty.conf estilo macOS.
# - Fondo: hyprpaper (extra) + ruta canonica
#   /usr/share/backgrounds/nimbus/sequoia-light.jpg (provisiona Task 5).
# - Shell: MacShell via install.sh upstream (ver iso.manifest); autostart
#   garantizado por exec-once=macshell (.conf) y macshell.lua (sesion Lua).
# - GRUB/SDDM: placeholders auditados (*.src en este directorio + .example
#   inactivo en sddm.conf.d/). No tocan la base CachyOS.
#
# Paleta canonica: #F5F5F7 / #1D1D1F / #007AFF. Fuente canonica: Inter.
#
# Limitacion V1 (semáforos): WhiteSur + MacShell cubren GTK/CSD; las
#   ventanas Hyprland SSD no-GTK no tienen semáforos nativos. No bloquea V1;
#   verificar aspecto en QEMU (docs/qemu.md).
# Global-menu V1 (Ruling menu-global 2026-10-27): menu D-Bus REAL no viable
#   en V1. MacBar no trae importer/registrador com.canonical.AppMenu.Registrar
#   (menuModelFor() = entradas estaticas por heuristica appKind; el unico
#   QsMenuOpener es el del system tray) y Quickshell upstream no ofrece menu
#   global (issue #170: "huge can of worms, not planned"); el unico puente
#   conocido exige binario externo + bus AT-SPI (cero AUR nuevo en V1).
#   El modulo exportador SI queda instalado (appmenu-gtk-module +
#   GTK_MODULES en hyprland.conf/.lua, Task menu-tienda): el bus queda listo
#   para un futuro consumidor. Las entradas que enviaban atajos a ciegas
#   (Ctrl+S/W/...) via sendshortcut se eliminaron de MacBar.qml (ver Ruling
#   inline en menuModelFor); solo quedan acciones reales (IPC Hyprland,
#   cierre Wayland, Spotlight, capturas). Inventario ISO: ningun exportador
#   relevante (firefox unico con menubar, exige registrador ausente; vlc es
#   Qt sin plugin de plataforma en repos; nautilus/pamac headerbar sin
#   menubar; kitty/mpv sin menus).
