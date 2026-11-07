#!/bin/bash
# verify-plasma.sh — gate estático de la línea Plasma (sin root, sin ISO real).
# Comprueba: perfil Plasma, skel sincronizado, paquetes sin Hyprland y CI de
# NimbusShell. La ISO real y F12 se validan aparte en VM/hardware.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIMBUS_SHELL="${NIMBUS_SHELL:-$REPO_ROOT/../NimbusShell}"
FAIL=0
ok() { echo "  [OK] $*"; }
bad() { echo "  [FALLO] $*" >&2; FAIL=1; }

echo "== verify-plasma: perfil estático =="
if "$REPO_ROOT/build_iso.sh" --check-only --profile plasma >/tmp/opencode/verify-plasma-check.log 2>&1; then
    ok "build_iso.sh --check-only --profile plasma"
else
    bad "check-only Plasma"; tail -20 /tmp/opencode/verify-plasma-check.log
fi

echo "== verify-plasma: skel sincronizado con NimbusShell =="
if "$NIMBUS_SHELL/scripts/nimbus-skel-sync" --check \
    --src "$NIMBUS_SHELL/dotfiles" --dest "$REPO_ROOT/nimbus-overlay/etc/skel" >/dev/null 2>&1; then
    ok "skel 1:1 (extras legacy/ISO permitidos)"
else
    bad "skel desincronizado; ejecuta NimbusShell/scripts/nimbus-skel-sync --apply"
fi

echo "== verify-plasma: paquetes sin legado Hyprland =="
if grep -vE '^\s*#|^\s*$' "$REPO_ROOT/packages.nimbus-plasma.append" \
    | grep -qxE 'hyprland|quickshell|greetd|hyprpaper|swaybg|hyprshell|hyprland-plugin-hyprbars'; then
    bad "hay paquetes Hyprland en packages.nimbus-plasma.append"
else
    ok "sin paquetes Hyprland"
fi

echo "== verify-plasma: CI de NimbusShell =="
if ( cd "$NIMBUS_SHELL" && ./scripts/ci.sh ) >/tmp/opencode/verify-plasma-ci.log 2>&1; then
    ok "NimbusShell CI"
else
    bad "NimbusShell CI"; tail -20 /tmp/opencode/verify-plasma-ci.log
fi

if [ "$FAIL" = "0" ]; then echo "VERIFY-PLASMA PASS"; else echo "VERIFY-PLASMA FAIL" >&2; fi
exit "$FAIL"
