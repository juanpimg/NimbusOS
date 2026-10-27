#!/bin/bash
# NimbusOS — nimbus-profile/customize_airootfs.sh
# Corre post-pacstrap como root (mkarchiso lo detecta en la raiz del perfil).
# Reaplica los 5 ficheros en conflicto (owned por cachyos-calamares-next y
# cachyos-kde-settings) desde el staging hacia su destino final.
# El overlay los copio a airootfs ANTES de pacstrap y pacman abortaria por
# conflicting files; por eso apply_overlay los mueve a
# /usr/share/nimbus/staging/ y este script los instala con overwrite.
set -euo pipefail

STAGING="/usr/share/nimbus/staging"
FILES=(
    "etc/calamares/modules/displaymanager.conf"
    "etc/calamares/modules/partition.conf"
    "etc/calamares/modules/users.conf"
    "etc/skel/.config/gtk-3.0/settings.ini"
    "etc/skel/.config/gtk-4.0/settings.ini"
)

for rel in "${FILES[@]}"; do
    src="$STAGING/$rel"
    dst="/$rel"
    if [ -f "$src" ]; then
        install -Dm644 "$src" "$dst"
        echo "customize_airootfs: instalado $dst (desde staging)"
    else
        echo "customize_airootfs AVISO: falta staging $src (omitido)" >&2
    fi
done

# Piel total (plan workflow-mac-piel-total Task 2): estos ficheros no los posee
# ningun paquete, asi que cp -a del overlay ya los deja en su destino; aqui se
# asegura presencia y permisos 644 de forma idempotente. Si algun build los
# difiriera a staging, se reinstalan desde ahi. Guards [ -f ]; seguro con
# `set -u`; nunca falla aunque un fichero falte.
SKIN_FILES=(
    "etc/skel/.config/hypr/hyprlock.conf"
    "etc/skel/.config/qt6ct/qt6ct.conf"
    "etc/dconf/db/local.d/nimbus"
    "etc/default/grub.d/nimbus.cfg"
)

for rel in "${SKIN_FILES[@]}"; do
    src="$STAGING/$rel"
    dst="/$rel"
    if [ -f "$src" ]; then
        install -Dm644 "$src" "$dst"
        echo "customize_airootfs: instalado $dst (piel, desde staging)"
    elif [ -f "$dst" ]; then
        chmod 644 "$dst"
        echo "customize_airootfs: piel ya presente $dst (permisos 644)"
    else
        echo "customize_airootfs AVISO: falta piel $dst (omitido)" >&2
    fi
done

# Compilar la base dconf si el override existe (idempotente; no falla si
# dconf no esta instalado en este punto del build):
if [ -f /etc/dconf/db/local.d/nimbus ] && command -v dconf >/dev/null 2>&1; then
    dconf update || echo "customize_airootfs AVISO: dconf update fallo (omitido)" >&2
fi

# Compatibilidad Calamares/boost (desync upstream 2026-10-26/27):
# cachyos-calamares-next enlaza libboost_python314.so.1.91.0 pero los repos ya
# sirven boost-libs 1.92.0 (verificado en sfs: consumidores piden 1.91.0,
# solo existe 1.92.0) y Calamares no arranca. Puente temporal con symlink
# (la ABI de libboost_python entre 1.91 y 1.92 es compatible para este uso;
# se valida lanzando Calamares en QEMU). QUITAR cuando upstream reconstruya
# Calamares contra 1.92: el guard solo actua si falta 1.91.0 y existe 1.92.0.
if [ ! -e /usr/lib/libboost_python314.so.1.91.0 ] && [ -e /usr/lib/libboost_python314.so.1.92.0 ]; then
    ln -s libboost_python314.so.1.92.0 /usr/lib/libboost_python314.so.1.91.0
    echo "customize_airootfs: compat symlink boost 1.91.0 -> 1.92.0 (temporal upstream)"
fi
