# Registro de cambios

> **Note for English-speaking contributors:** this changelog is written in Spanish first. An English version will follow.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## [v0.1.0-beta] - 2026-10-22

Primera beta pública: la ISO arranca a sesión live (`out/nimbus-2026.10.22-x86_64.iso`,
publicada en GitHub con su SHA-256). Verificado en este entorno salvo donde se dice
lo contrario (ver `docs/STATUS.md`).

### Añadido

- Escritorio estilo macOS en la sesión live: barra superior con la marca, reloj e
  indicadores; Dock inferior con iconos dibujados; fondo propio; greeter de SDDM con
  el tema de Nimbus y autologin del usuario `nimbus`. Verificado con capturas del
  guest en QEMU.
- Puerta de readiness honesta: `NIMBUS_LIVE_READY` solo se escribe si Hyprland y el
  shell responden.
- Instalador empaquetado (`nimbus-installer`: los seis módulos de Calamares, el tema
  del greeter y la configuración de SDDM) incluido en la ISO.
- `nimbus-update`: CLI (`check`/`apply`/`history`/`rollback`/`auto`) con snapshot antes
  de cada transacción y units de timer. Probado con dobles de prueba.
- Sesión de juegos (`nimbus-gaming-session`) con detección de VRR
  (`gamescope-vrr-check`) y página de Ajustes de energía/juegos que invoca a
  `nimbus-energy` y `nimbus-anonicy` de verdad. Sin verificar en hardware real.
- Ajustes traducido (claves `settings.*` en ES/EN) y puente de procesos del shell
  (`lib/Process.qml`) con `nimbus-shell ipc call` despachando de verdad.
- CI en verde: lint (SPDX, yamllint, shellcheck, actionlint) + 390 tests pytest +
  301 tests QML + 13 tests bats.

### Conocido como pendiente (no verificado en esta beta)

- La instalación no se ha probado de extremo a extremo.
- Nada verificado en hardware real (dGPU, batería, VRR, dual-boot, WiFi por chip).
- Sin repo público de paquetes: un sistema instalado apunta al repo local de bootstrap.
- La Store no instala de verdad (falta `flatpak`/`PackageKit` en la imagen).

## [Sin publicar]

### Añadido

- Monorepo (`tools/`, `packages/`, `shell/`, `dots/`, `iso/`, `installer/`, `tests/`, `docs/`).
- Cadena de confianza con firma offline manual: generación del keyring, firma de la DB y
  promoción `testing` → `stable` con verificación (`tools/genkeyring.sh`, `tools/sign_repo.sh`,
  `tools/promote.sh`, `tools/verify_repo.sh`).
- Paquetes `nimbus-keyring`, `nimbus-shell`, `nimbus-dots`, `nimbus-gaming`, `nimbus-energy`,
  `nimbus-update` y `nimbus-installer`.
- Shell Quickshell/QML (M1): singletons `Theme`, `Config`, `Translations`, `ShellController`,
  `Ipc`, `Services`, `PolkitAgent`; biblioteca, superficies (TopBar, Dock, Spotlight, Centro de
  Control, notificaciones, switcher, capturas, QuickLook, fondos, bloqueo) y aplicaciones
  (Ajustes, Store, tour). 301 tests QML.
- Configuración de Hyprland en Lua (`dots/hypr/hyprland.lua`) con sesión de emergencia.
- Perfil de ISO archiso 91 (`iso/profiles/nimbus/`) con constructor (`iso/build.sh --local-repo`)
  y banco de pruebas rootless (`tools/build-iso-rootless.sh`).
- Instalador Calamares (M2): seis módulos propios, tabla i18n ES/EN, herramientas
  (`nimbus-postinstall`, `nimbus-partitionsafe`, `nimbus-snapshots`) y tema de SDDM.
- Harness de integración en QEMU (`tests/integration/boot_live.sh`, marcador `NIMBUS_LIVE_READY`).
- 390 tests pytest y 13 tests bats.
- Documentación de estado verificable (`docs/STATUS.md`), plantillas de issue/PR y política de
  seguridad (`SECURITY.md`).
- Perfil gameready (M3): metapaquete `nimbus-gaming`, `nimbus-energy`, reglas de ananicy,
  `nimbus-gaming-tune` con presets, sesión de juegos con detección de VRR y página de
  Ajustes de energía/juegos. Sin verificar en hardware real.

### Sin terminar (pendiente, no en esta release)

- Instalación sin probar de extremo a extremo; nada verificado en hardware real;
  repo `nimbus` sin alojar; Store con `install()` simulada; servicios con solo la foto
  inicial (`probeServices()` sin suscripciones en vivo); agente de polkit sin registrar
  en `polkitd`.
  Detalle y evidencia en [docs/STATUS.md](docs/STATUS.md).
