# Nimbus — Hoja de ruta de planes

Este documento es el índice de los planes de implementación de Nimbus. **Un plan por
subsistema**, cada uno de los cuales produce software que funciona y se puede probar por
separado.

**Spec:** [`../specs/2026-10-21-nimbus-design.md`](../specs/2026-10-21-nimbus-design.md)

## Por qué varios planes

El spec cubre seis subsistemas independientes (infraestructura, shell, instalador, tienda,
gaming, energía). Un solo plan que los cubriera sería un transcript del proyecto, no un plan.
Cada plan siguiente tiene sus propias dependencias y su propio criterio de terminación.

## Regla de dependencia

```
Plan 1 (M0)  ──┬──► Plan 2 (M1: shell v0)
  Cimientos    ├──► Plan 3 (M2: instalador)
                └──► Plan 4 (M3: tienda, ajustes, greeter, tour)

Plan 2 (M1)  ──┬──► Plan 4 (M3)
  Shell        └──► Plan 5 (M4: gameready + energía)

Plan 3 (M2)  ──┬──► Plan 4 (M3)
  Instalador   └──► Plan 6 (M5/M6: beta, secure boot, i18n)

Plan 4 (M3)  ──────► Plan 6
Plan 5 (M4)  ──────► Plan 6
```

## Planes

| # | Hito | Plan | Estado |
|---|------|------|--------|
| 1 | M0 — Cimientos | [`2026-10-21-nimbus-m0-fundamentos.md`](2026-10-21-nimbus-m0-fundamentos.md) | **Escrito** |
| 2 | M1 — Shell v0 | `2026-10-21-nimbus-m1-shell.md` | Pendiente |
| 3 | M2 — Instalador | `2026-10-21-nimbus-m2-instalador.md` | Pendiente |
| 4 | M3 — Tienda, Ajustes, greeter, tour | `2026-10-21-nimbus-m3-tienda.md` | Pendiente |
| 5 | M4 — Gameready y energía | `2026-10-21-nimbus-m4-gaming.md` | Pendiente |
| 6 | M5/M6 — Beta pública y v1.0 | `2026-10-21-nimbus-m5-beta-v1.md` | Pendiente |

## Estructura del repositorio

Los seis planes comparten una única estructura. **Arrancamos en monorepo y dividimos en
repos separados cuando haya tracción community** (decisión de bootstrap; ver §3 del spec
"Procedencia del código").

```
Linux-MacOS/
├── docs/superpowers/         specs/ y plans/
├── tools/                    Scripting de toolchain (bash + python)
├── packages/                 PKGBUILDs del repo `nimbus`
├── shell/                    Código QML/Quickshell del shell
├── dots/                     Configuración Hyprland y defaults del sistema
├── iso/                      Perfiles archiso y constructor de ISO
├── installer/                Módulos y configuración de Calamares
├── third_party/              Código vendorizado (MIT de MacShell) — con SPDX MIT
└── tests/                    pytest, bats, qmltestrunner, integración QEMU
```

Cuando se divida, el mapeo es 1:1: `shell/` → `nimbus/nimbus-shell`, `dots/` →
`nimbus/nimbus-dots`, `packages/` → `nimbus/nimbus-packages`, `iso/` → `nimbus/nimbus-iso`,
`installer/` → `nimbus/nimbus-installer`.
