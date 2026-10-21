# Nimbus M4/M5 — Beta pública, Secure Boot e i18n Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir Nimbus en un sistema que una persona desconocida puede instalar y usar sin leer nada: la clave de firma bootstrap rotada por una clave custodiada de verdad, el repo `nimbus` alojado y firmado con espejos, arranque con Secure Boot activo sin tocar la BIOS, ES y EN completos sobre infraestructura gettext que permite añadir idiomas sin tocar código, y un programa beta público con proceso real de issues que cubre la matriz de hardware del spec.

**Architecture:** La cadena de confianza construida en M0 (keyring GPG, firma offline, promoción `testing` → `stable`) se vuelve real: la clave bootstrap se rota siguiendo el procedimiento de 6 pasos ya escrito en `packages/README.md`, y el repo `stable` se sirve desde GitHub (Releases + CDN) con la DB firmada. Secure Boot se resuelve con **shim firmado por Microsoft + UKI firmado por Nimbus + `sbctl`**, con la clave de Nimbus revocable y rotable sin depender de Microsoft. La i18n pasa de las dos tablas ES/EN en memoria (`shell/src/Nimbus/Translations.qml`, `installer/calamares/nimbus_i18n.py`) a **catálogos gettext compilados en el build**, manteniendo las tablas como fallback para que una traducción ausente nunca rompa el shell.

**Tech Stack:** CachyOS x86-64 (Arch-based) · archiso 91 · Hyprland 0.56.2 · Quickshell 0.3.2 · Qt 6.12 · QML · Calamares 3.4.2 (`cachyos-calamares-next`) · Python 3.14 + pytest 9.1 · bats 1.14 · QEMU/KVM · GitHub Actions · `shim` + UKI + `sbctl` · gettext (`xgettext`, `msgfmt`, `msgmerge`) · GitHub Releases + CDN · GPG

**Spec:** [`../specs/2026-10-21-nimbus-design.md`](../specs/2026-10-21-nimbus-design.md) — §3 (decisiones y requisitos de Secure Boot), §4.10 (repos e infraestructura), §4.11 (estrategia de pruebas), §5 (hitos M5 y M6), §4.13 (hardware soportado) y §9 (definición de terminado).

---

## Global Constraints

Valores exactos tomados del spec y del código. **Cada requisito de cada task incluye implícitamente esta sección.**

- **Base:** CachyOS x86-64, y solo x86-64 (D8). El usuario final nunca usa AUR: todo lo que necesite AUR se reempaqueta y firma en el repo `nimbus`.
- **Licencias:** el shell de Nimbus es **GPL-3.0-or-later**. Los ficheros bajo `third_party/` llevan SPDX `MIT`; **todos los demás** ficheros de código fuente llevan SPDX `GPL-3.0-or-later`.
- **Prohibido:** cualquier asset de Apple (logo, SF Pro, capturas de macOS) y los nombres "Finder"/"Spotlight" para componentes de Nimbus.
- **Versiones mínimas:** `quickshell >= 0.3.2`, `hyprland >= 0.56.2` (config Lua), `qt6 >= 6.12` con `qt6-shadertools` (para `qsb`), `archiso >= 91`, `calamares >= 3.4.2`.
- **ISO:** netinstall puro, **< 3 GB**, la sesión live debe llegar a Hyprland con nuestro shell y emitir el marcador `NIMBUS_LIVE_READY`.
- **Canales:** la base es rolling de CachyOS; el stack de escritorio se **pinea** en el repo `nimbus` y se promueve `testing` → `stable` **manualmente** con firma GPG **offline**. La clave maestra **nunca** vive en un runner de CI.
- **Firma:** toda firma GPG se hace en una clave offline; la CI **compila y prueba, pero no firma**. Las releases se sirven desde **GitHub** (Actions artifacts para `testing`, Releases + CDN para `stable`), con `SigLevel = Required DatabaseOptional` en el `pacman.conf` del usuario de `stable`.
- **Clave bootstrap (verificado en `packages/README.md` y `packages/nimbus-keyring/`):** `packages/nimbus-keyring/nimbus.gpg` (fingerprint `C069CB59A56B325AFE82C05A1AB48981EB7BDCC7`, uid `Nimbus Bootstrap`) es una clave de prueba generada en local cuya mitad privada está fuera de cualquier custodia documentada. **Hay que rotarla antes de cualquier beta o publicación**, siguiendo los 6 pasos de `packages/README.md`; la ISO siguiente embebe el keyring nuevo.
- **Secure Boot:** requisito de **v1.0**, no bloqueante para las betas. Antes del shim, las betas usan MOK provisional y el instalador lo dice. La clave de Nimbus debe ser **revocable y rotable** por nuestra parte sin depender de Microsoft (la revocación del shim por Microsoft ya ha pasado antes).
- **Idiomas:** las cadenas visibles al usuario existen en **español e inglés desde el primer día**, con la infraestructura gettext lista para que la comunidad añada idiomas **sin tocar código**.
- **Sin telemetría:** ningún componente envía datos de forma remota. El programa beta no recoge nada automáticamente: el tester pega su hardware en la plantilla.
- **Comunidad desde el día 1:** repos públicos, issues abiertas, decisiones documentadas. Criterio de salida de M5: **50+ testers activos**, issues triadas, cobertura de la matriz del §4.13.
- **Compromisos de git:** mensajes en inglés con estilo convencional (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`), prefijo de tipo + `!` si rompe API.
- **Entorno de desarrollo:** todo se hace en el directorio de trabajo; **nunca** se modifica la instalación CachyOS actual del fundador. Las pruebas de integración corren en QEMU/KVM (`tests/integration/boot_live.sh --iso … --timeout 900`); en local con `-accel kvm` (`/dev/kvm` existe en el equipo de referencia), en los runners de GitHub con `-accel tcg` (emulación por software, lenta). Comandos de test: `/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v`, `QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests`, `python tools/check_spdx.py --root .`.
- **Repos de CI (verificados):** Arch `https://archlinux.cachyos.org/repo/$repo/os/$arch` (core, extra) · CachyOS v3 `https://cdn77.cachyos.org/repo/$arch_v3/$repo` · CachyOS genérico `https://cdn77.cachyos.org/repo/$arch/$repo`.
- **Hardware de referencia:** una sola máquina — Intel i7-12700H + Iris Xe + RTX 4060 Max-Q (híbrido), 16 GB, NVMe 1 TB. Todo lo que la VM no puede simular lo cubre el programa beta.

---

## Review Focus

Cinco clases de entrada o modo de fallo que el spec implica pero que ninguna task ejercita por defecto, de la más probable a la menos probable. **Cada línea tiene su test en la task que es dueña del código**, en el estilo de steps de esa task.

1. **El usuario tiene Secure Boot activo y la ISO no arranca.** Es el fallo que hace abandonar la instalación antes de ver nada. La ISO debe arrancar encadenando shim firmado por Microsoft → UKI firmado por Nimbus, y el instalador debe verificarlo en la comprobación post-instalación. → **Task 3** (`test_secureboot.py::test_live_iso_boots_with_secure_boot`)
2. **Microsoft revoca el shim.** Nimbus debe poder seguir arrancando y firmando sin depender de Microsoft: la clave de Nimbus es revocable y rotable, y el re-enrolamiento con `sbctl` es un procedimiento documentado y probado. → **Task 3** (`test_secureboot.py::test_nimbus_key_is_revocable_and_rotatable`)
3. **Un traductor añade un idioma y una cadena falta.** El shell debe caer al inglés y nunca mostrar una clave suelta en pantalla; el instalador, igual. Añadir un idioma no toca código: solo añade un `.po`. → **Task 1** (`test_i18n.py::test_missing_translation_falls_back_to_english`, `tst_config.qml` existente)
4. **El repo alojado no está firmado con la clave de confianza y pacman se niega a instalar.** La DB `stable` debe estar firmada con la clave rotada, el keyring embebido en la ISO debe contenerla, y `verify_repo.sh` debe pasar sobre lo publicado. → **Task 2** (`test_hosting.py::test_published_stable_db_is_signed_by_trusted_key`)
5. **Un tester beta reporta "va lento" y nadie sabe qué hardware tenía.** Sin CPU, GPU (y si es híbrida), kernel y si es portátil, el informe no es accionable y el triaje se atasca. → **Task 4** (`test_beta_program.py::test_bug_template_requires_hardware_fields`)

---

## Estructura de ficheros

Mapa completo de lo que este plan crea o modifica. Cada fichero tiene **una** responsabilidad. Los ficheros marcados con `(existe)` ya están en el repo y solo se modifican donde se indica.

```
tools/
  extract-strings.sh       Extrae cadenas de QML/Python a shell/po/nimbus.pot (xgettext)
  update-translations.sh   Regenera el .pot y fusiona los .po sin perder traducciones (msgmerge)
  publish-repo.sh          Publica stable: reutiliza promote.sh, genera mirrorlist, escribe checksums
  verify-release.sh        Verifica una ISO o paquete publicado contra el keyring (gpg --verify + sha256)
  audit-deps.sh            Comprueba que las deps de packages/nimbus-*/PKGBUILD existen en Arch/CachyOS
shell/po/
  nimbus.pot               Catálogo plantilla generado (no se edita a mano)
  es.po / en.po            Catálogos ES/EN completos (0 msgid sin msgstr)
  es.mo / en.mo            Compilados por el build (msgfmt), NO versionados (van al .gitignore)
shell/src/Nimbus/
  Translations.qml         (existe) carga el catálogo del idioma activo; la tabla en memoria queda como fallback
  Config.qml               (existe, solo setLocale) valida el idioma y cae a inglés si no está disponible
installer/po/
  nimbus-installer.pot / es.po / en.po   Catálogos del instalador (mismas claves que nimbus_i18n.py)
installer/calamares/
  nimbus_i18n.py           (existe) gana available_locales() leído de installer/po/; fallback intacto
iso/secureboot/
  README.md                Diseño: cadena shim→UKI, sbctl, rotación, limitación honesta de Microsoft
  sign-uki.sh              Firma el UKI con la clave de Nimbus y verifica la firma antes de darla por buena
  enroll-keys.sh           Enrola las claves con sbctl (setup mode); falla con mensaje si no hay claves
  keys/README.md           Custodia: la privada nunca entra al repo; solo huella y procedimiento
iso/
  build.sh                 (existe, solo flag nuevo) acepta --secure-boot <dir-de-claves>
tests/
  test_i18n.py             Tests de catálogos, fallback y de los scripts de extracción/fusión
  test_hosting.py          Tests de rotación, DB firmada publicada, mirrorlist y keyring embebido
  test_secureboot.py       Tests de firma de UKI, ausencia de claves privadas y flag de build.sh
  test_beta_program.py     Tests de plantillas de issue, BETA.md y lista de fallos conocidos
  test_release_readiness.py Tests de la checklist de release y del auditor de dependencias
docs/
  BETA.md                  Programa beta: qué se prueba, qué es bloqueante, qué se espera del tester
  KNOWN-ISSUES.md          Fallos conocidos publicados de la beta (la beta es usable, no perfecta)
  PUBLISHING.md            Cómo se firma y publica una release, quién ejecuta cada paso, pérdida de clave
  RELEASE-CHECKLIST.md     Lista de verificación de v1.0 con lo manual marcado como manual
  ANNOUNCE-beta.md         Texto del primer anuncio (dónde se publica, qué promete, qué no promete)
.github/ISSUE_TEMPLATE/
  bug.yml                  Plantilla de fallo: exige CPU, GPU (+híbrida), kernel, portátil sí/no, salida de verify
  feature.yml              Plantilla de propuesta
  config.yml               Rutas a plantillas y a docs/BETA.md
packages/
  nimbus-keyring/          (existe, se rota) nuevos nimbus.gpg/nimbus-trusted/nimbus-revoked + PKGBUILD bump
  nimbus-mirrorlist/       (nuevo paquete) lista de espejos servida desde el propio repo
  README.md                (existe, se amplía) § nuevo: qué cambió con la rotación y dónde vive la custodia
```

---

## Olas de ejecución

Las tareas de una misma ola **tocan ficheros disjuntos** y pueden ejecutarse en paralelo en worktrees separados. La Task 2 (rotación) debe mergearse antes de que la Task 6 publique nada verificable con la clave nueva; por eso van en olas distintas.

```
Ola A (3 en paralelo)   Task 1 (gettext) · Task 2 (rotación y repo alojado) · Task 4 (programa beta)
Ola B (2 en paralelo)   Task 3 (Secure Boot) · Task 5 (endurecimiento v1.0)
Ola C (1, tras A+B)     Task 6 (publicación y anuncio)
```

---

### Task 1: Infraestructura de gettext — añadir un idioma no toca código

**Files:**
- Create: `shell/po/nimbus.pot` (generado, no a mano)
- Create: `shell/po/es.po`
- Create: `shell/po/en.po`
- Create: `installer/po/nimbus-installer.pot` (generado, no a mano)
- Create: `installer/po/es.po`
- Create: `installer/po/en.po`
- Create: `tools/extract-strings.sh`
- Create: `tools/update-translations.sh`
- Create: `tests/test_i18n.py`
- Modify: `shell/src/Nimbus/Translations.qml` (**solo** para añadir la carga del catálogo; la tabla en memoria no se toca)
- Modify: `shell/src/Nimbus/Config.qml` (**solo** `setLocale`)
- Modify: `installer/calamares/nimbus_i18n.py` (**solo** para añadir `available_locales()` y `translated()` con fallback intacto)
- Modify: `.gitignore` (**solo** para añadir `*.mo`)

**Interfaces:**
- Consumes: la tabla ES/EN de `shell/src/Nimbus/Translations.qml` (existe, ~130 claves verificadas) y `TRANSLATIONS` de `installer/calamares/nimbus_i18n.py` (existe, claves `appearance.*`, `software.*`, `verify.*`, `postinstall.*`).
- Produces:
  - `tools/extract-strings.sh --qml-dir shell/src --py installer --out shell/po/nimbus.pot` → regenera el `.pot` con `xgettext`; exit 1 si `xgettext` no está instalado, con mensaje que dice qué paquete instalar (`gettext`).
  - `tools/update-translations.sh` → regenera los dos `.pot` y fusiona los `.po` existentes con `msgmerge --update --backup=none`, **sin perder traducciones**; es **idempotente** (dos ejecuciones seguidas no producen diff).
  - `installer/calamares/nimbus_i18n.py::available_locales()` → lista de idiomas con `.po` completo en `installer/po/` (hoy: `["es", "en"]`); `translated(key, locale)` mantiene el contrato actual (locale desconocido → inglés; clave inexistente → la propia clave).
  - `Config.setLocale(tag)` → valida contra los idiomas disponibles y **cae a inglés** si no está; la tabla en memoria de `Translations.qml` queda como **fallback** si el catálogo del idioma no se encuentra.

- [ ] **Step 1: Escribe `tests/test_i18n.py`**
  - `shell/po/nimbus.pot` existe y contiene las cadenas de la interfaz (comprueba un puñado de `msgid` que hoy viven en la tabla: `app.store.title`, `cc.power.balanced`, `tour.step.dock.title`).
  - `shell/po/es.po` y `shell/po/en.po` están **completos**: 0 `msgid` sin `msgstr` (compruébalo parseando el `.po`, no por `msgfmt --check` solo, para que el test no dependa del locale del runner).
  - `msgfmt` compila los dos catálogos sin errores (skip si `msgfmt` no está instalado, con mensaje explícito).
  - `installer/po/es.po` y `en.po` cubren todas las claves de `available_keys()` de `nimbus_i18n.py`.
  - `tools/update-translations.sh` es **idempotente**: ejecutarlo dos veces seguidas deja `git status --short shell/po installer/po` vacío.
  - `available_locales()` devuelve exactamente los idiomas con `.po` completo; `translated("verify.gpu.ok", "de")` cae al inglés.
  - Añadir un idioma es solo añadir `shell/po/<lang>.po` + `installer/po/<lang>.po`: el test crea un `xx.po` mínimo en un temporal y comprueba que `available_locales()` lo recoge **sin tocar ningún `.py` ni `.qml`**.
- [ ] **Step 2**: Ejecuta y confirma que falla (`tools/extract-strings.sh` y los `.po` no existen).
- [ ] **Step 3**: Implementa los scripts, genera los `.pot`, rellena los `.po` ES/EN a partir de las tablas existentes (las tablas son la fuente de verdad de esta task; ninguna cadena nueva), y añade la carga del catálogo + `available_locales()` + el fallback.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: `python tools/check_spdx.py --root .` y la suite completa en verde.
- [ ] **Step 6**: Commit — `feat: gettext infrastructure with complete ES and EN catalogues`.

---

### Task 2: Rotación de la clave bootstrap y repo `nimbus` alojado y firmado

**Files:**
- Modify: `packages/nimbus-keyring/nimbus.gpg` (clave pública nueva; la privada **nunca** entra al repo)
- Modify: `packages/nimbus-keyring/nimbus-trusted` (ownertrust de la clave nueva)
- Modify: `packages/nimbus-keyring/nimbus-revoked` (revocación de la bootstrap `C069CB59A56B325AFE82C05A1AB48981EB7BDCC7`)
- Modify: `packages/nimbus-keyring/PKGBUILD` (bump de `pkgver`, misma estructura `arch=('any')`)
- Create: `packages/nimbus-mirrorlist/PKGBUILD` (+ fichero `mirrorlist`)
- Modify: `packages/README.md` (**solo** para añadir el § de la rotación ejecutada: fecha, fingerprint nuevo, dónde vive la custodia)
- Create: `tools/publish-repo.sh`
- Create: `tests/test_hosting.py`

**Interfaces:**
- Consumes: `tools/promote.sh` y `tools/verify_repo.sh` (existen; no se reescriben), y el procedimiento de 6 pasos de `packages/README.md` (esta task **ejecuta** esos 6 pasos, no los reinventa).
- Produces:
  - `packages/nimbus-keyring/` con la clave nueva: `nimbus.gpg` sigue siendo exportación armored importable con `gpg --import` (el contrato de la Task 2 de M0), `nimbus-trusted` referencia el fingerprint nuevo con nivel 6, y `nimbus-revoked` contiene la revocación de la bootstrap.
  - `tools/publish-repo.sh --repo <dir> --gpgdir <dir> --key <fpr> --mirrorlist <url-base>` → **reutiliza `tools/promote.sh`** para indexar y firmar (no duplica esa lógica; el test lo comprueba por el texto del script), genera la `mirrorlist` con la URL base dada, y deja `stable` listo para subir a Releases + CDN. Sale con 1 si la DB resultante no verifica con `verify_repo.sh`.
  - El `pacman.conf` del usuario de `stable` sigue el ejemplo ya documentado: `[nimbus]` con `SigLevel = Required DatabaseOptional` y `Server = https://github.com/juanpimg/NimbusOS/releases/download/stable/$arch`.
  - El keyring nuevo va **embebido en la ISO** (paso 6 del procedimiento): el perfil `iso/profiles/nimbus/` lo instala para que `pacman` verifique desde el primer arranque.

- [ ] **Step 1: Escribe `tests/test_hosting.py`**
  - La clave pública actual de `packages/nimbus-keyring/nimbus.gpg` **ya no es** la bootstrap (`C069CB59A56B325AFE82C05A1AB48981EB7BDCC7` no aparece en `gpg --show-keys` sobre el fichero).
  - `nimbus.gpg` sigue siendo importable con `gpg --import` en un homedir limpio (el contrato M0 no se rompe con la rotación).
  - `nimbus-revoked` menciona el fingerprint bootstrap y `nimbus-trusted` referencia la clave nueva con nivel 6.
  - Ningún fichero versionado contiene una clave privada: no hay `-----BEGIN PGP PRIVATE KEY BLOCK-----` en ningún fichero trackeado por git (búscalo sobre `git ls-files`).
  - `tools/publish-repo.sh` **reutiliza** `tools/promote.sh` (el texto del script lo invoca) en vez de reimplementar indexado y firma.
  - `publish-repo.sh` genera una `mirrorlist` con la URL base pasada por `--mirrorlist` y la DB resultante verifica con `tools/verify_repo.sh`.
  - `packages/nimbus-mirrorlist/` instala su fichero en `/etc/pacman.d/nimbus-mirrorlist` (compruébalo en el `PKGBUILD`, patrón `install -Dm644`).
- [ ] **Step 2**: Ejecuta y confirma que falla (la bootstrap sigue siendo la actual).
- [ ] **Step 3**: Ejecuta la rotación de verdad en una máquina offline siguiendo los 6 pasos de `packages/README.md` (generar, re-firmar, publicar keyring nuevo, servirlo en `stable` antes de retirar la antigua, revocar la antigua, actualizar el repo y etiquetar para que la ISO embeba el keyring nuevo), e implementa `publish-repo.sh` + `nimbus-mirrorlist`.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: SPDX + suite completa. Además `bats tests/keyring.bats tests/promote.bats` sigue en verde con la clave nueva.
- [ ] **Step 6**: Commit — `feat: rotate bootstrap signing key and publish hosted signed repo`.

---

### Task 3: Secure Boot — shim, UKI y `sbctl`

**Files:**
- Create: `iso/secureboot/README.md`
- Create: `iso/secureboot/sign-uki.sh`
- Create: `iso/secureboot/enroll-keys.sh`
- Create: `iso/secureboot/keys/README.md`
- Create: `tests/test_secureboot.py`
- Modify: `iso/build.sh` (**solo** para añadir el flag `--secure-boot <dir-de-claves>`)
- Modify: `installer/calamares/modules/nimbus-verify/nimbus-verify.py` (**solo** para añadir el check `secureboot`)

**Interfaces:**
- Consumes: el bootloader que elija `nimbus-bootloader` (GRUB en multiboot, systemd-boot en disco único; Plan 3/M2) y el check-list de `nimbus-verify` (14 checks del Plan 3: `gpu` … `keyring`).
- Produces:
  - `iso/secureboot/sign-uki.sh --uki <fichero> --gpgdir <dir> --key <fpr>` → firma el UKI con la clave de Nimbus vía `sbctl` (o `sbsign`, pendiente de decidir según lo que traiga CachyOS) y **verifica** la firma después de firmar (`sbctl verify`); no basta con mirar el exit code del firmador. Falla con mensaje que **no revela la ruta de la clave privada**.
  - `iso/secureboot/enroll-keys.sh` → enrola las claves con `sbctl enroll-keys` (setup mode); documenta que en hardware real esto se hace una vez por máquina.
  - `iso/build.sh --secure-boot <dir-de-claves>` → construye la ISO con la cadena shim→UKI; **sin el flag**, construye la ISO de beta con MOK provisional y **lo dice** en la salida (no finge Secure Boot).
  - Nuevo check `secureboot` en `nimbus-verify`: informa si Secure Boot está activo y si la cadena verifica; en beta con MOK provisional lo dice explícitamente en vez de dar un "ok" falso.
  - `iso/secureboot/keys/README.md` explica que la **privada nunca entra al repo** y remite a la custodia de `packages/README.md`.

- [ ] **Step 1: Escribe `tests/test_secureboot.py`**
  - `sign-uki.sh` **verifica** la firma tras firmar (el test usa un UKI simulado y `sbctl`/`sbsign` si están; si no están, skip con mensaje, nunca falso verde).
  - `sign-uki.sh` **falla** si la clave privada no está disponible, y el mensaje no contiene ninguna ruta local.
  - `iso/build.sh --help` (o invocación sin args válidos) documenta `--secure-boot`; sin el flag, la salida menciona "MOK provisional".
  - Ningún fichero versionado es una clave privada (`*.key`, `*.pem`, o bloques `PRIVATE KEY` sobre `git ls-files`).
  - El shim que se instale en la ISO es el **oficial firmado por Microsoft** con checksum verificado (el test comprueba que el script verifica un checksum antes de usar el binario; la URL y el hash exactos quedan fijados en `iso/secureboot/README.md`, pendiente de decidir hasta tener red CachyOS).
  - El check `secureboot` distingue tres estados: `ok` (cadena verifica), `mok` (provisional de beta), `off` (desactivado); nunca informa `ok` con MOK provisional.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa los scripts, el flag y el check.
- [ ] **Step 4**: Ejecuta y confirma que pasa. Además, arranque real: `bash tests/integration/boot_live.sh --iso <iso-con-secureboot>` llega a `NIMBUS_LIVE_READY` (en QEMU sin Secure Boot esto valida que la ISO firmada sigue arrancando; el arranque con Secure Boot activo se prueba en hardware real, Task 4).
- [ ] **Step 5**: SPDX + suite completa.
- [ ] **Step 6**: Commit — `feat: Secure Boot with signed UKI and sbctl key management`.

---

### Task 4: Programa beta — issues con hardware, triaje y fallos conocidos

**Files:**
- Create: `docs/BETA.md`
- Create: `docs/KNOWN-ISSUES.md`
- Create: `.github/ISSUE_TEMPLATE/bug.yml`
- Create: `.github/ISSUE_TEMPLATE/feature.yml`
- Create: `.github/ISSUE_TEMPLATE/config.yml`
- Create: `tests/test_beta_program.py`

**Interfaces:**
- Consumes: la matriz de hardware del §4.13 del spec (CPU v3/v4, AMD GCN3+, Intel Gen8+/Arc, NVIDIA Turing+ con módulos abiertos, híbridos on-demand, wifi `iwlwifi`/`rtw88`/`brcmfmac`, PipeWire, CUPS) y los 14 checks de `nimbus-verify` (el tester pega su salida).
- Produces:
  - `docs/BETA.md` — qué se prueba (la matriz §4.13 línea por línea), qué es un fallo **bloqueante** (no arranca, Windows deja de arrancar, no hay red, no hay audio, el rollback no funciona) y qué no (un icono feo, un typo), cómo se informa (plantilla + salida de `nimbus-verify`), qué hardware hace falta, y qué se espera del tester y del proyecto (tiempos de triaje, qué significa "triada"). Dice explícitamente que el proyecto **no recoge telemetría** y que el tester puede pedir que su informe se cierre.
  - `.github/ISSUE_TEMPLATE/bug.yml` — exige: CPU, GPU (y si el equipo es híbrido), kernel (`uname -r`), portátil sí/no, y la salida de la verificación. Sin esos campos, "va lento" no es accionable.
  - `docs/KNOWN-ISSUES.md` — la lista de fallos conocidos publicada de la beta (la beta es un sistema real de uso diario, no un esqueleto; los fallos conocidos están escritos, no escondidos).

- [ ] **Step 1: Escribe `tests/test_beta_program.py`**
  - Las plantillas existen y son **YAML válido** (se parsean).
  - `bug.yml` pide exactamente: CPU, GPU, híbrida sí/no, kernel, portátil sí/no, salida de la verificación.
  - `docs/BETA.md` define qué es **bloqueante** y qué no, menciona cada familia de la matriz §4.13 (AMD, Intel iGPU, Arc, NVIDIA, híbridos, wifi), y dice que no hay telemetría.
  - `docs/KNOWN-ISSUES.md` existe y cada entrada tiene: síntoma, hardware afectado, workaround y estado.
  - `config.yml` enlaza a las plantillas y a `docs/BETA.md`.
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa plantillas y documentos (el contenido inicial de `KNOWN-ISSUES.md` sale de los fallos reales vistos en M0–M3, no de memoria).
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: SPDX + suite completa.
- [ ] **Step 6**: Commit — `feat: public beta program with hardware-aware issue templates`.

---

### Task 5: Endurecimiento de v1.0 — accesibilidad, checklist de release y auditoría

**Files:**
- Create: `docs/RELEASE-CHECKLIST.md`
- Create: `tools/audit-deps.sh`
- Create: `tests/test_release_readiness.py`
- Modify: `shell/src/Nimbus/lib/` (**solo** para añadir nombres accesibles y foco visible; ningún cambio visual por defecto)

**Interfaces:**
- Consumes: los criterios de terminación de M0 (8 condiciones), M1 (8), M2 (7) y M3 (8), la definición de terminado del §9 (9 condiciones) y los `PKGBUILD` de `packages/nimbus-*/`.
- Produces:
  - `docs/RELEASE-CHECKLIST.md` — la lista de verificación de v1.0: las 8 condiciones de M0, las 8 de M1, las 7 de M2, las 8 de M3, el arranque con Secure Boot (Task 3), ES/EN completos (Task 1), ausencia de telemetría, y accesibilidad. Cada punto dice si está **automatizado** (con el comando exacto) o es **manual** (con quién lo ejecuta).
  - `tools/audit-deps.sh` → comprueba que cada dependencia declarada en `packages/nimbus-*/PKGBUILD` **existe** en los repos de Arch/CachyOS (`pacman -Si` contra los repos de CI); sale con 1 y lista las inexistentes. Un paquete renombrado en upstream es una instalación rota en la primera actualización.
  - Accesibilidad (lo que "un desconocido instala y no necesita leer nada" exige de verdad): todos los controles interactivos del shell exponen nombre accesible, el foco de teclado es visible y sigue un orden cuerdo, y el contraste de `Theme.text` sobre `Theme.background`/`surface` cumple en claro y en oscuro. Los tests lo comprueban sobre `Theme` (valores exactos ya fijados en M0), no a ojo.

- [ ] **Step 1: Escribe `tests/test_release_readiness.py`**
  - La checklist menciona M0, M1, M2, M3, Secure Boot, i18n ES/EN y telemetría, y cada punto está marcado como automatizado (con comando) o manual (con responsable).
  - `tools/audit-deps.sh` sale con 1 ante una dependencia inexistente (el test le inyecta un `PKGBUILD` con una dep inventada en un temporal).
  - Contraste: `Theme.text` sobre `Theme.background` y `surface` supera el umbral en ambos modos (calculado en el test, no a ojo).
  - Los componentes de `shell/src/Nimbus/lib/` exponen `Accessible.name` (o la propiedad equivalente que use el toolkit; el test falla hoy porque no existe).
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa la checklist, el auditor y los nombres accesibles.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: SPDX + suite completa.
- [ ] **Step 6**: Commit — `feat: v1.0 release checklist, dependency audit and shell accessibility`.

---

### Task 6: Publicación — releases firmadas, checksums y primer anuncio

**Files:**
- Create: `tools/verify-release.sh`
- Create: `docs/PUBLISHING.md`
- Create: `docs/ANNOUNCE-beta.md`
- Create: `tests/test_publishing.py`

**Interfaces:**
- Consumes: `tools/publish-repo.sh` (Task 2; el repo ya está alojado y firmado con la clave rotada), la ISO construida por `iso/build.sh`, y `docs/BETA.md` + `docs/KNOWN-ISSUES.md` (Task 4; el anuncio enlaza a ambos, no los duplica).
- Produces:
  - `tools/verify-release.sh --file <fichero> --sig <firma> [--keyring <dir>]` → verifica la firma GPG **y** el checksum SHA256 del fichero; exit 0 solo si ambas pasan. Es el comando que el anuncio dice al usuario que ejecute.
  - `docs/PUBLISHING.md` — el procedimiento completo: qué se firma (ISO + `nimbus.db` + paquetes), en qué orden, quién ejecuta cada paso (la firma solo la ejecuta quien tenga acceso a la clave offline), cómo se sube a Releases + CDN, y **qué se hace si la clave se pierde** (remite a la rotación de `packages/README.md`, no la duplica).
  - `docs/ANNOUNCE-beta.md` — el texto del primer anuncio: qué es Nimbus en una frase, dónde se descarga, cómo se verifica (el comando de `verify-release.sh`), qué hardware está soportado (§4.13), qué fallos son conocidos (enlace a `KNOWN-ISSUES.md`), y qué **no** se promete (Secure Boot completo hasta v1.0, ARM64 fuera de alcance).

- [ ] **Step 1: Escribe `tests/test_publishing.py`**
  - `verify-release.sh` pasa con firma + checksum buenos y **falla** con una firma manipulada, con un checksum manipulado, y con un fichero sin firma.
  - `docs/PUBLISHING.md` documenta el orden de firma, quién ejecuta cada paso, y el procedimiento de **pérdida de clave** (con enlace a la rotación).
  - `docs/ANNOUNCE-beta.md` contiene: enlace de descarga, comando de verificación, matriz de hardware soportado, enlace a fallos conocidos, y una sección explícita de lo que **no** se promete.
  - Ningún paso de `PUBLISHING.md` pide meter la clave privada en un runner de CI (búscalo por texto: ni `GPG_PRIVATE_KEY` en un workflow ni `echo "$KEY" | gpg --import` en ningún `.yml`).
- [ ] **Step 2**: Ejecuta y confirma que falla.
- [ ] **Step 3**: Implementa el script y los documentos. Firma la primera beta de verdad con la clave rotada.
- [ ] **Step 4**: Ejecuta y confirma que pasa.
- [ ] **Step 5**: SPDX + suite completa.
- [ ] **Step 6**: Commit — `feat: signed releases with checksums and beta announcement`.

---

## Criterio de terminación de M4/M5

1. Las 6 tareas están mergeadas y revisadas.
2. `/tmp/opencode/nimbus-venv/bin/python -m pytest tests -v` pasa entero, incluidos `test_i18n.py`, `test_hosting.py`, `test_secureboot.py`, `test_beta_program.py` y `test_release_readiness.py` y `test_publishing.py`.
3. La clave bootstrap (`C069CB59A56B325AFE82C05A1AB48981EB7BDCC7`) está rotada: `verify_repo.sh` pasa sobre `stable` con la clave nueva y la ISO embebe el keyring nuevo.
4. La ISO arranca en un equipo con **Secure Boot activo** sin tocar la BIOS; con MOK provisional solo se publica beta y el instalador lo dice.
5. ES y EN están **completos** (0 cadenas sin traducir en `shell/po/` y en `installer/po/`) y `msgfmt` compila los cuatro catálogos; añadir un idioma es añadir dos `.po`, sin tocar código.
6. Existe un **programa beta público** con plantillas de issue que piden hardware, proceso de triaje con tiempos, cobertura de la matriz §4.13 y lista de fallos conocidos publicada.
7. El repo `nimbus` está **alojado, indexado y firmado** con la clave de confianza, con espejos y una `mirrorlist` que los clientes usan; una release se puede **descargar y verificar** con `tools/verify-release.sh` (firma + SHA256).
8. La lista de verificación de v1.0 está escrita, cada punto automatizado **pasa** (`audit-deps.sh` incluido) y cada punto manual tiene responsable.
9. `python tools/check_spdx.py --root .` pasa.

Cuando las nueve se cumplan, M4/M5 está cerrado y **v1.0** es verificar la checklist, no descubrir trabajo nuevo.
