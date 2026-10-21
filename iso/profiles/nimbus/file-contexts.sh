#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

# Contexto de SELinux (no se usa en Nimbus, pero archiso lo exige).
echo "system_u:object_r:usr_t:s0 /usr/lib/nimbus(/.*)?"
