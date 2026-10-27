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

# NOTA Calamares/boost (desync upstream 2026-10-26/27, verificado en VM):
# cachyos-calamares-next 3.4.2-13 (2026-08-13) enlaza libboost_python314.so.1.91.0
# pero los repos sirven boost-libs 1.92.0. Se probó un symlink 1.91->1.92:
# NO vale (símbolo _ZN5boost6python6detail11init_module... ausente en 1.92,
# error en VM). Sin puente posible desde nuestra capa: hay que esperar a que
# CachyOS reconstruya Calamares contra 1.92; el próximo build lo recoge solo.
# NO crear el symlink: solo enmascara el error real.
