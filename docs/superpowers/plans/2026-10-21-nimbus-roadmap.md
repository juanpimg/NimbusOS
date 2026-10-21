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
  Cimientos    ├──► Plan 3 (M2: instalador y greeter)
                └──► Plan 4 (M3: gameready y energía)

Plan 2 (M1)  ──┬──► Plan 3 (M2)
  Shell        └──► Plan 4 (M3)

Plan 3 (M2)  ──────► Plan 5 (M4/M5: beta, Secure Boot, i18n)
Plan 4 (M3)  ──────► Plan 5
```

## Planes

| # | Hito | Plan | Estado |
|---|------|------|--------|
| 1 | M0 — Cimientos | [`2026-10-21-nimbus-m0-fundamentos.md`](2026-10-21-nimbus-m0-fundamentos.md) | **En ejecución** (8 tareas) |
| 2 | M1 — Shell v0 | [`2026-10-21-nimbus-m1-shell.md`](2026-10-21-nimbus-m1-shell.md) | **Escrito** (12 tareas, 3 olas) |
| 3 | M2 — Instalador y greeter | [`2026-10-21-nimbus-m2-instalador.md`](2026-10-21-nimbus-m2-instalador.md) | **Escrito** (5 tareas) |
| 4 | M3 — Gameready y energía | [`2026-10-21-nimbus-m3-gameready.md`](2026-10-21-nimbus-m3-gameready.md) | **Escrito** (5 tareas, 2 olas) |
| 5 | M4/M5/M6 — Beta, Secure Boot, i18n | [`2026-10-21-nimbus-m4-beta.md`](2026-10-21-nimbus-m4-beta.md) | **Escrito** (5 tareas, 2 olas) |

### Remapeo de hitos respecto al spec

El spec define seis hitos (M0…M6). Los planes los agrupan de otra manera porque **el M3 del
spec (Nimbus Store, Ajustes, greeter y tour) se ha absorbido en el Plan 2**, ya que el shell
es su precondición y no tiene sentido construirlos separados:

| Hito del spec | Dónde vive ahora |
|---------------|-------------------|
| M0 Cimientos | Plan 1 |
| M1 Shell v0 | Plan 2 (Task 1 = cimientos del shell; Tasks 2-12 = los 13 módulos) |
| M2 Instalador | Plan 3 (incluye el greeter, que era M3) |
| M3 Tienda, Ajustes, tour | **Plan 2**, Tasks 10, 11 y 12 |
| M4 Gameready y energía | Plan 4 |
| M5 Beta y M6 v1.0 | Plan 5 (Secure Boot, i18n, publicación y lista de verificación) |

## Ejecución en paralelo

Los planes están diseñados para ejecutarse **en paralelo** donde las tareas tocan ficheros
disjuntos. El mecanismo:

1. Cada tarea que puede ir en paralelo se ejecuta en un **worktree git propio**, con su
   rama, a partir del mismo commit base.
2. Cada tarea tiene su propio implementador **y su propio revisor**, y el revisor arranca en
   cuanto el implementador termina — solapándose con las demás tareas, no después.
3. Al terminar la revisión, la rama de la tarea se integra en la rama de integración.
4. La **verificación de integración** (construir la ISO y arrancarla en QEMU) es secuencial y
   se hace una sola vez, con todo integrado. Es la que detecta los fallos que solo aparecen
   al juntar las piezas.

## Estructura del repositorio

Los planes comparten una única estructura. **Arrancamos en monorepo y dividimos en repos
separados cuando haya tracción community** (decisión de bootstrap; ver §3 del spec
"Procedencia del código").

```
Linux-MacOS/
├── docs/superpowers/         specs/ y plans/
├── docs/                     Documentación para la comunidad (arquitectura, build, roadmap)
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
