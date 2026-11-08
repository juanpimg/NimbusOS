# Modelo de producto — NimbusOS y NimbusShell

> Espejo del documento canónico de NimbusShell
> (`NimbusShell/docs/architecture/PRODUCT-MODEL.md`). Si hay conflicto, manda
> el de NimbusShell para el escritorio y este para el sistema/ISO.

## Dos productos, una dirección

```
CachyOS (base)
  └── NimbusOS (ISO instalable + sistema)
        └── NimbusShell (escritorio Plasma + apps + tema + ajustes)
```

- **NimbusOS** es el sistema instalable: ISO, Calamares, arranque, paquetes del
  sistema, usuarios, servicios, drivers y actualizaciones. Entrega: **ISO**.
- **NimbusShell** es la capa de escritorio: Plasma 6.8, tema Tahoe, barra, Dock,
  Spotlight, Mission Control, KCM, apps, scripts, dotfiles canónicos y tests.
  Entrega: **commit/tag** (+ `install.sh` para cualquier Arch).
- **Dirección única:** NimbusShell → NimbusOS. NimbusOS importa; no copia a mano.

## Fuente de verdad

| Área | Vive en | NimbusOS la consume así |
|---|---|---|
| Dotfiles del escritorio | `NimbusShell/dotfiles/` | Skel del build (`nimbus-skel-sync`) |
| Paquetes del escritorio | `NimbusShell/packages/plasma.list` | `packages.nimbus-plasma.append` |
| Tema Tahoe | `NimbusShell/packages/themes/` | Overlay Plasma + build |
| Barra, apps y KCM | `NimbusShell/packages/shell/`, `apps/`, `packages/kcm/` | `scripts/build-components` |
| Sistema, ISO, arranque, drivers | `NimbusOS/` | Solo NimbusOS |

## Flujo de release

1. NimbusShell CI verde y tag `vX.Y.Z`.
2. NimbusOS fija `NIMBUS_SHELL_COMMIT`/`NIMBUS_SHELL_TAG` en `iso.manifest`.
3. Build Plasma sincroniza skel, paquetes, tema y binarios desde ese commit.
4. ISO validada en VM/hardware (F12).
5. Tag de NimbusOS `vX.Y.Z` solo con la matriz de aceptación verde.

## Estado actual (2026-11-07)

- `main`: ISO Hyprland estable (congelada temporalmente).
- `plasma-migration`: línea nueva Plasma + NimbusShell. `--check-only --profile
  plasma` es el gate estático; la ISO real y F12 siguen pendientes.
- `plasma-skel-sync`: port aditivo del skel (59 ficheros).
- NimbusShell: Plasma activo, 103/112, CI verde.

## Regla de oro

Si afecta al escritorio, se implementa en NimbusShell y se importa. Si afecta a
cómo se instala o arranca el sistema, se implementa en NimbusOS.
