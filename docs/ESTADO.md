# Estado del proyecto (línea local macshell)

Actualizado: 2026-10-26. Rama de trabajo: `feature/workflow-mac-piel-total`.

## Qué hay

- ISO `nimbus-2026.10.26` en compilación: workflow Mac + piel total + entrada directa.
- ISO `nimbus-2026.10.25` probada en QEMU: arranca (GRUB → autoboot → live).
- Suite verde: macshell 95/0, power 77/0, store 77/0, calamares 83/0 (+1 skip), build 130/0.

## Decisiones vigentes del usuario

- Workflow Mac completo (ventanas centradas, Spaces, Mission Control).
- Piel total automática (arranque, bloqueo, apps, ajustes).
- Entrada directa sin login (rápida para probar).

## Huecos (sin adornos)

1. Instalación Calamares de extremo a extremo en VM: pendiente de probar con la ISO nueva.
2. Menú GRUB dice "CachyOS" (solo texto, no afecta).
3. Batería virtual sin emulación en QEMU 11 (opcional).
4. Semáforos en ventanas SSD no-GTK: limitación V1.
5. Sin pruebas en hardware real (GPU, portátil híbrido, batería).

## Nota sobre GitHub

El repo remoto `juanpimg/NimbusOS` (`main` 73c9972) describe OTRA línea
(nimbus-shell propio, SDDM, gaming, pytest) sin historia común con esta
línea local (macshell + overlay archiso, `git init` local). No se ha tocado
el remoto. Antes de unificar hay que decidir qué línea manda.
