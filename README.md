# Nimbus

Arch por debajo, Hyprland en la superficie, la pulido de macOS encima.

> Estado: **M0 — en construcción**.

Nimbus es una distribución Linux estilo macOS basada en CachyOS (Arch).
Este monorepo contiene el shell, los dots, el instalador, la ISO, los paquetes
y las herramientas del proyecto.

## Roadmap

| Hito | Subsistema | Repo futuro |
|------|------------|-------------|
| M0 — Cimientos | Infraestructura, licencias, CI | `nimbus/nimbus-meta` |
| M1 — Shell v0 | Shell de escritorio (QML/Quickshell) | `nimbus/nimbus-shell` |
| M2 — Instalador | Módulos y configuración de Calamares | `nimbus/nimbus-installer` |
| M3 — Tienda y sistema | Tienda, Ajustes, greeter, tour | `nimbus/nimbus-apps` |
| M4 — Gaming y energía | Gameready, perfiles de energía | `nimbus/nimbus-gaming` |
| M5/M6 — Beta y v1.0 | ISO, secure boot, i18n | `nimbus/nimbus-iso` |

Cuando el proyecto tenga tracción community, cada directorio se dividirá en su
propio repositorio siguiendo el mapeo 1:1 documentado en el roadmap.

## Licencia

GPL-3.0-or-later. Ver [`LICENSE`](LICENSE) y [`LICENSES.md`](LICENSES.md).
