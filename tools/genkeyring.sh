#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Genera la clave GPG de firma de Nimbus y el árbol del paquete nimbus-keyring.
set -euo pipefail

OUTDIR=""
KEYUID=""
EMAIL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --outdir)
      OUTDIR="${2:-}"
      shift 2
      ;;
    --uid)
      KEYUID="${2:-}"
      shift 2
      ;;
    --email)
      EMAIL="${2:-}"
      shift 2
      ;;
    *)
      echo "genkeyring: opción desconocida: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$OUTDIR" ] || [ -z "$KEYUID" ] || [ -z "$EMAIL" ]; then
  echo "genkeyring: se requieren --outdir, --uid y --email" >&2
  exit 1
fi

if [ -f "$OUTDIR/nimbus.gpg" ]; then
  echo "genkeyring: el keyring ya existe en $OUTDIR/nimbus.gpg" >&2
  exit 1
fi

mkdir -p "$OUTDIR/gnupg"
chmod 700 "$OUTDIR/gnupg"

gpg --homedir "$OUTDIR/gnupg" --batch --yes --quiet --passphrase '' \
  --quick-generate-key "$KEYUID" rsa4096 sign never

FPR="$(gpg --homedir "$OUTDIR/gnupg" --batch --yes --quiet --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"

gpg --homedir "$OUTDIR/gnupg" --batch --yes --quiet --armor --export "$KEYUID" \
  > "$OUTDIR/nimbus.gpg"

mkdir -p "$OUTDIR/nimbus-keyring"
cp "$OUTDIR/nimbus.gpg" "$OUTDIR/nimbus-keyring/nimbus.gpg"
printf '%s:6:\n' "$FPR" > "$OUTDIR/nimbus-keyring/nimbus-trusted"
: > "$OUTDIR/nimbus-keyring/nimbus-revoked"
cat > "$OUTDIR/nimbus-keyring/nimbus-keyring.install" <<'EOF'
usr/share/pacman/keyrings/nimbus.gpg
usr/share/pacman/keyrings/nimbus-trusted
usr/share/pacman/keyrings/nimbus-revoked
post_install() {
  pacman-key --populate nimbus
}
EOF

printf '%s\n' "$FPR"
