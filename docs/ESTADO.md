# Estado del proyecto

Actualizado: **2026-11-07**. Rama nueva: **`plasma-migration`**.
Estable/rollback: `main` (ISO Hyprland `nimbus-2026.10.27`).

## Decisión vigente

NimbusOS 1.0 se basa en **KDE Plasma 6.8 + NimbusShell**. Hyprland/MacShell queda
congelado como perfil `legacy-hypr`. La frontera entre productos está en
[`architecture/PRODUCT-MODEL.md`](architecture/PRODUCT-MODEL.md).

## Qué hay en la línea Plasma

- **Skel**: portado desde NimbusShell (`plasma-skel-sync`, 59 ficheros; 62/62
  1:1 con 9 extras legacy/ISO permitidos).
- **Paquetes:** `packages.nimbus-plasma.append` (127 paquetes, sin Hyprland) y
  `packages.nimbus-plasma-aur.txt` (sin hyprshell/hyprbars).
- **Overlay Plasma:** `nimbus-overlay-plasma/` con SDDM, Calamares
  (`displaymanager: sddm`), tema SDDM Nimbus, `nimbus-bar-start`,
  `nimbus-hide-panel`, unidad/autostart de la barra.
- **Binarios:** NimbusShell compila 9 GUI + KCM con `scripts/build-components`;
  el build los instala en `airootfs` (`/usr/local` y `/usr`).
- **Check estático:** `./build_iso.sh --check-only --profile plasma` →
  **CHECK-ONLY PASS**.
- **Legacy:** `./build_iso.sh --check-only --profile legacy-hypr` →
  **CHECK-ONLY PASS**.

## Huecos (sin adornos)

1. **ISO Plasma real:** no construida en esta máquina (requiere root, archiso y
   red). Es el siguiente paso.
2. **Instalación Calamares E2E Plasma:** pendiente en VM.
3. **Primer arranque SDDM → Plasma → barra/dock/Spotlight:** pendiente.
4. **F12-T01…T06:** tests, rendimiento, ISO final, matriz/tag, firma/legal y
   soak 8 h.
5. **Skel NimbusOS:** la rama `plasma-skel-sync` está publicada; el perfil
   Plasma elimina en build el legado (`hypr`, `macshell`, `quickshell`).

## GitHub

- NimbusShell: `main` Plasma activo, CI verde, 103/112.
- NimbusOS: `main` Hyprland estable; `plasma-migration` es la línea nueva,
  publicada en el PR draft <https://github.com/juanpimg/NimbusOS/pull/1>. No se
  mergea hasta validar la ISO Plasma en VM/hardware.
- ISOs (GBs) no se suben; `iso.manifest` registra SHA y pins.
