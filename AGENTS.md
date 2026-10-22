# AGENTS.md — Nimbus

<!-- La versión en inglés seguirá. -->

Instrucciones **para el agente** que trabaja en este repositorio. OpenCode carga
este archivo automáticamente al arrancar una sesión aquí (es un `AGENTS.md` en la
raíz), así que léelo antes de tocar nada.

## Qué es esto

**Nimbus** es una distribución Linux estilo macOS sobre CachyOS (Arch-based),
con shell propio en **Quickshell 0.3.2 (QML)** sobre **Hyprland 0.56** y
instalador **Calamares**. El objetivo del fundador: *que sea sencillo para la
gente aportar*, y que un desconocido clone, entienda, construya y abra un PR
**sin preguntar a nadie**.

El escritorio ya **funciona y se ve** (barra con la marca, Dock con iconos,
fondo propio, greeter de SDDM con autologin). La ISO se construye y arranca.

## Las reglas que no se negocian

- **Modelo**: usa siempre `opencode-go/minimax-m3.1-flash-free` para subagentes
  y revisiones. **No lo cambies** sin que lo pida expresamente.
- **Idioma**: la documentación va en **español**; el código, los identificadores
  y los mensajes de commit, en **inglés**.
- **Sin assets de Apple ni de terceros**: iconos dibujados, fondos generados.
  `LICENSES.md` tiene que ser verdad: si algo de terceros se distribuye, está
  listado con su licencia.
- **Sin telemetría**: nada sale del equipo.
- **ES + EN** desde el primer día: toda cadena visible por `Config.translated(key)`
  y las tablas (`Translations.qml`, `nimbus_i18n.py`) **simétricas**.
- **Regla de oro del shell**: colores, radios y métricas salen de `Theme`; el
  texto visible, de `Config.translated`.
- **Nada de terminal para el usuario final**: un CLI puede existir, pero su camino
  de uso normal es una pantalla.
- **Regla dura de ananicy**: ninguna regla baja la prioridad de un proceso de
  juego ni del sistema de audio.
- **La firma es offline y manual**: la CI **nunca** firma.
- Cabecera SPDX en todo fichero nuevo; scripts con `set -euo pipefail` y sin `eval`.
- **TDD**: cada arreglo empieza por un test que falla (RED), luego el arreglo (GREEN).
- **Honestidad**: si algo no está verificado, se dice. No se promete ninguna
  captura o comportamiento que no se haya visto.

## Comandos

```bash
# Suite completa (pytest necesita el venv en esta maquina)
python -m pytest tests -q
QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" \
  /usr/lib/qt6/bin/qmltestrunner -input shell/tests
PATH="$HOME/.local/bin:$PATH" bats tests/*.bats
python tools/check_spdx.py --root .        # cabeceras SPDX
python tools/check_links.py                # enlaces y rutas de la documentacion

# Construir la ISO (~8 min; necesita sudo y usuario sin privilegios)
sudo env NIMBUS_BUILD_USER=$USER bash iso/build.sh --outdir "$PWD/out" --local-repo

# Arrancar y comprobar que el escritorio levanta
bash tests/integration/boot_live.sh --iso out/nimbus-*.iso --timeout 600
```

## Trampas (esto ya ha costado horas; no las repitas)

1. **`/tmp` es un tmpfs de 7,7 GB** en la máquina de desarrollo. Lleno, la build
   falla con errores que **no hablan de disco**: *"keyring is not writable"*,
   *"Resolving timed out"*, *"signature is invalid"*. **Mira `df -h /tmp` antes de
   culpar a las claves GPG o a la red.** La caché de pacman la comparten todas las
   builds: dos a la vez se pisan y dan los mismos falsos errores de firma.
2. **`makepkg` exige que su directorio sea escribible** y sale con **código 11**.
3. **`qs` (Quickshell) usa un parser tipo clap**: rechaza opciones desconocidas
   (`--no-tour` aborta el arranque) y un `--` convierte el argumento en posicional.
4. **La consola serie de la ISO la ocupa un kitty**: la salida de los comandos va
   al VT gráfico, **no** a la serie. Para ver el escritorio, usa el
   `screendump` del monitor de QEMU (`-monitor tcp:127.0.0.1:4555`): la ventana
   GTK depende del gestor de ventanas del host y puede quedar en otro plano.
5. **Un `Loader` de QML no instancia ventanas** y el fallo es silencioso (el shell
   "arranca" y no se ve nada). Y si una ventana flotante declara tamaño **y** su
   contenido se ancla a ella, la circularidad se resuelve con el tamaño de la
   pantalla entera. Patrón que funciona: la ventana **no** declara tamaño y el
   contenido **no** se ancla a ella.
6. **La puerta de readiness es honesta**: `NIMBUS_LIVE_READY` solo se escribe si
   Hyprland y el shell responden. `NIMBUS_LIVE_TIMEOUT` significa que el shell
   **no** arrancó: mira `journalctl -u nimbus-live.service`.
7. **El compositor necesita grupo `video`/`render`/`input`** (para abrir
   `/dev/dri/card0`) y **`LIBSEAT_BACKEND=noop`** (en la live no hay sesión de
   logind). Los grupos se declaran en `etc/sysusers.d/nimbus.conf` (tipo `m`),
   **no** editando `/etc/group` a mano.

## Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Estado real (qué funciona, qué no) | [`docs/STATUS.md`](docs/STATUS.md) |
| Guía de continuidad y trampas | [`docs/CONTINUAR.md`](docs/CONTINUAR.md) |
| Arquitectura | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| Construir la ISO | [`docs/BUILDING.md`](docs/BUILDING.md) |
| API real de Quickshell/Hyprland | [`docs/QUICKSHELL-API.md`](docs/QUICKSHELL-API.md) |
| Spec (la autoridad) | `docs/superpowers/specs/2026-10-21-nimbus-design.md` |
| Decisiones y su porque | [`docs/DECISIONES.md`](docs/DECISIONES.md) |
| Planes por hito | `docs/superpowers/plans/` |
| Memoria entre sesiones | plugin `opencode-mem` (ver `docs/CONTINUAR.md` §5-bis) |

**Carga perezosa**: no leas todo esto de golpe. Lee lo que necesite la tarea
(`docs/STATUS.md` para saber el estado, `docs/CONTINUAR.md` para continuar un
trabajo, `docs/QUICKSHELL-API.md` antes de tocar el shell).

## Cómo trabajar aquí

- **Una pista = un worktree = una rama** (`git worktree add`). Commitea **por
  partes**: el servidor se reinicia y se pierden agentes enteros.
- **No toques `shell/src/**` y `iso/profiles/**` a la vez que otra pista**: son
  las dos zonas con más conflictos.
- Cuando cambies un comportamiento, **cambia su test** en el mismo commit.
- Si algo no está verificado en hardware real (GPU, batería, VRR, dual-boot),
  dilo en el informe; no lo des por bueno.
