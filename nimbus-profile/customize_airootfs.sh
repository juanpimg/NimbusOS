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
