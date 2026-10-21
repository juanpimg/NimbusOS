# Estado del proyecto Nimbus

> **Note for English-speaking contributors:** this status page is written in Spanish first. An English version will follow.

Un único sitio que dice la verdad: qué funciona, qué no, y qué puede coger un contribuidor.
Si este documento y otro discrepan, manda este documento y abre un issue.

Última actualización: 2026-10-22, rama `main` (`a158ac7`).
Los números de tests se obtuvieron ejecutando las suites, no de memoria.

## Cómo leer este documento

- **Funciona** = hay un comando que lo demuestra y se cita la salida.
- **No funciona** = se cita el fichero y la línea que lo demuestra.
- **Pendiente de hardware real** = el proyecto no puede verificarlo aquí; lo tiene que cubrir el programa beta.

## Qué funciona y cómo se verifica

| Qué | Cómo se verifica (comando y salida real) |
|-----|------------------------------------------|
| Suite Python: 251 tests | `/tmp/opencode/nimbus-venv/bin/python -m pytest tests -q` → `251 passed` (canónico: `python -m pytest tests -v`) |
| Suite bats: 13 tests | `PATH="$HOME/.local/bin:$PATH" bats tests/*.bats` → 13 `ok` (7 en `tests/keyring.bats`, 6 en `tests/promote.bats`) |
| Suite QML: 249 tests | `QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests` → `Totals: 249 passed, 0 failed` (16 ficheros `tst_*.qml`) |
| Cabeceras SPDX: 105 ficheros | `python tools/check_spdx.py --root .` → `SPDX OK: 105 ficheros` |
| La ISO arranca a sesión live | `bash tests/integration/boot_live.sh --iso out/nimbus-*.iso --timeout 600` → `OK: la sesión live de Nimbus está lista` (el marcador `NIMBUS_LIVE_READY` solo se escribe si Hyprland y el shell responden) |
| ISO netinstall < 3 GB | `out/nimbus-2026.10.22-x86_64.iso` existe en el árbol (perfil en `iso/profiles/nimbus/`, constructor `iso/build.sh --local-repo`) |
| Cadena de firma bootstrap | `tools/genkeyring.sh`, `tools/sign_repo.sh`, `tools/promote.sh`, `tools/verify_repo.sh`, cubiertos por los 13 tests bats |
| CI en cada push/PR | `.github/workflows/ci.yml`: lint (SPDX, yamllint, shellcheck, actionlint) + las tres suites. **Verde en `main`** |
| El shell **carga** y se ve | La config de Quickshell arrancaba con `IpcHandler is not a type` (faltaba `import Quickshell.Io`) y con `PanelWindow is not a type` (faltaba `import Quickshell`). Corregido: se ven la barra con la marca Nimbus, el reloj y el Dock |
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
- **El shell no puede ejecutar procesos.** Cero usos de `Quickshell.Process` en `shell/src/`;
  la única mención es un comentario en `shell/src/Nimbus/modules/Screenshot.qml:10`.
- **`nimbus-shell ipc call` no está implementado como subcomando.** `shell/nimbus-shell` es
  `exec qs -c … "$@"`, sin subcomando `ipc` propio; los atajos de `dots/hypr/hyprland.lua:26`
  lo invocan (`"nimbus-shell ipc call " .. action`) y el manejo vive dentro del shell en marcha
  (`shell/src/Nimbus/Ipc.qml`), nunca probado de extremo a extremo.
- **Servicios reales a `false`.** `shell/src/Nimbus/Services.qml:13-19`: `notificationsAvailable`,
  `statusNotifierAvailable`, `mprisAvailable`, `upowerAvailable` y `batteryPresent` valen `false`;
  sin D-Bus todo es `"unknown"`.
- **`PolkitAgent.available` es `false`.** `shell/src/Nimbus/PolkitAgent.qml:16`, con mensaje
  `auth.unavailable` (`:18`). Sin diálogo real de autenticación.
- **La Store usa un catálogo simulado.** `shell/src/Nimbus/apps/Store/store_backend.py`:
  `install()` solo hace `_installed_ids.add(app_id)`; el fichero no invoca `flatpak`,
  `PackageKit` ni `subprocess` (único import externo: `shutil`). El botón Actualizar de
  `SettingsSoftware.qml:30-35` hace `console.info`, no actualiza.
- **`nimbus-update` existe pero solo se ha probado con dobles de prueba.** El paquete
  `packages/nimbus-update/` trae la CLI y las dos units (`nimbus-snapshots.timer`,
  `nimbus-auto-update.timer`), pero el snapshot y el rollback **no se han probado sobre un disco
  Btrfs real**: los tests usan fakes. Queda por verificar en una VM con Btrfs.
- **El repo público aún no existe.** `installer/tools/nimbus-postinstall` ya **no** apunta a
  `mirror.nimbus.org` (un dominio inexistente): usa el repo local de bootstrap
  (`file:///var/lib/nimbus/repo`) y declara con honestidad que el repo público está pendiente.
  Mientras tanto, **un sistema instalado no puede actualizarse** hasta que se aloje el repo.
  (`iso/build.sh --local-repo`).
- **Ajustes muestra claves crudas.** 66 claves distintas `settings.*` usadas vía
  `Config.translated("settings.…")` en `shell/src/Nimbus/apps/Settings/`, cero definidas en la
  tabla de `shell/src/Nimbus/Translations.qml`; `Translations.lookup()` devuelve la propia clave
  cuando falta (`Translations.qml:257-264`). Lo que se ve es `settings.about.title`, no el texto.
- **Sistema de ficheros por defecto `ext4`.** `installer/calamares/settings.conf:39`
  (`defaultFileSystemType=ext4`); el diseño pide Btrfs como único con rollback.

## Qué puede coger un contribuidor

Tareas concretas y pequeñas. Cada una cabe en un PR y dice el fichero y el primer paso.

1. **Traducir Ajustes (66 claves).** Fichero: `shell/src/Nimbus/Translations.qml`.
   Primer paso: listar las claves con
   `grep -rhoE 'Config\.translated\("settings\.[a-zA-Z0-9_.]+"\)' shell/src | sort -u`
   y añadirlas en ES/EN. Verificación: el runner QML de arriba.
2. **Añadir Calamares al perfil de la ISO.** Fichero: `iso/profiles/nimbus/packages.x86_64`.
   Primer paso: añadir el paquete y extender `tests/test_iso_profile.py`.
   Verificación: `python -m pytest tests/test_iso_profile.py -v`.
3. **Crear las units que `nimbus-postinstall` ya nombra.** Ficheros nuevos junto a
   `installer/tools/nimbus-snapshots`. Primer paso: leer `nimbus-postinstall:273-274` y escribir
   `nimbus-snapshots.timer` (+ `nimbus-auto-update.timer` cuando exista `nimbus-update`).
4. **Añadir el check `secureboot` a `nimbus-verify`.** Fichero: `installer/calamares/`
   (módulo `nimbus-verify`, hoy 14 checks, ninguno de Secure Boot). Estado honesto con MOK
   provisional, no shim completo.
5. **Empaquetar el tema SDDM y fondos propios en la ISO.** La ISO instala los temas `elarun`,
   `maldives` y `maya`, no `installer/greeter/nimbus-greeter/`. Primer paso: comprobar qué temas
   declara `tests/test_greeter_theme.py` y llevar el nuestro al perfil.
6. **Corregir `defaultFileSystemType` a Btrfs.** Fichero: `installer/calamares/settings.conf:39`.
   Pequeño pero con consecuencias: verificar con la suite de Calamares.
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
- Juego real en Steam con Proton-GE + gamescope (sesión "Nimbus Gaming", hoy inexistente: ver
  "Qué NO funciona").

Regla dura del proyecto: las pruebas de hardware se hacen en disco USB externo,
**nunca sobre la instalación CachyOS del fundador**.

## Contradicciones conocidas pendientes (fuera del alcance de esta pista)

Documentadas aquí para que nadie las redescubra; las corrige quien toque esos ficheros:

- `docs/BUILDING.md:27` dice "189 passed" (son 251); `:45` dice "SPDX OK: 34 ficheros" (son 105);
  `:161` sitúa Secure Boot en "M6" (el resto del repo dice M5/v1.0).
- `docs/ROADMAP.md:13` dice "189 pytest" en la fila M2.
- `docs/ARCHITECTURE.md:51` sitúa `nimbus-update` en el "hito M3"; `README.md:30` y el roadmap lo
  sitúan en M5/v1.0.
- `docs/superpowers/plans/2026-10-21-nimbus-roadmap.md:36-37` dice 5 tareas en M3 y M4-beta
  (ambos planes tienen 6: `grep -c '^### Task'`) y declara M0 "En ejecución" con "8 de sus 9
  tareas" cuando el plan tiene 8 tasks y está fusionado.
