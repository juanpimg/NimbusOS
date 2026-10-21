#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

echo "[nimbus] airoot: preparando la imagen"

# Mirrores por defecto de la ISO (los definitivos se configuran en la instalación).
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://archlinux.cachyos.org/repo/$repo/os/$arch
EOF

# El repo de Nimbus. Durante el bootstrap, build.sh lo inyecta como repo local
# file:// con el flag --local-repo; en producción, es la URL pública.
NIMBUS_REPO_URL="${NIMBUS_REPO_URL:-file:///run/archiso/bootmnt/nimbus-repo}"
cat > /etc/pacman.d/mirrorlist.nimbus <<EOF
Server = ${NIMBUS_REPO_URL}
EOF
cat >> /etc/pacman.conf <<'EOF'

[nimbus]
# TODO(bootstrap): el repo local de bootstrap va sin firmar, asi que la
# verificacion se relaja. Cuando el repo publico este alojado y firmado
# (repo de produccion), esto pasa a:
#   SigLevel = Required DatabaseOptional
SigLevel = Optional
Server = file:///run/archiso/bootmnt/nimbus-repo
EOF

pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm nimbus-keyring
pacman -S --noconfirm --needed nimbus-shell nimbus-dots

# Se activa el servicio que arranca el shell de la sesión live.
systemctl enable nimbus-live.service
