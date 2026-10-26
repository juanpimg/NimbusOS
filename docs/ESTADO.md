# Estado del proyecto

Actualizado: 2026-10-26. Rama: `main` (publicado en GitHub `juanpimg/NimbusOS`).

## Qué hay

- ISO `nimbus-2026.10.26` verificada en QEMU: arranca (GRUB → live),
  escritorio con barra+dock, terminal con semáforos nativos, Spotlight,
  Spaces, instalador "Hello".
- Sesión canónica Lua (`hyprland.lua`): todo MacShell funciona al 100%
  (semáforos, switcher); `.conf` queda como fallback.
- Suite verde: macshell 177/0, power 77/0, store 106/0,
  calamares 84/0 (+1 skip), build 130/0.

## Decisiones vigentes del usuario

- Workflow Mac completo, usable por usuarios de Mac y de Windows.
- Semáforos NATIVOS (hyprbars) en vez de overlay; MacShell vendoreado intacto.
- Piel total automática; entrada directa sin login (rápida para probar).

## Huecos (sin adornos)

1. Instalación Calamares de extremo a extremo en VM: pendiente de probar.
2. Menú GRUB dice "CachyOS" (solo texto, no afecta).
3. Batería virtual sin emulación en QEMU 11 (opcional).
4. Reloj del live en inglés (requiere locale + `lang/es.js` upstream).
5. Sin pruebas en hardware real (GPU, portátil híbrido, batería).

## GitHub

`main` local y remoto sincronizados. Las ISOs (GBs) no se suben por diseño;
el manifiesto `iso.manifest` registra SHA de cada build.
