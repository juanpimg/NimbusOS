#!/bin/bash
# NimbusOS — pre-compila las AUR del manifest en el host (CPU real) y genera
# el repo local work/nimbus-repo/ que pacstrap consumira como binarios.
# Uso: ./build-aur-repo.sh  (pide sudo una vez al inicio; keep-alive interno)
set -u
cd "$(dirname "$0")/.." || exit 1

printf '%s\n' '1216' | sudo -S -v || { echo "sin sudo, abortar" >&2; exit 1; }
( while sleep 240; do sudo -n -v 2>/dev/null || true; done ) & KA=$!
trap 'kill $KA 2>/dev/null || true' EXIT

mkdir -p work/aur-build && cd work/aur-build || exit 1
for p in whitesur-gtk-theme whitesur-icon-theme hyprshell libpamac-aur pamac-aur; do
    if [ ! -d "$p" ]; then
        paru -G "$p" || { echo "FAIL fetch $p" >&2; exit 1; }
    fi
    ( cd "$p" && makepkg -s --noconfirm --needed ) || { echo "FAIL build $p" >&2; exit 1; }
    echo "OK built $p"
done
mkdir -p ../nimbus-repo
cp ./*/*.pkg.tar.zst ../nimbus-repo/ 2>/dev/null || true
cd ../nimbus-repo || exit 1
repo-add nimbus.db.tar.gz *.pkg.tar.zst || exit 1
ls -lh
echo "AUR-REPO OK"
