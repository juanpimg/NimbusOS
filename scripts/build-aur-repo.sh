#!/bin/bash
# NimbusOS — pre-compila las AUR del manifest en el host (CPU real) y genera
# el repo local work/nimbus-repo/ que pacstrap consumira como binarios.
# Uso: ./build-aur-repo.sh  (pide sudo una vez al inicio; keep-alive interno)
set -u
cd "$(dirname "$0")/.." || exit 1

printf '%s\n' '1216' | sudo -S -v || { echo "sin sudo, abortar" >&2; exit 1; }
( while sleep 240; do sudo -n -v 2>/dev/null || true; done ) & KA=$!
trap 'kill $KA 2>/dev/null || true' EXIT

# Paso 0: pre-instalar TODAS las dependencias (build + runtime) con sudo
# no-interactivo. Asi makepkg -s nunca necesita invocar sudo (que falla sin
# tty en segundo plano). --asdeps para no contaminar el host como explicitos.
pipe_sudo() { printf '%s\n' '1216' | sudo -S "$@"; }
pipe_sudo pacman -Sy --needed --noconfirm --asdeps \
    base-devel vala meson ninja gobject-introspection itstool asciidoc \
    xorgproto gettext sassc which gtk3 rust gtk4 gtk4-layer-shell libadwaita \
    libnotify libhandy desktop-file-utils zstd gnutls git hyprland \
    || { echo "FAIL pre-instalar deps" >&2; exit 1; }

mkdir -p work/aur-build && cd work/aur-build || exit 1
for p in whitesur-gtk-theme whitesur-icon-theme hyprshell libpamac-aur pamac-aur; do
    if [ ! -d "$p" ]; then
        _ok=0
        for _try in 1 2 3 4 5; do
            if paru -G "$p"; then _ok=1; break; fi
            echo "reintento fetch $p ($_try/5) en 20s..." >&2; sleep 20
        done
        [ "$_ok" = "1" ] || { echo "FAIL fetch $p" >&2; exit 1; }
    fi
    ( cd "$p" && makepkg -s --noconfirm --needed ) || { echo "FAIL build $p" >&2; exit 1; }
    # Instalar en el host (necesario para encadenar deps AUR: pamac-aur
    # requiere libpamac-aur en la DB; --asdeps para no contaminar):
    pipe_sudo pacman -U --noconfirm --asdeps "$p"/*.pkg.tar.zst || { echo "FAIL install $p" >&2; exit 1; }
    echo "OK built+installed $p"
done
mkdir -p ../nimbus-repo
cp ./*/*.pkg.tar.zst ../nimbus-repo/ 2>/dev/null || true
cd ../nimbus-repo || exit 1
repo-add nimbus.db.tar.gz *.pkg.tar.zst || exit 1
ls -lh
echo "AUR-REPO OK"
