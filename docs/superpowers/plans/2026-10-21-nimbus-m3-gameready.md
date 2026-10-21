# Nimbus M3 — Gameready y energía Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir el interruptor "gameready" del instalador en una promesa cumplida: Steam instalado y configurado con Proton-GE por defecto, una sesión de juegos a un clic con VRR y HDR, telemetría de rendimiento lista, y un portátil que aguanta la batería sin que el usuario toque una sola configuración.

**Architecture:** El gaming de Nimbus no es un tema: es un **metapaquete** que el instalador ofrece, más una **sesión de escritorio alternativa** (gamescope + Steam Big Picture) más una capa de **energía y gráficos híbridos** que vive en el sistema, no en un panel. Todo lo que el usuario necesita para jugar está en el paquete; todo lo que necesita para que el portátil no muera está en el sistema.

**Tech Stack:** Steam · Proton-GE y `proton-cachyos` · gamescope 3.16 con VRR/HDR · gamemode · MangoHud · vkBasalt · Heroic / Lutris / Bottles · `power-profiles-daemon` · `auto-cpufreq` · `ananicy-cpp` · `nvidia-prime` · sched-ext (LAVD/BORE)

**Spec:** [`../specs/2026-10-21-nimbus-design.md`](../specs/2026-10-21-nimbus-design.md) — §4.6 (gameready), §4.7 (portátiles y energía), §2 (objetivos G3, G4), §4.13 (hardware soportado).

---

## Global Constraints

- **Base:** CachyOS x86-64. El usuario final nunca usa AUR: todo lo que necesite AUR se reempaqueta y firma en el repo `nimbus`.
- **Cero terminal:** el gaming y la energía se=configuran desde el instalador y desde Ajustes, nunca desde una terminal.
- **Promesa de gaming:** el contenido del perfil "gameready" es el que define este plan. Un juego debe funcionar: launcher instalado, Proton listo por defecto, rendimiento de CPU y GPU adecuado, telemetría activa.
- **Promesa de portátil:** con la tapa cerrada el equipo no se descarga en un día de uso normal; el modo híbrido no gasta la dGPU cuando no hace falta; y el usuario puede tocar el límite de carga de la batería desde Ajustes.
- **Hardware soportado (§4.13 del spec):** NVIDIA Turing+ con módulos abiertos; AMD GCN3+ con RADV; Intel Gen8+ y Arc. Los portátiles híbridos (iGPU + dGPU) son el caso por defecto.
- **Licencias:** todo fichero de código fuente fuera de `third_party/` lleva SPDX `GPL-3.0-or-later`.
- **Idiomas:** toda cadena visible al usuario existe en **español e inglés**.
- **Compromisos de git:** mensajes en inglés con estilo convencional.

---

## Review Focus

1. **El juego se lanza pero va a 30 FPS en un portátil con dGPU.** El perfil de energía o el modo de gráficos híbridos pueden estar frenando la GPU. → **Task 2**
2. **El portátil se calienta y descarga en una hora.** El scheduler y la governors importan tanto como la GPU. → **Task 4**
3. **La batería se degrada por estar siempre al 100 %.** El límite de carga debe ser configurable y applied por defecto. → **Task 3**
4. **El juego usa la iGPU en vez de la dGPU** (o al revés): la exchanged detección de GPU es la causa más común de "va lento" y nadie sabe por qué. → **Task 2**
5. **MangoHud no aparece o el juego no arranca con él.** Un overlay mal configurado puede impedir lanzar el juego. → **Task 4**

---

## Estructura de ficheros

```
packages/
  nimbus-gaming/            Metapaquete con el stack de juegos
    PKGBUILD
    nimbus-gaming.install
    files/nimbus-gaming-tune     Script de ajuste de rendimiento por juego
    files/mangohud.conf          Preset de MangoHud
    files/gamescope.conf         Preset de gamescope (VRR, HDR)
  nimbus-energy/            Metapaquete de energía y gráficos
    PKGBUILD
    files/nimbus-energy           CLI de energía (polkit)
    files/ananicy/ananicy.d/50-nimbus-gaming.rules
  nimbus-dots/              (ya existe en M0; aquí se le añaden los hooks)
iso/profiles/nimbus/overlay/usr/share/xsessions/
  nimbus-gaming.desktop     Sesión de juegos
shell/src/Nimbus/apps/Settings/
  SettingsPower.qml         (ya existe en M1) — aquí se amplía con límites y GPU
  SettingsGaming.qml        NUEVO: preferencias de gaming
tests/
  test_gaming_stack.py
  test_energy.py
  test_gaming_session.py
```

---

## Olas de ejecución

```
Ola A (3 en paralelo)   Task 1 (metapaquete gaming) · Task 3 (energía) · Task 4 (rendimiento)
Ola B (2 en paralelo)   Task 2 (sesión de juegos, depende de T1) · Task 5 (rendimiento de escritorio)
```

---

### Task 1: Metapaquete `nimbus-gaming` — el stack completo

**Files:**
- Create: `packages/nimbus-gaming/PKGBUILD`
- Create: `packages/nimbus-gaming/nimbus-gaming.install`
- Create: `packages/nimbus-gaming/files/nimbus-gaming-tune`
- Create: `packages/nimbus-gaming/files/mangohud.conf`
- Create: `packages/nimbus-gaming/files/gamescope.conf`
- Create: `tests/test_gaming_stack.py`

**Interfaces:**
- Produces:
  - `packages/nimbus-gaming/PKGBUILD` — metapaquete. Sus dependencias exactas:
    `steam`, `proton-ge`, `proton-cachyos`, `gamescope`, `gamemode`, `mangohud`, `vkbasalt`,
    `lib32-vulkan`, `vkd3d-proton`, `heroic`, `lutris`, `bottles`, `protonup-qt`,
    `protontricks`, `steam-dev` (para las herramientas de Steam).
    Se construye desde el árbol local del monorepo (`source=()`, ficheros en `$startdir/../..`).
  - `nimbus-gaming-tune` — CLI que ajusta el rendimiento **de un juego concreto**:
    ```
    nimbus-gaming-tune <appid> [--profile performance|balanced] [--mangohud on|off]
    ```
    Hace: fijar la governor de CPU a `performance` mientras el juego corre y restaurar la anterior al salir; activar el perfil de energía `performance`; forzar la dGPU con `prime-select on` si el sistema es híbrido; y exportar las variables de gamescope. **Debe ser reversible**: si el juego se cierra, el sistema vuelve al estado anterior.
  - `mangohud.conf` — preset de MangoHud: muestra FPS, frametime, GPU/CPU temp, uso de GPU, RAM y VRAM. **Sin** elementos que el juego no pueda renderizar (nada deallergies).
  - `gamescope.conf` — preset de gamescope con `--nvidia-drm-syncs`, `--rt`, `--expose-wayland`, y el FSR si la GPU lo soporta.
  - `nimbus-gaming.install` — script de post-instalación que **no** lanza nada automáticamente, pero deja el Proton por defecto configurado en la configuración de Steam.

- [ ] **Step 1: Escribe `tests/test_gaming_stack.py`**
  - El `PKGBUILD` declara **exactamente** las 14 dependencias listadas arriba (comprueba el conjunto, no que "contenga" varias).
  - `nimbus-gaming-tune` **restaura** la governor y el perfil de energía al salir, y el test lo comprueba sobre una configuración simulada.
  - `nimbus-gaming-tune` es **idempotente**: ejecutarlo dos veces no deja el sistema en un estado distinto al de una sola ejecución.
  - `mangohud.conf` contiene `fps` y `frametime`, y **no** contiene `exec` (ejecutar procesos desde el overlay es un problema de seguridad y de estabilidad).
  - `gamescope.conf` no fuerza opciones de VRR en hardware que no lo soporta: el VRR se activa por detección, no por configuración estática.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa el metapaquete, el script y los presets.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite y el SPDX.
- [ ] **Step 6**: Commit — `feat: nimbus-gaming metapackage with per-game tuning and presets`.

---

### Task 2: Sesión "Nimbus Gaming" — juegos a un clic

**Files:**
- Create: `iso/profiles/nimbus/overlay/usr/share/xsessions/nimbus-gaming.desktop`
- Create: `packages/nimbus-gaming/files/nimbus-gaming-session`
- Create: `packages/nimbus-gaming/files/gamescope-vrr-check`
- Create: `tests/test_gaming_session.py`

**Interfaces:**
- Consumes: el metapaquete de la Task 1.
- Produces:
  - `nimbus-gaming.desktop` — entrada de sesión XDG:
    ```
    [Desktop Entry]
    Name=Nimbus Gaming
    Comment=Juegos a pantalla completa
    Exec=/usr/bin/nimbus-gaming-session
    Type=Application
    DesktopNames=Nimbus Gaming
    ```
  - `nimbus-gaming-session` — arranca gamescope con Steam en modo Big Picture:
    ```
    nimbus-gaming-session [--steam bignpicture|client]
    ```
    Comportamiento: detecta si el sistema **tiene** VRR disponible (`gamescope --help` + la salida de `hyprctl`/sysfs del panel); si lo tiene, pasa los flags de VRR; si no, arranca gamescope **sin** ellos y **lo dice** por `notify-send`. Nunca pasa un flag que el hardware no soporta, porque gamescope con VRR mal configurado puede **no mostrar imagen**.
  - `gamescope-vrr-check` — script que responde sí/no a "¿este panel tiene VRR?", leyendo el sysfs del panel (`/sys/class/drm/*/edid` y la extensión de display del kernel) y **sin** asumir que todos los portátiles lo tienen.

- [ ] **Step 1: Escribe `tests/test_gaming_session.py`**
  - El `.desktop` tiene `Name=Nimbus Gaming` y `Exec=/usr/bin/nimbus-gaming-session`.
  - `nimbus-gaming-session` **no** pasa flags de VRR cuando la detección dice que no hay VRR (comprueba el texto del script y, si puedes, ejecuta la rama con un entorno simulado).
  - `gamescope-vrr-check` sale con 0 y "sí" cuando se simula un panel con VRR, y con 1 y "no" cuando no.
  - La sesión **avisa** al usuario cuando arranca sin VRR.
  - El perfil de energía `performance` se aplica **dentro** de la sesión de juegos, y no fuera de ella.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa los tres ficheros.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite y el SPDX.
- [ ] **Step 6**: Commit — `feat: Nimbus Gaming session with VRR detection and gamescope`.

---

### Task 3: Energía, batería y gráficos híbridos

**Files:**
- Create: `packages/nimbus-energy/PKGBUILD`
- Create: `packages/nimbus-energy/files/nimbus-energy`
- Create: `packages/nimbus-energy/files/energy-helper.conf`
- Create: `tests/test_energy.py`

**Interfaces:**
- Produces:
  - `packages/nimbus-energy/PKGBUILD` — depende de `power-profiles-daemon`, `auto-cpufreq`, `ananicy-cpp`, `nvidia-prime` (si hay dGPU NVIDIA) y `tlp` **no** (TLP queda fuera: es invasivo y entra en conflicto con `power-profiles-daemon`).
  - `nimbus-energy` — CLI con polkit para lo que requiere privilegios:
    ```
    nimbus-energy profile get|set <economy|balanced|performance>
    nimbus-energy charge-limit get|set <porcentaje 0-100|off>
    nimbus-energy gpu get|set <auto|on-demand|always>
    ```
    Comportamiento por comando:
    - `profile`: escribe en `power-profiles-daemon` y **verifica** que el cambio se aplicó.
    - `charge-limit`: en AMD usa `amdgpu_charge_limit`; en NVIDIA usa `nvidia-smi -pl`; en Intel usa `thinkpad_acpi` o `fwupd`. Si el hardware no lo soporta, **lo dice** y no finge haberlo aplicado.
    - `gpu`: en sistemas híbridos escribe el modo de `nvidia-prime` (`on-demand` por defecto, `always` opcional). En sistemas sin dGPU NVIDIA, informa de que no aplica y sale con 0.
  - `energy-helper.conf` — valores por defecto: `profile=balanced`, `charge-limit=80`, `gpu=on-demand`.
    **El límite de carga al 80 % es el valor por defecto**: es lo que hacen los fabricantes de portátiles y es lo que alarga la vida de la batería.

- [ ] **Step 1: Escribe `tests/test_energy.py`**
  - Los valores por defecto son exactamente `balanced`, `80` y `on-demand`.
  - `charge-limit set 80` **verifica** que el hardware lo aplicó, y si no puede, devuelve un error **legible**, no un 0 silencioso.
  - `charge-limit set 95` se rechaza con un mensaje, si el valor está fuera de rango.
  - `gpu set always` en un sistema sin NVIDIA devuelve "no aplica" y sale con 0, no con un error.
  - `profile set performance` verifica el resultado con `power-profiles-daemon` en vez de asumir que ha funcionado.
  - La CLI **no** puede ejecutarse sin privilegios: pide polkit.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa el metapaquete y la CLI.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite y el SPDX.
- [ ] **Step 6**: Commit — `feat: power profiles, battery charge limits and hybrid GPU control`.

---

### Task 4: Rendimiento de CPU y telemetría de juegos

**Files:**
- Create: `packages/nimbus-gaming/files/nimbus-scheduler`
- Create: `packages/nimbus-gaming/files/nimbus-gaming-tune` (ampliación)
- Create: `tests/test_gaming_stack.py` (ampliación)

**Interfaces:**
- Produces:
  - `nimbus-scheduler` — CLI:
    ```
    nimbus-scheduler list|set <sched-ext|lavd|bore|bmq|default> [--list]
    ```
    Reglas: solo ofrece schedulers **disponibles en el kernel instalado** (los comprueba en `/sys/kernel/sched_ext/`); `default` es siempre la opción segura; y cambiar de scheduler **requiere reiniciar**, lo cual el script dice con claridad.
  - `nimbus-gaming-tune` (ampliación) — debe:
    - Fijar la governor de CPU a `performance` **solo mientras el juego corre**, y restaurarla al salir (incluido si el juego se cierra a la fuerza).
    - Activar el perfil de energía `performance` y restaurar el anterior.
    - Forzar la dGPU en un sistema híbrido (`prime-select on`) y **restaurar** `on-demand` al salir.
    - Activar `gamemode` y `mangohud` según lo pedido.
    - **Ser reversible en cualquier caso**, incluso con `SIGTERM`: usa `trap` para restaurar.

- [ ] **Step 1**: Amplía `tests/test_gaming_stack.py`
  - `nimbus-scheduler list` solo lista schedulers **disponibles** en el sistema simulado.
  - `nimbus-scheduler set` **avisa** de que requiere reiniciar.
  - `nimbus-gaming-tune` **restaura** la governor, el perfil de energía y el modo de GPU al salir, y también cuando recibe `SIGTERM`.
  - El perfil por defecto de un portátil es `balanced`, **no** `performance`.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `nimbus-scheduler` y amplía `nimbus-gaming-tune`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite y el SPDX.
- [ ] **Step 6**: Commit — `feat: scheduler selection and reversible per-game performance tuning`.

---

### Task 5: Rendimiento del escritorio — reglas de ananicy y zram

**Files:**
- Create: `packages/nimbus-energy/files/ananicy/ananicy.d/50-nimbus-gaming.rules`
- Create: `packages/nimbus-energy/files/90-nimbus-gaming.conf`
- Create: `packages/nimbus-energy/files/nimbus-anonicy`
- Create: `tests/test_energy.py` (ampliación)

**Interfaces:**
- Produces:
  - `50-nimbus-gaming.rules` — reglas de ananicy que **suben la prioridad** de los procesos del shell (nimbus-shell, Quickshell) y la **bajan** de los que no tienen nada que ver con la interfaz (indexadores, actualizadores en segundo plano), de modo que el escritorio no se eternice cuando el juego corre.
    Regla dura: **ninguna regla baja la prioridad de un proceso del juego ni del sistema de audio**.
  - `90-nimbus-gaming.conf` — configuración de ananicy que **se activa solo** cuando hay un juego en marcha, y se desactiva al salir.
  - `nimbus-anonicy` — CLI:
    ```
    nimbus-anonicy enable|disable|status
    ```
    Que activa el conjunto de reglas de gaming y lo restaura al salir.

- [ ] **Step 1**: Amplía `tests/test_energy.py`
  - Las reglas de ananicy **no** mencionan `steam`, `gamescope`, `proton`, `wine` ni procesos de audio con una prioridad baja: comprobarlo por texto es una guarda barata contra un error muy caro (el juego se ralentiza).
  - `nimbus-anonicy disable` restaura el conjunto de reglas por defecto.
  - El estado se puede consultar.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa las reglas, la configuración y la CLI.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite y el SPDX.
- [ ] **Step 6**: Commit — `feat: ananicy rules and desktop performance management for gaming`.

---

## Criterio de terminación de M3

1. Las 5 tareas están mergeadas y revisadas.
2. `/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v` pasa entero.
3. El instalador ofrece el perfil "gameready" y **la instalación de ese perfil deja Steam, Proton y gamescope operativos**.
4. La sesión "Nimbus Gaming" aparece en el greeter y arranca gamescope con Steam en modo Big Picture.
5. En el portátil de referencia (Intel i7-12700H + Iris Xe + RTX 4060 Max-Q), un juego de Steam con Proton arranca **sin tocar ninguna configuración**, y el modo híbrido usa la dGPU durante el juego y la apaga al salir.
6. El límite de carga de batería al 80 % está aplicado por defecto y se puede cambiar desde Ajustes.
7. Con la tapa cerrada, el sistema pasa a `s2idle` y la batería no se descarga en un día de uso normal.
8. `python tools/check_spdx.py --root .` pasa.

Cuando las ocho se cumplan, M3 está cerrado y el **Plan 5 (beta, Secure Boot e i18n)** puede arrancar.
