# NimbusOS ISO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir ISO booteable reproducible NimbusOS (CachyOS + Hyprland flotante estilo macOS) con macshell, tienda gráfica, power-tuning laptop y Calamares estilo Setup Assistant.

**Architecture:** No forkar base. Clonar tag fijo de `CachyOS/CachyOS-Live-ISO`, aplicar overlay `nimbus-overlay/` sobre `archiso/airootfs/` (+ append a `packages_desktop.x86_64`), mantener `pacman.conf` solo con repos oficiales. Toda UI viene de upstreams existentes.

**Tech Stack:** CachyOS (`linux-cachyos` BORE), Hyprland >=0.55 (Lua), Quickshell MacShell (`0-ss/MacShell`), pamac-gtk, auto-cpufreq, zram-generator, Calamares (base `cachyos-calamares`), archiso/mkarchiso, QEMU/KVM validación.

**Spec:** `docs/ESPECIFICACION.md` (antes `INICIO.txt` en raíz) (paso 0 + regla no-reinventar + ergonomía + specs técnicas + 5 subagentes + 4 fases).

## Global Constraints

- Base consume exclusivamente repos oficiales CachyOS + Arch vía `pacman.conf`. Nosotros solo capa integración ISO/dotfiles/temas.
- Prohibido programar docks/bars/stores/instaladores desde cero si existe repo funcional. Clonar/adaptar.
- Hyprland abre todo flotante por defecto: `windowrulev2 = float, class:^(.*)$`.
- Atajos `Ctrl+C/V/X/Z/S/A/F/P` intactos (no bindear en Hyprland). `Super`/`Super+Espacio`=Spotlight/Launchpad, `Alt+Tab`=switch con preview.
- Esquinas 12-14px, sombras suaves, blur Dual-Kawase sobre macshell. Semáforos rojo/amarillo/verde arriba-izquierda.
- `exec-once = macshell` garantizado al inicio.
- Flatpak/Flathub prioritario por defecto, AUR transparente sin `makepkg` manual, cero terminal para tareas cotidianas.
- Calamares: pantalla `Hello`, fuente Inter/SF, `Borrar disco e instalar` por defecto, copia íntegra `/etc/skel` vía `useradd -m`.
- Reproducible: fijar tag upstream + `SOURCE_DATE_EPOCH`, manifest con commits.

## Review Focus

- Hyprland 0.55+ usa Lua (`hyprland.lua`), ignora `hyprland.conf` para `hl.dsp.*`. Esperado: bar/dock/glass funcionan, binds Lua fallan si solo se escribe `.conf`.
- MacShell crash `wl_display invalid object` con muchas ventanas + live capture. Esperado: auto-restart + opción OFF glass/capture.
- CPU host sin x86-64-v3/v4 ejecuta `linux-cachyos` con illegal-instruction. Esperado: check `lscpu` previo, abortar con mensaje claro.
- QEMU sin `-device acpi-battery` (QEMU<8.2) reporta `upower -d` sin batería. Esperado: fallback documentado, no falso verde.
- Menú global D-Bus real no existe en MacShell (solo título app). Esperado: no prometerlo en V1, fake-menu documentado.

---

### Task 1: macshell + hyprland.conf flotante

**Files:**
- Create: `nimbus-overlay/etc/skel/.config/hypr/hyprland.conf`
- Create: `nimbus-overlay/usr/bin/macshell` (wrapper a `~/.local/bin/macshell-start`)
- Create: `nimbus-overlay/etc/skel/.config/macshell/env`
- Test: `scripts/verify-macshell.sh`

**Interfaces:**
- Consumes: upstream `https://github.com/0-ss/MacShell` (MIT, 245 stars, push 2026-10-23, Quickshell>=0.3.2, Qt6.8+, Hyprland>=0.55 Lua)
- Produces: `exec-once = macshell` funcional, `layerrule blur macdock/macspot/macbarbg`, binds `SUPER Space -> qs spotlight toggle`, `ALT Tab -> switcher next`

- [ ] **Step 1: Fijar versión upstream**

Pin `main @ 2026-10-23` (186 commits) en `iso.manifest`. Alternativas descartadas: `megaturtl/ags-hyprland`, `randalmurphal/ags-configs` (0 stars), `Jas-SinghFSU/HyprPanel` (no macOS fiel).

- [ ] **Step 2: Escribir `hyprland.conf` flotante + blur + binds**

Incluir: `windowrulev2=float all`, rounded 12-14px, `decoration blur enabled` (Dual-Kawase), `layerrule blur macdock/macspot/macbarbg + ignorealpha`, `exec-once=macshell`, `SUPER Space`, `SUPER V clipboard`, `ALT Tab switcher`, `SUPER L lock`. No bindear `CTRL-*`. `QS_ICON_THEME=papirus`, `wallpaperPath` fijo en settings.json.

- [ ] **Step 3: Verificar sintaxis y desconflictos**

Run: `hyprland --check-config -c nimbus-overlay/etc/skel/.config/hypr/hyprland.conf` + `grep -r waybar/hyprpanel/ags/dunst/mako/swaync nimbus-overlay/ || true`
Expected: PASS sin errores, sin shells conflictivos (MacBar posee `org.freedesktop.Notifications`).

- [ ] **Step 4: Commit**

```bash
git add nimbus-overlay/etc/skel/.config/hypr/hyprland.conf nimbus-overlay/usr/bin/macshell
git commit -m "feat(hypr): floating default + macshell autostart + blur"
```

### Task 2: Laptop power + GPU híbrida + VA-API + ZRAM

**Files:**
- Create: `nimbus-overlay/etc/auto-cpufreq.conf` (plantilla `[charger]/[battery]`)
- Create: `nimbus-overlay/etc/udev/rules.d/80-nvidia-pm.rules`
- Create: `nimbus-overlay/etc/modprobe.d/nvidia-pm.conf`
- Create: `nimbus-overlay/etc/systemd/zram-generator.conf`
- Create: `nimbus-overlay/etc/sysctl.d/99-vm-zram-parameters.conf`
- Modify: `packages.nimbus.x86_64.append` (sección power/drivers/codecs)
- Test: `scripts/verify-power.sh`

**Interfaces:**
- Consumes: decisión `auto-cpufreq` (no PPD), PRIME RTD3 nativo (no supergfxctl abandonado, no envycontrol archivado 2026-05), `zram-generator+zstd`
- Produces: paquetes listos para append, valores `governor/EPP/platform_profile`, `NVreg_DynamicPowerManagement=0x02/0x03`, `zram-size=min(ram/2,8192)`

- [ ] **Step 1: Escribir append de paquetes**

```
auto-cpufreq thermald zram-generator nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-prime switcheroo-control nvtop mesa vulkan-radeon vulkan-intel vulkan-mesa-layers lib32-vulkan-mesa-layers libva libva-utils vdpauinfo libvdpau-va-gl intel-media-driver libva-intel-driver libvpl vpl-gpu-rt libva-nvidia-driver ffmpeg gst-plugins-bad mpv vlc
```
Excluir: `power-profiles-daemon tuned-ppd tlp bumblebee optimus-manager xf86-video-intel`.

- [ ] **Step 2: Escribir configs plantilla (sin aplicar en host)**

`auto-cpufreq`: charger `performance/balance_performance/always/performance`, battery `powersave/balance_power/auto/low-power`. udev `power/control=auto` PCI 10de. modprobe `NVreg_DynamicPowerManagement=0x02` (Turing) nota `0x03` Ampere+, `nvidia-drm.modeset=1`. zram `zstd, min(ram/2,8192), priority 100`. sysctl `swappiness=180, watermark_boost_factor=0, watermark_scale_factor=125, page-cluster=0`.

- [ ] **Step 3: Verificar en QEMU/live (post-build)**

Run: `vainfo; vdpauinfo; zramctl; cat /sys/bus/pci/devices/*/power/runtime_status | grep suspended; auto-cpufreq --stats`
Expected: VA-API OK Intel/AMD, `suspended` dGPU en reposo, ZRAM `[zstd]` activo.

- [ ] **Step 4: Commit**

```bash
git add nimbus-overlay/etc/auto-cpufreq.conf nimbus-overlay/etc/udev/rules.d/80-nvidia-pm.rules packages.nimbus.x86_64.append
git commit -m "feat(power): auto-cpufreq + PRIME RTD3 + ZRAM zstd"
```

### Task 3: App Store + USB plug&play + atajos

**Files:**
- Modify: `packages.nimbus.x86_64.append` (añadir tienda/USB)
- Create: `nimbus-overlay/etc/pamac.conf.d/nimbus.conf` (`EnableFlatpak=true, EnableAUR=true`)
- Create: `nimbus-overlay/etc/skel/.config/hypr/10-shortcuts.conf` (importado desde hyprland.conf)
- Modify: `nimbus-overlay/etc/skel/.config/hypr/hyprland.conf` (añadir `exec-once udiskie/polkit/notifs`)
- Test: `scripts/verify-store.sh`

**Interfaces:**
- Consumes: `https://github.com/manjaro/pamac` + `libpamac`, Flathub `https://dl.flathub.org/repo/flathub.flatpakrepo`
- Produces: tienda única OOTB, `flatpak remote-add flathub` en post-install, `udiskie --automount --notify --smart-tray`

- [ ] **Step 1: Decisión documentada (no reabrir)**

Elegido `pamac-gtk + libpamac-flatpak-plugin + appstream + archlinux-appstream-data + flatpak + xdg-desktop-portal-hyprland + base-devel git polkit-gnome + whitesur-gtk-theme`. Descartado `vinifmor/bauh` (abandonado 0.10.7 Ene-2024, foro CachyOS pide removerlo), `Discover` (sin AUR por diseño, PackageKit lock, desaconsejado ArchWiki). Nota: `Seafoam-Labs/Shelly-ALPM` reevaluar en 6 meses.

- [ ] **Step 2: Escribir autostart USB + portal**

```
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = udiskie --automount --notify --smart-tray
exec-once = swaynotificationcenter
```
Paquetes: `udisks2 udiskie gvfs gvfs-mtp ntfs-3g exfatprogs dosfstools mtools swaynotificationcenter nautilus`.

- [ ] **Step 3: Verificar atajos no roban Ctrl**

Run: `grep -E 'bind.*CTRL.*(C|V|X|Z|S|A|F|P)' nimbus-overlay/etc/skel/.config/hypr/*.conf || echo OK; grep -E 'SUPER, SPACE|ALT, TAB' nimbus-overlay/etc/skel/.config/hypr/*.conf`
Expected: `OK` (cero binds Ctrl), `SUPER SPACE` launcher + `ALT TAB hyprshell switch` presentes. `hyprshell https://github.com/H3rmt/hyprshell` como preview (fallback `cyclenext` comentado).

- [ ] **Step 4: Commit**

```bash
git add packages.nimbus.x86_64.append nimbus-overlay/etc/pamac.conf.d/nimbus.conf
git commit -m "feat(store): pamac + flathub + udiskie plug&play"
```

### Task 4: Calamares estilo Setup Assistant

**Files:**
- Create: `nimbus-overlay/etc/calamares/branding/nimbus/branding.desc`
- Create: `nimbus-overlay/etc/calamares/branding/nimbus/show.qml`
- Create: `nimbus-overlay/etc/calamares/branding/nimbus/stylesheet.qss`
- Create: `nimbus-overlay/etc/calamares/settings.conf`
- Create: `nimbus-overlay/etc/calamares/modules/partition.conf`
- Create: `nimbus-overlay/etc/calamares/modules/users.conf`
- Create: `nimbus-overlay/etc/calamares/modules/displaymanager.conf`
- Test: `qmlscene -I /usr/share/calamares/qml branding/nimbus/show.qml`

**Interfaces:**
- Consumes: base `https://github.com/CachyOS/cachyos-calamares` (75 stars, branch cachyos, GPL-3.0) + ejemplos `calamares/calamares-extensions` (ahora codeberg.org/Calamares). No existe tema maduro macOS, se adapta `fancy/` ejemplo.
- Produces: flujo `Hello->locale/keyboard->partition(erase)->users->summary->finished Reboot`, `windowSize 1024x640`, paleta `#F5F5F7/#1D1D1F/#007AFF`, font Inter.

- [ ] **Step 1: Copiar base CachyOS y recortar sequence**

`branding: nimbus`, `show: [welcome,locale,keyboard,partition,users,summary]`, `exec: [partition,mount,unpackfs,machineid,locale,keyboard,localecfg,fstab,initcpiocfg,initcpio,users,displaymanager,networkcfg,hwclock,services-systemd,initramfs,bootloader,umount]`, `prompt-install:false, oem-setup:false`, quitar `tracking/packagechooserq/notesqml`. `partition: erase default, allowManualPartitioning:false, swap file, btrfs/ext4, efi 512MiB`. `users: wheel, bash, no root pass`. `displaymanager: [greetd], Hyprland`.

- [ ] **Step 2: Escribir branding.desc + QSS + show.qml Hello**

`welcomeStyleCalamares:false, welcomeExpandingLogo:true, sidebar widget|none, SidebarBackground #F5F5F7, SidebarText #1D1D1F, Current #007AFF, slideshowAPI:2`, 3 slides máximo.

- [ ] **Step 3: Verificar QML + skel intacto**

Run: `qmlscene -I /usr/share/calamares/qml nimbus-overlay/etc/calamares/branding/nimbus/show.qml` + `ls nimbus-overlay/etc/skel/.config/hypr/hyprland.conf && test -f nimbus-overlay/etc/calamares/settings.conf`
Expected: QML render sin errores, skel presente (luego `useradd -m` lo copia íntegro, test live `diff -r /etc/skel /home/$USER`).

- [ ] **Step 4: Commit**

```bash
git add nimbus-overlay/etc/calamares/
git commit -m "feat(calamares): nimbus Setup Assistant Hello + erase default"
```

### Task 5: Perfil archiso + build_iso.sh + QEMU

**Files:**
- Create: `build_iso.sh`
- Create: `packages.nimbus.x86_64.append` (final merge)
- Create: `iso.manifest` (tags + commits)
- Modify: `nimbus-overlay/.../profiledef.sh:file_permissions` (si se añade binario)
- Test: `out/nimbus-*.iso + .sha256 + QEMU boot`

**Interfaces:**
- Consumes: `https://github.com/CachyOS/CachyOS-Live-ISO` (`archiso/profiledef.sh iso_name=cachyos, packages_desktop.x86_64 ~200 pkgs linux-cachyos, airootfs/etc/skel`), Tasks 1-4 overlays
- Produces: `out/nimbus-YYYY.MM.DD-x86_64.iso` reproducible, log `build.log`

- [ ] **Step 1: Escribir `build_iso.sh` (7 pasos)**

check_deps (`archiso mkinitcpio-archiso git squashfs-tools grub qemu-full ovmf`), pin `SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)`, setup_keys (`pacman-key --populate archlinux cachyos`), get_upstream (`git clone --depth 1 --branch <TAG> ... work/upstream`), apply_overlay (`cp -a nimbus-overlay/* work/upstream/archiso/airootfs/; cat packages.nimbus.append >> packages_desktop.x86_64`), build (`sudo mkarchiso -v -w work/build -o out work/upstream/archiso`), verify (`sha256sum, isoinfo -l`).

- [ ] **Step 2: Dry-run sin root (validar rutas)**

Run: `bash -n build_iso.sh && shellcheck build_iso.sh; ./build_iso.sh --check-only`
Expected: PASS sintaxis, upstream clonable, overlay copia sin overwrite `passwd/shadow`, `file_permissions` declara `nimbus-live-setup 0755`.

- [ ] **Step 3: Build real + QEMU validación**

Run:
```bash
qemu-img create -f qcow2 /tmp/nimbus-test.qcow2 20G
qemu-system-x86_64 -enable-kvm -M q35,accel=kvm -cpu host -smp 4 -m 4096 -bios /usr/share/ovmf/x64/OVMF.fd -drive file=out/nimbus-*.iso,media=cdrom,readonly=on -drive file=/tmp/nimbus-test.qcow2,if=virtio,format=qcow2 -device virtio-vga-gl -display sdl,gl=on -device virtio-tablet-pci -device virtio-net-pci,netdev=n0 -netdev user,id=n0 -device acpi-battery -boot order=d -serial stdio
```
Checklist: `Hyprland+macshell autostart`, `upower -d|grep battery`, lanzar calamares, instalar a /dev/vda, reboot order=c, login Hyprland. Pre-check `lscpu|grep x86-64-v[34]` o abortar.

- [ ] **Step 4: Commit + tag manifest**

```bash
git add build_iso.sh packages.nimbus.x86_64.append iso.manifest
git commit -m "feat(build): reproducible mkarchiso + QEMU acpi-battery test"
```
