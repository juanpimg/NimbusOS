# Nimbus M3 — Gameready y energía Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir el interruptor "gameready" del instalador en una promesa cumplida: Steam instalado y configurado con Proton-GE por defecto, una sesión de juegos a un clic con VRR y HDR, telemetría de rendimiento lista, y un portátil que aguanta la batería sin que el usuario toque una sola configuración.

**Architecture:** El gaming de Nimbus no es un tema: es un **metapaquete** que el instalador ofrece, más una **sesión de escritorio alternativa** (gamescope + Steam Big Picture), más una capa de **energía y gráficos híbridos** que vive en el sistema y se controla desde Ajustes. Todo lo que el usuario necesita para jugar está en el paquete; todo lo que necesita para que el portátil no muera está en el sistema.

**Tech Stack:** Steam · Proton-GE y `proton-cachyos` · gamescope 3.16 con VRR/HDR · gamemode · MangoHud · vkBasalt · Heroic / Lutris / Bottles · `power-profiles-daemon` · `auto-cpufreq` · `ananicy-cpp` · `nvidia-prime` · sched-ext (LAVD/BORE)

**Spec:** [`../specs/2026-10-21-nimbus-design.md`](../specs/2026-10-21-nimbus-design.md) — §4.6 (gameready), §4.7 (portátiles y energía), §4.13 (hardware soportado).

---

## Global Constraints

- **Base:** CachyOS x86-64. El usuario final nunca usa AUR: todo lo que necesite AUR se reempaqueta y firma en el repo `nimbus`.
- **Cero terminal:** el gaming y la energía se configuran desde el instalador y desde Ajustes, nunca desde una terminal.
- **Promesa de gaming:** un juego debe funcionar: launcher instalado, Proton listo por defecto, rendimiento adecuado, telemetría activa.
- **Promesa de portátil:** con la tapa cerrada el equipo no se descarga en un día de uso normal; el modo híbrido no gasta la dGPU cuando no hace falta; y el límite de carga de batería se puede tocar desde Ajustes.
- **Hardware (§4.13 del spec):** NVIDIA Turing+ con módulos abiertos; AMD GCN3+ con RADV; Intel Gen8+ y Arc. Los híbridos (iGPU + dGPU) son el caso por defecto.
- **Licencias:** todo fichero de código fuente fuera de `third_party/` lleva SPDX `GPL-3.0-or-later`.
- **Idiomas:** toda cadena visible al usuario existe en español e inglés.

---

## Review Focus

1. **El juego arranca pero va a 30 FPS en un portátil con dGPU.** La causa más frecuente es que la dGPU no se usa, o que el perfil de energía frena la CPU. → **Task 2**
2. **El portátil se calienta y descarga en una hora.** El scheduler y la governor importan tanto como la GPU. → **Task 4**
3. **La batería se degrada por estar siempre al 100 %.** El límite de carga debe ser configurable y estar aplicado por defecto. → **Task 3**
4. **MangoHud no aparece, o el juego ni arranca con él.** Un overlay mal configurado puede impedir lanzar el juego. → **Task 5**
5. **El juego usa la iGPU en vez de la dGPU.** La detección de GPU es la causa número uno de "va lento" y nadie sabe por qué. → **Task 2**

---

## Estructura de ficheros

```
packages/
  nimbus-gaming/            Metapaquete con el stack de juegos
    PKGBUILD
    nimbus-gaming.install
    files/nimbus-gaming-tune     Ajuste de rendimiento por juego
    files/mangohud.conf          Preset de MangoHud
    files/gamescope.conf         Preset de gamescope (VRR, HDR)
  nimbus-energy/            Metapaquete de energía y gráficos
    PKGBUILD
    files/nimbus-energy          CLI de energía (polkit)
    files/nimbus-scheduler       CLI de scheduler
    files/ananicy/ananicy.d/50-nimbus-gaming.rules
    files/90-nimbus-gaming.conf
  nimbus-dots/              (ya existe en M0) — aquí se le añade el gancho de gaming
iso/profiles/nimbus/overlay/usr/share/xsessions/
  nimbus-gaming.desktop     Sesión de juegos
shell/src/Nimbus/apps/Settings/
  SettingsGaming.qml        (nuevo) preferencias de gaming
tests/
  test_gaming_stack.py
  test_energy.py
  test_gaming_session.py
```

---

## Olas de ejecución

```
Ola A (3 en paralelo)   Task 1 (metapaquete gaming) · Task 3 (energía) · Task 4 (scheduler y reglas)
Ola B (3 en paralelo)   Task 2 (sesión de juegos) · Task 5 (telemetría y presets) · Task 6 (ajustes de gaming)
```

---

### Task 1: Metapaquete `nimbus-gaming`

**Files:**
- Create: `packages/nimbus-gaming/PKGBUILD`
- Create: `packages/nimbus-gaming/nimbus-gaming.install`
- Create: `tests/test_gaming_stack.py`

**Interfaces:**
- Produces: el metapaquete, con estas **dependencias exactas**:
  `steam`, `proton-ge`, `proton-cachyos`, `gamescope`, `gamemode`, `mangohud`, `vkbasalt`,
  `lib32-vulkan`, `vkd3d-proton`, `heroic`, `lutris`, `bottles`, `protonup-qt`, `protontricks`.
  Se construye desde el árbol local del monorepo (`source=()` vacío, ficheros vía `$startdir/../..`).
- `nimbus-gaming.install` — script de post-instalación que **no lanza nada automáticamente**
  pero deja el Proton por defecto configurado en la configuración de Steam, y **es idempotente**.

- [ ] **Step 1: Escribe `tests/test_gaming_stack.py`**
  - El `PKGBUILD` declara **exactamente** ese conjunto de 14 dependencias (comprueba el conjunto,
    no que "contenga" varias).
  - El PKGBUILD **no** depende de ningún paquete de AUR.
  - `nimbus-gaming.install` es **idempotente**: ejecutarlo dos veces no duplica la configuración
    del Proton por defecto.
  - El `PKGBUILD` declara la licencia `GPL-3.0-or-later` y tiene la cabecera SPDX.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: `python tools/check_spdx.py --root .` y la suite completa en verde.
- [ ] **Step 6**: Commit — `feat: nimbus-gaming metapackage`.

---

### Task 2: Sesión "Nimbus Gaming"

**Files:**
- Create: `iso/profiles/nimbus/overlay/usr/share/xsessions/nimbus-gaming.desktop`
- Create: `packages/nimbus-gaming/files/nimbus-gaming-session`
- Create: `packages/nimbus-gaming/files/gamescope-vrr-check`
- Create: `tests/test_gaming_session.py`

**Interfaces:**
- Produces:
  - `nimbus-gaming.desktop` — entrada de sesión XDG con `Name=Nimbus Gaming` y
    `Exec=/usr/bin/nimbus-gaming-session`.
  - `nimbus-gaming-session [--steam bignpicture|client]` — arranca gamescope con Steam en modo
    Big Picture.
  - `gamescope-vrr-check` — responde sí/no a "¿este panel tiene VRR?", leyendo el sysfs del
    panel y la extensión de display del kernel, **sin asumir que todos los portátiles lo tienen**.

- [ ] **Step 1: Escribe `tests/test_gaming_session.py`**
  - El `.desktop` tiene `Name=Nimbus Gaming` y el `Exec` correcto.
  - `gamescope-vrr-check` sale con 0 y "sí" cuando se simula un panel con VRR, y con 1 y "no"
    cuando no. (La detección se hace sobre **datos inyectados**, para poder probarla.)
  - `nimbus-gaming-session` **no** pasa flags de VRR cuando la detección dice que no hay VRR.
    Esto es crítico: **gamescope con VRR mal configurado puede no mostrar imagen**.
  - La sesión **avisa** al usuario cuando arranca sin VRR.
  - El perfil de energía `performance` se aplica **dentro** de la sesión de juegos, y no fuera de ella.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: SPDX + suite completa.
- [ ] **Step 6**: Commit — `feat: Nimbus Gaming session with VRR detection`.

---

### Task 3: Energía, batería y gráficos híbridos

**Files:**
- Create: `packages/nimbus-energy/PKGBUILD`
- Create: `packages/nimbus-energy/files/nimbus-energy`
- Create: `packages/nimbus-energy/files/energy-helper.conf`
- Create: `tests/test_energy.py`

**Interfaces:**
- Produces:
  - `nimbus-energy` — CLI con polkit para lo que requiere privilegios:
    ```
    nimbus-energy profile get|set <economy|balanced|performance>
    nimbus-energy charge-limit get|set <porcentaje 0-100|off>
    nimbus-energy gpu get|set <auto|on-demand|always>
    ```
    - `profile`: escribe en `power-profiles-daemon` y **verifica** que el cambio se aplicó.
    - `charge-limit`: en AMD usa `amdgpu_charge_limit`; en NVIDIA `nvidia-smi -pl`; en Intel
      `thinkpad_acpi` o `fwupd`. Si el hardware no lo soporta, **lo dice** y no finge haberlo aplicado.
    - `gpu`: en sistemas híbridos escribe el modo de `nvidia-prime` (`on-demand` por defecto).
      Sin dGPU NVIDIA, informa de que no aplica y sale con 0.
  - `energy-helper.conf` — valores por defecto: `profile=balanced`, `charge-limit=80`, `gpu=on-demand`.
    **El 80 % es el valor por defecto**: es lo que hacen los fabricantes de portátiles y es lo
    que alarga la vida de la batería.
  - `nimbus-energy/PKGBUILD` — depende de `power-profiles-daemon`, `auto-cpufreq`, `ananicy-cpp`
    y `nvidia-prime` (si hay dGPU). **No** de `tlp`: es invasivo y entra en conflicto con
    `power-profiles-daemon`.

- [ ] **Step 1: Escribe `tests/test_energy.py`**
  - Los valores por defecto son exactamente `balanced`, `80` y `on-demand`.
  - `charge-limit set 95` se **rechaza** con un mensaje (fuera de rango).
  - `charge-limit set 80` **verifica** que el hardware lo aplicó, y si no puede, devuelve un
    error **legible**, no un 0 silencioso.
  - `gpu set always` en un sistema sin NVIDIA devuelve "no aplica" y sale con 0.
  - `profile set performance` **verifica** el resultado con `power-profiles-daemon` en vez de
    asumir que ha funcionado.
  - La CLI **no** puede ejecutarse sin privilegios: pide polkit.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: SPDX + suite completa.
- [ ] **Step 6**: Commit — `feat: power profiles, charge limits and hybrid GPU control`.

---

### Task 4: Scheduler, reglas de ananicy y rendimiento de escritorio

**Files:**
- Create: `packages/nimbus-energy/files/nimbus-scheduler`
- Create: `packages/nimbus-energy/files/ananicy/ananicy.d/50-nimbus-gaming.rules`
- Create: `packages/nimbus-energy/files/90-nimbus-gaming.conf`
- Create: `packages/nimbus-energy/files/nimbus-anonicy`
- Create: `tests/test_energy.py` (ampliación)

**Interfaces:**
- Produces:
  - `nimbus-scheduler list|set <sched-ext|lavd|bore|bmq|default>` — solo ofrece schedulers
    **disponibles en el kernel instalado** (los comprueba en `/sys/kernel/sched_ext/`).
    `default` es siempre la opción segura. Cambiar de scheduler **requiere reiniciar**, y el script
    lo dice con claridad.
  - `50-nimbus-gaming.rules` — reglas de ananicy que **suben** la prioridad de los procesos del
    shell (nimbus-shell, Quickshell) y la **bajan** de los que no tienen nada que ver con la
    interfaz (indexadores, actualizadores en segundo plano).
    **Regla dura: ninguna regla baja la prioridad de un proceso del juego ni del sistema de
    audio.** Un error aquí se nota como "el juego va lento".
  - `90-nimbus-gaming.conf` — configuración de ananicy que **se activa solo** cuando hay un
    juego en marcha, y se desactiva al salir.
  - `nimbus-anonicy enable|disable|status`.

- [ ] **Step 1: Amplía `tests/test_energy.py`**
  - `nimbus-scheduler list` solo lista schedulers **disponibles** (con un sysdir inyectado).
  - `nimbus-scheduler set` **avisa** de que requiere reiniciar.
  - Las reglas de ananicy **no** mencionan `steam`, `gamescope`, `proton`, `wine` ni procesos
    de audio con prioridad baja: es una guarda barata contra un error caro.
  - `nimbus-anonicy disable` restaura el conjunto de reglas por defecto.
  - El perfil por defecto de un portátil es `balanced`, **no** `performance`.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: SPDX + suite completa.
- [ ] **Step 6**: Commit — `feat: scheduler selection and desktop performance management`.

---

### Task 5: Telemetría de juegos y presets

**Files:**
- Create: `packages/nimbus-gaming/files/mangohud.conf`
- Create: `packages/nimbus-gaming/files/gamescope.conf`
- Create: `packages/nimbus-gaming/files/nimbus-gaming-tune`
- Create: `tests/test_gaming_stack.py` (ampliación)

**Interfaces:**
- Produces:
  - `mangohud.conf` — preset con FPS, frametime, temperatura de GPU/CPU, uso de GPU, RAM y VRAM.
    **Sin `exec`**: ejecutar procesos desde el overlay es un problema de estabilidad y seguridad.
  - `gamescope.conf` — preset de gamescope. **El VRR se activa por detección, no por
    configuración estática**: un flag de VRR en un panel que no lo soporta hace que gamescope
    **no muestre imagen**.
  - `nimbus-gaming-tune <appid> [--profile performance|balanced] [--mangohud on|off]` — ajusta el
    rendimiento **de un juego concreto**: governor de CPU a `performance` mientras corre,
    perfil de energía `performance`, forzar la dGPU (`prime-select on`) en un sistema híbrido,
    y activar gamemode y mangohud según se pida.
    **Debe ser reversible**: al salir el juego, la governor, el perfil de energía y el modo de
    GPU **vuelven** a su valor anterior. Usa `trap` para restaurar incluso con `SIGTERM`.

- [ ] **Step 1: Amplía `tests/test_gaming_stack.py`**
  - `mangohud.conf` contiene `fps` y `frametime`, y **no** contiene `exec`.
  - `gamescope.conf` **no** fuerza VRR de forma estática (la detección va en la Task 2).
  - `nimbus-gaming-tune` **restaura** la governor, el perfil de energía y el modo de GPU al
    salir, y también cuando recibe `SIGTERM`.
  - `nimbus-gaming-tune` es **idempotente**.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: SPDX + suite completa.
- [ ] **Step 6**: Commit — `feat: game telemetry presets and reversible per-game tuning`.

---

### Task 6: Preferencias de gaming en Ajustes

**Files:**
- Create: `shell/src/Nimbus/apps/Settings/SettingsGaming.qml`
- Create: `shell/tests/tst_settings.py` (ampliación)
- Modify: `shell/src/Nimbus/apps/Settings/Settings.qml` (**solo** para añadir la sección)

**Interfaces:**
- Produces: la sección `gaming` de Ajustes, con:
  - interruptor de **modo de juego** (que aplica el perfil de energía y el scheduler),
  - selección del **Proton por defecto** (Proton-GE o Proton de CachyOS),
  - interruptor de **MangoHud**,
  - estado del **VRR** (detectado, no supuesto),
  - **límite de carga de batería** (el de la Task 3, que se puede cambiar desde aquí).

  Los valores por defecto: gameready **desactivado**, Proton-GE, MangoHud **activado**,
  límite de carga **80 %**.

- [ ] **Step 1: Amplía `shell/tests/tst_settings.py`**
  - La sección `gaming` existe y aparece en el **orden exacto** que exige el spec.
  - Los valores por defecto son los de arriba.
  - El estado del VRR se muestra como **"detectado"** o **"no disponible"**, nunca como
    "sí" sin comprobar.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: SPDX + suite completa.
- [ ] **Step 6**: Commit — `feat: gaming preferences in system settings`.

---

## Criterio de terminación de M3

1. Las 6 tareas están mergeadas y revisadas.
2. `/tmp/nimbus-venv/bin/python -m pytest tests -v` pasa entero.
3. El instalador ofrece el perfil "gameready" y **su instalación deja Steam, Proton y gamescope
   operativos**.
4. La sesión "Nimbus Gaming" aparece en el greeter y arranca gamescope con Steam en Big Picture.
5. En el portátil de referencia (Intel i7-12700H + Iris Xe + RTX 4060 Max-Q), un juego de Steam
   con Proton **arranca sin tocar ninguna configuración**, y el modo híbrido usa la dGPU durante
   el juego y la apaga al salir.
6. El límite de carga de batería al 80 % está aplicado por defecto y se puede cambiar desde Ajustes.
7. Con la tapa cerrada, el sistema pasa a `s2idle` y la batería no se descarga en un día normal.
8. `python tools/check_spdx.py --root .` pasa.

Cuando las ocho se cumplan, M3 está cerrado y el **Plan 5 (beta, Secure Boot e i18n)** puede arrancar.
