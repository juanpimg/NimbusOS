#!/bin/sh
# NimbusOS: reservado para variables de entorno de la sesion Plasma.
# (Shebang solo para shellcheck; startplasma-wayland hace source del fichero.)
# NO lanza procesos: startplasma-wayland hace source de este script antes de
# que exista Wayland y nimbus-bar moria con `Failed to create wl_display`
# (bug F3-T03). Vias de arranque de la barra: nimbus-bar.service (systemd)
# y autostart nimbus-bar.desktop (fallback no-systemd).
