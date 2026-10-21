# Hoja de ruta: hitos M0…M6

> **Note for English-speaking contributors:** these docs are written in Spanish first. An English version will follow.

Nimbus es un **proyecto comunitario desde el día 1**: repositorios públicos, issues abiertas y decisiones documentadas. No hay nada privado que "se liberará más adelante"; si lees esto, ya estás dentro. Cada hito deja el sistema **usable**, no un esqueleto.

Fuente: documento de diseño §5. Posición actual: **M0 en curso** (Tasks 1–4 hechas: licencias, keyring, pins, tokens del shell; Tasks 5–8 pendientes: Hyprland, ISO, Calamares, harness QEMU).

| Hito | Contenido | Criterio de salida |
|------|-----------|-------------------|
| **M0 — Cimientos** | Repos, CI, anillo de keyring, modelo de pins (`testing`/`stable`) con firma offline manual, ISO netinstall mínima con Hyprland | La ISO arranca en VM e instala un Hyprland pelado; el ciclo build → test → promocionar a `stable` funciona de extremo a extremo |
| **M1 — Shell v0** | Tokens de diseño, TopBar, Dock, notificaciones, Centro de Control, agente de polkit propio | El shell se ve y se siente coherente; tour manual en VM |
| **M2 — Instalador** | Todos los módulos de Calamares, arranque dual con GRUB, post-instalación, verificación | Instalación completa automatizada en VM, del ISO al escritorio; dual-boot con Windows probado en disco de prueba |
| **M3 — Tienda y greeter** | Nimbus Store, Ajustes del sistema, tema de SDDM, tour | Un usuario puede instalar una app sin tocar nada más que un botón |
| **M4 — Gameready y energía** | Perfil Gaming completo, sesión Nimbus Gaming, gestión de energía, híbrido | Juego real funcionando en el portátil de referencia |
| **M5 — Beta pública** | Docs, sitio, proceso de issues, programa beta, primer release | 50+ testers activos, issues triadas, cobertura de la matriz de hardware |
| **M6 — v1.0** | Estabilidad, accesibilidad, i18n completa ES/EN, Secure Boot con shim firmado, sistema de actualizaciones maduro | Un desconocido instala Nimbus y no necesita leer nada |

Notas:

- Secure Boot se **diseña** en M0 (toca bootloader e ISO) pero se **entrega** en M6. Las betas usan MOK provisional.
- Cada hito produce software que funciona y se prueba por separado; el índice de planes vive en [superpowers/plans/2026-10-21-nimbus-roadmap.md](superpowers/plans/2026-10-21-nimbus-roadmap.md).
- La beta de M5 es un sistema real de uso diario, con los fallos conocidos publicados.
