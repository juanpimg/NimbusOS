# Registro de cambios

> **Note for English-speaking contributors:** this changelog is written in Spanish first. An English version will follow.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
No hay releases versionadas todavía: todo lo no publicado va en `[Sin publicar]`.
Esta entrada describe **lo que hay**, no lo que habrá.

## [Sin publicar]

### Añadido

- Monorepo (`tools/`, `packages/`, `shell/`, `dots/`, `iso/`, `installer/`, `tests/`, `docs/`).
- Cadena de confianza con firma offline manual: generación del keyring, firma de la DB y
  promoción `testing` → `stable` con verificación (`tools/genkeyring.sh`, `tools/sign_repo.sh`,
  `tools/promote.sh`, `tools/verify_repo.sh`).
- Paquetes `nimbus-keyring`, `nimbus-shell`, `nimbus-dots`, `nimbus-gaming` y `nimbus-energy`.
- Shell Quickshell/QML (M1): singletons `Theme`, `Config`, `Translations`, `ShellController`,
  `Ipc`, `Services`, `PolkitAgent`; biblioteca, superficies (TopBar, Dock, Spotlight, Centro de
  Control, notificaciones, switcher, capturas, QuickLook, fondos, bloqueo) y aplicaciones
  (Ajustes, Store, tour). 249 tests QML.
- Configuración de Hyprland en Lua (`dots/hypr/hyprland.lua`) con sesión de emergencia.
- Perfil de ISO archiso 91 (`iso/profiles/nimbus/`) con constructor (`iso/build.sh --local-repo`)
  y banco de pruebas rootless (`tools/build-iso-rootless.sh`).
- Instalador Calamares (M2): seis módulos propios, tabla i18n ES/EN, herramientas
  (`nimbus-postinstall`, `nimbus-partitionsafe`, `nimbus-snapshots`) y tema de SDDM.
- Harness de integración en QEMU (`tests/integration/boot_live.sh`, marcador `NIMBUS_LIVE_READY`).
- 251 tests pytest y 13 tests bats.
- Documentación de estado verificable (`docs/STATUS.md`), plantillas de issue/PR y política de
  seguridad (`SECURITY.md`).
- Perfil gameready parcial (M3): metapaquete `nimbus-gaming`, `nimbus-energy`, reglas de ananicy
  y `nimbus-gaming-tune` con presets. Sin sesión de gaming ni pantalla de Ajustes.

### Sin terminar (pendiente, no en esta release)

- El instalador no está en la ISO; el shell no ejecuta procesos; `nimbus-shell ipc call` sin
  subcomando propio; servicios y polkit a `false`; Store con catálogo simulado; sin
  `nimbus-update`, sin units de timers, sin snapshots operativos; repo `nimbus` sin alojar
  (`mirror.nimbus.org` sin publicar); Ajustes con claves `settings.*` sin traducir.
  Detalle y evidencia en [docs/STATUS.md](docs/STATUS.md).
