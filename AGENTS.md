# AGENTS.md — Instrucciones para sesiones de IA (vibecoding)

Lee esto antes de tocar nada. El proyecto se documenta en español; responde y documenta en español.

## Qué es (30 segundos)

NimbusOS = ISO Linux instalable con estética macOS. Base CachyOS + **KDE Plasma 6.8** + la capa **NimbusShell** (barra, Dock, Spotlight, Mission Control, tema Tahoe, apps y ajustes). El perfil **Hyprland/MacShell** queda congelado como `legacy-hypr` para rollback.

> **Decisión 2026-11-07:** la línea nueva es `plasma-migration`. `main` sigue
> siendo la ISO Hyprland estable hasta validar la ISO Plasma en VM/hardware.
> Fronteras y fuente de verdad: `docs/architecture/PRODUCT-MODEL.md`.

## Comandos (memorízalos)

```bash
# Línea Plasma (nueva)
NIMBUS_SHELL=../NimbusShell ./scripts/verify-plasma.sh
NIMBUS_SHELL=../NimbusShell ./build_iso.sh --check-only --profile plasma
NIMBUS_SHELL=../NimbusShell ./build_iso.sh --profile plasma

# Línea estable Hyprland (rollback)
./build_iso.sh --check-only --profile legacy-hypr
./build_iso.sh --profile legacy-hypr

bash scripts/verify-<tema>.sh        # power|store|calamares|build (legacy: macshell)
./scripts/test-qemu.sh               # VM de prueba (necesita KVM + display)
./scripts/build-aur-repo.sh          # precompila AUR al repo local (largo, con red)
```

## Reglas duras (violarlas rompe la ISO)

1. **NimbusShell es la fuente de verdad del escritorio.** Dotfiles, tema, barra,
   apps y KCM se importan desde `NimbusShell`; no se copian a mano. El skel se
   genera con `NimbusShell/scripts/nimbus-skel-sync`.
2. **Repos oficiales solo** en `packages.nimbus-plasma.append` y
   `packages.nimbus.x86_64.append`. Cero AUR ahí. AUR → `packages.nimbus-*-aur.txt`
   + binario en repo local `[nimbus]` (o defer a live-setup).
3. **Overlay jamás** trae `etc/passwd|shadow|gshadow|group`. Si un fichero choca
   con un paquete (pacstrap aborta), va a `usr/share/nimbus/staging/` y lo
   instala `nimbus-overlay/root/customize_airootfs.sh` post-pacstrap.
4. **Perfil Plasma:** DM = SDDM; portal = `xdg-desktop-portal-kde`; energía =
   `power-profiles-daemon`; nada de `hyprland`, `quickshell`, `greetd`,
   `hyprpaper`, `hyprbars` ni `hyprshell`.
5. **Perfil legacy-hypr:** se mantiene congelado y funcional; cualquier cambio
   ahí exige `hyprland --verify-config` con HOME temporal y `scripts/verify-macshell.sh`.
6. **Cero binds `CTRL-*`** en cualquier perfil (Ctrl intacto para el usuario).
7. **Evidencia antes que afirmaciones**: todo PASS con salida del comando vista,
   no "debería pasar". `--check-only` verde + ISO real en VM antes de mergear.
8. **Pins**: `UPSTREAM_COMMIT` (CachyOS-Live-ISO) y `NIMBUS_SHELL_COMMIT` viven
   en `iso.manifest`. Subir un pin = re-auditar + QEMU con capturas.
9. **Memoria**: UNA sola VM a la vez (`-smp 2 -m 2048`), borrar su qcow2 al
   terminar. Nunca compilar y virtualizar a la vez si hay poca RAM.
10. **Commits**: mensajes cortos en inglés (`feat|fix|docs|chore(scope): ...`).
    Push directo a `main` solo con suite verde. ISOs (GBs) nunca se suben.

## Dónde está cada cosa

- `nimbus-overlay-plasma/` → delta Plasma: SDDM, Calamares, barra, tema, skel.
- `nimbus-overlay/` → overlay base (live, Calamares, systemd, theming).
- `packages.nimbus-plasma.append` / `packages.nimbus-plasma-aur.txt` → perfil Plasma.
- `packages.nimbus.x86_64.append` / `packages.nimbus-aur.txt` → perfil Hyprland legacy.
- `docs/architecture/` → modelo de producto, mapa y ramas.
- `docs/MIGRACION-PLASMA.md` → checklist del corte.
- `docs/ARQUITECTURA.md` → cómo encajan las piezas.
- `docs/FILOSOFIA.md` → colaboración upstream. `docs/ESTADO.md` → qué hay y qué falta.
