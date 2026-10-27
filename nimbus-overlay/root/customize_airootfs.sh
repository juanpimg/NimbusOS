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

# Puente temporal con las librerias REALES 1.91 (no symlink: ABI incompatible,
# probado en VM). Se instalan SOLO si algun binario de Calamares las sigue
# pidiendo (grep sobre las entradas NEEDED del ELF; sin readelf). Cuando
# upstream reconstruya contra 1.92, el guard no se cumple y la compat deja
# de instalarse sola. Ruling out: symlink a 1.92 e inyectar .so sin condicion.
_CAL_NEED_191=0
for _cb in /usr/bin/calamares /usr/lib/calamares/libcalamares.so /usr/lib/libcalamares.so; do
    if [ -f "$_cb" ] && grep -q 'libboost_.*\.so\.1\.91\.0' "$_cb" 2>/dev/null; then
        _CAL_NEED_191=1; break
    fi
done
if [ "$_CAL_NEED_191" = "1" ]; then
    _n=0
    for _lib in /usr/share/nimbus/compat/libboost_*.so.1.91.0; do
        [ -f "$_lib" ] || continue
        install -Dm644 "$_lib" "/usr/lib/$(basename "$_lib")" && _n=$((_n+1))
    done
    echo "customize_airootfs: compat boost 1.91 instaladas ($_n libs, Calamares las pide)"
    [ "$_n" -gt 0 ] || echo "customize_airootfs AVISO: Calamares pide 1.91 pero staging vacio (revisar build)" >&2
else
    echo "customize_airootfs: Calamares ya no pide boost 1.91 (compat innecesaria, omitida)"
fi

# Branding del SO (derivado honesto, como Ubuntu hace con Debian):
# /etc/os-release lo pone el paquete base (dice CachyOS) y about-info.sh de
# MacShell lo lee en vivo para "About This Linux". Se reetiqueta SOLO el nombre
# visible (NAME/PRETTY_NAME); ID/ID_LIKE/URLs se conservan para no romper
# tooling que detecta la base. Idempotente y con guards.
if [ -f /etc/os-release ]; then
    sed -i 's/^NAME=.*/NAME="NimbusOS"/; s/^PRETTY_NAME=.*/PRETTY_NAME="NimbusOS"/' /etc/os-release
    echo "customize_airootfs: os-release reetiquetado a NimbusOS (ID intacto)"
else
    echo "customize_airootfs AVISO: sin /etc/os-release (omitido)" >&2
fi
