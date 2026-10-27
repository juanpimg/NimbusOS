# Task 5 — Reporte de build ISO (NimbusOS)

## Fix packages.x86_64 (2026-10-23)

**Root cause:** mkarchiso fallaba con `Packages file
'work/upstream/archiso/packages.x86_64' does not exist` + `syslinux missing`.
El perfil upstream solo trae `packages_desktop.x86_64`; su
`util-iso.sh prepare_profile desktop` hace
`cp archiso/packages_desktop.x86_64 archiso/packages.x86_64` antes de
buildear. `build_iso.sh apply_overlay` concatenaba el append a
`packages_desktop.x86_64` pero nunca generaba `packages.x86_64` → lista
vacía → syslinux missing.

**Fix mínimo en `build_iso.sh` apply_overlay (tras file_permissions, antes de build):**
- `cp packages_desktop.x86_64 packages.x86_64` (sobreescribir) + check
  `[ -f packages.x86_64 ]` + `grep -q '^syslinux$'`.
- Idempotencia ante re-run: si `packages_desktop.x86_64` ya contiene el
  marcador Nimbus (`# --- Task`), restaurar desde git
  (`checkout -- archiso/packages_desktop.x86_64`) antes de concatenar.
  (El orden normal ya es limpio: `get_upstream` hace `reset --hard
  $UPSTREAM_COMMIT` antes de apply; la guarda cubre re-runs sin get_upstream.)
- `sed` de `iso_name` solo si aún dice `cachyos`; inyección
  `file_permissions` solo si `macshell` ausente (el `assert` de python
  fallaba en re-run).
- Sin tocar overlay ni paquetes.

**Verificación:** `bash -n build_iso.sh` OK,
`./build_iso.sh --check-only` PASS,
`bash scripts/verify-build.sh` → PASS=71 FAIL=0.
`verify-build.sh` ahora exige el `cp` y el check `syslinux`.

## Fix AUR fuera de pacstrap (2026-10-23)

**Root cause:** 5 paquetes del append no estan en repos oficiales
(`pacman -Si`: whitesur-gtk-theme, whitesur-icon-theme, pamac-gtk,
libpamac-flatpak-plugin, hyprshell) y rompian `pacstrap` (mkarchiso solo
resuelve repos oficiales; `pacman.conf` sin repos propios). `paru` SI esta
en cachyos/oficial y queda en pacstrap.

**Fix:**
- `build_iso.sh apply_overlay`: lista AUR fija (desde
  `packages.nimbus-aur.txt`, fallback hardcodeado); doble filtro
  `grep -vxFf upstream | grep -vxFf aur-skip` al concatenar a
  `packages_desktop.x86_64`; registra `out/skipped-aur.txt` (ademas de
  `skipped-dupes.txt`). Check-only simula lo mismo (falla si queda una AUR
  o si falta `paru`).
- `packages.nimbus.x86_64.append`: seccion extra `paru` (cachyos/oficial,
  no dupe upstream); las 5 AUR se mantienen como declaracion canonica.
- `nimbus-live-setup`: paso 5 instala las 5 via
  `paru -S --needed --noconfirm` leyendo el manifest
  (`usr/share/nimbus/packages.nimbus-aur.txt`); guards: solo con red
  (`getent`/`ping`), salto si `paru -Q` ya presente, log a
  `/var/log/nimbus-live-setup.log`, `exit 0` siempre. Idempotencia +
  pamac.conf/flathub/mask PPD intactos.
- Manifest `packages.nimbus-aur.txt` (5 lineas) en raiz + copia overlay.
- `verify-build.sh`: fusion simulada con filtro AUR (5 checks sin-AUR +
  `paru` si + `skipped-aur`), checks manifest raiz/overlay, checks
  `live-setup` invoca `paru`/`paru -Q`/log/manifest, checks build
  `skipped-aur`/`aur-skip`.

**Verificacion:** `bash -n` OK (build_iso, verify, live-setup),
`--check-only` PASS, `verify-build.sh` → PASS=91 FAIL=0.

## Fix pacstrap nvidia + prompts (2026-10-23)

**Root cause:** append duplicaba `nvidia-dkms` + `nvidia-utils` que el pin
upstream ya trae (`linux-cachyos-*-nvidia-open`, `nvidia-utils`); `nvidia-dkms`
ya no existe como paquete (provides → `nvidia-open-dkms`) y enredaba al solver
en la desincronización cachyos 615.71 vs extra 615.78. Además 3 prompts
colgaban pacstrap: `libxtables.so` (iptables), `qt6-multimedia-backend`
(ffmpeg), `tessdata` (eng).

**Fix mínimo en `packages.nimbus.x86_64.append`:** quitar `nvidia-dkms` y
`nvidia-utils` (upstream los aporta; se mantiene `lib32-nvidia-utils`,
`nvidia-prime`, `libva-nvidia-driver`, resto inocente); añadir explícitos
`iptables`, `qt6-multimedia-ffmpeg`, `tesseract-data-eng` (todos en extra)
para fijar defaults. `verify-build.sh`: 2 checks sin-duplicado + 3 checks
defaults presentes. Plan B si el solver sigue fallando por el pin
`linux-cachyos-nvidia-open→open-dkms`: mover también `lib32-nvidia-utils` y
`libva-nvidia-driver` al manifest AUR/live-setup.

**Verificación:** `bash -n` OK, `--check-only` PASS,
`verify-build.sh` → PASS=96 FAIL=0. Commit `nimbusos`.

## Fix overlay vs paquetes conflicting files (2026-10-23)

**Root cause:** overlay copiaba 5 paths a airootfs ANTES de pacstrap y los
poseen paquetes (cachyos-calamares-next: displaymanager/partition/users.conf;
cachyos-kde-settings: gtk-3.0/gtk-4.0 settings.ini) → pacman aborta; archiso
no permite overwrite en pacstrap.

**Fix archiso-nativo:** `apply_overlay` tras `cp -a` mueve (mv, idempotente
con guards) los 5 a `$AIROOTFS/usr/share/nimbus/staging/`; copia
`nimbus-profile/customize_airootfs.sh` a `$PROFILE_DIR/` + chmod +x
(mkarchiso lo ejecuta post-pacstrap como root, sí puede sobrescribir con
`install -Dm644`). Overlay repo intacto (fuente de verdad para verify/QEMU).

**Verificación:** `bash -n` OK (build_iso, customize, verify),
`--check-only` PASS, `verify-build.sh` → PASS=103 FAIL=0. Commit `nimbusos`.

## Fix live-setup AUR real (2026-10-23)

**Root cause (verificado AUR RPC v5, no reinvestigar):** `pamac-gtk` y
`libpamac-flatpak-plugin` NO existen en AUR; el paquete real es `pamac-aur`
(meson+vala, dep `libpamac-aur` auto). El script moria en
`[ -f /etc/pamac.conf ] || die` (pamac ausente en live → conf ausente →
exit 1 → FAILED) y corria `paru -S` como root (makepkg prohibe compilar
como root).

**Fix:**
- `packages.nimbus-aur.txt` (+ copia overlay): `pamac-gtk` y
  `libpamac-flatpak-plugin` → `pamac-aur`; comentario libpamac-aur como dep.
- `packages.nimbus.x86_64.append`: seccion Task5 build-deps AUR (vala meson
  ninja gobject-introspection itstool asciidoc xorgproto gettext sassc gtk3
  gtk4 gtk4-layer-shell libadwaita libhandy desktop-file-utils cargo; todas
  extra/oficiales, el filtro dedupica solo).
- `nimbus-live-setup`: paso 1 crea `/etc/pamac.conf` minimo si falta (no
  die); paso 5 detecta usuario live (uid 1000, fallback liveuser), salta sin
  usuario no-root, ejecuta paru via `runuser -u $_u -- env HOME=...`
  desde su HOME; marker solo si todo el manifest instalado (`pacman -Q`),
  fast-path exit 0 si marker + completo.
- Unit: sin `ConditionPathExists=` ni `ExecStartPost=` (el script gestiona
  el marker; re-ejecucion barata).
- `verify-build.sh`: checks manifest pamac-aur/sin pamac-gtk, append
  vala/meson/cargo, script runuser/sin die pamac.conf, unit sin
  ConditionPathExists/ExecStartPost.
- `nimbus-overlay/etc/pamac.conf.d/nimbus.conf`: NO tocado (documenta
  flags; el script fusiona).

**Nota (fuera de alcance):** el append Task3 aun lista `pamac-gtk` y
`libpamac-flatpak-plugin` como paquetes `extra` (decision historica
vinculante + lineas 88-89); esos nombres no existen en repos ni AUR y
romperian pacstrap si llegan a el — pendiente de Task3, no se toco.

**Verificación:** `bash -n` OK (4 ficheros), `--check-only` PASS,
`verify-build.sh` → PASS=114 FAIL=0, shellcheck warning OK, sandbox con
stubs (id/getent/pacman/paru/runuser): crea conf, paru como liveuser con
HOME correcto, fast-path, salto sin usuario, exit 0 siempre. Commit
`nimbusos`.
