# Estado del proyecto

Actualizado: 2026-10-27 mañana. Rama: `main` (publicado en GitHub `juanpimg/NimbusOS`).

## Qué hay

- ISO FINAL `nimbus-2026.10.27` (build 05:47) verificada en QEMU con capturas:
  fondo Sequoia, barra translúcida, dock, terminal con semáforos nativos
  en titlebar hyprbars, menú kitty, hostname `nimbus`.
- Sesión canónica Lua (`hyprland.lua`): todo MacShell funciona al 100%
  (switcher unificado, Spotlight, Launchpad `Super+A`); `.conf` queda como fallback.
- Suite verde: macshell 220/0, power 77/0, store 113/0, p1 56/0,
  calamares 115/0, build 134/0.

## Decisiones vigentes del usuario

- Workflow Mac completo, usable por usuarios de Mac y de Windows.
- Semáforos NATIVOS (hyprbars) en vez de overlay; MacShell vendoreado intacto.
- Piel total automática; entrada directa sin login (rápida para probar).

## Huecos (sin adornos)

1. Instalación Calamares E2E pendiente: bloqueada hasta que CachyOS reconstruya
   calamares contra boost 1.92 (nuestro fix symlink probado incompatible en VM).
   Instalador abre pero falla al cargar; el build lo recogerá solo.
2. Menú GRUB dice "CachyOS" (solo texto, no afecta).
3. Batería virtual sin emulación en QEMU 11 (opcional).
4. Reloj del live en inglés (requiere locale + `lang/es.js` upstream).
5. Sin pruebas en hardware real (GPU, portátil híbrido, batería).

## GitHub

`main` local y remoto sincronizados. Las ISOs (GBs) no se suben por diseño;
el manifiesto `iso.manifest` registra SHA de cada build.
