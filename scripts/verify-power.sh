#!/bin/bash
# NimbusOS Task 2 — scripts/verify-power.sh
# Verifica capa power: append de paquetes + configs plantilla + excluidos ausentes.
# Uso: bash scripts/verify-power.sh [--root DIR]  (DIR por defecto: repo)
# Devuelve 0 si todo PASS; 1 si algun FAIL.
set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
if [ "${1:-}" = "--root" ]; then
  ROOT="${2:-}"
  [ -n "$ROOT" ] || { echo "Uso: $0 [--root DIR]" >&2; exit 2; }
fi
APP="$ROOT/packages.nimbus.x86_64.append"
OVL="$ROOT/nimbus-overlay"
ACF="$OVL/etc/auto-cpufreq.conf"
UDEV="$OVL/etc/udev/rules.d/80-nvidia-pm.rules"
MODP="$OVL/etc/modprobe.d/nvidia-pm.conf"
ZRAM="$OVL/etc/systemd/zram-generator.conf"
SYSCTL="$OVL/etc/sysctl.d/99-vm-zram-parameters.conf"
PASS=0; FAIL=0; SKIP=0
ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }
chk()  {
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi
}
chkg() {
  local d="$1" f="$2" re="$3"
  if grep -qE -- "$re" "$f" 2>/dev/null; then ok "$d"; else bad "$d"; fi
}

echo "== Task 2 verify: power + GPU hibrida + VA-API + ZRAM =="

# --- Ficheros existen ----------------------------------------------------------
for f in "$ACF" "$UDEV" "$MODP" "$ZRAM" "$SYSCTL" "$APP"; do
  [ -f "$f" ] && ok "existe: ${f#$ROOT/}" || bad "existe: ${f#$ROOT/}"
done

# --- Task1 intacto --------------------------------------------------------------
chkg "Task1 intacto (seccion Task 1)" "$APP" '--- Task 1'
for p in hyprland quickshell hyprlock kitty inter-font whitesur-gtk-theme whitesur-icon-theme capitaine-cursors; do
  chkg "Task1 intacto: $p" "$APP" "^${p}$"
done
chkg "Task2 seccion power presente" "$APP" '--- Task2 power'

# --- Paquetes Task2 (exactos del brief, menos Task5: nvidia-dkms/utils los aporta upstream) ---
for p in auto-cpufreq thermald zram-generator \
  lib32-nvidia-utils nvidia-prime switcheroo-control nvtop mesa vulkan-radeon \
  vulkan-intel vulkan-mesa-layers lib32-vulkan-mesa-layers libva libva-utils \
  vdpauinfo libvdpau-va-gl intel-media-driver libva-intel-driver libvpl \
  vpl-gpu-rt libva-nvidia-driver ffmpeg gst-plugins-bad mpv vlc; do
  chkg "append: $p" "$APP" "^${p}$"
done
for p in nvidia-dkms nvidia-utils; do
  if grep -qx "$p" "$APP" 2>/dev/null; then bad "Task5: sin $p duplicado (lo aporta upstream)"; else ok "Task5: sin $p duplicado (lo aporta upstream)"; fi
done
chkg "append marca seccion AUR" "$APP" 'AUR'

# --- Excluidos ausentes como paquetes -------------------------------------------
for p in power-profiles-daemon tuned-ppd tlp bumblebee optimus-manager xf86-video-intel; do
  if grep -qE "^${p}$" "$APP" 2>/dev/null; then
    bad "excluido ausente del append: $p"
  else
    ok "excluido ausente del append: $p"
  fi
done

# --- auto-cpufreq: valores exactos -----------------------------------------------
chkg "acf [charger]" "$ACF" '^\[charger\]'
chkg "acf [battery]" "$ACF" '^\[battery\]'
chkg "acf charger governor=performance" "$ACF" '^governor = performance'
chkg "acf charger EPP=balance_performance" "$ACF" '^energy_performance_preference = balance_performance'
chkg "acf charger turbo=always" "$ACF" '^turbo = always'
chkg "acf charger platform_profile=performance" "$ACF" '^platform_profile = performance'
chkg "acf battery governor=powersave" "$ACF" '^governor = powersave'
chkg "acf battery EPP=balance_power" "$ACF" '^energy_performance_preference = balance_power'
chkg "acf battery turbo=auto" "$ACF" '^turbo = auto'
chkg "acf battery platform_profile=low-power" "$ACF" '^platform_profile = low-power'

# --- udev NVIDIA ------------------------------------------------------------------
chkg "udev power/control=auto" "$UDEV" 'ATTR\{power/control\}="auto"'
chkg "udev PCI 10de" "$UDEV" '0x10de'

# --- modprobe NVIDIA ---------------------------------------------------------------
chkg "modprobe NVreg_DynamicPowerManagement=0x02" "$MODP" 'NVreg_DynamicPowerManagement=0x02'
chkg "modprobe nota 0x03 Ampere+" "$MODP" '0x03'
chkg "modprobe nvidia-drm modeset=1" "$MODP" 'nvidia-drm.*modeset=1|modeset=1'

# --- zram ---------------------------------------------------------------------------
chkg "zram zstd" "$ZRAM" 'zstd'
chkg "zram min(ram/2,8192)" "$ZRAM" 'min\(ram / 2, 8192\)'
chkg "zram priority 100" "$ZRAM" 'swap-priority = 100'

# --- sysctl ---------------------------------------------------------------------------
chkg "sysctl swappiness=180" "$SYSCTL" '^vm\.swappiness = 180'
chkg "sysctl watermark_boost_factor=0" "$SYSCTL" '^vm\.watermark_boost_factor = 0'
chkg "sysctl watermark_scale_factor=125" "$SYSCTL" '^vm\.watermark_scale_factor = 125'
chkg "sysctl page-cluster=0" "$SYSCTL" '^vm\.page-cluster = 0'

# --- Sintaxis --------------------------------------------------------------------------
chk "verify-power supera bash -n" bash -n "$ROOT/scripts/verify-power.sh"
if command -v udevadm >/dev/null 2>&1; then
  chk "udev rules validas (udevadm verify)" udevadm verify "$UDEV"
else
  skip "udevadm verify (udevadm no instalado)"
fi
# systemd-analyze verify solo valida units, no sysctl.d: chequeo sintactico
# propio (toda linea activa debe ser `clave = valor`).
if awk 'NF && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*[a-z0-9._-]+[[:space:]]*=[[:space:]]*[^[:space:]]/ {bad=1} END{exit bad}' "$SYSCTL" 2>/dev/null; then
  ok "sysctl sintaxis clave=valor"
else
  bad "sysctl sintaxis clave=valor"
fi

# --- Checks live/QEMU (SKIP fuera de live) -----------------------------------------------
if command -v vainfo >/dev/null 2>&1; then
  chk "live: vainfo OK" vainfo
else
  skip "live: vainfo (no instalado fuera de live)"
fi
if command -v zramctl >/dev/null 2>&1 && zramctl --noheadings 2>/dev/null | grep -q .; then
  chk "live: zram activo" zramctl
else
  skip "live: zramctl (sin zram en host de build)"
fi

echo "-------------------------------------------------------------"
echo "RESULT: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
