#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck disable=SC2034

iso_name="nimbus"
iso_label="NIMBUS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Nimbus <https://github.com/juanpimg/NimbusOS>"
iso_application="Nimbus Linux"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="nimbus"
bootmodes=('bios.syslinux'
           'uefi.grub')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
# Consola serie para el harness de QEMU (tests/integration/boot_live.sh):
# la ultima consola listada es /dev/console, asi el marcador NIMBUS_LIVE_READY
# llega al log serie sin quitar la salida en pantalla.
kernel_params_x86_64="console=tty0 console=ttyS0,115200"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
)
