# Mapa de NimbusOS

| Ruta | Responsabilidad |
|---|---|
| `build_iso.sh` | Build reproducible. Perfiles `plasma` (nuevo) y `legacy-hypr` (estable). |
| `packages.nimbus-plasma.append` | Paquetes del sistema + escritorio Plasma. |
| `packages.nimbus.x86_64.append` | Paquetes del perfil Hyprland (legacy). |
| `packages.nimbus-plasma-aur.txt` | AUR del perfil Plasma (sin hyprshell/hyprbars). |
| `packages.nimbus-aur.txt` | AUR del perfil Hyprland (legacy). |
| `nimbus-overlay-plasma/` | Delta Plasma: SDDM, Calamares, barra, skel, tema. |
| `nimbus-overlay/` | Overlay base (live, Calamares, systemd, theming). |
| `iso.manifest` | Pins de upstream, NimbusShell y AUR. |
| `docs/architecture/` | Este mapa y el modelo de producto. |
| `docs/MIGRACION-PLASMA.md` | Checklist y estado del corte. |
| `scripts/verify-*.sh` | Verificación por área. |

## Frontera

NimbusOS pone la casa; NimbusShell pone el interior. El escritorio se diseña una
vez en NimbusShell y NimbusOS lo importa en el build.
