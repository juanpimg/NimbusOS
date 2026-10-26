#!/bin/bash
# NimbusOS — pre-compila las AUR del manifest en el host (CPU real) y genera
# el repo local work/nimbus-repo/ que pacstrap consumira como binarios.
# Uso: ./build-aur-repo.sh  (pide sudo una vez al inicio; keep-alive interno)
set -u
cd "$(dirname "$0")/.." || exit 1
ROOT="$PWD"

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
    libnotify libhandy desktop-file-utils zstd gnutls git hyprland cmake \
    dbus-glib appstream appstream-glib archlinux-appstream-data json-glib \
    libsoup3 polkit vte3 \
    || { echo "FAIL pre-instalar deps" >&2; exit 1; }

mkdir -p work/aur-build && cd work/aur-build || exit 1
# Mapeo paquete -> directorio de fuentes (los split packages como
# hyprland-plugin-hyprbars viven en el pkgbase hyprland-plugins).
srcdir_of() { case "$1" in hyprland-plugin-hyprbars) echo hyprland-plugins;; *) echo "$1";; esac; }
for p in whitesur-gtk-theme whitesur-icon-theme hyprshell libpamac-aur pamac-aur hyprland-plugin-hyprbars; do
    d="$(srcdir_of "$p")"
    if [ ! -d "$d" ]; then
        _ok=0
        for _try in 1 2 3 4 5; do
            if paru -G "$p"; then _ok=1; break; fi
            echo "reintento fetch $p ($_try/5) en 20s..." >&2; sleep 20
        done
        [ "$_ok" = "1" ] || { echo "FAIL fetch $p" >&2; exit 1; }
    fi
    if ls "$d/$p"-*.pkg.tar.zst >/dev/null 2>&1; then
        echo "OK $p ya compilado, reutilizo binario"
    else
        # Sin --pkg (makepkg antiguo): compila todos los splits del pkgbase
        # e instalamos/copiamos solo el nuestro ($p-*.pkg.tar.zst).
        ( cd "$d" && makepkg -s --noconfirm ) || { echo "FAIL build $p" >&2; exit 1; }
    fi
    # Instalar en el host (necesario para encadenar deps AUR: pamac-aur
    # requiere libpamac-aur en la DB; --asdeps para no contaminar):
    pipe_sudo pacman -U --noconfirm --asdeps "$d/$p"-*.pkg.tar.zst || { echo "FAIL install $p" >&2; exit 1; }
    echo "OK built+installed $p"
done
mkdir -p ../nimbus-repo
# Copiar SOLO los paquetes del manifest (un pkgbase split puede haber
# compilado hermanos que no queremos en la ISO).
[ -f "$ROOT/packages.nimbus-aur.txt" ] || { echo "FAIL sin manifest $ROOT/packages.nimbus-aur.txt" >&2; exit 1; }
while IFS= read -r _aur || [ -n "$_aur" ]; do
    case "$_aur" in ''|\#*) continue ;; esac
    _found="$(ls ./*/"$_aur"-*.pkg.tar.zst 2>/dev/null || true)"
    [ -n "$_found" ] || { echo "FAIL falta binario $_aur" >&2; exit 1; }
    # shellcheck disable=SC2086
    cp $_found ../nimbus-repo/ || exit 1
done < "$ROOT/packages.nimbus-aur.txt"
cd ../nimbus-repo || exit 1
repo-add nimbus.db.tar.gz *.pkg.tar.zst || exit 1
ls -lh
echo "AUR-REPO OK"
