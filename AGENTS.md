# AGENTS.md — Instrucciones para sesiones de IA (vibecoding)

Lee esto antes de tocar nada. El proyecto se documenta en español; responde y documenta en español.

## Qué es (30 segundos)

NimbusOS = ISO Linux instalable con estética macOS. Base CachyOS + shell MacShell (Quickshell/QML, MIT) sobre Hyprland 0.56 (sesión canónica **Lua**, `.conf` como fallback). **Sin afiliación** con Apple, CachyOS ni MacShell (ver README).

## Comandos (memorízalos)

```bash
./build_iso.sh --check-only          # validación rápida, sin root (SIEMPRE primero)
bash scripts/verify-<tema>.sh        # macshell|power|store|calamares|build|p1 (suite)
./scripts/test-qemu.sh               # VM de prueba (necesita KVM + display)
./scripts/build-aur-repo.sh          # precompila AUR al repo local (largo, con red)
```

## Reglas duras (violarlas rompe la ISO)

1. **Repos oficiales solo** en `packages.nimbus.x86_64.append`. Cero AUR ahí. AUR → `packages.nimbus-aur.txt` + binario en repo local `[nimbus]` (o defer a live-setup).
2. **Overlay jamás** trae `etc/passwd|shadow|gshadow|group`. Si un fichero choca con un paquete (pacstrap aborta), va a `usr/share/nimbus/staging/` y lo instala `nimbus-overlay/root/customize_airootfs.sh` post-pacstrap.
3. **Cero binds `CTRL-*`** en `nimbus-overlay/etc/skel/.config/hypr/*.conf|lua` (Ctrl intacto para el usuario).
4. **Hyprland 0.56**: sintaxis vigente `window_rule`/`layer_rule`/`gesture =`/`hl.plugin.*` en Lua; `--verify-config` (nunca `--check-config`); verificar con HOME temporal (el `source = ~/.config/...` da falso globbing si no).
5. **Plugin sin `.so` en verify**: el modo `--verify-config` no carga plugins; si el check falla SOLO por `hyprbars|plugin|nil`, es SKIP documentado, no FAIL.
6. **MacShell vendoreado intacto**: QML upstream NO se reescribe (filosofía anti-fork). Excepciones mínimas documentadas como `NimbusOS Ruling` con propuesta aguas arriba.
7. **Evidencia antes que afirmaciones**: todo PASS con salida del comando vista, no "debería pasar". Suite completa en verde antes de mergear/pushear.
8. **Pins**: `UPSTREAM_COMMIT` (CachyOS-Live-ISO) y MacShell (commit+VERSION) viven en `iso.manifest`. Subir un pin = re-auditar + QEMU con capturas.
9. **Memoria**: UNA sola VM a la vez (`-smp 2 -m 2048`), borrar su qcow2 al terminar. Nunca compilar y virtualizar a la vez si hay poca RAM.
10. **Commits**: mensajes cortos en inglés (`feat|fix|docs|chore(scope): ...`). Push directo a `main` solo con suite verde. ISOs (GBs) nunca se suben (`.gitignore`).

## Dónde está cada cosa

- `nimbus-overlay/etc/skel/` → home del usuario live/instalado (hypr, MacShell, theming).
- `nimbus-overlay/{etc,usr,root}/` → raíz del live (greetd, calamares, servicios, `customize_airootfs.sh`).
- `docs/ARQUITECTURA.md` → cómo encajan las piezas. `docs/FILOSOFIA.md` → reglas de colaboración upstream. `docs/ESTADO.md` → qué hay y qué falta.
