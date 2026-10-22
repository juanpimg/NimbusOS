# Índice de documentación

> **Note for English-speaking contributors:** these docs are written in Spanish first. An English version will follow.

Orden de lectura recomendado. Los enlaces son relativos y funcionan en GitHub.

## Puerta de entrada

1. [README.md](../README.md) — qué es Nimbus, estado honesto del proyecto, estructura del repo e inicio rápido.
2. [CONTINUAR.md](CONTINUAR.md) — **si vas a retomar el proyecto**: dónde está cada cosa, los comandos, las trampas reales y por dónde seguir.
3. [STATUS.md](STATUS.md) — estado verificable: qué funciona, qué no y qué puedes coger.
4. Este índice — mapa de lo que hay y en qué orden leerlo.
5. [CONTRIBUTING.md](../CONTRIBUTING.md) — cómo contribuir, tests, commits, licencias y flujo de PRs.

## Comprender el sistema

5. [ARCHITECTURE.md](ARCHITECTURE.md) — capas, modelo de pins, repo y firma, cadena de confianza, arquitectura del shell (singletons, IPC, superficies) e instalador Calamares (módulos, orden e i18n).
6. [BUILDING.md](BUILDING.md) — guía de construcción: ISO local, QEMU, instalación en VM y resolución de problemas.
7. [ROADMAP.md](ROADMAP.md) — hitos M0…M5, qué entrega cada uno y su criterio de salida.
8. [QUICKSHELL-API.md](QUICKSHELL-API.md) — referencia de la API real de Quickshell 0.3.2 e Hyprland 0.56 verificada contra los paquetes instalados.

## Decisiones

- [DECISIONES.md](DECISIONES.md) — que se decidio, por que y que se rompe si
  la decision fue mala (la parte que no se deduce del codigo).

## Fuente de verdad

9. [superpowers/specs/2026-10-21-nimbus-design.md](superpowers/specs/2026-10-21-nimbus-design.md) — documento de diseño. Si esta documentación y el diseño discrepan, **manda el diseño** y abre un issue.
10. [superpowers/plans/2026-10-21-nimbus-roadmap.md](superpowers/plans/2026-10-21-nimbus-roadmap.md) — índice de planes de implementación.
11. [superpowers/plans/2026-10-21-nimbus-m0-fundamentos.md](superpowers/plans/2026-10-21-nimbus-m0-fundamentos.md) — plan M0. También están escritos los planes M1 (shell), M2 (instalador), M3 (gameready) y M4 (beta). No hay planes M5/M6: la v1.0 se sigue en [ROADMAP.md](ROADMAP.md) (fila M5).

## Referencia operativa

12. [STATUS.md](STATUS.md) — qué funciona, qué no y qué coger, con evidencias.
13. [RELEASE-NOTES.md](RELEASE-NOTES.md) — lo que dice la beta: qué puedes hacer con la ISO, cómo probarla y qué no hace todavía.
14. [../packages/README.md](../packages/README.md) — modelo de pins `testing`/`stable`, contratos de `promote.sh` y `verify_repo.sh`, y rotación de clave.

## Comprobaciones

- `python tools/check_links.py` — **todos los enlaces entre documentos resuelven** y
  ninguna ruta documentada apunta a algo que no exista. Se ejecuta en la CI.
14. [../LICENSES.md](../LICENSES.md) — licencias: GPL-3.0-or-later, sin código de terceros distribuido.
15. [../LICENSE](../LICENSE) — texto completo de la GPL-3.0.
16. [../CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) — Contributor Covenant v2.1.
