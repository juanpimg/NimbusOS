# Construir Nimbus

> **Note for English-speaking contributors:** these docs are written in Spanish first. An English version will follow.

Guía para compilar, probar e instalar Nimbus en local. Cada comando indica si está **verificado** en este entorno o si requiere algo que aquí no hay (CachyOS, root); lo no verificado se dice explícitamente.

## Prerrequisitos

Trabajo verificado sobre CachyOS (Arch) x86-64. Paquetes necesarios:

```bash
sudo pacman -S --needed base-devel archiso quickshell hyprland qt6-declarative \
  qt6-wayland qt6-shadertools repo bats python-pytest lua yamllint actionlint \
  shellcheck qemu-desktop cachyos-calamares-next inter-font
```

> `cachyos-calamares-next` solo hace falta para las tareas del instalador (validar `installer/`); `inter-font` la exige el paquete `nimbus-shell`.

> No verificado en este entorno: requiere CachyOS y root. Aquí se comprobó que `archiso`, `shellcheck`, `yamllint` y `actionlint` **no** están instalados, y que `repo-add`, `makepkg`, `qemu-system-x86_64` (11.1.2), `lua`/`luac`, `gpg` (2.4.9) y `bats` (1.11.0, en `~/.local/bin`) sí lo están.

## Verificar el repo sin construir nada

Tres suites, todas verificadas (salidas resumidas bajo cada comando):

```bash
python -m pytest tests -v
# 189 passed: cabeceras SPDX, config de Hyprland, perfil de la ISO, Calamares
# (settings, comportamiento, arranque dual, bootloader, post-instalación,
# tema del greeter) y punto de entrada del shell
# (en este contenedor: /tmp/opencode/nimbus-venv/bin/python -m pytest tests -v)

PATH="$HOME/.local/bin:$PATH" bats tests/*.bats
# 13 passed: keyring, firma, promoción testing -> stable y verificación

QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests
# 249 passed: singletons (Theme, Config, Translations, ShellController, Ipc,
# Services, PolkitAgent), lib, superficies, Ajustes, Store, tour y fondos
# (Qt 6.12.0)
```

Y el validador SPDX suelto:

```bash
python tools/check_spdx.py --root .
# SPDX OK: 34 ficheros
# (en este contenedor: /tmp/opencode/nimbus-venv/bin/python tools/check_spdx.py --root .)
```

## Construir la ISO

El perfil sigue el formato declarativo de **archiso 91** y vive en `iso/profiles/nimbus/`:

- `profiledef.sh`: metadatos (`nimbus`, etiqueta `NIMBUS_<AAAAMM>`, modos `bios.syslinux` + `uefi.grub`), imagen airootfs en squashfs y parámetros de kernel con consola serie (`console=tty0 console=ttyS0,115200`) para que el harness de QEMU capture el marcador por el log serie.
- `pacman.conf`: repos y niveles de firma que `mkarchiso` usa en el host (vía `-C`) y que quedan en la imagen. Solo repos x86-64 genéricos (nada de `-v3`/`-v4`): la ISO debe arrancar bajo QEMU+TCG, cuya CPU `qemu64` no tiene AVX y moriría con SIGILL ante binarios x86-64-v3.
- `packages.x86_64` y `bootstrap_packages`: netinstall pura (< 3 GB, verificado por test): lo mínimo para arrancar la sesión live (Hyprland + shell); el resto se descarga durante la instalación.
- `airootfs/`: `etc/os-release` de Nimbus, usuario `nimbus`, unidades `nimbus-live.service` (arranca el shell) y `nimbus-live-ready.service` (escribe `NIMBUS_LIVE_READY` en `/dev/console` solo si el shell arrancó), keyring de bootstrap y configs de arranque (`grub/`, `syslinux/`).
- `iso/build.sh`: constructor. Invocación nueva de mkarchiso (`mkarchiso -m iso -o "$OUTDIR" -w "$WORK" "$WORK/profile"`), comprueba que `mkarchiso` y `mksquashfs` existen y falla de forma ruidosa si no se construyó ningún paquete.

```bash
sudo pacman -S --needed --noconfirm archiso repo
bash iso/build.sh --outdir /tmp/opencode/nimbus-iso --local-repo
bash tests/integration/boot_live.sh --iso /tmp/opencode/nimbus-iso/nimbus-*.iso --timeout 900
```

El camino oficial es el de root (los dos primeros comandos): es el que usa el CI
(`iso.yml`, runner con root). El banco rootless existe para máquinas de desarrollo
donde `sudo` pide contraseña.

> No verificado en este entorno: aquí no hay `mkarchiso` ni root, así que `iso/build.sh` no se ejecutó (pasa `bash -n`). En CI (`iso.yml`, runner con root) sí se ejecuta con esos mismos comandos.

### El flag `--local-repo` y por qué existe

El flag `--local-repo` es una bandera sin argumento: compila los PKGBUILDs de `packages/` con `makepkg` en un repo local `file://` (`iso/work/nimbus-repo`) y reescribe solo la copia staged del `pacman.conf` con la ruta del host. Existe por el bootstrap: el repo `nimbus` aún no está alojado en ningún servidor, así que sin ese flag la construcción falla porque `nimbus-shell` no se puede resolver. Cuando el repo público esté alojado y firmado, el bootstrap dejará de ser necesario.

Detalles que importan:

- El repo local de bootstrap va **sin firmar** (`SigLevel = Optional` con un `TODO(bootstrap)` visible en la sección `[nimbus]` del `pacman.conf` del perfil): es un apaño temporal de construcción, no el modelo de firma del proyecto (ese es offline, ver [../packages/README.md](../packages/README.md)).
- Si `packages/nimbus-keyring/` aún no tiene sus fuentes (se generan fuera del repo con `tools/genkeyring.sh`), `build.sh` usa como apaño temporal las de bootstrap del perfil y las limpia al salir para no dejar rastro en el árbol.
- La ISO es netinstall pura (< 3 GB): construirla y probarla exige red.

### Banco de pruebas rootless y sus límites

El banco rootless construye la ISO **sin root** para máquinas de desarrollo donde
`sudo` pide contraseña:

```bash
bash tools/build-iso-rootless.sh --outdir <dir>
```

`--keep` conserva `iso/work` para inspeccionar el fallo; sin ese flag se limpia
al terminar. El script descarga `archiso`, `squashfs-tools` y
`arch-install-scripts` del espejo a un prefijo local (`$NIMBUS_ROOTLESS_PREFIX`,
por defecto bajo `$TMPDIR`), parcha las copias locales y ejecuta
`iso/build.sh --outdir … --local-repo` dentro de
`unshare --user --map-root-user …`.

Por qué hace falta parchear: un user namespace no puede montar `devtmpfs` ni
`sysfs`, no puede hacer `chown` a uids sin mapear, y `gpg-agent` necesita un
runtime dir propio (sin él, `pacman-key --populate` falla con
"keyring is not writable" y aborta la transacción). El harness lo resuelve
parcheando copias locales de `pacstrap` (tmpfs en vez de devtmpfs con bind de
los nodos de `/dev`, gid 5 → 0, `/run` como tmpfs con stub de DNS propio,
`/sys` como `true`, y enlaces de `/dev/stdin` para los hooks de alpm) y de
`makepkg` (permite root solo con `NIMBUS_ALLOW_ROOT=1`), además de tolerar en
la copia local de `mkarchiso` el `chown` al usuario live cuando el namespace no
mapea su uid. **Nunca modifica el sistema**: todo ocurre en el prefijo local.

Límites conocidos:

- Necesita red (descarga los paquetes del espejo) y mapeos de uid en
  `/etc/subuid` y `/etc/subgid`. Con doble rango (uid 0 interior mapeado al
  usuario real y uid 1000 interior al rango de `subuid`) el `chown` al usuario
  live funciona y la imagen es idéntica a la de CI; con un solo rango el
  parche deja un home temporal que basta para desarrollo. Sin mapeo completo,
  el fallo típico es `chown` con "cannot change owner" o "Invalid argument"
  en los hooks de `systemd-sysusers`/`systemd-tmpfiles`.
- En CI (GitHub Actions, contenedor con root) no hace falta: allí se instala
  `archiso` con pacman y se construye con normalidad.
- No ejecutado en este entorno (exige red y user namespaces); existe y pasa `bash -n`.

Dos detalles del harness que han roto builds reales:

- **Cerrojo `flock`.** Síntoma: dos builds sobre la misma caché de paquetes se
  pisan (uno renombra el `.part` que el otro va a renombrar) y el build aborta
  con "could not rename ...: No such file or directory". El script serializa
  con `flock` sobre `$PREFIX/build.lock` los builds que compartan prefijo; si
  ya hay otro en marcha, aborta con "ya hay otro build en marcha con este
  prefijo". Si te pasa esto, espera a que termine el otro o usa otro
  `$NIMBUS_ROOTLESS_PREFIX`.
- **Marcador de versión del parche: `NIMBUS_ROOTLESS_PATCH_V4`.** Síntoma: tras
  cambiar el parcheo, el build falla por causas ya resueltas. Causa: el
  harness se salta el parcheo si el marcador ya está en el fichero; si se
  cambia el parche sin subir el número, cree que ya está parcheado y aplica
  solo las correcciones viejas. Regla: si se toca `patch_pacstrap`, **hay que
  subir el número** del marcador (`V4` → `V5`, …). El marcador va detrás del
  shebang: delante lo rompería y `env` recaería a `/bin/sh`.

Espejos usados durante la construcción (los mismos que el perfil en `../iso/profiles/nimbus/pacman.conf`):

- Arch (`core`, `extra`): `https://mirror.rackspace.com/archlinux/$repo/os/$arch` y `https://mirror.leaseweb.com/archlinux/$repo/os/$arch`.
- CachyOS: `https://mirror.bali0531.hu/repo/$arch/$repo` (primero: el único verificado con el `glibc` nuevo) y `https://cdn77.cachyos.org/repo/$arch/$repo` (segundo).

No usar `https://archlinux.cachyos.org/repo/$repo/os/$arch`: sirve un borde desfasado que devolvió 404 para `glibc` recién sincronizado y abortó la construcción de la ISO entera.

Sobre `cachyos-v3`: la ISO en vivo usa siempre los repos genéricos, porque tiene que arrancar en hardware desconocido y la CPU por defecto de QEMU (`qemu64`) no tiene AVX2: un binario v3 abortaría con SIGILL. La elección de `cachyos-v3` la hace el instalador sobre el hardware real de destino.

## Probar la sesión live en QEMU

El harness (`tests/integration/boot_live.sh`, con `tests/integration/lib.sh` y `tests/integration/build_and_boot.sh` para el flujo completo build + boot) arranca la ISO en QEMU, captura la consola serie y espera el marcador `NIMBUS_LIVE_READY` que emite el servicio `nimbus-live-ready.service` (solo se ejecuta si el shell arrancó). `--timeout` por defecto: 600 s (900 s en el flujo de CI).

Diferencia `-accel kvm` / `-accel tcg`: con KVM la VM usa virtualización por hardware (rápida); sin `/dev/kvm` QEMU cae a `tcg`, emulación pura por software (lenta: 5–10 minutos solo el arranque). El harness elige solo: `kvm` si `/dev/kvm` existe y es escribible, `tcg` si no. En este equipo `/dev/kvm` **existe** (verificado); en los runners alojados de GitHub **no** existe, así que la CI usará `tcg`. Además la VM usa `-cpu max`: el modelo por defecto (`qemu64`) no expone AVX2 y los binarios x86-64-v3 abortarían con SIGILL dentro de la VM.

Nota honesta: el harness verifica que la sesión live arranca (marcador `NIMBUS_LIVE_READY`, que solo se escribe cuando Hyprland y el shell responden de verdad). El escritorio de verdad —las superficies del M1 en pantalla— solo se verá cuando la integración del M1 termine; no hay capturas porque nadie lo ha visto aún.

No toques tu instalación para probar: el desarrollo ocurre en el repo, las pruebas de integración en VM y las de hardware real en disco externo USB, nunca sobre la instalación CachyOS principal.

## Instalar en una VM o en un disco de repuesto

El instalador existe como configuración de Calamares más seis módulos propios (`installer/calamares/modules/`: `nimbus-dualboot`, `nimbus-appearance`, `nimbus-software`, `nimbus-bootloader`, `nimbus-postinstall`, `nimbus-verify`, con su secuencia en `installer/calamares/settings.conf` y su tabla i18n ES/EN en `installer/calamares/nimbus_i18n.py`), herramientas (`installer/tools/`: `nimbus-postinstall`, `nimbus-partitionsafe`, `nimbus-snapshots`) y tema de SDDM (`installer/greeter/nimbus-greeter/`). Cubierto por `tests/test_calamares_settings.py`, `tests/test_calamares_behavior.py`, `tests/test_dualboot_safety.py`, `tests/test_bootloader_rollback.py`, `tests/test_postinstall.py` y `tests/test_greeter_theme.py`. El orden de los módulos y por qué importa se explica en [ARCHITECTURE.md](ARCHITECTURE.md) (§ "Instalador Calamares").

Lo que sigue sin existir: el perfil gameready completo (el instalador ya ofrece el perfil de software `gaming`, pero la sesión gaming con VRR/HDR, energía e híbridos es M3), Secure Boot (llega en M6; las betas usan MOK provisional) y la publicación del repo de paquetes.

Reglas vigentes desde ya (documento de diseño §4.11): nunca pruebes sobre tu instalación principal; en VM para integración, en USB externo para hardware real (drivers NVIDIA, suspensión, batería). El dual-boot con Windows llevará salvaguardas (copia de la tabla de particiones, aviso de Fast Boot, verificación post-instalación) y se marcará como beta en v1.

## Resolución de problemas

- **`archiso` no instalado.** Síntoma: `iso/build.sh` falla al invocar `mkarchiso`. Remedio: `sudo pacman -S archiso` en CachyOS. No ejecutado aquí (requiere root; verificado que `mkarchiso` no está en este entorno).
- **`makepkg --packagelist` no construye nada.** Síntoma: el repo local queda vacío y `build.sh` aborta con "no se ha construido ningun paquete". Causa: `--packagelist` solo imprime las rutas que se producirían, no compila. Remedio: `PKGDEST=<dir> makepkg` (es lo que hace `iso/build.sh`). Verificado: `makepkg --help` lo documenta ("Únicamente lista…") y `tests/test_iso_profile.py::test_build_uses_pkgdest_and_not_packagelist` lo cubre.
- **`pacman-key --populate` solo importa exportaciones de clave pública (armored), no keyboxes.** Síntoma: con un keybox responde "no valid OpenPGP data found", la clave entra sin confianza y **todas** las firmas del repo fallan. Remedio: `nimbus.gpg` debe empezar por `-----BEGIN PGP PUBLIC KEY BLOCK-----` (verificado: el del repo es armored). Cubierto por `tests/keyring.bats`: "nimbus.gpg es importable con gpg --import" (`pacman-key --populate` hace exactamente `gpg --import` del fichero) y "el ownertrust y el populate estan bien formados" (nivel 6 + `post_install` con el populate).
- **`repo-add` de pacman 7 exige una extensión de base de datos válida.** Síntoma: la DB queda inutilizable para pacman. Remedio: `repo-add nimbus.db.tar.gz …` más el symlink `nimbus.db -> nimbus.db.tar.gz` (es lo que hacen `iso/build.sh` y `tools/promote.sh`); `nimbus.db` a secas ya no vale. Verificado en código (`iso/build.sh`, `tools/promote.sh`) y cubierto por `tests/test_iso_profile.py::test_build_indexes_repo_with_valid_db_extension`; `repo-add` 7.1.0 presente en este entorno.
- **Sin `/dev/kvm`.** Síntoma: QEMU arranca pero todo va muy lento o el harness agota el timeout. Causa: sin KVM se usa `tcg`. Remedio en local: cargar el módulo KVM y tener permisos sobre `/dev/kvm`; en CI no hay remedio, es el modo esperado. Verificado: `/dev/kvm` existe en este equipo.
- **`makepkg` se niega a correr como root.** Síntoma: `makepkg` aborta con "Running makepkg as root is not allowed". Es comportamiento propio de `makepkg`, no un bug nuestro (el plan M0 lo tiene en cuenta: los tests construyen paquetes de prueba a mano en vez de invocar `makepkg`). Remedio: compilar siempre como usuario normal, nunca con `sudo`. No ejecutado como root en este entorno, por razones obvias.
- **`SigLevel = Required` es demasiado estricto para un keyring recién poblado.** Síntoma: **toda** firma de paquete sale como "signature is invalid" y la transacción se aborta, aunque las claves sean las correctas. Causa: `Required` = `PackageRequired` + `PackageTrustedOnly`, y `PackageTrustedOnly` exige confianza *ultimate* del empaquetador. Un keyring recién poblado no la alcanza: las firmas cruzadas de las claves maestras de Arch son SHA-1, que gpg 2.4+ rechaza, así que la validez se queda en torno al 78 %. Remedio: `SigLevel = PackageRequired DatabaseOptional`, que sigue exigiendo una firma **válida** (clave válida, no revocada ni caducada; un paquete manipulado sigue rechazándose) y es lo que usa el perfil de la ISO (`iso/profiles/nimbus/pacman.conf` y la copia de la sesión live, con el porqué en sus comentarios). El sistema instalado recupera el nivel estricto con `pacman-key --refresh-keys` en el post-instalación.
- **Un `.conf` suelto junto a `hyprland.lua` no se carga nunca.** Síntoma: añades `dots/hypr/quirks.conf` (layout, window rules) y Hyprland lo ignora en silencio: el layout no cambia y las reglas no se aplican. Causa: en modo Lua los ficheros solo se cargan con `require()`; un `.conf` acompañante es un fichero muerto. Remedio: todo va **dentro** de `hyprland.lua` con la API nativa (`hl.config(...)` para el layout flotante, `hl.window_rule(...)` para la regla de emergencia). Cubierto por `tests/test_hyprland_config.py::test_quirks_conf_is_gone`, `test_no_classic_window_rules_in_repo` y `test_layout_is_floating`: el repo no contiene ningún `quirks.conf` ni `windowrule =` clásico.
- **La API real de Hyprland 0.56 no es la de los `.conf`.** Síntoma: la config no carga o un bind no hace nada, sin error claro. Causa: los nombres clásicos no existen en modo Lua. Lo que usa el repo (verificado en `dots/hypr/hyprland.lua`, fijado por `tests/test_hyprland_config.py`): `hl.bind` toma dos argumentos, el primero un único string combinado (`"SUPER + SHIFT + E"`); los dispatchers son `hl.dsp.exec_cmd(...)`, `hl.dsp.window.close()`, `hl.dsp.focus({ workspace = N })` (con **número**, no string) y `hl.dsp.send_shortcut({ mods = ..., key = ... })`. No existen `hl.dsp.closewindow`, `hl.dsp.copy`, `hl.dsp.paste` ni `hl.dsp.workspace(N)`. La sesión de emergencia usa el dispatcher directo como el resto de binds: envolverla en una llamada intermedia rompe la carga de toda la config.
- **La API real de Quickshell: `ShellRoot`, no `Item`.** Síntoma: `qs -c` muere al instante y no hay proceso de shell. Causa: la raíz de una config no es un `Item` de QtQuick. Lo que usa el repo (verificado en `shell/src/shell.qml`, fijado por `tests/test_shell_entrypoint.py`): la raíz es **`ShellRoot`** (módulo `Quickshell`); las superficies son **`PanelWindow`/`FloatingWindow`/`PopupWindow`** (módulo `Quickshell.Wayland`, no `Window` de QtQuick ni `Loader` cargando otro fichero); y los servicios disponibles están en **`Quickshell.Services`**: `Greetd`, `Mpris`, `Notifications`, `Pam`, `Pipewire`, `Polkit`, `SystemTray`, `UPower` (verificado leyendo los `.qmltypes` del paquete quickshell 0.3.2 durante M0). Si `shell.qml` falta o su raíz no es un tipo de Quickshell, no hay shell.
- **Qt5 frente a Qt6 `qmltestrunner`.** Síntoma: con `/usr/bin/qmltestrunner` la suite termina sin salida (muere en silencio) o falla con errores de importación o de API. Causa: `/usr/bin/qmltestrunner` es Qt5 (verificado: enlaza `libQt5QuickTest.so.5`); los tests exigen Qt6. Remedio: usar siempre `/usr/lib/qt6/bin/qmltestrunner` (verificado: enlaza `libQt6QuickTest.so.6`) con `QT_QPA_PLATFORM=offscreen` para correr sin sesión gráfica.
- **`QML2_IMPORT_PATH` mal apuntado y `qmldir` en el sitio equivocado.** Síntoma: `module "Nimbus" is not installed` o `Cannot find module "Nimbus"`. Causa: QML resuelve un módulo buscando un *directorio* con ese nombre en el `QML2_IMPORT_PATH`; con un `qmldir` plano en `shell/src/` el import no resuelve. Remedio: el `qmldir` va en `shell/src/Nimbus/`, y el import path debe ser su padre, `shell/src` (no `shell/src/Nimbus/`). Verificado: con `QML2_IMPORT_PATH="$PWD/shell/src"` los 17 tests pasan. Fijado por `tests/test_shell_entrypoint.py::test_qmldir_registers_the_three_singletons` y `test_launcher_import_path_contains_nimbus_module`.
- **El test de SPDX no debe reimplementar el recorrido del checker.** Síntoma: el test pasa en verde pero comprueba otra cosa que la herramienta (por ejemplo, no sabe qué directorios ignora) y se desincroniza de ella. Causa: el test tiene su propia copia de la lógica de recorrido. Remedio: el test **usa** la herramienta (`tests/test_spdx_headers.py` invoca `tools/check_spdx.py` por subprocess en vez de duplicar su recorrido) y además comprueba que la herramienta **falla** cuando falta una cabecera (`test_check_spdx_detects_a_missing_header`): un chequeo que siempre pasa no comprueba nada.
