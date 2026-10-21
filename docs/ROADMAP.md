# Hoja de ruta: hitos M0…M6

> **Note for English-speaking contributors:** these docs are written in Spanish first. An English version will follow.

Nimbus es un **proyecto comunitario desde el día 1**: repositorios públicos, issues abiertas y decisiones documentadas. No hay nada privado que "se liberará más adelante"; si lees esto, ya estás dentro. Cada hito deja el sistema **usable**, no un esqueleto.

Fuente: documento de diseño §5. Posición actual: **M0, M1 y M2 implementados en el repo** (ver `git log`: andamiaje, keyring, pins, shell completo con TopBar/Dock/Spotlight/Centro de Control/notificaciones/switcher/capturas/QuickLook/fondos/bloqueo/Ajustes/Store/tour, y los seis módulos del instalador con sus herramientas y el tema de SDDM). **En curso:** la integración del M1 en la sesión live (el harness QEMU verifica el arranque por marcador, pero el escritorio en pantalla no se ha visto aún) y la prueba del arranque dual con Windows en disco de prueba. El criterio de salida se verifica con `bash iso/build.sh --outdir … --local-repo` + `bash tests/integration/boot_live.sh --iso …` (requiere CachyOS con root, o el banco rootless; no ejecutado en este entorno, ver [BUILDING.md](BUILDING.md)).

| Hito | Contenido | Criterio de salida | Estado real |
|------|-----------|-------------------|-------------|
| **M0 — Cimientos** | Repos, CI, anillo de keyring, modelo de pins (`testing`/`stable`) con firma offline manual, ISO netinstall mínima con Hyprland | La ISO arranca en VM e instala un Hyprland pelado; el ciclo build → test → promocionar a `stable` funciona de extremo a extremo | Implementado |
| **M1 — Shell v0** | Tokens de diseño, TopBar, Dock, Spotlight, notificaciones, Centro de Control, switcher, capturas, QuickLook, fondos, bloqueo, Ajustes, Store, tour, agente de polkit propio | El shell se ve y se siente coherente; tour manual en VM | Código y tests implementados (249 QML + gates en pytest); el tour manual en VM, **pendiente de verificar** |
| **M2 — Instalador** | Todos los módulos de Calamares (`nimbus-dualboot`, `nimbus-appearance`, `nimbus-software`, `nimbus-bootloader`, `nimbus-postinstall`, `nimbus-verify`), herramientas, arranque dual con GRUB, post-instalación, verificación, tema de SDDM | Instalación completa automatizada en VM, del ISO al escritorio; dual-boot con Windows probado en disco de prueba | Código y tests implementados (189 pytest); instalación en VM y dual-boot en disco real, **pendientes de probar** |
| **M3 — Tienda y greeter** | Nimbus Store, Ajustes del sistema, tema de SDDM, tour | Un usuario puede instalar una app sin tocar nada más que un botón | **Adelantado**: Store, Ajustes, tema de SDDM y tour se implementaron en M1/M2; el criterio (instalar una app con un botón) usa la Store con backend Flatpak y fallback nativo, **pendiente de probar en sesión real** |
| **M4 — Gameready y energía** | Perfil Gaming completo, sesión Nimbus Gaming, gestión de energía, híbrido | Juego real funcionando en el portátil de referencia | **No empezado** (el instalador solo ofrece el perfil de software `gaming`, que es una lista de paquetes, no el perfil) |
| **M5 — Beta pública** | Docs, sitio, proceso de issues, programa beta, primer release | 50+ testers activos, issues triadas, cobertura de la matriz de hardware | **No empezado** |
| **M6 — v1.0** | Estabilidad, accesibilidad, i18n completa ES/EN, Secure Boot con shim firmado, sistema de actualizaciones maduro | Un desconocido instala Nimbus y no necesita leer nada | **No empezado** |

Notas:

- Secure Boot se **diseña** en M0 (toca bootloader e ISO) pero se **entrega** en M6. Las betas usan MOK provisional.
- Cada hito produce software que funciona y se prueba por separado; el índice de planes vive en [superpowers/plans/2026-10-21-nimbus-roadmap.md](superpowers/plans/2026-10-21-nimbus-roadmap.md).
- La beta de M5 es un sistema real de uso diario, con los fallos conocidos publicados.
