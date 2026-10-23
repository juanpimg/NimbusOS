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
# Global-menu V1: la top-bar muestra solo el titulo de la app activa, sin
#   menu D-Bus appmenu (sin vala-panel-appmenu/protocolo global-menu).
