# Arquitectura NimbusOS

Cómo encajan las piezas. Lee `AGENTS.md` primero (reglas duras).

## 1. De dónde sale la ISO

```
CachyOS-Live-ISO (pin UPSTREAM_COMMIT)
  + nimbus-overlay/  (cp -a a airootfs; conflictos → staging/)
  + packages.nimbus.x86_64.append  (merge - duplicados upstream - AUR-no-en-repo)
  + repo local [nimbus]  (binarios AUR precompilados por build-aur-repo.sh)
  + profiledef.nimbus.inc  (iso_name=nimbus, file_permissions binarios, 8 hilos)
  → mkarchiso → out/nimbus-YYYY.MM.DD-x86_64.iso (+ .sha256 + build.log)
```

El build son 7 pasos en `build_iso.sh`: `check_deps → pin SOURCE_DATE_EPOCH → setup_keys → get_upstream (reset --hard al pin) → apply_overlay → build → verify`. Reproducible: mismo pin + mismo overlay = misma ISO (salvo `SOURCE_DATE_EPOCH`).

## 2. Conflictos overlay vs paquetes (el truco clave)

`pacstrap` aborta si un fichero ya existe en `airootfs/` y lo posee un paquete. Los 5 conocidos (3 `etc/calamares/modules/*.conf` de cachyos-calamares-next + 2 `gtk-*.0/settings.ini` de cachyos-kde-settings) se **mueven** a `usr/share/nimbus/staging/` y `nimbus-overlay/root/customize_airootfs.sh` (corre post-pacstrap como root, mkarchiso lo ejecuta desde `airootfs/root/`) los reinstala con `install -Dm644`. Todo con guards `[ -f ]`, idempotente.

## 3. Sesión gráfica (live e instalado)

```
greetd (autologin liveuser) → Hyprland
  ├─ hyprland.lua (canónica Lua 0.55+): binds, reglas, hyprbars, gestos
  ├─ hyprland.conf + 10-shortcuts.conf (fallback si no hay .lua)
  └─ exec-once = macshell → /usr/bin/macshell → macshell-start
      → quickshell MacShell (barra, dock, spotlight) + MacLock aparte
```

Ventanas: todas flotantes, centradas 1100×700 (diálogos 700×500), titlebars nativas vía plugin `hyprbars` (botones a la izquierda). Semáforos GTK via WhiteSur CSD (excluidos de hyprbars con `no_bar`).

## 4. Primer arranque (live-setup) e instalado

- Live: `nimbus-live-setup.service` fusiona `pamac.conf` (Flatpak+AUR), `remote-add flathub`, instala AUR pendientes vía `paru` como liveuser, `enable`/`mask` servicios (auto-cpufreq, thermald, bluetooth; mask power-profiles-daemon). Idempotente, log en `/var/log/`.
- Instalado: Calamares (`settings.conf` + `shellprocess_nimbus_installed`) ejecuta `nimbus-installed-setup`: regenera `greetd/config.toml` con el **usuario real** (el live hardcodea `liveuser`) y repite fusión + enables.

## 5. Dónde vive cada decisión

| Decisión | Fichero |
|---|---|
| Pin upstream + MacShell + AUR | `iso.manifest` |
| Paquetes oficiales | `packages.nimbus.x86_64.append` |
| Paquetes AUR | `packages.nimbus-aur.txt` (+ copia en overlay para live-setup) |
| Excepciones a upstream (mínimas, documentadas) | comentarios `NimbusOS Ruling` + `theming/README.md` |
| Verificación | `scripts/verify-*.sh` (cada check enlaza a su fichero) |

## 6. Límites conocidos (no reabrir sin evidencia nueva)

- Calamares roto upstream (boost 1.91 vs 1.92): sin workaround posible, se recoge solo al rebuild.
- Menú global D-Bus: no viable en V1 (Quickshell no lo contempla); menús sintéticos eliminados.
- Reloj en español: requiere locale + `lang/es.js` upstream.
- `.conf` legacy muere en Hyprland 0.57; la canónica es Lua.
