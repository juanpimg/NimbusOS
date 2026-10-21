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
# 3 passed: cabeceras SPDX, licencia y árbol limpio
# (en este contenedor: /tmp/opencode/nimbus-venv/bin/python -m pytest tests -v)

PATH="$HOME/.local/bin:$PATH" bats tests/*.bats
# 13 passed: keyring, firma, promoción testing -> stable y verificación

QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests
# 17 passed: singletons Theme, Config y Translations (Qt 6.12.0)
```

Y el validador SPDX suelto:

```bash
python tools/check_spdx.py --root .
# SPDX OK: 15 ficheros
# (en este contenedor: /tmp/opencode/nimbus-venv/bin/python tools/check_spdx.py --root .)
```

## Construir la ISO

> **Pendiente en M0 (Tasks 6 y 8).** `iso/build.sh` y `tests/integration/boot_live.sh` no existen aún en esta rama, así que los comandos de abajo **no están verificados**: describen la interfaz que fija el plan M0, no un script que puedas ejecutar hoy.

Cuando existan, el flujo será:

```bash
sudo pacman -S --needed --noconfirm archiso repo
bash iso/build.sh --outdir /tmp/opencode/nimbus-iso --local-repo
bash tests/integration/boot_live.sh --iso /tmp/opencode/nimbus-iso/nimbus-*.iso --timeout 900
```

El flag `--local-repo` existe por el bootstrap: el repo `nimbus` aún no está alojado en ningún servidor, así que `build.sh` compila los PKGBUILDs de `packages/` con `makepkg` en un repo local `file://` y lo inyecta en el `pacman.conf` del perfil. Sin ese flag la construcción falla porque `nimbus-shell` no se puede resolver. Cuando el repo público esté alojado y firmado, el bootstrap dejará de ser necesario.

La ISO es netinstall pura (< 3 GB): lleva lo mínimo para arrancar la sesión live (Hyprland + shell) y descarga el resto durante la instalación, así que construirla y probarla exige red.

Espejos usados durante la construcción:

- Arch (`core`, `extra`): `https://archlinux.cachyos.org/repo/$repo/os/$arch`
- CachyOS v3: `https://cdn77.cachyos.org/repo/$arch_v3/$repo`
- CachyOS genérico: `https://cdn77.cachyos.org/repo/$arch/$repo`

## Probar la sesión live en QEMU

> **Pendiente.** El harness (`tests/integration/boot_live.sh`) no existe aún; lo descrito aquí es el diseño del plan M0.

El harness arranca la ISO en QEMU, captura la consola serie y espera el marcador `NIMBUS_LIVE_READY` que emite el servicio `nimbus-live-ready.service` (solo se ejecuta si el shell arrancó). `--timeout` por defecto: 600 s.

Diferencia `-accel kvm` / `-accel tcg`: con KVM la VM usa virtualización por hardware (rápida); sin `/dev/kvm` QEMU cae a `tcg`, emulación pura por software (lenta: 5–10 minutos solo el arranque). El harness elige solo: `kvm` si `/dev/kvm` existe y es escribible, `tcg` si no. En este equipo `/dev/kvm` **existe** (verificado); en los runners alojados de GitHub **no** existe, así que la CI usará `tcg`.

No toques tu instalación para probar: el desarrollo ocurre en el repo, las pruebas de integración en VM y las de hardware real en disco externo USB, nunca sobre la instalación CachyOS principal.

## Instalar en una VM o en un disco de repuesto

> **Pendiente.** El instalador (Calamares + módulos propios) es hito M2; hoy no hay nada que instalar.

Reglas vigentes desde ya (documento de diseño §4.11): nunca pruebes sobre tu instalación principal; en VM para integración, en USB externo para hardware real (drivers NVIDIA, suspensión, batería). El dual-boot con Windows llevará salvaguardas (copia de la tabla de particiones, aviso de Fast Boot, verificación post-instalación) y se marcará como beta en v1.

## Resolución de problemas

- **`archiso` no instalado.** Verificado: `which archiso` está vacío en este entorno. Síntoma: `iso/build.sh` (cuando exista) falla al invocar `mkarchiso`. Remedio: `sudo pacman -S archiso` en CachyOS. No verificado aquí (requiere root).
- **Sin `/dev/kvm`.** Síntoma: QEMU arranca pero todo va muy lento o el harness agota el timeout. Causa: sin KVM se usa `tcg`. Remedio en local: cargar el módulo KVM y tener permisos sobre `/dev/kvm`; en CI no hay remedio, es el modo esperado. Verificado: `/dev/kvm` existe en este equipo.
- **`makepkg` se niega a correr como root.** Síntoma: `makepkg` aborta con "Running makepkg as root is not allowed". Es comportamiento propio de `makepkg`, no un bug nuestro (el plan M0 lo tiene en cuenta: los tests construyen paquetes de prueba a mano en vez de invocar `makepkg`). Remedio: compilar siempre como usuario normal, nunca con `sudo`. No ejecutado como root en este entorno, por razones obvias.
- **Qt5 frente a Qt6 `qmltestrunner`.** Síntoma: los tests QML fallan con errores de importación o de API. Causa: `/usr/bin/qmltestrunner` es Qt5 (verificado: enlaza `libQt5QuickTest.so.5`); los tests exigen Qt6. Remedio: usar siempre `/usr/lib/qt6/bin/qmltestrunner` (verificado: enlaza `libQt6QuickTest.so.6`).
- **`QML2_IMPORT_PATH` mal apuntado.** Síntoma: `Cannot find module "Nimbus"`. Causa: el `qmldir` vive en `shell/src/Nimbus/`, así que el import path debe ser su padre, `shell/src` (no `shell/src/Nimbus/`). Verificado: con `QML2_IMPORT_PATH="$PWD/shell/src"` los 17 tests pasan.
