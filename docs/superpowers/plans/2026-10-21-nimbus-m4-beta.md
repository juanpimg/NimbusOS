# Nimbus M4/M5 — Beta pública, Secure Boot e i18n Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerrar el círculo: que Nimbus arranque en un portátil recién comprado **sin tocar la BIOS**, que se pueda traducir a cualquier idioma sin tocar código, que haya una beta pública con proceso real de issues, y que el repo de paquetes esté **alojado y firmado** de forma que la cadena de confianza que se construyó en M0 sirva de algo.

**Architecture:** Secure Boot se resuelve con **shim firmado por Microsoft + UKI firmado por Nimbus + `sbctl`**, lo que permite instalar en un equipo con Secure Boot activo sin que el usuario entre en la BIOS. La i18n pasa de la tabla ES/EN en memoria a **gettext** con catálogos `.po`, manteniendo ES y EN completos desde el primer día. La publicación mueve el repo `nimbus` de un repo local a un repo alojado con firma GPG real, espejos y releases firmadas con checksum.

**Tech Stack:** `shim` + `systemd-boot` (UKI) · `sbctl` · gettext / `msgfmt` · `xgettext` · GitHub Releases + CDN · GPG · CachyOS tooling

**Spec:** [`../specs/2026-10-21-nimbus-design.md`](../specs/2026-10-21-nimbus-design.md) — §3 (requisitos de Secure Boot), §4.10 (repos e infraestructura), §4.11 (estrategia de pruebas), §5 (hitos M5, M6), §4.8 (Store, para las traducciones).

---

## Global Constraints

- **Secure Boot:** requisito de **v1.0**, no bloqueante para las betas. El diseño se hace en M0 y se entrega aquí.
- **Base:** CachyOS x86-64. El usuario final nunca usa AUR.
- **Firma:** toda firma GPG se hace en una clave **offline**; la CI **compila y prueba, pero no firma**. La clave maestra nunca vive en un runner.
- **Idiomas:** ES y EN **completos** en v1.0. La infraestructura de gettext debe existir desde el principio para que la comunidad pueda añadir idiomas sin tocar código.
- **Sin telemetría.**
- **Comunidad desde el día 1:** los repos son públicos, las issues están abiertas, y las decisiones se documentan.
- **Licencias:** todo fichero de código fuente fuera de `third_party/` lleva SPDX `GPL-3.0-or-later`.
- **Compromisos de git:** mensajes en inglés con estilo convencional.

---

## Review Focus

1. **El usuario tiene Secure Boot activo y la ISO no arranca.** Es el fallo que hace abandonar la instalación. → **Task 1**
2. **Microsoft revoca el shim.** Nimbus debe poder seguir arrancando sin depender de Microsoft. → **Task 1**
3. **Un traductor añade un idioma y rompe el shell.** Una cadena que falta debe caer al inglés, nunca a una clave suelta en pantalla. → **Task 2**
4. **El repo alojado no está firmado con la clave de confianza y pacman se niega a instalar.** → **Task 4**
5. **Un tester beta reporta un fallo y nadie sabe qué hardware tenía.** → **Task 3**

---

## Olas de ejecución

```
Ola A (3 en paralelo)   Task 1 (Secure Boot) · Task 2 (i18n) · Task 3 (programa beta)
Ola B (2 en paralelo)   Task 4 (publicación) · Task 5 (endurecimiento v1.0)
```

---

### Task 1: Secure Boot — shim, UKI y `sbctl`

**Files:**
- Create: `iso/secureboot/README.md`
- Create: `iso/secureboot/sign-uki.sh`
- Create: `iso/secureboot/build-shim.sh`
- Create: `iso/secureboot/keys/README.md`
- Create: `tests/test_secureboot.py`
- Modify: `iso/build.sh`
- Modify: `iso/profiles/nimbus/customize.sh`

**Interfaces:**
- Produces:
  - `iso/secureboot/build-shim.sh` — descarga el shim oficial firmado por Microsoft (con su checksum **verificado**) y lo instala en el árbol de Secure Boot.
  - `iso/secureboot/sign-uki.sh` — firma el UKI con la clave de Nimbus usando `sbctl`, y **verifica** que la firma es válida antes de darla por buena.
  - `iso/build.sh` — acepta `--secure-boot <directorio-de-claves>`; cuando se pasa, construye la ISO con Secure Boot habilitado; sin el flag, construye la ISO de la beta con MOCK provisional y **lo dice** en la salida.
  - `iso/secureboot/keys/README.md` — explica que la **clave privada** de Nimbus nunca entra en el repositorio, que solo se guarda cifrada en la máquina offline, y el procedimiento de rotación.

- [ ] **Step 1: Escribe `tests/test_secureboot.py`**
  - `sign-uki.sh` **verifica** la firma tras firmar (no comprueba solo el código de salida de `sbctl`).
  - `sign-uki.sh` **falla** si la clave privada no está disponible, con un mensaje que no revela la ruta de la clave.
  - `build-shim.sh` **verifica el checksum** del shim descargado antes de usarlo, y falla si no coincide.
  - `iso/build.sh` **no** intenta firmar sin clave: en modo beta, la ISO se construye sin Secure Boot y **lo dice**.
  - Ningún fichero del árbol contiene una clave privada: el test comprueba que no hay ficheros con extensión `.key`/`.pem` versionados.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa los scripts y las modificaciones.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite y el SPDX.
- [ ] **Step 6**: Commit — `feat: Secure Boot with signed UKI and sbctl`.

---

### Task 2: i18n con gettext — ES y EN completos

**Files:**
- Create: `shell/po/nimbus.pot`
- Create: `shell/po/es.po`
- Create: `shell/po/en.po`
- Create: `tools/update-translations.sh`
- Create: `tests/test_i18n.py`
- Modify: `shell/src/Nimbus/Translations.qml`
- Modify: `shell/src/Nimbus/Config.qml`

**Interfaces:**
- Produces:
  - `tools/update-translations.sh` — extrae las cadenas con `xgettext`, actualiza `nimbus.pot` y **fusiona** los catálogos existentes sin perder traducciones (`msgmerge`).
  - `shell/po/{nimbus.pot,es.po,en.po}` — catálogos gettext.
  - `Translations.qml` — pasa a **cargar** el catálogo del idioma activo, con la tabla en memoria como **fallback** si el catálogo no se encuentra.
  - `Config.qml` — `setLocale(tag)` valida que el idioma está disponible y, si no, **cae al inglés**.

- [ ] **Step 1: Escribe `tests/test_i18n.py`**
  - `nimbus.pot` existe y contiene las cadenas de la interfaz.
  - `es.po` y `en.po` están **completos**: ninguna entrada queda sin traducir (`msgfmt --check` y el recuento de `msgid` sin `msgstr` es 0).
  - `msgfmt` compila los dos catálogos sin errores.
  - La tabla en memoria de `Translations.qml` sigue existiendo como fallback: si el catálogo del idioma **no se encuentra**, la cadena se devuelve desde la tabla, **nunca** como clave suelta.
  - Un idioma desconocido cae al inglés.
  - `tools/update-translations.sh` es **idempotente**: ejecutarlo dos veces no produce diferencias.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa la extracción, los catálogos y el cambio en `Translations.qml`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite y el SPDX.
- [ ] **Step 6**: Commit — `feat: gettext-based i18n with complete ES and EN catalogues`.

---

### Task 3: Programa beta — proceso real de issues y matriz de hardware

**Files:**
- Create: `docs/BETA.md`
- Create: `docs/issue-template/bug.yml`
- Create: `docs/issue-template/feature.yml`
- Create: `docs/issue-template/config.yml`
- Create: `.github/ISSUE_TEMPLATE/bug.yml`
- Create: `.github/ISSUE_TEMPLATE/feature.yml`
- Create: `tests/test_beta_program.py`

**Interfaces:**
- Produces:
  - `docs/BETA.md` — el programa beta: qué se prueba, qué se considera un fallo bloqueante, cómo se informa, qué hardware hace falta, y qué se espera del tester (y qué del proyecto).
  - `.github/ISSUE_TEMPLATE/bug.yml` — plantilla de fallo que **pide el hardware**: CPU, GPU (y si es híbrida), kernel, si es portátil, y la salida de la verificación. Sin esos campos, un informe de "va lento" no es accionable.
  - `.github/ISSUE_TEMPLATE/feature.yml` — plantilla de propuesta.
  - `docs/issue-template/config.yml` — rutas a las plantillas y a la documentación.
  - `tests/test_beta_program.py` — valida que las plantillas existen, que son YAML válido, y que la de bug pide los campos de hardware.

- [ ] **Step 1: Escribe `tests/test_beta_program.py`**
  - Las tres plantillas existen y son **YAML válido** (se parsean).
  - La plantilla de bug **pide** los campos: CPU, GPU, si el equipo es híbrido, kernel, y si es portátil.
  - `docs/BETA.md` define qué es un fallo **bloqueante** y qué no, y menciona la matriz de hardware del spec.
  - `docs/BETA.md` dice explícitamente que el proyecto **no** manda datos de telemetría, y que el tester puede pedir que su informe se cierre.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa las plantillas y el documento.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite y el SPDX.
- [ ] **Step 6**: Commit — `feat: public beta program with hardware-aware issue templates`.

---

### Task 4: Publicación — repo alojado, espejos y releases firmadas

**Files:**
- Create: `docs/PUBLISHING.md`
- Create: `tools/publish-repo.sh`
- Create: `tools/verify-release.sh`
- Create: `tests/test_publishing.py`

**Interfaces:**
- Produces:
  - `tools/publish-repo.sh --repo <dir> --gpgdir <dir> --key <fpr> --mirrorlist <url>` — publica el contenido de `stable` en el destino final: indexa, **firma**, genera la lista de espejos y escribe el `nimbus.db` firmado. **Reutiliza `tools/promote.sh`** para la parte de indexado y firma, no la duplica.
  - `tools/verify-release.sh --file <fichero> --sig <firma> --keyring <keyring>` — verifica una ISO o un paquete publicado.
  - `docs/PUBLISHING.md` — el procedimiento completo: cómo se firma una release, cómo se verifica, cómo se publica en los espejos, y **qué se hace si la clave se pierde** (el procedimiento de rotación que ya se documentó en `packages/README.md`).

- [ ] **Step 1: Escribe `tests/test_publishing.py`**
  - `publish-repo.sh` produce una DB **firmada** y una lista de espejos.
  - `verify-release.sh` **falla** con una firma manipulada y **pasa** con la firma buena.
  - `publish-repo.sh` **reutiliza** `tools/promote.sh` en vez de reimplementar la indexación y la firma (compruébalo por el texto del script).
  - `docs/PUBLISHING.md` documenta el **procedimiento de pérdida de clave** y dice quién puede ejecutar cada paso.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa los scripts y el documento.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite y el SPDX.
- [ ] **Step 6**: Commit — `feat: publishing tooling with signed releases and mirrors`.

---

### Task 5: Endurecimiento de v1.0

**Files:**
- Create: `docs/RELEASE-CHECKLIST.md`
- Create: `tools/audit-deps.sh`
- Create: `tests/test_release_readiness.py`

**Interfaces:**
- Produces:
  - `docs/RELEASE-CHECKLIST.md` — la lista de verificación de una release v1.0, marcada con lo que hoy **no** está automatizado. Debe cubrir: las 8 condiciones de terminación de M0, las 8 de M1, las 7 de M2, las 8 de M3, el arranque con Secure Boot, la completitud ES/EN, y la ausencia de telemetría.
  - `tools/audit-deps.sh` — comprueba que las dependencias declaradas de los paquetes del repo `nimbus` **existen** en los repos de Arch/CachyOS, y avisa de las que no. Un paquete renombrado en upstream es una instalación rota en la primera actualización.
  - `tests/test_release_readiness.py` — valida que la lista de verificación menciona cada hito y cada condición.

- [ ] **Step 1: Escribe `tests/test_release_readiness.py`**
  - La lista de verificación menciona M0, M1, M2, M3 y Secure Boot.
  - `tools/audit-deps.sh` existe y **falla** con código distinto de 0 si encuentra una dependencia inexistente.
  - `docs/RELEASE-CHECKLIST.md` dice explícitamente qué puntos siguen siendo **manuales**.

- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa la lista y el script.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: Verifica el resto de la suite y el SPDX.
- [ ] **Step 6**: Commit — "feat: release checklist and dependency audit for v1.0".

---

## Criterio de terminación de M4/M5

1. Las 5 tareas están mergeadas y revisadas.
2. `/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v` pasa entero.
3. La ISO arranca en un equipo con **Secure Boot activo**, sin tocar la BIOS.
4. ES y EN están **completos** (0 cadenas sin traducir) y `msgfmt` compila los dos catálogos.
5. Existe un **programa beta público** con plantillas de issue que piden hardware, y un proceso documentado de qué es bloqueante.
6. El repo `nimbus` está **alojado, indexado y firmado** con la clave de confianza, con espejos y una `mirrorlist` que los clientes usan.
7. Una release de ISO se puede **descargar y verificar** con `tools/verify-release.sh`.
8. La lista de verificación de v1.0 está escrita y sus puntos automatizados **pasan**.

Cuando las ocho se cumplan, M4/M5 está cerrado y **v1.0** es alcanzable.
