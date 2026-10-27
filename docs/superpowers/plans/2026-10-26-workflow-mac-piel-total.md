# Workflow Mac + Piel total Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ventanas y escritorios estilo Mac usables por usuarios de Mac y Windows, con piel macOS en todo el SO y entrada directa sin login.

**Architecture:** Ajustes solo-overlay sobre Hyprland 0.56 (.conf vigente: `window_rule`/`layer_rule`, `gesture`), theming WhiteSur/Inter existente como base, sin cambiar apps base (Nautilus/Kitty se tematizan, no se sustituyen), greetd con autologin directo.

**Tech Stack:** Hyprland 0.56 hyprlang .conf, Quickshell MacShell, GTK3/4 WhiteSur, Qt6, greetd, Calamares, archiso.

**Spec:** `docs/ESPECIFICACION.md` (autoridad) + decisiones usuario 2026-10-26: workflow Mac completo validado, piel total automática, entrada directa sin login.

## Global Constraints

- Hyprland >= 0.56: `window_rule` (no `windowrulev2`), `layer_rule` (no `layerrule`), gestos swipe via `gesture = 3, horizontal, workspace` (no `workspace_swipe`).
- Verificación con `hyprland --verify-config` en HOME temporal (no `--check-config`).
- Cero binds `CTRL-*` en `hypr/*.conf` (Ctrl intacto para copiar/pegar).
- Overlay nunca trae `etc/passwd|shadow|gshadow|group`.
- Solo repos oficiales en `packages.*append` para pacstrap; AUR via `packages.nimbus-aur.txt` + repo local `[nimbus]` o live-setup.
- `MacBar` posee notificaciones: prohibido dunst/mako/swaync/waybar/hyprpanel.
- Entrada directa: greetd autologin a Hyprland, sin pantalla de login.

## Review Focus

- Ventana que abre fuera de pantalla o gigante en pantallas pequeñas → debe abrir centrada y caber siempre.
- App sin decoración propia que no se pueda arrastrar → toda ventana movible por cabecera y redimensionable por bordes.
- Usuario Windows que solo usa ratón → todo accesible por dock/barra sin atajos obligatorios.
- Live en QEMU sin aceleración → animaciones no deben colgar el arranque.
- Tema que no aplica en apps Qt/Electron → Qt hereda WhiteSur + Inter.

---

### Task 1: Ventanas y escritorios estilo Mac

**Files:**
- Modify: `nimbus-overlay/etc/skel/.config/hypr/hyprland.conf`
- Modify: `nimbus-overlay/etc/skel/.config/hypr/10-shortcuts.conf`
- Modify: `nimbus-overlay/etc/skel/.config/hypr/macshell.lua` (solo si el bind Lua diverge del .conf)
- Modify: `scripts/verify-macshell.sh`, `scripts/verify-store.sh` (checks de los nuevos binds/reglas)

**Interfaces:**
- Consumes: flotante global `window_rule = float` existente, `gesture = 3, horizontal, workspace` existente.
- Produces: reglas `window_rule` de centrado/tamaño, binds Super+1..9 / Ctrl+flechas / Mission Control / togglefloating / fullscreen; Task 4 consume la conf para `--verify-config` en ISO.

- [ ] **Step 1: Write the failing test**
  - Añadir checks en `verify-macshell.sh`: `window_rule` centrado (`center`), binds `SUPER, 1..9`, `CTRL, LEFT/RIGHT`, `Mission Control/overview`, `togglefloating`, `fullscreen`.
  - Añadir checks en `verify-store.sh`: cero `CTRL-*` sigue verde con los nuevos binds.
- [ ] **Step 2: Run test to verify it fails**
  - Run: `bash scripts/verify-macshell.sh` / `bash scripts/verify-store.sh`
  - Expected: FAIL en los checks nuevos.
- [ ] **Step 3: Implement centrado y tamaño Mac en `hyprland.conf`**
  - `window_rule = float, class:^(.*)$` (existe) + `window_rule = center, class:^(.*)$` + `window_rule = size 1100 700, class:^(.*)$` (cabe en 1366x768 y en 4K se ve proporcionado).
  - Semáforos: mantener WhiteSur + MacShell; ventanas SSD siguen movibles por cabecera.
- [ ] **Step 4: Implement escritorios y Mission Control en `10-shortcuts.conf`**
  - `bind = SUPER, 1..9, workspace, N` / `bind = SUPER SHIFT, 1..9, movetoworkspace, N`.
  - `bind = CTRL, LEFT/RIGHT, workspace, -1/+1` (compatible Mac `Ctrl+flechas` y Windows).
  - Mission Control: `bind = SUPER, TAB?` NO (ALT+TAB es switcher) → `bind = SUPER, UP, exec, qs -c MacShell ipc call overview toggle` si MacShell lo expone; si no existe, `bind = SUPER, W, overview` documentado como fallback. Verificar nombre real del ipc en `MacShell/shell.qml`.
  - `bind = SUPER, F, fullscreen` (botón verde = fullscreen), `bind = SUPER, T, togglefloating`? NO: `SUPER+T` es kitty. Usar `bind = SUPER SHIFT, F, togglefloating`.
  - Minimizar: `bind = SUPER, M, exec, qs -c MacShell ipc call minimize` si existe; si no, documentar clic amarillo.
- [ ] **Step 5: Run tests to verify they pass**
  - Run: `HOME_TMP fusion + hyprland --verify-config` (como hacen los scripts) → `config ok`.
  - Run: `bash scripts/verify-macshell.sh` → PASS; `bash scripts/verify-store.sh` → PASS.
- [ ] **Step 6: Commit**
  - `git add nimbus-overlay/etc/skel/.config/hypr/ scripts/verify-macshell.sh scripts/verify-store.sh`
  - `git commit -m "feat(hypr): workflow Mac (centrado, Spaces, Mission Control, fullscreen)"`

### Task 2: Piel macOS total (arranque, bloqueo, apps, ajustes)

**Files:**
- Modify: `nimbus-overlay/etc/skel/.config/gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `kitty/kitty.conf`, `fontconfig/fonts.conf`
- Modify: `nimbus-overlay/etc/nimbus/theming/grub-theme.src` (+ overlay `etc/default/grub.d/nimbus.cfg` si aplica), `nimbus-overlay/etc/skel/.config/hypr/hyprlock.conf` (crear si no existe)
- Modify: `packages.nimbus.x86_64.append` (solo repos oficiales: `plymouth`, `qt5ct`/`qt6ct`, `gnome-settings`? NO apps nuevas sin auditar)
- Modify: `scripts/verify-macshell.sh` (checks theming), `iso.manifest` (pins de temas si se añaden)

**Interfaces:**
- Consumes: WhiteSur + Inter + Papirus fallback + capitaine existentes.
- Produces: ficheros theming listos para `customize_airootfs.sh`; Task 4 los empaqueta.

- [ ] **Step 1: Write the failing test**
  - Checks: `hyprlock.conf` existe con fondo blur + reloj grande; `kitty.conf` fondo oscuro translúcido estilo Terminal Mac; Qt (`qt6ct.conf` o `qt5ct`) hereda WhiteSur+Inter; GRUB tema Whitesur referenciado.
- [ ] **Step 2: Run test to verify it fails**
  - Run: `bash scripts/verify-macshell.sh` → FAIL en checks nuevos.
- [ ] **Step 3: Implement bloqueo y terminal**
  - `hyprlock.conf`: fondo screenshot blur, hora grande Inter, avatar liveuser, hint "Pulsa cualquier tecla".
  - `kitty.conf`: fuente Inter, padding, cursor beam, opacidad 0.92, esquema oscuro macOS.
- [ ] **Step 4: Implement Qt + Nautilus Finder-like + GRUB/Plymouth**
  - Qt6: `etc/skel/.config/qt6ct/qt6ct.conf` con estilo `gtk2` (hereda WhiteSur) + fuente Inter. Solo si `qt6ct` está en repos oficiales; si no, `QT_QPA_PLATFORMTHEME=gtk3` via `hyprland.conf` env.
  - Nautilus: `org.gnome.nautilus` gsettings override en overlay (`etc/dconf/db/local.d/nimbus`) con vista iconos + barra lateral, sin cambiar de app.
  - GRUB: tema Whitesur desde `grub-theme.src` (solo referencia + `GRUB_THEME=` en `etc/default/grub.d/nimbus.cfg`); NO renombrar entradas CachyOS en este plan (bootloader text es Minor conocido).
  - Plymouth: solo si `plymouth` está en repos y el perfil lo soporta; si no, ledger `Ruling` y skip.
- [ ] **Step 5: Run tests to verify they pass**
  - Run: `bash scripts/verify-macshell.sh` → PASS; `bash -n` en todo lo tocado.
- [ ] **Step 6: Commit**
  - `git commit -m "feat(theme): piel Mac total (bloqueo, terminal, Qt, Nautilus, GRUB)"`

### Task 3: Instalador y sesión directa final

**Files:**
- Modify: `nimbus-overlay/etc/calamares/*` (solo retoques: mantener Hello + erase default; añadir slide de Spaces/Spotlight si `show.qml` lo permite)
- Modify: `nimbus-overlay/root/customize_airootfs.sh` (aplicar `hyprlock.conf`, `qt6ct`, dconf, GRUB cfg post-pacstrap)
- Modify: `scripts/verify-calamares.sh` (checks nuevos)

**Interfaces:**
- Consumes: Tasks 1-2 (ficheros a instalar), greetd autologin existente (NO tocar: entrada directa decidida).
- Produces: customize que no falla si un fichero falta (guards `[ -f ]`); Task 4 lo ejecuta en build.

- [ ] **Step 1: Write the failing test**
  - Checks: customize instala `hyprlock.conf`, `qt6ct.conf`, `dconf` y `grub.d/nimbus.cfg` via `install -Dm644` con guards.
- [ ] **Step 2: Run test to verify it fails** (`bash scripts/verify-calamares.sh` → FAIL nuevo).
- [ ] **Step 3: Implement customize + slides** (guards idempotentes, `set -u` safe).
- [ ] **Step 4: Run test to verify it passes** (`bash scripts/verify-calamares.sh` → PASS).
- [ ] **Step 5: Commit** (`git commit -m "feat(installer): customize piel total + slides Spaces"`)

### Task 4: Build ISO + verificación + QEMU

**Files:**
- Modify: `iso.manifest` (nueva entrada ISO/SHA/SIZE/DATE/NOTA)
- Modify: `scripts/verify-build.sh` (solo si un check nuevo lo exige)

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: `out/nimbus-YYYY.MM.DD-x86_64.iso` instalable + manifest + reporte QEMU headless.

- [ ] **Step 1: Run suite completa** (`verify-macshell/power/store/calamares/build` + `--check-only`) → todo PASS antes de compilar.
- [ ] **Step 2: Build limpio con root** (`rm -rf work/build` + `./build_iso.sh`; ~15 min) → `BUILD PASS`.
- [ ] **Step 3: Verificar contenido del squashfs** (`unsquashfs -cat` hyprland.conf con `window_rule/layer_rule/gesture`; macshell vendoreado; customize x5).
- [ ] **Step 4: Boot headless QEMU** (OVMF edk2, `-display none`, serial) → GRUB + inicio live sin kernel panic.
- [ ] **Step 5: Commit manifest** (`git commit -m "chore: ISO nimbus-YYYY.MM.DD workflow Mac + piel total"`)
