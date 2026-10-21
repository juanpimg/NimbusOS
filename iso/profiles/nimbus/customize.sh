#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

echo "[nimbus] customize: ajustando la imagen"

# Marca de Nimbus en el sistema.
cat > /etc/os-release <<'EOF'
NAME="Nimbus"
PRETTY_NAME="Nimbus Linux"
ID=nimbus
ID_LIKE=arch cachyos
ANSI_COLOR="38;2;0;122;255"
HOME_URL="https://github.com/juanpimg/NimbusOS"
EOF

# Mot de passe y configuracion de la sesion live.
echo "root:nimbus" | chpasswd

# En la ISO live la sesion la aporta nimbus-live.service, no SDDM: dos gestores
# de display peleandose por la pantalla hacen que la sesion parpadee.
systemctl disable sddm.service 2>/dev/null || true
cat > /etc/sddm.conf <<'EOF'
[Autologin]
Session=hyprland
User=nimbus
EOF

# El repo de Nimbus queda disponible para la instalación.
pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm nimbus-keyring
pacman -S --noconfirm --needed nimbus-shell nimbus-dots
