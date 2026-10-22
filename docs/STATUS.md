# Estado del proyecto Nimbus

> **Note for English-speaking contributors:** this status page is written in Spanish first. An English version will follow.

Un único sitio que dice la verdad: qué funciona, qué no, y qué puede coger un contribuidor.
Si este documento y otro discrepan, manda este documento y abre un issue.

Última actualización: 2026-10-22, rama `main` (`2d1a2b8`).
Los números de tests se obtuvieron ejecutando las suites, no de memoria.

## Cómo leer este documento

- **Funciona** = hay un comando que lo demuestra y se cita la salida.
- **No funciona** = se cita el fichero y la línea que lo demuestra.
- **Pendiente de hardware real** = el proyecto no puede verificarlo aquí; lo tiene que cubrir el programa beta.

## Qué funciona y cómo se verifica

| Qué | Cómo se verifica (comando y salida real) |
|-----|------------------------------------------|
| Suite Python: 390 tests | `/tmp/opencode/nimbus-venv/bin/python -m pytest tests -q` → `390 passed` (canónico: `python -m pytest tests -v`) |
| Suite bats: 13 tests | `PATH="$HOME/.local/bin:$PATH" bats tests/*.bats` → 13 `ok` (7 en `tests/keyring.bats`, 6 en `tests/promote.bats`) |
| Suite QML: 301 tests | `QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests` → `Totals: 301 passed, 0 failed` (21 ficheros `tst_*.qml`) |
| Cabeceras SPDX: 123 ficheros | `python tools/check_spdx.py --root .` → `SPDX OK: 123 ficheros` |
| La ISO arranca a sesión live | `bash tests/integration/boot_live.sh --iso out/nimbus-*.iso --timeout 600` → `OK: la sesión live de Nimbus está lista` (el marcador `NIMBUS_LIVE_READY` solo se escribe si Hyprland y el shell responden) |
| ISO netinstall < 3 GB | `out/nimbus-2026.10.22-x86_64.iso` existe en el árbol (perfil en `iso/profiles/nimbus/`, constructor `iso/build.sh --local-repo`) |
| Cadena de firma bootstrap | `tools/genkeyring.sh`, `tools/sign_repo.sh`, `tools/promote.sh`, `tools/verify_repo.sh`, cubiertos por los 13 tests bats |
| CI en cada push/PR | `.github/workflows/ci.yml`: lint (SPDX, yamllint, shellcheck, actionlint) + las tres suites. **Verde en `main`** |
| El shell **carga** y se ve | La config de Quickshell arrancaba con `IpcHandler is not a type` (faltaba `import Quickshell.Io`) y con `PanelWindow is not a type` (faltaba `import Quickshell`). Corregido: se ven la barra con la marca Nimbus, el reloj y el Dock |
| El escritorio **se parece a macOS** | Captura del guest (`out/nimbus-*.iso` en QEMU, `screendump` del monitor): fondo degradado propio de Nimbus (swaybg), barra superior con la marca, la fecha/hora y los indicadores, y Dock inferior con iconos dibujados |
| La **ISO lleva el instalador** | `packages/nimbus-installer/` (43 ficheros: los 6 modulos de Calamares, el tema del greeter, la config de SDDM) y la ISO live lo lista. **La instalacion de verdad todavia no se ha probado end-to-end** |
| **Sesion de juegos** con deteccion de VRR | `nimbus-gaming-session` + `gamescope-vrr-check`: el VRR se **detecta** (sysfs del conector, con respaldo por EDID) y si no se puede confirmar, la sesion **no** activa `--adaptive-sync` (un flag estatico en un panel que no lo soporta deja gamescope en negro) |
| **Ajustes de energia y juegos** | `SettingsGaming.qml`: llama a `nimbus-energy` y `nimbus-anonicy` de verdad (no `console.info`) y muestra el resultado |
| El instalador está **empaquetado** | `packages/nimbus-installer/` mete los 6 módulos de Calamares, el tema del greeter y la config de SDDM; `iso/profiles/nimbus/packages.x86_64` lo lista |
| `settings.conf` lo entiende Calamares | Estaba en INI y Calamares lo lee con YAML: el instalador no arrancaba. Ahora es YAML válido (`yaml.safe_load` OK) |
| Hay **actualizaciones y rollback** | `packages/nimbus-update/`: `nimbus-update check\|apply\|history\|rollback\|auto`, con snapshot antes de cada transacción y dos units de timer |
| La CI construye paquetes | `makepkg` exige que su directorio sea escribible (la CI compila como `builder` sobre un checkout de `root`): arreglado, con el error a la vista si vuelve a pasar |

## Qué NO funciona todavía

Nada de lo siguiente está escrito en ningún otro sitio. Todo verificado contra el árbol.

- **El instalador está en la ISO pero la instalación no se ha probado end-to-end.** El paquete
  `nimbus-installer` existe y la ISO lo lista, pero **nadie ha instalado Nimbus de verdad**: no
  hay un test que arranque la ISO, ejecute Calamares y llegue a un escritorio instalado
  (`tests/integration/` solo arranca la sesión live). Es el hueco más grande que queda.
- **El shell ejecuta procesos a través de un puente dedicado.** `shell/src/Nimbus/lib/Process.qml`
  envuelve `Quickshell.Process` (módulo `Quickshell.Io`) y antepone `pkexec` cuando la
  acción necesita privilegios; lo usan Ajustes→Energía, Ajustes→Juegos y el backend
  de la Store. Lo que sigue sin existir es la prueba de extremo a extremo: lanzar
  `nimbus-shell ipc call <target> <fn>` desde Hyprland y ver el efecto en el shell
  en marcha dentro de la sesión live.
- **`nimbus-shell ipc call` despacha de verdad.** `shell/nimbus-shell` acepta el
  subcomando `ipc call <target> <fn>` y lo reenvía por el socket IPC de Quickshell
  (`qs ipc call …`) al `IpcHandler` correspondiente de `shell/src/shell.qml` (uno con
  `target: "nimbus"` que delega en `Ipc.call(target, fn)`, más uno por superficie).
  La tabla válida vive en `shell/src/Nimbus/Ipc.qml` (`validCalls`, 12 targets);
  ante target o función desconocidos avisa por `console.warn` sin tumbar el shell.
- **Los servicios se sondean, pero el estado real llega tarde.** `Services.qml` ahora tiene
  `probeServices()` que distingue `ready` / `unavailable` / `missing-module` por servicio, y el
  Shell arranca igualmente. Lo que **no** hay: actualizaciones en vivo de Mpris, del volumen de
  Pipewire o del estado de UPower (solo la foto inicial).
- **El agente de polkit sigue sin registrarse en `polkitd`.** `shell/src/Nimbus/PolkitAgent.qml`:
  el diálogo de autenticación es propio y no está conectado al bus de polkit, así que una acción
  privilegiada desde la interfaz pide la clave por otro camino (el `pkexec` del puente de
  procesos).
- **La Store se invoca de verdad, pero no instala de verdad.** La Store ya se monta **con su
  backend** (que llama a `store_backend.py` por CLI con `--json`), pero la transaccion de
  `install()` sigue siendo simulada: no hay `libflatpak` ni `PackageKit` en la ISO, asi que no se
  instala nada de verdad. Los botones de "Actualizar" de `SettingsSoftware.qml` siguen haciendo
  `console.info`.
- **`nimbus-update` existe pero solo se ha probado con dobles de prueba.** El paquete
  `packages/nimbus-update/` trae la CLI y las dos units (`nimbus-snapshots.timer`,
  `nimbus-auto-update.timer`), pero el snapshot y el rollback **no se han probado sobre un disco
  Btrfs real**: los tests usan fakes. Queda por verificar en una VM con Btrfs.
- **El repo público aún no existe.** `installer/tools/nimbus-postinstall` ya **no** apunta a
  `mirror.nimbus.org` (un dominio inexistente): usa el repo local de bootstrap
  (`file:///var/lib/nimbus/repo`) y declara con honestidad que el repo público está pendiente.
  Mientras tanto, **un sistema instalado no puede actualizarse** hasta que se aloje el repo.
  (`iso/build.sh --local-repo`).
- **Ajustes está traducido.** Las 88 claves distintas `settings.*` usadas vía
  `Config.translated("settings.…")` en `shell/src/` existen en la tabla ES/EN de
  `shell/src/Nimbus/Translations.qml` (comprobado por script: cero claves sin definir;
  `Translations.lookup` sigue devolviendo la propia clave como último recurso).

## Qué puede coger un contribuidor

Tareas concretas y pequeñas. Cada una cabe en un PR y dice el fichero y el primer paso.

1. **Conectar "Actualizar" de Ajustes→Software a `nimbus-update`.** Fichero:
   `shell/src/Nimbus/apps/Settings/SettingsSoftware.qml` (los botones aún hacen
   `console.info`). Primer paso: llamar a `nimbus-update` vía el puente
   `lib/Process.qml` siguiendo el patrón de `SettingsPower.qml`.
   Verificación: el runner QML de arriba.
2. **Llevar `nimbus-gaming` y `nimbus-energy` a la ISO.** Fichero:
   `iso/profiles/nimbus/packages.x86_64` (hoy no lista ninguno de los dos; la
   sesión de juegos y los perfiles de energía existen pero no viajan en la live).
   Primer paso: añadir los paquetes y extender `tests/test_iso_profile.py`.
   Verificación: `python -m pytest tests/test_iso_profile.py -v`.
3. **Suscribir Mpris, volumen y UPower en vivo en `Services`.** Fichero:
   `shell/src/Nimbus/Services.qml` (`probeServices()` solo toma la foto inicial;
   el estado real llega tarde). Primer paso: leer `probeServices()` y los flags
   `...Available`, y suscribir los cambios detrás de ellos.
   Verificación: el runner QML de arriba.
4. **Añadir el check `secureboot` a `nimbus-verify`.** Fichero: `installer/calamares/`
   (módulo `nimbus-verify`, hoy 14 checks, ninguno de Secure Boot). Estado honesto:
   detectar e informar, sin shim completo (Secure Boot se entrega en M5/v1.0).
5. **Probar la instalación de extremo a extremo en VM.** Hoy `tests/integration/`
   solo arranca la sesión live; nadie ha instalado Nimbus de verdad (es el hueco
   nº 1). Primer paso: leer `tests/integration/boot_live.sh` y añadir un modo que
   ejecute Calamares desatendido y compruebe que hay un escritorio instalado.
6. **Hacer que la Store instale de verdad.** La Store se monta con su backend pero
   `install()` está simulada y la ISO no trae `flatpak` ni `PackageKit`. Primer paso:
   añadir `flatpak` a `iso/profiles/nimbus/packages.x86_64` y cablear `install()`
   al backend real. Verificación: `tests/test_store_backend.py` y la suite del perfil.
7. **Documentar decisiones pendientes.** Si algo no está decidido, se escribe "pendiente de decidir",
   no se inventa. Ver `CONTRIBUTING.md` (§ "Documentación").

## Pendiente de hardware real

El proyecto no puede verificarlo aquí (una sola máquina de prueba, sin laboratorio).
Cada línea necesita un tester del programa beta con ese hardware, con el parte descrito en
`.github/ISSUE_TEMPLATE/hardware.yml`.

- Portátil híbrido (dGPU NVIDIA + iGPU): PRIME on-demand, VRR, consumo con tapa cerrada.
- Batería: suspensión `s2idle`, límite de carga, descarga real con tapa cerrada.
- Arranque dual con Windows en disco de prueba (ambos sistemas arrancan).
- GPUs AMD (GCN3+/RADV), Intel Arc, WiFi por chip, Bluetooth, audio real, impresoras.
- Juego real en Steam con Proton-GE + gamescope: la sesión "Nimbus Gaming" existe
  (`nimbus-gaming-session` con detección de VRR) y hay página de Ajustes de juegos,
  pero nada se ha probado en hardware real (ver "Qué funciona").

Regla dura del proyecto: las pruebas de hardware se hacen en disco USB externo,
**nunca sobre la instalación CachyOS del fundador**.
