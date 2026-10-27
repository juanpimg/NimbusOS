# =============================================================================
# NimbusOS — profiledef.nimbus.inc (Task 5)
# Fragmento archiso consumido por build_iso.sh (paso apply_overlay): se aplica
# sobre work/upstream/archiso/profiledef.sh (base CachyOS-Live-ISO) con sed.
# NO es un profiledef completo: el perfil canonico sigue siendo el upstream;
# este fichero solo declara el DELTA NimbusOS para que el build sea auditable.
#
# 1. Renombrado ISO:
#      iso_name="cachyos"  ->  iso_name="nimbus"
#    (mkarchiso deriva out/nimbus-<iso_version>-x86_64.iso de iso_name.)
#
# 2. file_permissions ADITIVOS (binarios del overlay con 0755). build_iso.sh
#    inserta estas lineas dentro del array file_permissions=( ... ) upstream:
#      ["/usr/bin/macshell"]="0:0:755"
#      ["/usr/bin/nimbus-live-setup"]="0:0:755"
#      ["/usr/bin/nimbus-minimize-toggle"]="0:0:755"
#      ["/usr/bin/nimbus-installed-setup"]="0:0:755" (%post instalado P0)
#    El array upstream ya declara /root/.automated_script.sh y /usr/local/bin/*
#    con 0755; estas tres entradas son las unicas que aporta NimbusOS.
#
# REGLA: nunca declarar aqui /etc/passwd ni /etc/shadow (los gestiona el
# perfil upstream; sobrescribirlos romperia el login live). verify-build.sh
# falla si este fichero menciona passwd/shadow.
# M1 (fragilidad conocida): este parche asume la estructura
#   file_permissions=( ... ) del profiledef.sh upstream (apertura en su
#   propia linea + cierre `)` en su propia linea). Si el upstream reestructura
#   ese bloque, el build real falla en apply_overlay (assert de anclaje) en
#   lugar de corromper en silencio; actualizar entonces este .inc + el regex.
#   verify-build.sh alerta ademas si el upstream cambia de DM
#   (grep display-manager en el perfil; DM Nimbus V1: greetd+Hyprland, sin
#   prueba E2E — ver docs/qemu.md).
# =============================================================================
# NIMBUS_PROFILEDEF_PATCH_V1
NIMBUS_ISO_NAME="nimbus"
NIMBUS_FILE_PERMISSIONS_ADD=(
  '["/usr/bin/macshell"]="0:0:755"'
  '["/usr/bin/nimbus-live-setup"]="0:0:755"'
  '["/usr/bin/nimbus-minimize-toggle"]="0:0:755"'
  '["/usr/bin/nimbus-installed-setup"]="0:0:755"'
)
