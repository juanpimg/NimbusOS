# Cómo seguir trabajando en Nimbus

<!-- La versión en inglés seguirá. -->

Este documento es el punto de entrada para **quien retome el proyecto** (tú en otra
sesión, o alguien que llegue de cero). No sustituye al spec: el spec
[`2026-10-21-nimbus-design.md`](superpowers/specs/2026-10-21-nimbus-design.md)
sigue siendo la autoridad de **qué** hay que hacer; este dice **cómo se está** y
**por dónde seguir**.

## 1. Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Repositorio principal | `/home/jp/Escritorio/Proyectos/Linux-MacOS` (rama `main`) |
| Rama de trabajo | `feature/m4-beta` (idem que `main`; se recrea con `git branch -f feature/m4-beta main`) |
| ISO construida | `out/nimbus-2026.10.22-x86_64.iso` (1,4 GB, **no** está en git) |
| Release pública | <https://github.com/juanpimg/NimbusOS/releases/tag/v0.1.0-beta> |
| Worktrees de trabajo | `/home/jp/.local/share/opencode/worktree/a3e79a/<pista>` — se crean con `git worktree add` |
| Informes de la sesión | `.superpowers/sdd/2026-10-22-nimbus-m4-beta/` (**no** está en git: está en `.gitignore`) |
| Ledger de rulings | `.superpowers/sdd/2026-10-21-nimbus-m0-fundamentos/progress.md` (idem, local) |

**Regla del proyecto**: una pista = un worktree = una rama. Cada agente trabaja en
su worktree y **commitea por partes** (el servidor se reinició varias veces durante
la última sesión y se perdieron agentes enteros).

## 2. El estado, en corto

- El **escritorio funciona y se parece a macOS**: barra con la marca y el reloj,
  Dock con iconos dibujados, fondo propio, greeter de SDDM con autologin.
  Verificado con capturas del guest (`screendump` del monitor de QEMU).
- La **ISO lleva el instalador** (6 módulos de Calamares + tema del greeter), pero
  **nadie ha instalado Nimbus de verdad**: falta el test ISO → Calamares →
  escritorio instalado.
- **Tests**: 390 pytest + 301 QML + 13 bats, en verde. **CI en verde** en GitHub.
- El detalle completo (qué funciona, qué no y cómo se verifica) está en
  [`STATUS.md`](STATUS.md).

## 3. Los cuatro comandos que importan

```bash
cd /home/jp/Escritorio/Proyectos/Linux-MacOS

# Suite completa
python -m pytest tests -q
QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" \
  /usr/lib/qt6/bin/qmltestrunner -input shell/tests
PATH="$HOME/.local/bin:$PATH" bats tests/*.bats

# Construir la ISO (tarda ~8 min; necesita sudo y usuario sin privilegios)
sudo env NIMBUS_BUILD_USER=$USER bash iso/build.sh --outdir "$PWD/out" --local-repo

# Arrancar la ISO y comprobar que el escritorio levanta
bash tests/integration/boot_live.sh --iso out/nimbus-*.iso --timeout 600
```

> En esta máquina `pytest` **no está en el PATH**: usa
> `/tmp/opencode/nimbus-venv/bin/python -m pytest` (el venv del proyecto). En la
> CI y en cualquier otro equipo, `python -m pytest` vale.

## 4. Ver el escritorio de verdad (capturar el guest)

La ventana de QEMU depende del gestor de ventanas del host y puede quedar en otro
plano: **usa el monitor**, que siempre refleja lo que ve el guest.

```bash
rm -f /tmp/opencode/mon.sock
setsid nohup qemu-system-x86_64 -accel kvm -cpu max -m 8192 -smp 4 \
  -device virtio-gpu-pci -vga none -cdrom "$PWD/out/nimbus-*.iso" -display none \
  -monitor tcp:127.0.0.1:4555,server,nowait \
  -serial file:/tmp/opencode/serie.log -no-reboot >/dev/null 2>&1 &

# esperar a que la sesion este lista
grep -q NIMBUS_LIVE_READY /tmp/opencode/serie.log

# capturar
printf 'screendump /tmp/opencode/shot.ppm\n' | socat - TCP:127.0.0.1:4555
convert /tmp/opencode/shot.ppm /tmp/opencode/shot.png
```

## 5. Trampas reales (las que cuestan tiempo)

Estas no están en ningún sitio más y ya han costado horas:

1. **`/tmp` es un tmpfs de 7,7 GB** en esta máquina. Las pruebas de `pacstrap`, los
   chroots de depuración y las ISO de prueba lo llenan en minutos. Con `/tmp` al
   100 % la build falla con errores que **no hablan de disco**: *"keyring is not
   writable"*, *"Resolving timed out"*, *"signature is invalid"*, *"Failure writing
   output"*. **Antes de culpar a las claves, mira `df -h /tmp`.**
2. **La caché de pacman (`/tmp/nimbus-pacman-cache`) la comparten todas las
   builds**: dos a la vez se pisan yappears "signature is invalid". `iso/build.sh`
   ya toma un `flock` (`/tmp/nimbus-build.lock`), pero **solo serializa a quien
   usa ese script** ✗ (las builds de otro worktree con la versión antigua no lo
   toman).
3. **`makepkg` exige que su directorio sea escribible** y sale con **código 11**
   ("No tiene permisos de escritura en la carpeta $SRCDEST"). En la CI el checkout
   es de `root` y compila como otro usuario: `iso/build.sh` abre permisos y los
   devuelve.
4. **`qs` (Quickshell) usa un parser tipo clap**: rechaza opciones desconocidas
   (`--no-tour` aborta el arranque ✗) y un `--` convierte el argumento en
   posicional ✗. Para pasar argumentos a la app QML no hay vía hoy.
5. **La consola serie de la ISO la ocupa un kitty**: la salida de los comandos va
   al VT gráfico, **no** a la serie. Por eso `hyprctl … > /dev/ttyS0` tampoco
   ayuda. Para leer el estado del guest, usa el **journal** (`journalctl -b`) o el
   `screendump`.
6. **Las ventanas flotantes de Quickshell y el tamaño del contenido**: si el
   contenido se ancla a la ventana **y** la ventana declara tamaño, la circularidad
   se resuelve con **el tamaño de la pantalla** ✗ (una tarjeta se convertía en un
   cartel a pantalla completa). El patrón que funciona: la ventana **no** declara
   tamaño y el contenido **no** se ancla a ella.
7. **La puerta de readiness es honesta** (escribe el marcador solo si el shell
   responde). Si ves `NIMBUS_LIVE_TIMEOUT`, el shell **no** arrancó: mira
   `journalctl -u nimbus-live.service` y el log de Quickshell. Antes mentía.

## 5-bis. Memoria persistente (opencode-mem)

Este proyecto tiene **memoria entre sesiones** con el plugin
[`tickernelz/opencode-mem`](https://github.com/tickernelz/opencode-mem) (MIT),
instalado **solo aqui**:

| Pieza | Donde | Que hace |
|---|---|---|
| Registro del plugin | `opencode.json` (raiz del repo) | Carga el plugin **solo en este proyecto** (OpenCode fusiona la config del proyecto con la global) |
| Ajustes del plugin | `.opencode/opencode-mem.jsonc` | Override **por proyecto**: base de datos, modelo de embeddings, provider, cifrado |
| Base de datos | `/home/jp/.opencode-mem/nimbus` (fuera del repo) | Turso/libSQL local con vectores; **nada sale de la maquina** |
| Clave de cifrado | `~/.config/opencode/opencode-mem-db.key` (0600) | AES-256-GCM en reposo: las memorias no se guardan en claro |

**Como se usa**: la herramienta `memory` aparece en el catalogo del agente:
`memory({ mode: "add" | "search" | "list" | "profile" | "forget" | ... })`.
La busqueda es **por palabras clave** (las etiquetas pesan mas); el vector
semantico se usa internamente para deduplicar y para el perfil de
preferencias.

**Lo que ya esta guardado** (5 memorias del proyecto + el perfil del
propietario): las trampas del build (`/tmp` lleno, cache de pacman
compartida), las del shell (el `Loader` y las ventanas flotantes), las de la
sesion live (grupos de video, `LIBSEAT_BACKEND`), el gate de readiness
honesto y como ver el guest (`screendump` del monitor).

**Para usarlo en otro proyecto de OpenCode** (no esta instalado globalmente a
proposito):
1. Anade `"opencode-mem@latest"` al array `plugins` de su `opencode.json`.
2. Copia `.opencode/opencode-mem.jsonc` a `<proyecto>/.opencode/` y cambia
   `storagePath` por una ruta propia: si comparten `storagePath`, las memorias
   de un proyecto se mezclan con las de otro.
3. Recuerda que el modelo de embeddings se descarga la primera vez (0,5-2 GB de
   RAM mientras esta cargado) y que la UI web escucha en `127.0.0.1:4747`.


## 6. Por dónde seguir (por impacto)

1. **Test de instalación end-to-end** en QEMU: arrancar la ISO, ejecutar Calamares,
   llegar a un escritorio instalado. Es lo que separa "beta" de "beta instalable"
   y es el hueco nº 1 del §9 del spec.
2. **Secure Boot** (shim + UKI + `sbctl`) y **rotación de la clave de firma**:
   requisitos de v1.0. El procedimiento de rotación está en `packages/README.md`.
3. **Repo público de paquetes**: mientras no exista, `pacman -Syu` no trae nada en
   un sistema instalado (hoy apunta al repo local de bootstrap).
4. **Store de verdad**: `libflatpak` + `PackageKit` en la imagen, con el diálogo de
   polkit.
5. **Agente de polkit** registrado en `polkitd` (hoy el diálogo es propio y el
   puente usa `pkexec`).
6. **Verificación en hardware real**: portátil híbrido, dGPU, batería, VRR,
   dual-boot con Windows. Nada de eso se puede cerrar aquí.
7. **Btrfs por defecto ya está en el instalador** ✓, pero falta el `snapper`/equivalente
   propio y el primer snapshot.

## 7. Las reglas del proyecto (no negociables)

- **Nada de assets de Apple ni de terceros**: los iconos se dibujan, los fondos se
  generan, y `LICENSES.md` tiene que ser verdad.
- **Sin telemetría**: nada sale del equipo.
- **ES + EN** desde el primer día: toda cadena visible por `Config.translated(key)`;
  las tablas (`Translations.qml`, `nimbus_i18n.py`) simétricas.
- **Regla de oro del shell**: los colores, radios y métricas salen de `Theme`; el
  texto visible, de `Config.translated`.
- **Nada de terminal para el usuario final**: un CLI puede existir, pero su camino
  de uso normal es una pantalla.
- **Regla dura de ananicy**: ninguna regla baja la prioridad de un proceso de
  juego ni del sistema de audio.
- **La firma es offline y manual**: la CI nunca firma.
- Cabecera SPDX en todo fichero nuevo; scripts con `set -euo pipefail` y sin `eval`.
- **TDD**: cada arreglo empieza por un test que falla.

## 8. Documentos del repo

| Documento | Para qué |
|---|---|
| [`STATUS.md`](STATUS.md) | Qué funciona, cómo se verifica y qué no (léelo primero) |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Cómo encaja cada subsistema |
| [`BUILDING.md`](BUILDING.md) | Construir la ISO, con sus trampas |
| [`QUICKSHELL-API.md`](QUICKSHELL-API.md) | La API **real** de Quickshell 0.3.2 y Hyprland 0.56 |
| [`RELEASE-NOTES.md`](RELEASE-NOTES.md) | Lo que dice la beta de la release |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md) | Cómo aportar un PR |
| [`SECURITY.md`](../SECURITY.md) | Cómo reportar un fallo |
| [`superpowers/specs/`](superpowers/specs/) | El spec (la autoridad) |
| [`superpowers/plans/`](superpowers/plans/) | Los planes por hito |
