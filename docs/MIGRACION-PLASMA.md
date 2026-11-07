# Migración de NimbusOS a Plasma + NimbusShell

> **Decisión (2026-11-07):** NimbusOS 1.0 se basa en **KDE Plasma 6.8 +
> NimbusShell**. Hyprland/MacShell queda como perfil `legacy-hypr` congelado.
> Esta rama (`plasma-migration`) es la línea nueva; `main` no se toca hasta
> validar la ISO Plasma en VM/hardware.

## Estado

| Paso | Estado |
|---|---|
| Skel Plasma portado desde NimbusShell | Hecho en `plasma-skel-sync` (59 ficheros, 9 extras legacy/ISO). |
| `nimbus-skel-sync --check/--apply` | Hecho y probado (13/13). |
| KCM + 9 binarios GUI compilables | Hecho en NimbusShell (`build-components`, 10/10). |
| Paquete del escritorio Plasma | En esta rama: `packages.nimbus-plasma.append`. |
| Overlay Plasma (SDDM, Calamares, barra, tema) | En esta rama: `nimbus-overlay-plasma/`. |
| Perfil `plasma` en `build_iso.sh` | En esta rama; gate `--check-only --profile plasma`. |
| ISO real Plasma en VM | **Pendiente (F12).** |
| Matriz de aceptación + tag | Pendiente tras la ISO. |

## Qué cambia respecto a Hyprland

1. **Escritorio:** Hyprland/Quickshell/MacShell fuera; Plasma 6.8 + NimbusShell.
2. **DM:** greetd/Hyprland fuera; SDDM con tema Nimbus (live e instalado).
3. **Skel:** generado desde `NimbusShell/dotfiles/`; sin `hypr/`, `macshell/`,
   `macdock/`, `quickshell/`.
4. **Paquetes:** `packages.nimbus-plasma.append` (sistema + Plasma) y
   `packages.nimbus-plasma-aur.txt` (sin hyprshell/hyprbars).
5. **Binarios:** `nimbus-bar`, apps y KCM desde NimbusShell con
   `scripts/build-components`; unidades/autostart de la barra desde
   `NimbusShell/iso/profile/`.
6. **Portal:** `xdg-desktop-portal-kde` en vez de `-hyprland`.
7. **Energía:** `power-profiles-daemon` (Plasma) en vez de auto-cpufreq
   enmascarado; thermald/bluetooth se mantienen.
8. **Liquid Glass:** el efecto `kwin-effects-glass` se construye/instala con
   `NimbusShell/scripts/install-glass-nimbus` (pin en `packaging/glass`). La
   ISO Plasma aún no lo empaqueta en el build; es un pendiente de F12-T03.

## Checklist de corte

- [x] Documento de arquitectura y fronteras.
- [x] Skel portado de forma aditiva.
- [x] Paquete Plasma y AUR Plasma.
- [x] Overlay Plasma (SDDM, Calamares, barra, tema).
- [x] `build_iso.sh --profile plasma` + `--check-only`.
- [ ] Empaquetar `kwin-effects-glass` en la ISO (Liquid Glass).
- [ ] Build real de la ISO en host con root.
- [ ] Instalación Calamares E2E en VM.
- [ ] Primer arranque SDDM → Plasma → barra/dock/Spotlight.
- [ ] F12-T01 (tests), T02 (rendimiento), T03 (ISO final), T04 (matriz/tag),
      T05 (firma/legal), T06 (soak 8h).
- [ ] Merge `plasma-migration → main` y pin/tag.

## Cómo validar sin root

```bash
./build_iso.sh --check-only --profile plasma
```

Debe validar: paquetes sin Hyprland, overlay Plasma, SDDM, skel sincronizado,
fuentes de NimbusShell y binarios/unidades necesarios.

## Cómo construir (host con root)

```bash
NIMBUS_SHELL=/ruta/a/NimbusShell ./build_iso.sh --profile plasma
```

El build real sincroniza el skel, compila los 10 componentes de NimbusShell y
empaqueta todo; después se prueba en QEMU con `scripts/test-qemu.sh`.

## Rollback

`main` sigue siendo la ISO Hyprland estable. Si la ISO Plasma falla, no se
mergea: se corrige en `plasma-migration` y se reconstruye. No se borra el
perfil legacy hasta que la ISO Plasma pase F12.
