# Construir Nimbus

> **Note for English-speaking contributors:** these docs are written in Spanish first. An English version will follow.

Guía para compilar, probar e instalar Nimbus en local. Cada comando indica si está **verificado** en este entorno o si requiere algo que aquí no hay (CachyOS, root); lo no verificado se dice explícitamente.

## Prerrequisitos

Trabajo verificado sobre CachyOS (Arch) x86-64. Paquetes necesarios:

```bash
sudo pacman -S --needed base-devel archiso quickshell hyprland qt6-declarative \
  qt6-wayland qt6-shadertools repo bats python-pytest lua yamllint actionlint \
  shellcheck qemu-desktop
```

> No verificado en este entorno: requiere CachyOS y root. Aquí se comprobó que `archiso`, `shellcheck`, `yamllint` y `actionlint` **no** están instalados, y que `repo-add`, `makepkg`, `qemu-system-x86_64` (11.1.2), `lua`/`luac`, `gpg` (2.4.9) y `bats` (1.11.0, en `~/.local/bin`) sí lo están.

## Verificar el repo sin construir nada

Tres suites, todas verificadas (salidas resumidas bajo cada comando):

```bash
python -m pytest tests -v
# 53 passed: cabeceras SPDX, config de Hyprland, perfil de la ISO y Calamares
# (en este contenedor: /tmp/opencode/nimbus-venv/bin/python -m pytest tests -v)

PATH="$HOME/.local/bin:$PATH" bats tests/*.bats
# 13 passed: keyring, firma, promoción testing -> stable y verificación

QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests
# 17 passed: singletons Theme, Config y Translations (Qt 6.12.0)
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

> No verificado en este entorno: aquí no hay `mkarchiso` ni root, así que `iso/build.sh` no se ejecutó (pasa `bash -n`). En CI (`iso.yml`, runner con root) sí se ejecuta con esos mismos comandos.

### El flag `--local-repo` y por qué existe

El flag `--local-repo` es una bandera sin argumento: compila los PKGBUILDs de `packages/` con `makepkg` en un repo local `file://` (`iso/work/nimbus-repo`) y reescribe solo la copia staged del `pacman.conf` con la ruta del host. Existe por el bootstrap: el repo `nimbus` aún no está alojado en ningún servidor, así que sin ese flag la construcción falla porque `nimbus-shell` no se puede resolver. Cuando el repo público esté alojado y firmado, el bootstrap dejará de ser necesario.

Detalles que importan:

- El repo local de bootstrap va **sin firmar** (`SigLevel = Optional` con un `TODO(bootstrap)` visible en la sección `[nimbus]` del `pacman.conf` del perfil): es un apaño temporal de construcción, no el modelo de firma del proyecto (ese es offline, ver [../packages/README.md](../packages/README.md)).
- Si `packages/nimbus-keyring/` aún no tiene sus fuentes (se generan fuera del repo con `tools/genkeyring.sh`), `build.sh` usa como apaño temporal las de bootstrap del perfil y las limpia al salir para no dejar rastro en el árbol.
- La ISO es netinstall pura (< 3 GB): construirla y probarla exige red.

### Banco de pruebas rootless y sus límites

`tools/build-iso-rootless.sh --outdir out` (opcional `--keep` para conservar `iso/work`) construye la ISO **sin root**: descarga `archiso`, `squashfs-tools` y `arch-install-scripts` del espejo a un prefijo local, parcha las copias de `pacstrap` (tmpfs en vez de devtmpfs, gid 5 → 0, sin montar `/run` ni `/sys`) y de `makepkg` (permite root solo con `NIMBUS_ALLOW_ROOT=1`), y ejecuta `iso/build.sh --outdir … --local-repo` dentro de `unshare --user --map-root-user …`.

Límites conocidos:

- Necesita red (descarga los paquetes del espejo) y mapeos de uid en `/etc/subuid` y `/etc/subgid` (mapea el uid 1000 interior al usuario de la sesión live; con un solo rango falla el `chown` con "cannot change owner").
- En CI (GitHub Actions, contenedor con root) no hace falta: allí se instala `archiso` con pacman y se construye con normalidad.
- No ejecutado en este entorno (exige red y user namespaces); existe y pasa `bash -n`.

Espejos usados durante la construcción:

- Arch (`core`, `extra`): `https://archlinux.cachyos.org/repo/$repo/os/$arch`
- CachyOS v3: `https://cdn77.cachyos.org/repo/$arch_v3/$repo`
- CachyOS genérico: `https://cdn77.cachyos.org/repo/$arch/$repo`

## Probar la sesión live en QEMU

El harness (`tests/integration/boot_live.sh`, con `tests/integration/lib.sh` y `tests/integration/build_and_boot.sh` para el flujo completo build + boot) arranca la ISO en QEMU, captura la consola serie y espera el marcador `NIMBUS_LIVE_READY` que emite el servicio `nimbus-live-ready.service` (solo se ejecuta si el shell arrancó). `--timeout` por defecto: 600 s (900 s en el flujo de CI).

Diferencia `-accel kvm` / `-accel tcg`: con KVM la VM usa virtualización por hardware (rápida); sin `/dev/kvm` QEMU cae a `tcg`, emulación pura por software (lenta: 5–10 minutos solo el arranque). El harness elige solo: `kvm` si `/dev/kvm` existe y es escribible, `tcg` si no. En este equipo `/dev/kvm` **existe** (verificado); en los runners alojados de GitHub **no** existe, así que la CI usará `tcg`. Además la VM usa `-cpu max`: el modelo por defecto (`qemu64`) no expone AVX2 y los binarios x86-64-v3 abortarían con SIGILL dentro de la VM.

No toques tu instalación para probar: el desarrollo ocurre en el repo, las pruebas de integración en VM y las de hardware real en disco externo USB, nunca sobre la instalación CachyOS principal.

## Instalar en una VM o en un disco de repuesto

El instalador existe como configuración de Calamares más tres módulos propios (`installer/calamares/modules/nimbus-appearance`, `nimbus-software`, `nimbus-verify`, con su secuencia en `installer/calamares/settings.conf`): elige modo y acento, instala por perfiles de software y verifica el sistema instalado. Cubierto por `tests/test_calamares_settings.py` y `tests/test_calamares_behavior.py`.

Lo que sigue sin existir: arranque dual implementado, Secure Boot (llega en M6; las betas usan MOK provisional) y publicación del repo de paquetes.

Reglas vigentes desde ya (documento de diseño §4.11): nunca pruebes sobre tu instalación principal; en VM para integración, en USB externo para hardware real (drivers NVIDIA, suspensión, batería). El dual-boot con Windows llevará salvaguardas (copia de la tabla de particiones, aviso de Fast Boot, verificación post-instalación) y se marcará como beta en v1.

## Resolución de problemas

- **`archiso` no instalado.** Síntoma: `iso/build.sh` falla al invocar `mkarchiso`. Remedio: `sudo pacman -S archiso` en CachyOS. No ejecutado aquí (requiere root; verificado que `mkarchiso` no está en este entorno).
- **`makepkg --packagelist` no construye nada.** Síntoma: el repo local queda vacío y `build.sh` aborta con "no se ha construido ningun paquete". Causa: `--packagelist` solo imprime las rutas que se producirían, no compila. Remedio: `PKGDEST=<dir> makepkg` (es lo que hace `iso/build.sh`). Verificado: `makepkg --help` lo documenta ("Únicamente lista…") y `tests/test_iso_profile.py::test_build_uses_pkgdest_and_not_packagelist` lo cubre.
- **`pacman-key --populate` solo importa exportaciones de clave pública (armored), no keyboxes.** Síntoma: con un keybox responde "no valid OpenPGP data found", la clave entra sin confianza y **todas** las firmas del repo fallan. Remedio: `nimbus.gpg` debe empezar por `-----BEGIN PGP PUBLIC KEY BLOCK-----` (verificado: el del repo es armored). Cubierto por `tests/keyring.bats`: "nimbus.gpg es importable con gpg --import" (`pacman-key --populate` hace exactamente `gpg --import` del fichero) y "el ownertrust y el populate estan bien formados" (nivel 6 + `post_install` con el populate).
- **`repo-add` de pacman 7 exige una extensión de base de datos válida.** Síntoma: la DB queda inutilizable para pacman. Remedio: `repo-add nimbus.db.tar.gz …` más el symlink `nimbus.db -> nimbus.db.tar.gz` (es lo que hacen `iso/build.sh` y `tools/promote.sh`); `nimbus.db` a secas ya no vale. Verificado en código (`iso/build.sh`, `tools/promote.sh`) y cubierto por `tests/test_iso_profile.py::test_build_indexes_repo_with_valid_db_extension`; `repo-add` 7.1.0 presente en este entorno.
- **Sin `/dev/kvm`.** Síntoma: QEMU arranca pero todo va muy lento o el harness agota el timeout. Causa: sin KVM se usa `tcg`. Remedio en local: cargar el módulo KVM y tener permisos sobre `/dev/kvm`; en CI no hay remedio, es el modo esperado. Verificado: `/dev/kvm` existe en este equipo.
- **`makepkg` se niega a correr como root.** Síntoma: `makepkg` aborta con "Running makepkg as root is not allowed". Es comportamiento propio de `makepkg`, no un bug nuestro (el plan M0 lo tiene en cuenta: los tests construyen paquetes de prueba a mano en vez de invocar `makepkg`). Remedio: compilar siempre como usuario normal, nunca con `sudo`. No ejecutado como root en este entorno, por razones obvias.
- **Qt5 frente a Qt6 `qmltestrunner`.** Síntoma: los tests QML fallan con errores de importación o de API. Causa: `/usr/bin/qmltestrunner` es Qt5 (verificado: enlaza `libQt5QuickTest.so.5`); los tests exigen Qt6. Remedio: usar siempre `/usr/lib/qt6/bin/qmltestrunner` (verificado: enlaza `libQt6QuickTest.so.6`).
- **`QML2_IMPORT_PATH` mal apuntado.** Síntoma: `Cannot find module "Nimbus"`. Causa: el `qmldir` vive en `shell/src/Nimbus/`, así que el import path debe ser su padre, `shell/src` (no `shell/src/Nimbus/`). Verificado: con `QML2_IMPORT_PATH="$PWD/shell/src"` los 17 tests pasan.
