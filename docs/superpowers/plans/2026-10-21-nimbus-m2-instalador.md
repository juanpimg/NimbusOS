# Nimbus M2 — Instalador y greeter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir el esqueleto de instalador que existe en M0 en un instalador completo y a prueba deTDB de un portátil real: arranque dual con Windows sin perder datos, cifrado LUKS2, bootloader con rollback de un clic, greeter propio, post-instalación que deja el sistema listo para usar y una verificación post-instalación que dice la verdad sobre lo que funciona.

**Architecture:** El instalador sigue siendo **Calamares** (fork de `cachyos-calamares-next`), con módulos de Nimbus para las partes donde el comportamiento por defecto no sirve: apariencia, selección de software y verificación. Todo lo que Calamares hace bien — particionado, cifrado, usuarios — se reutiliza; Nimbus añade la pieza que Calamares no tiene: **el conocimiento de que Nimbus es una distro con repo propio, snapshots y rollback**, y la promesa de que el primer arranque ya está todo listo.

**Tech Stack:** Calamares 3.4.2 (`cachyos-calamares-next`) · Python 3.14 · Btrfs + `snapper`/`snapper-sync` · systemd-boot + `limine-snapper-sync` · GRUB · SDDM 0.21 · LUKS2/cryptsetup

**Spec:** [`../specs/2026-10-21-nimbus-design.md`](../specs/2026-10-21-nimbus-design.md) — §4.4 (instalador), §4.5 (primer arranque), §4.9 (actualizaciones y rollback), §9 (definición de terminado).

---

## Global Constraints

- **Base:** CachyOS x86-64. El usuario final nunca usa AUR ni escribe una terminal.
- **Promesa central:** una persona que nunca ha usado Linux instala Nimbus en **menos de 10 minutos** y **no escribe un comando**.
- **Arranque dual:** se ofrece, y su implementación es la parte más delicada del instalador: la fuente número uno de sistemas inarrancables y pérdida de datos. Todo lo que toque particiones **copia la tabla de particiones antes de escribir**, avisa de Fast Boot, y verifica al final que **ambos** sistemas arrancan.
- **Snapshots:** Btrfs es el sistema de archivos por defecto y el **único con rollback completo**. En ext4/xfs el instalador lo dice de forma explícita y ofrece el kernel LTS como red.
- **Secure Boot:** en M2 el arranque es con MOCK provisional. El shim firmado por Microsoft llega en el **Plan 5 (M4/M5/M6)**, antes de v1.0.
- **Licencias:** todo fichero de código fuente fuera de `third_party/` lleva SPDX `GPL-3.0-or-later`.
- **Idiomas:** toda cadena visible al usuario existe en **español e inglés**.
- **Compromisos de git:** mensajes en inglés con estilo convencional.

---

## Review Focus

1. **El usuario tiene Windows en el disco y arranca desde él.** El instalador debe tocar solo lo que ha dicho que va a tocar, y dejar Windows arrancable. → **Task 1**
2. **El usuario tiene Fast Boot activado.** Es el fallo clásico que hace que GRUB no aparezca y que Windows "no arranque" después de instalar. → **Task 1**
3. **El disco no tiene partición EFI, o ya tiene una de Windows.** El instalador debe reutilizarla o crear una sin romper el arranque de Windows. → **Task 1**
4. **La instalación termina y el sistema no arranca.** Debe existir el rollback de un clic y una forma de llegar a él sin teclado. → **Task 2**
5. **El disco no es Btrfs.** El instalador debe decirlo con claridad en lugar de prometer un rollback que no existe. → **Task 2**

---

## Estructura de ficheros

```
installer/
  calamares/
    settings.conf                     Flujo (ya existe en M0; se amplía)
    modules/
      nimbus-appearance/              (ya existe en M0)
      nimbus-software/                (ya existe en M0)
      nimbus-verify/                  (ya existe en M0)
      nimbus-dualboot/                NUEVO: salvaguardas del arranque dual
      nimbus-bootloader/              NUEVO: bootloader con rollback
  modules/
    nimbus-postinstall/               Script de post-instalación (el "no-touch" del usuario)
  greeter/
    nimbus-greeter/                   Tema SDDM
  tools/
    nimbus-partitionsafe              Copia y compara tablas de particiones
    nimbus-snapshots                  Política de snapshots Btrfs
    nimbus-postinstall                Orquestador de post-instalación
tests/
  test_dualboot_safety.py
  test_bootloader_rollback.py
  test_postinstall.py
  test_greeter_theme.py
```

---

### Task 1: Arranque dual con Windows, a prueba de pérdida de datos

**Files:**
- Create: `installer/calamares/modules/nimbus-dualboot/nimbus-dualboot.conf`
- Create: `installer/calamares/modules/nimbus-dualboot/nimbus-dualboot.py`
- Create: `installer/tools/nimbus-partitionsafe`
- Create: `tests/test_dualboot_safety.py`

**Interfaces:**
- Consumes: el módulo `partition` de Calamares upstream (no lo reescribas).
- Produces:
  - `installer/tools/nimbus-partitionsafe` — CLI:
    ```
    nimbus-partitionsafe backup <device> <destino-dir>
    nimbus-partitionsafe verify <device> <respaldo-dir>
    nimbus-partitionsafe efi <device>            # imprime la particion EFI existente, o vacio
    ```
    Comportamiento: `backup` vuelca la tabla de particiones con `sfdisk --dump` (y un `sgdisk --backup` si está disponible) al directorio indicado; `verify` compara la tabla actual con la de referencia y **sale con 1** si ha cambiado algo que no debería; `efi` localiza la partición EFI existente sin modificarla.
  - `nimbus-dualboot` — módulo Calamares que se ejecuta **antes** de `partition` y hace:
    1. Detectar si hay una instalación de Windows (NTFS con `*/Windows/System32` o un `os-release` de Windows) y preguntar si se quiere instalar junto a ella.
    2. Detectar y **advertir de Fast Boot** (`/sys/firmware/efi/efivars/...` o la presencia de `FastBoot` en `bootmgfw.efi`); si está activo, **impedir continuar** con un mensaje que explique cómo desactivarlo en Windows (`powercfg /h off` + desactivarlo en la BIOS). Esto no es opcional: es el fallo que másupporta旋转
    3. Copiar la tabla de particiones con `nimbus-partitionsafe backup` **antes** de que Calamares toque nada.
    4. Comprobar que existe una partición EFI utilizable (Windows ya tiene una) y no crear una segunda si la hay.
    5. Exponer a los pasos siguientes un aviso de "hay Windows instalada" para que `bootloader` use **GRUB** y no systemd-boot.

- [ ] **Step 1: Escribe `tests/test_dualboot_safety.py`**

Debe comprobar, sin tocar ningún disco real:
- `nimbus-partitionsafe backup` crea un fichero de respaldo con la tabla de particiones y un checksum.
- `nimbus-partitionsafe verify` **sale con 1** cuando la tabla ha cambiado y con 0 cuando no.
- `nimbus-partitionsafe verify` detecta un cambio en el **número de particiones**, que es el caso grave.
- El módulo **detecta Fast Boot** en una entrada simulada y **se niega a continuar** (devuelve un estado de error), en vez de dejar pasar.
- El módulo detecta una partición EFI existente y **no propone crear otra**.

- [ ] **Step 2**: Ejecuta el test y confirma que falla.
- [ ] **Step 3**: Implementa `nimbus-partitionsafe` (bash o Python; Python 3.14 es más fácil de testear) y el módulo.
- [ ] **Step 4**: Ejecuta el test y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite (`/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v`).
- [ ] **Step 6**: Commit — `feat: dual-boot safeguards with partition table backup and fast-boot detection`.

---

### Task 2: Bootloader con rollback de un clic

**Files:**
- Create: `installer/calamares/modules/nimbus-bootloader/nimbus-bootloader.conf`
- Create: `installer/calamares/modules/nimbus-bootloader/nimbus-bootloader.py`
- Create: `installer/tools/nimbus-snapshots`
- Create: `tests/test_bootloader_rollback.py`

**Interfaces:**
- Produces:
  - `installer/tools/nimbus-snapshots` — CLI:
    ```
    nimbus-snapshots setup <mountpoint-btrfs>      # crea subvolumenes y politica de snapshots
    nimbus-snapshots list <mountpoint-btrfs>       # lista los snapshots con su fecha
    nimbus-snapshots last-good <mountpoint-btrfs>  # imprime el subvolumen del ultimo snapshot bueno
    nimbus-snapshots cleanup <mountpoint-btrfs> <max>  # conserva los N mas recientes
    ```
    `setup` es **idempotente**: ejecutarlo dos veces no rompe nada.
  - `nimbus-bootloader` — módulo Calamares que:
    - Elige **GRUB** si hay Windows instalada (multiboot) y **systemd-boot** si el disco es de Nimbus solo.
    - Configura `snapper-sync` (systemd-boot) o el submenú de snapshots en GRUB, de modo que el menú de arranque ofrezca **`Nimbus (última versión conocida buena)`** y **`Nimbus (modo seguro)`** además de la versión normal.
    - Con un disco **no-Btrfs**, **no** promete rollback: instala `linux-cachyos-lts` como red y lo deja escrito en el resumen.

- [ ] **Step 1: Escribe `tests/test_bootloader_rollback.py`**
  - `setup` es idempotente: dos ejecuciones dejan el mismo estado.
  - `cleanup` conserva exactamente los N más recientes.
  - La elección de bootloader depende de la presencia de Windows: GRUB si hay, systemd-boot si no.
  - Con disco no-Btrfs, el instalador **no** añade entradas de rollback al menú y **sí** añade el kernel LTS.
  - El menú ofrece las entradas "última versión conocida buena" y "modo seguro".

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa `nimbus-snapshots` y el módulo.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite.
- [ ] **Step 6**: Commit — `feat: bootloader selection with one-click snapshot rollback`.

---

### Task 3: Post-instalación — dejar el sistema listo sin tocar nada

**Files:**
- Create: `installer/calamares/modules/nimbus-postinstall/nimbus-postinstall.conf`
- Create: `installer/calamares/modules/nimbus-postinstall/nimbus-postinstall.py`
- Create: `installer/tools/nimbus-postinstall`
- Create: `tests/test_postinstall.py`

**Interfaces:**
- Produces:
  - `installer/tools/nimbus-postinstall` — CLI idempotente que ejecuta, en orden, y **sabe continuar si un paso opcional falla**:
    ```
    nimbus-postinstall --root <raiz> [--offline]
    ```
    Pasos: (1) copiar el keyring de Nimbus y ejecutar `pacman-key --populate nimbus`; (2) añadir el repo `nimbus` a `pacman.conf` con `SigLevel = Required DatabaseOptional` y su mirrorlist; (2b) **elegir el repo de CachyOS segun la CPU del equipo de destino**: si soporta AVX2 (x86-64-v3) se anade `[cachyos-v3]`, y si no, se deja el generico `[cachyos]`. La ISO en vivo usa **siempre** los repos genericos, porque tiene que arrancar en hardware desconocido; es el instalador, sobre el hardware real, el que activa la optimizacion; (3) activar el servicio de snapshots y el de actualizaciones automáticas; (4) configurar el greeter (tema Nimbus); (5) configurar el **perfil de energía** por defecto y el límite de carga de batería si el hardware lo soporta; (6) configurar los **gráficos híbridos** en modo `on-demand` si hay dGPU NVIDIA; (7) copiar los defaults de `dots/` a `/etc/skel/` para que los usuarios nuevos los hereden; (8) poner `/etc/os-release` con la marca Nimbus.
    Cada paso reporta `ok`, `skipped` o `failed`, y **el script sale con 0 aunque un paso opcional falle**, Leaving solo los pasos críticos pueden hacerlo fracasar.
  - `nimbus-postinstall.py` — módulo Calamares que invoca la herramienta anterior y **muestra el resultado** en el resumen final, paso a paso, con un mensaje accionable por cada fallo.

- [ ] **Step 1: Escribe `tests/test_postinstall.py`**
  - Cada paso es **idempotente**: ejecutarlo dos veces no cambia el resultado ni duplica entradas en `pacman.conf`.
  - Un paso opcional que falla **no** aborta el resto.
  - Un paso crítico que falla **sí** aborta y se reporta.
  - El repo se añade a `pacman.conf` con `SigLevel = Required DatabaseOptional` y **no** se añade dos veces.
  - **La seleccion de repo por CPU es correcta**: con AVX2 se anade `[cachyos-v3]`, sin ella se deja `[cachyos]`. Y con una CPU sin AVX2 el sistema **arranca igual** con el repo generico, nunca con el v3.
  - En modo `--offline`, los pasos que necesitan red se marcan como `skipped`, no como `failed`.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa la herramienta y el módulo.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite.
- [ ] **Step 6**: Commit — `feat: idempotent post-install orchestration leaving the system ready`.

---

### Task 4: Greeter de Nimbus

**Files:**
- Create: `installer/greeter/nimbus-greeter/metadata.desktop`
- Create: `installer/greeter/nimbus-greeter/Main.qml`
- Create: `installer/greeter/nimbus-greeter/theme.conf`
- Create: `installer/greeter/nimbus-greeter/background.svg`
- Create: `tests/test_greeter_theme.py`

**Interfaces:**
- Produces: un tema SDDM completo en `installer/greeter/nimbus-greeter/`, con `metadata.desktop` declaring `Type=sddm-theme`, `Theme-Name=Nimbus`, y los assets que SDDM espera.
  - `Main.qml` — `property string currentUser: string`, `property bool passwordWrong: bool`, `property bool busy: bool`, `signal loginRequested(string user, string password)`, `signal rebootRequested()`, `signal shutdownRequested()`.
  - Fondo con degradado y **el reloj grande**, como el de macOS.
  - **El logo de Nimbus**, no el de Apple.

- [ ] **Step 1: Escribe `tests/test_greeter_theme.py`**
  - `metadata.desktop` declara `Type=sddm-theme` y `Theme-Name=Nimbus`.
  - Los ficheros que SDDM exige están todos presentes (`metadata.desktop`, `Main.qml`, `theme.conf`).
  - **Ningún asset de Apple**: el tema no referencia ningún logo de Apple ni capturas de macOS.
  - `Main.qml` declara las tres señales esperadas.
  - La contraseña **no** se guarda en ninguna propiedad (la emite y la descarta).

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa el tema.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite.
- [ ] **Step 6**: Commit — `feat: Nimbus SDDM greeter theme`.

---

### Task 5: Verificación post-instalación honesta

**Files:**
- Modify: `installer/calamares/modules/nimbus-verify/nimbus-verify.py`
- Modify: `installer/calamares/modules/nimbus-verify/nimbus-verify.conf`
- Modify: `tests/test_calamares_settings.py`

**Interfaces:**
- Consumes: la estructura de `nimbus-verify` que M0 ya dejó (funciones `check_*` que devuelven `(bool, str)`).
- Produces: la lista final de comprobaciones, que debe ser la que un usuario de verdad necesita ver:
  1. `gpu` — la GPU aparece y renderiza (comprobar `/dev/dri/renderD*` y el driver).
  2. `graphics-hybrid` — si hay iGPU y dGPU, el modo de PRIME es `on-demand`.
  3. `audio` — hay un dispositivo de salida y PipeWire está activo.
  4. `network` — hay una conexión configurada.
  5. `bluetooth` — el servicio está activo **si** el hardware lo tiene.
  6. `webcam` — si hay dispositivo de vídeo, está disponible.
  7. `suspend` — el sistema declara soporte de suspensión y `s2idle` está disponible.
  8. `battery` — si hay batería, el porcentaje es legible y el límite de carga está aplicado.
  9. `disk-space` — hay espacio suficiente.
  10. `bootloader` — el cargador instalado es el esperado y es arrancable.
  11. `dual-boot` — **si** se instaló junto a Windows, la partición EFI es compartible y GRUB está instalado.
  12. `snapshots` — **si** el disco es Btrfs, hay al menos un snapshot.
  13. `updates` — el repo `nimbus` está configurado y la clave es de confianza.
  14. `keyring` — `pacman-key --populate nimbus` se ha ejecutado y la clave está importada.

- [ ] **Step 1: Amplía `tests/test_calamares_settings.py`** con las 14 comprobaciones esperadas, cada una nombrada exactamente como arriba.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa las 14 comprobaciones reales.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite.
- [ ] **Step 6**: Commit — `feat: honest post-install verification covering the full hardware matrix`.

---

## Criterio de terminación de M2

1. Las 5 tareas están mergeadas y revisadas.
2. `/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v` pasa entero.
3. El instalador se puede completar **de principio a fin en una VM** sin intervención manual.
4. Un arranque dual con Windows se puede **probar en un disco de prueba** y ambos sistemas arrancan.
5. El rollback de un clic está presente en el menú de arranque y se ha **probado** (arrancar la versión anterior).
6. El greeter de Nimbus arranca y permite iniciar sesión.
7. Tras instalar, el sistema **arranca y entra al escritorio sin ningún paso manual adicional**: la Appearance ya está aplicada, el repo funciona, y el tour aparece.

Cuando las siete se cumplan, M2 está cerrado y el **Plan 4 (gameready y energía)** puede arrancar.
