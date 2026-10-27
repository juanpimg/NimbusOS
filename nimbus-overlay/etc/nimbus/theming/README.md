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

# P1 visibles (2026-10-27, rama feature/p1-visibles)
#
# GRUB vendoreado: el tema Whitesur vive en
#   usr/share/grub/themes/whitesur/ (ensamblado de
#   https://github.com/vinceliuice/grub2-themes @ 4c5a771, GPL-3.0;
#   variante whitesur/1080p; pin en etc/nimbus/theming/grub-theme.src).
#   El repo antiguo vinceliuice/grub-themes devuelve 404 (renombrado).
#   etc/default/grub.d/nimbus.cfg fija GRUB_THEME a la ruta vendoreada y
#   GRUB_DISTRIBUTOR="NimbusOS" (renombra menuentries; no toca
#   /etc/default/grub del paquete grub).
# Wallpaper real: usr/share/backgrounds/nimbus/sequoia-light.jpg es foto
#   federal NPS de dominio publico (ver README.REPLACE-WITH-REAL.txt del
#   mismo directorio: URL Commons + licencia). Ruta/nombre intactos.
# Cursor XWayland (Ruling cursor-hypr 2026-10-27): capitaine-cursors(-light)
#   NO trae metadatos hyprcursor (verificado: /usr/share/icons solo tiene
#   cursors/ + index.theme, sin dir hyprcursors ni manifest.hl; en repos
#   oficiales no hay tema hyprcursor estilo macOS). Fallback documentado:
#   se fija XCURSOR_THEME/XCURSOR_SIZE=24 (cubre XWayland + GTK) y se
#   mantienen HYPRCURSOR_* como declaracion de intencion (Hyprland ignora el
#   tema ausente sin romper). Sin AUR nuevo en P1.
# Reloj live en espanol (Ruling reloj-es 2026-10-27): SKIP en P1.
#   Sin locale es_ES generado, LANG/LC_TIME=es_ES.UTF-8 no es viable (glibc
#   cae a C con avisos; archiso no genera locales en el live) y, aun con
#   locale-gen en el build, el reloj seguiria en ingles: MacShell no trae
#   lang/es.js (solo ru.js; I18n.tr() cae al ingles) y no se bifurca upstream
#   en P1. Requiere: (1) locale-gen es_ES en customize_airootfs + LC_TIME en
#   la sesion, (2) lang/es.js aceptado aguas arriba en MacShell.
