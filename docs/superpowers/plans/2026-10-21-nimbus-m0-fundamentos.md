# Nimbus M0 — Cimientos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Poner en pie la infraestructura de Nimbus — repositorio, control de licencias, keyring GPG con firma offline, canales `testing`/`stable`, tokens de diseño del shell, configuración de Hyprland, perfil de ISO de archiso, configuración de Calamares y un harness de integración en QEMU — de modo que una ISO arranque en una VM, instale un Hyprland pelado con nuestro shell y el ciclo build→test→promocionar a `stable` funcione de extremo a extremo.

**Architecture:** Monorepo con un `tools/` de scripts (bash + python) que implementa toda la cadena de firma y promoción, un `packages/` con los PKGBUILDs del repo `nimbus`, `shell/` con el código QML/Quickshell, `dots/` con la config de Hyprland, `iso/` con el perfil archiso e `installer/` con la config y los módulos de Calamares. El stack de escritorio se construye en el repo `nimbus` y se promueve de `testing` a `stable` con firma GPG manual; la base (kernel, Mesa, systemd) sigue a CachyOS en rolling.

**Tech Stack:** CachyOS x86-64 (Arch-based) · archiso 91 · Hyprland 0.56.2 · Quickshell 0.3.2 · Qt 6.12 · QML · Calamares 3.4.2 (`cachyos-calamares-next`) · Python 3.14 + pytest 9.1 · bats 1.14 · QEMU/KVM · GitHub Actions

**Spec:** [`../specs/2026-10-21-nimbus-design.md`](../specs/2026-10-21-nimbus-design.md) — leer §2 (objetivos/anti-objetivos), §3 (decisiones y procedencia), §4.2 (base y modelo de pins), §4.4 (instalador) y §4.13 (hardware soportado).

---

## Global Constraints

Valores exactos tomados del spec. **Cada requisito de cada task incluye implícitamente esta sección.**

- **Base:** CachyOS x86-64. El usuario final nunca usa AUR: todo lo que necesite AUR se reempaqueta y firma en el repo `nimbus`.
- **Licencias:** el shell de Nimbus es **GPL-3.0-or-later**. El código vendorizado de MacShell es **MIT**. Los ficheros bajo `third_party/` llevan SPDX `MIT`; **todos los demás** ficheros de código fuente llevan SPDX `GPL-3.0-or-later`.
- **Prohibido:** cualquier asset de Apple (logo, SF Pro, capturas de macOS) y los nombres "Finder"/"Spotlight" para componentes de Nimbus.
- **Versiones mínimas:** `quickshell >= 0.3.2`, `hyprland >= 0.56.2` (config Lua), `qt6 >= 6.12` con `qt6-shadertools` (para `qsb`), `archiso >= 91`, `calamares >= 3.4.2`.
- **ISO:** netinstall puro, **< 3 GB**, la sesión live debe llegar a Hyprland con nuestro shell.
- **Canales:** la base es rolling de CachyOS; el stack de escritorio se **pinea** en el repo `nimbus` y se promueve `testing` → `stable` **manualmente** con firma GPG **offline**. La clave maestra **nunca** vive en un runner de CI.
- **Firma:** toda firma GPG se hace en una clave offline; la CI **compila y prueba, pero no firma**.
- **Idiomas:** las cadenas visibles al usuario existen en **español e inglés desde el primer día**, con gettext listo para ampliar.
- **Sin telemetría:** ningún componente envía datos de forma remota.
- **Compromisos de git:** mensajes en inglés con estilo convencional (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`), prefijo de tipo + `!` si rompe API.
- **Entorno de desarrollo:** todo se hace en el directorio de trabajo; **nunca** se modifica la instalación CachyOS actual del fundador. Las pruebas de integración corren en QEMU/KVM.
- **Repos de CI (verificados):** Arch `https://archlinux.cachyos.org/repo/$repo/os/$arch` (core, extra) · CachyOS v3 `https://cdn77.cachyos.org/repo/$arch_v3/$repo` · CachyOS genérico `https://cdn77.cachyos.org/repo/$arch/$repo`.

---

## Review Focus

Cinco clases de entrada o modo de fallo que el spec implica pero que ninguna task ejercita por defecto, de la más probable a la menos probable. **Cada línea tiene su test en la task que es dueña del código**, en el estilo de steps de esa task.

1. **Sin red durante la instalación.** El instalador debe detectar la ausencia de conexión y explicarla con un mensaje accionable, no fallar con un error de `pacman` o un spinner infinito. → **Task 7** (`test_calamares_settings.py::test_installer_requires_connectivity_step`)
2. **El idioma del sistema no es ES ni EN.** El shell debe caer a inglés sin mostrar claves de traducción sin traducir ni fallar al arrancar. → **Task 4** (`tst_config.qml::test_falls_back_to_english_for_unknown_locale`)
3. **La GPU no soporta el shader de cristal, o no hay aceleración por hardware.** La interfaz debe seguir siendo usable con un desenfoque simple; el shader es una mejora, nunca un requisito. → **Task 4** (`tst_theme.qml::test_glass_has_opaque_fallback`)
4. **Una actualización de Hyprland o Quickshell rompe el shell.** El usuario no debe encontrarse con una pantalla negra: debe existir una sesión de emergencia con terminal, alcanzable desde el greeter. → **Task 5** (`test_hyprland_config.py::test_emergency_session_is_declared`) y **Task 8** (el harness comprueba que la sesión live levanta el shell)
5. **El usuario actualiza el shell y su configuración usa un esquema de versión anterior.** La configuración debe migrarse o resetearse con seguridad, nunca provocar un fallo al arrancar. → **Task 4** (`tst_config.qml::test_migrates_older_config_schema`)

---

## Estructura de ficheros

Mapa completo de lo que este plan crea. Cada fichero tiene **una** responsabilidad.

```
tools/
  check_spdx.py        Validador de cabeceras SPDX (usado por CI y por los tests)
  genkeyring.sh        Genera la clave GPG maestra y el paquete nimbus-keyring
  sign_repo.sh         Firma la DB de un repo pacman
  promote.sh           Promueve testing → stable: copia, indexa y firma
  verify_repo.sh       Verifica firmas de paquetes y de la DB de un repo
packages/
  README.md            Documenta el modelo de pins (canales, promoción, rotación)
  nimbus-keyring/      PKGBUILD del keyring con la clave pública de Nimbus
  nimbus-shell/        PKGBUILD del shell QML/Quickshell
  nimbus-dots/         PKGBUILD de la config de Hyprland y los defaults
shell/
  src/qmldir            Registro del módulo QML "Nimbus" (singletons)
  nimbus-shell          Launcher que arranca el shell con el QML2_IMPORT_PATH correcto
  src/Theme.qml        Singleton de tokens de diseño (color, métricas, cristal)
  src/Config.qml       Singleton de configuración persistida, con versionado y migración
  src/Translations.qml Singleton de la tabla de traducciones ES/EN con fallback
  src/main.qml         Punto de entrada del shell
  tests/tst_theme.qml  Tests de los tokens de diseño
  tests/tst_config.qml Tests de configuración, migración y fallback de idioma
dots/
  hypr/hyprland.lua    Config Lua de Hyprland (layout flotante, atajos Apple)
  hypr/quirks.conf     Ajustes de Hyprland en formato clásico
  nimbus/defaults.conf Defaults del sistema escritos por el shell
  nimbus/nimbus-start  Script de arranque del shell, invocado por Hyprland
iso/
  build.sh             Construye la ISO (soporta --local-repo para el bootstrap)
  profiles/nimbus/     Perfil archiso (airoot.sh, packages.x86_64, customize.sh, overlay)
installer/
  calamares/settings.conf           Flujo de 11 pasos del instalador
  calamares/modules/nimbus-*/       Módulos propios (apariencia, software, verificación)
tests/
  test_spdx_headers.py
  test_hyprland_config.py
  test_iso_profile.py
  test_calamares_settings.py
  keyring.bats
  promote.bats
  integration/lib.sh
  integration/boot_live.sh
  integration/build_and_boot.sh
third_party/
  macshell/            Código MIT vendorizado de MacShell (llega en el Plan 2)
.github/workflows/
  ci.yml               Lint y tests unitarios
  iso.yml              Construcción de ISO y test de arranque en QEMU
```

---

### Task 1: Andamiaje del monorepo, control de licencias y CI

**Files:**
- Create: `README.md`
- Create: `LICENSE` (texto completo de GPL-3.0)
- Create: `LICENSES.md`
- Create: `CONTRIBUTING.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `.editorconfig`
- Create: `.gitignore`
- Create: `pytest.ini`
- Create: `tools/check_spdx.py`
- Create: `tests/test_spdx_headers.py`
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: nada (es la primera task).
- Produces:
  - `tools/check_spdx.py --root <dir>` → exit 0 si todos los ficheros de código fuente bajo `<dir>` tienen una cabecera SPDX válida; exit 1 e imprime por stdout la lista `ruta: motivo`. Política: ficheros bajo `third_party/` requieren SPDX `MIT`; el resto requiere `GPL-3.0-or-later`.
  - `pytest.ini` en la raíz, con `testpaths = tests` y `python_files = test_*.py`.
  - Workflow `ci.yml` con los jobs `lint` y `test`.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_spdx_headers.py`:

```python
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE_SUFFIXES = {".py", ".sh", ".bats", ".qml", ".cpp", ".h", ".lua", ".js", ".yaml", ".yml"}


def _sources():
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix not in SOURCE_SUFFIXES:
            continue
        if ".git" in path.parts:
            continue
        yield path


def test_check_spdx_passes_on_clean_tree():
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "check_spdx.py"), "--root", str(ROOT)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_every_source_file_declares_a_spdx_identifier():
    offenders = []
    for path in _sources():
        head = path.read_text(encoding="utf-8", errors="replace")[:600]
        expected = "MIT" if "third_party" in path.parts else "GPL-3.0-or-later"
        if f"SPDX-License-Identifier: {expected}" not in head:
            offenders.append(f"{path.relative_to(ROOT)} (esperaba {expected})")
    assert offenders == [], "\n".join(offenders)


def test_licenses_md_exists_and_lists_third_party():
    text = (ROOT / "LICENSES.md").read_text(encoding="utf-8")
    assert "MacShell" in text
    assert "MIT" in text
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `python -m pytest tests/test_spdx_headers.py -v`
Expected: FAIL — `tests/test_spdx_headers.py` no puede ejecutarse porque `tools/check_spdx.py` no existe, y `LICENSES.md` tampoco.

- [ ] **Step 3: Implementa `tools/check_spdx.py` y el andamiaje**

Crea `tools/check_spdx.py` con la cabecera `#!/usr/bin/env python3` + SPDX `GPL-3.0-or-later`. Debe:
1. Recorrer `--root` (por defecto `.`) y recoger ficheros con sufijo en `.py .sh .bats .qml .cpp .h .lua .js .yaml .yml`, excluyendo cualquier ruta que contenga `.git`.
2. Para cada fichero, leer los primeros 600 bytes y buscar `SPDX-License-Identifier: <esperado>`, donde `<esperado>` es `MIT` si alguna parte de la ruta es `third_party`, y `GPL-3.0-or-later` en caso contrario.
3. Si hay infracciones, imprimir `ruta: falta SPDX <esperado>` por línea y salir con 1. Si no, imprimir `SPDX OK: N ficheros` y salir con 0.

Crea además:
- `LICENSE` con el texto íntegro de la GPL-3.0 (descárgalo de `https://www.gnu.org/licenses/gpl-3.0.txt`; no lo reescribas a mano).
- `LICENSES.md` con una tabla de dos filas: MacShell (MIT, `third_party/macshell/`, código vendorizado) y los componentes propios (GPL-3.0-or-later), más una nota de que los assets de Apple están excluidos por marca registrada.
- `README.md` con el nombre, la frase "Arch por debajo, Hyprland en la superficie, la pulido de macOS encima", el estado "M0 — en construcción", y una tabla de los repos del roadmap.
- `CONTRIBUTING.md` y `CODE_OF_CONDUCT.md` ( Contributor Covenant v2.1 ).
- `.editorconfig` con `indent_style = space`, `indent_size = 4`, `end_of_line = lf`, `insert_final_newline = true`, `charset = utf-8`.
- `.gitignore` con: `*.iso`, `build/`, `out/`, `__pycache__/`, `.pytest_cache/`, `*.qcow2`, `*.pkg.tar.zst`, `*.db`, `*.db.sig`, `*.sig`, `keys/`, `gpg/`, `.superpowers/`.
- `pytest.ini`:
  ```ini
  [pytest]
  testpaths = tests
  python_files = test_*.py
  addopts = -ra
  ```

- [ ] **Step 4: Ejecuta el test para verificar que pasa**

Run: `python -m pytest tests/test_spdx_headers.py -v`
Expected: PASS — 3 passed.

- [ ] **Step 5: Crea `.github/workflows/ci.yml`**

Workflow con dos jobs, ambos en `ubuntu-latest` salvo donde se indique:

`lint`:
```yaml
      - name: Cabeceras SPDX
        run: python tools/check_spdx.py --root .
      - name: Yamllint
        run: yamllint .
      - name: Actionlint
        run: actionlint
      - name: Shellcheck
        run: |
          sudo apt-get update && sudo apt-get install -y shellcheck
          sh_files="$(git ls-files '*.sh')"
          if [ -n "$sh_files" ]; then shellcheck $sh_files; fi
```

`test`, en `container: archlinux:latest` con los repos de CachyOS añadidos antes de instalar dependencias:
```yaml
      - name: Preparar repos CachyOS
        run: |
          printf 'Server = https://archlinux.cachyos.org/repo/$repo/os/$arch\n' \
            | tee -a /etc/pacman.d/mirrorlist
          printf '[cachyos]\nServer = https://cdn77.cachyos.org/repo/$arch/$repo\n' \
            > /etc/pacman.d/mirrorlist.cachyos
          printf '[cachyos-v3]\nServer = https://cdn77.cachyos.org/repo/$arch_v3/$repo\n' \
            > /etc/pacman.d/mirrorlist.cachyos-v3
          for r in cachyos cachyos-v3; do
            printf "[$r]\nInclude = /etc/pacman.d/mirrorlist.$r\n" >> /etc/pacman.conf
          done
      - name: Instalar dependencias
        run: pacman -Sy --noconfirm python-pytest bats qt6-declarative qt6-wayland qt6-shadertools lua
      - name: Tests Python
        run: python -m pytest tests -v
      - name: Tests Bats
        run: |
          if ls tests/*.bats >/dev/null 2>&1; then bats tests/*.bats; fi
      - name: Tests QML
        run: |
          if [ -d shell/tests ]; then
            QT_QPA_PLATFORM=offscreen \
              QML2_IMPORT_PATH="$PWD/shell/src" \
              /usr/lib/qt6/bin/qmltestrunner -input shell/tests
          fi
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: bootstrap monorepo, SPDX enforcement and CI"
```

---

### Task 2: Keyring `nimbus`, firma GPG y rotación

**Files:**
- Create: `tools/genkeyring.sh`
- Create: `tools/sign_repo.sh`
- Create: `packages/nimbus-keyring/PKGBUILD`
- Create: `packages/nimbus-keyring/nimbus-keyring.install`
- Create: `tests/keyring.bats`

**Interfaces:**
- Consumes: `tools/check_spdx.py` (Task 1) — las cabeceras SPDX de los scripts nuevos.
- Produces:
  - `tools/genkeyring.sh --outdir <dir> --uid <uid> --email <email>` → genera una clave GPG RSA-4096 sin passphrase en `<dir>/gnupg/`, exporta la clave pública **armored** a `<dir>/nimbus.gpg`, crea el árbol de paquete `<dir>/nimbus-keyring/` con `nimbus.gpg`, `nimbus-trusted`, `nimbus-revoked` y `nimbus-keyring.install`, e imprime por stdout **solo** el fingerprint de 40 hex. Sale con 1 si `--outdir` ya contiene `nimbus.gpg` (no sobrescribe).
  - `tools/sign_repo.sh --repo <dir> --gpgdir <dir> --key <fpr>` → firma `<dir>/<nombre>.db` produciendo `<dir>/<nombre>.db.sig`. **No sobrescribe** una `.sig` existente: sale con 1 e imprime `ya firmado`.
  - El paquete `nimbus-keyring` instala `/usr/share/pacman/keyrings/nimbus.gpg`, `nimbus-trusted` y `nimbus-revoked`, y su `.install` ejecuta `pacman-key --populate nimbus` en `post_install`.

  **FORMATO DEL ARTEFACTO (load-bearing).** `nimbus.gpg` debe ser la **clave pública exportada en ASCII armored**, igual que `cachyos.gpg` y `archlinux.gpg` en `/usr/share/pacman/keyrings/`. **No** debe ser un keybox KBXf. La razón es concreta: `pacman-key --populate` importa el fichero con `gpg --import <fichero>`, y `gpg --import` solo acepta **exportaciones de clave pública** (armored o binarias), no bases de datos de keyring. Con un keybox, `gpg --import` responde "no valid OpenPGP data found", el populate no importa nada, y **toda firma del repositorio de Nimbus falla con "signature from unknown trust"**. Verificado contra `/usr/bin/pacman-key` (línea 318) y contra los keyring de producción.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/keyring.bats`:

```bats
#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  TESTDIR="$(mktemp -d)"
  export GNUPGHOME="$TESTDIR/gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "genkeyring exporta una clave y el paquete del keyring" {
  run bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  [ "$status" -eq 0 ]
  [ -f "$TESTDIR/out/nimbus.gpg" ]
  [ -f "$TESTDIR/out/nimbus-keyring/nimbus.gpg" ]
  [ -f "$TESTDIR/out/nimbus-keyring/nimbus-trusted" ]
  [ -f "$TESTDIR/out/nimbus-keyring/nimbus-revoked" ]
  [ -f "$TESTDIR/out/nimbus-keyring/nimbus-keyring.install" ]
  [[ "$output" =~ ^[0-9A-F]{40}$ ]]
}

@test "genkeyring se niega a sobrescribir un keyring existente" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  run bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  [ "$status" -eq 1 ]
  [[ "$output" == *"existe"* ]]
}

@test "la clave exportada verifica su propia firma" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/out/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  printf 'contenido\n' > "$TESTDIR/datos.txt"
  gpg --homedir "$TESTDIR/out/gnupg" --batch --yes --detach-sign --local-user "$FPR" "$TESTDIR/datos.txt"
  run gpg --homedir "$TESTDIR/out/gnupg" --verify "$TESTDIR/datos.txt.sig" "$TESTDIR/datos.txt"
  [ "$status" -eq 0 ]
}

@test "nimbus.gpg es importable con gpg --import, como exige pacman-key --populate" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  # pacman-key --populate hace exactamente esto: gpg --import <nimbus.gpg>.
  # Si el artefacto es un keybox en vez de una exportacion armored, falla aqui.
  mkdir -p "$TESTDIR/importhome"
  chmod 700 "$TESTDIR/importhome"
  run gpg --homedir "$TESTDIR/importhome" --quiet --import "$TESTDIR/out/nimbus.gpg"
  [ "$status" -eq 0 ]
  # Y la clave importada debe ser la de Nimbus.
  run gpg --homedir "$TESTDIR/importhome" --list-keys --with-colons
  [[ "$output" == *"nimbus@example.org"* ]]
}

@test "nimbus.gpg verifica con la clave pública, sin la clave privada" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/out/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  printf 'contenido\n' > "$TESTDIR/datos.txt"
  gpg --homedir "$TESTDIR/out/gnupg" --batch --yes --detach-sign --local-user "$FPR" "$TESTDIR/datos.txt"

  # Un keyring limpio que solo tiene la clave pública, tal y como verá el usuario.
  # nimbus.gpg es una exportacion armored: hay que IMPORTARLA antes de usarla
  # como keyring; pasarle el fichero armored a --keyring no funciona.
  mkdir -p "$TESTDIR/verifyhome"
  chmod 700 "$TESTDIR/verifyhome"
  run gpg --homedir "$TESTDIR/verifyhome" --quiet --import "$TESTDIR/out/nimbus.gpg"
  [ "$status" -eq 0 ]
  run gpg --homedir "$TESTDIR/verifyhome" --verify "$TESTDIR/datos.txt.sig" "$TESTDIR/datos.txt"
  [ "$status" -eq 0 ]
}

@test "el ownertrust y el populate estan bien formados" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/out/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  # El ownertrust debe referenciar la clave con nivel 6 (ultimate). Sin esto,
  # pacman-key importa la clave pero no le da confianza y toda firma del repo
  # falla con "signature from unknown trust".
  grep -q ":6:" "$TESTDIR/out/nimbus-keyring/nimbus-trusted"
  grep -q "$FPR" "$TESTDIR/out/nimbus-keyring/nimbus-trusted"
  # Y el .install debe ejecutar el populate, que es lo que aplica el ownertrust.
  grep -q "pacman-key --populate nimbus" "$TESTDIR/out/nimbus-keyring/nimbus-keyring.install"
}

@test "sign_repo firma la base de datos y se niega a firmar dos veces" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/out/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  mkdir -p "$TESTDIR/repo"
  printf '%%FILENAME%%\n' > "$TESTDIR/repo/nimbus.db"
  run bash "$REPO_ROOT/tools/sign_repo.sh" --repo "$TESTDIR/repo" --gpgdir "$TESTDIR/out/gnupg" --key "$FPR"
  [ "$status" -eq 0 ]
  [ -f "$TESTDIR/repo/nimbus.db.sig" ]
  run bash "$REPO_ROOT/tools/sign_repo.sh" --repo "$TESTDIR/repo" --gpgdir "$TESTDIR/out/gnupg" --key "$FPR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ya firmado"* ]]
}
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `bats tests/keyring.bats`
Expected: FAIL — todos los tests fallan con "No such file or directory" apuntando a `tools/genkeyring.sh`.

- [ ] **Step 3: Implementa `tools/genkeyring.sh`**

Script bash con `set -euo pipefail`, cabecera SPDX. Comportamiento:
1. Valida `--outdir`, `--uid`, `--email` obligatorios; sin ellos, error y salida 1.
2. Si `<outdir>/nimbus.gpg` existe, imprime `el keyring ya existe` por stderr y sale con 1.
3. Crea `<outdir>/gnupg` con `chmod 700` y genera la clave con:
   ```bash
   gpg --homedir "$OUTDIR/gnupg" --batch --yes --passphrase '' \
       --quick-generate-key "$UID" rsa4096 sign never
   ```
   La clave debe tener capacidad de **firmar** (no certificar-only) para poder firmar DBs de pacman.
3. Exporta la clave pública en **ASCII armored** a `<outdir>/nimbus.gpg`:
   ```bash
   gpg --homedir "$OUTDIR/gnupg" --batch --yes --armor --export "$KEYUID" > "$OUTDIR/nimbus.gpg"
   ```
   **Este es el formato que consumen `pacman-key --populate` y los keyring de
   producción (`cachyos.gpg`, `archlinux.gpg`): una exportación de clave pública armored.
   NO un keybox KBXf** — ver la nota de formato en el bloque Interfaces. El fichero debe
   empezar por `-----BEGIN PGP PUBLIC KEY BLOCK-----`.
4. Crea `<outdir>/nimbus-keyring/` con **cuatro** ficheros:
   - `nimbus.gpg` — copia de la exportación armored.
   - `nimbus-trusted` — el ownertrust: `printf '%s:6:\n' "$FPR" > nimbus-trusted`.
     **Sin este fichero, `pacman-key --populate` importa la clave pero no le da confianza,
     y toda firma del repo de Nimbus falla con "signature from unknown trust".** El formato
     es el de `gpg --export-ownertrust`.
   - `nimbus-revoked` — fichero vacío, placeholder para revocaciones futuras.
   - `nimbus-keyring.install` con este contenido exacto:
     ```
     usr/share/pacman/keyrings/nimbus.gpg
     usr/share/pacman/keyrings/nimbus-trusted
     usr/share/pacman/keyrings/nimbus-revoked
     post_install() {
       pacman-key --populate nimbus
     }
     ```
     El patrón está verificado contra `cachyos-keyring`, que_distribution `cachyos.gpg`,
     `cachyos-trusted` y `cachyos-revoked` en `/usr/share/pacman/keyrings/`.
5. Imprime **solo** el fingerprint: `gpg --homedir "$OUTDIR/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}'`.

**Nota sobre `--quick-generate-key`:** usa el alias `sign` para que la clave sirva tanto para firmar como para ser la clave de un owner-trusted en el keyring de pacman. Si `gpg` se queja de que el alias no existe en esta versión, usa `--quick-gen-key "$UID" rsa4096 default never`.

- [ ] **Step 4: Implementa `tools/sign_repo.sh`**

Script bash con `set -euo pipefail`. Comportamiento:
1. Valida `--repo`, `--gpgdir`, `--key`.
2. Localiza la DB: el primer `*.db` de `--repo` en orden lexicográfico. Si no hay ninguna, sale con 1 y `no hay base de datos que firmar`.
3. Si `<db>.sig` ya existe, imprime `ya firmado` por stderr y sale con 1.
4. Firma:
   ```bash
   gpg --homedir "$GPGDIR" --batch --yes --local-user "$KEY" --detach-sign "$DB"
   ```
   Esto produce `<db>.sig`.

- [ ] **Step 5: Crea `packages/nimbus-keyring/PKGBUILD` y `nimbus-keyring.install`**

`packages/nimbus-keyring/PKGBUILD`:
```bash
# SPDX-License-Identifier: GPL-3.0-or-later
pkgname=nimbus-keyring
pkgver=20261021
pkgrel=1
pkgdesc="Clave pública de firma de los paquetes de Nimbus"
arch=('any')
license=('GPL-3.0-or-later')
url="https://github.com/juanpimg/NimbusOS"
install=nimbus-keyring.install
source=("nimbus.gpg" "nimbus-trusted" "nimbus-revoked")
sha256sums=('SKIP')
package() {
  install -Dm644 nimbus.gpg "$pkgdir/usr/share/pacman/keyrings/nimbus.gpg"
  install -Dm644 nimbus-trusted "$pkgdir/usr/share/pacman/keyrings/nimbus-trusted"
  install -Dm644 nimbus-revoked "$pkgdir/usr/share/pacman/keyrings/nimbus-revoked"
}
```

`packages/nimbus-keyring/nimbus-keyring.install`:
```
usr/share/pacman/keyrings/nimbus.gpg
usr/share/pacman/keyrings/nimbus-trusted
usr/share/pacman/keyrings/nimbus-revoked
post_install() {
  pacman-key --populate nimbus
}
```

- [ ] **Step 6: Ejecuta los tests para verificar que pasan**

Run: `bats tests/keyring.bats`
Expected: PASS — 4 passed.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: nimbus keyring, offline GPG signing and rotation tooling"
```

---

### Task 3: Canales `testing` y `stable` — el modelo de pins

**Files:**
- Create: `tools/promote.sh`
- Create: `tools/verify_repo.sh`
- Create: `packages/README.md`
- Create: `tests/promote.bats`

**Interfaces:**
- Consumes: `tools/sign_repo.sh` (Task 2).
- Produces:
  - `tools/promote.sh --from <dir> --to <dir> --gpgdir <dir> --key <fpr>` → copia los `*.pkg.tar.zst` de `--from` a `--to` **solo si** no existe ya allí un paquete con el mismo `nombre-versión`; indexa el repo de destino con `repo-add` y firma la DB resultante con `tools/sign_repo.sh`. Si `--from` está vacío, deja `--to` intacto pero **regenera y firma** la DB. Sale con 1 si algún paquete colisiona.
  - `tools/verify_repo.sh --repo <dir> --gpgdir <dir>` → verifica la firma de la DB y la firma de cada paquete; exit 0 si todo cuadra, exit 1 e imprime la lista de fallos.
  - `packages/README.md` documenta el modelo: qué repos son rolling, qué repos son pineados, cómo se promueve, cómo se rota la clave.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/promote.bats`:

```bats
#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  TESTDIR="$(mktemp -d)"
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/key" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/key/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  mkdir -p "$TESTDIR/testing" "$TESTDIR/stable"
}

teardown() {
  rm -rf "$TESTDIR"
}

_make_pkg() {
  local name="$1" ver="$2"
  local dir="$TESTDIR/build/$name-$ver"
  rm -rf "$dir"; mkdir -p "$dir"
  # Un paquete pacman válido necesita .PKGINFO y .MTREE; repo-add rechaza
  # cualquier otra cosa, así que aquí se construyen a mano (sin makepkg, que
  # se niega a correr como root y rompería el CI en contenedores).
  printf 'pkgname = %s\npkgver = %s\npkgrel = 1\npkgdesc = paquete de prueba\nurl = https://example.org\nbuilddate = 1700000000\npackager = Test <test@example.org>\nsize = 1\narch = x86_64\nlicense = GPL-3.0-or-later\n' "$name" "$ver" > "$dir/.PKGINFO"
  printf 'contenido\n' > "$dir/dato"
  ( cd "$dir" && bsdtar -cf - --format=mtree .PKGINFO dato | gzip -c > "$dir/.MTREE" )
  ( cd "$dir" && bsdtar -czf "$TESTDIR/testing/${name}-${ver}-x86_64.pkg.tar.gz" .PKGINFO .MTREE dato )
}

@test "promote copia paquetes y produce una DB firmada" {
  _make_pkg nimbus-shell 0.1.0
  run bash "$REPO_ROOT/tools/promote.sh" --from "$TESTDIR/testing" --to "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg" --key "$FPR"
  [ "$status" -eq 0 ]
  [ -f "$TESTDIR/stable/nimbus-shell-0.1.0-x86_64.pkg.tar.gz" ]
  [ -f "$TESTDIR/stable/nimbus.db" ]
  [ -f "$TESTDIR/stable/nimbus.db.sig" ]
}

@test "promote se niega a sobrescribir la misma versión" {
  _make_pkg nimbus-shell 0.1.0
  bash "$REPO_ROOT/tools/promote.sh" --from "$TESTDIR/testing" --to "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg" --key "$FPR"
  run bash "$REPO_ROOT/tools/promote.sh" --from "$TESTDIR/testing" --to "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg" --key "$FPR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ya existe"* ]]
}

@test "promote con testing vacío deja stable intacto pero firmado" {
  run bash "$REPO_ROOT/tools/promote.sh" --from "$TESTDIR/testing" --to "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg" --key "$FPR"
  [ "$status" -eq 0 ]
  [ -f "$TESTDIR/stable/nimbus.db.sig" ]
  [ -z "$(ls -A "$TESTDIR/stable" | grep pkg.tar || true)" ]
}

@test "verify_repo detecta un paquete manipulado" {
  _make_pkg nimbus-shell 0.1.0
  bash "$REPO_ROOT/tools/promote.sh" --from "$TESTDIR/testing" --to "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg" --key "$FPR"
  run bash "$REPO_ROOT/tools/verify_repo.sh" --repo "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg"
  [ "$status" -eq 0 ]
  printf 'manipulado\n' >> "$TESTDIR/stable/nimbus-shell-0.1.0-x86_64.pkg.tar.gz"
  run bash "$REPO_ROOT/tools/verify_repo.sh" --repo "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg"
  [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `bats tests/promote.bats`
Expected: FAIL — `tools/promote.sh` y `tools/verify_repo.sh` no existen.

- [ ] **Step 3: Implementa `tools/promote.sh`**

Script bash con `set -euo pipefail`. Comportamiento:
1. Valida `--from`, `--to`, `--gpgdir`, `--key`.
2. Recorre los `*.pkg.tar.*` de `--from`. Para cada uno extrae `nombre-versión` del nombre de fichero (todo antes del sufijo `-<arquitectura>.pkg.tar.*`) y comprueba si ya existe en `--to` un fichero con ese prefijo. Si existe: imprime `el paquete <nombre-versión> ya existe en el destino` y **sale con 1 sin copiar nada más** (promoción atómica: o todo o nada).
3. Copia los paquetes no colisionados a `--to`.
4. Indexa con `repo-add`. Si no hay paquetes, se crea una DB vacía:
   ```bash
   shopt -s nullglob
   pkgs=("$TO"/*.pkg.tar.*)
   shopt -u nullglob
   if [ ${#pkgs[@]} -gt 0 ]; then
       repo-add "$TO/nimbus.db.tar.gz" "${pkgs[@]}"
   fi
   ```
   **La base de datos se llama `nimbus.db.tar.gz`, no `nimbus.db`.** pacman 7 rechaza
   `nimbus.db` con el error "does not have a valid database archive extension". `repo-add`
   crea el archivo `nimbus.db.tar.gz` y un **symlink** `nimbus.db` -> `nimbus.db.tar.gz`;
   pacman sigue leyendo la base como `nimbus.db` y la firma como `nimbus.db.sig`, asi que
   el contrato de `tools/sign_repo.sh` (busca el primer `*.db` lexicografico) se mantiene.

   `repo-add` requiere el paquete `repo` (`pacman -S repo`). Si no está disponible, el script imprime `repo-add no encontrado: instala el paquete repo` y sale con 1.

   **Si no hay paquetes que promover, la DB del destino NO se toca**: `repo-add` con cero
   paquetes responde "No changes made to package database" y no crea ningun archivo, y un
   tar vacio manufactured no es una base de datos valida para pacman.
5. Firma la DB con `tools/sign_repo.sh --repo "$TO" --gpgdir "$GPGDIR" --key "$KEY"`.

**Nota:** el test usa `.pkg.tar.gz` (no `.zst`) porque `repo-add` y `pacman` aceptan ambos, pero `.zst` requiere `zstd`. Mantén el soporte de ambos patrones en el glob: `*.pkg.tar.zst` y `*.pkg.tar.gz`.

- [ ] **Step 4: Implementa `tools/verify_repo.sh`**

Script bash con `set -euo pipefail`. Comportamiento:
1. Valida `--repo` y `--gpgdir`.
2. Verifica cada paquete con `gpg --homedir "$GPGDIR" --verify <paquete> <firma>`; si un paquete no tiene fichero `.sig` contiguo, se considera fallo.
3. Verifica la DB: `gpg --homedir "$GPGDIR" --verify "$REPO/nimbus.db.sig" "$REPO/nimbus.db"`.
4. Acumula fallos; si hay alguno, imprime la lista y sale con 1. Si no, imprime `repo verificado: N paquetes` y sale con 0.

- [ ] **Step 5: Escribe `packages/README.md`**

Documenta, con ejemplos de comandos reales:
- Qué repos son rolling (cachyos, cachyos-v3, cachyos-v4, core, extra) y cuáles son pineados (`nimbus`).
- El flujo `testing` → `stable`: la CI compila y publica en `testing` **sin firmar**; la promoción es manual con la clave offline.
- El contrato de `promote.sh` y `verify_repo.sh`.
- **Rotación de clave:** procedimiento en 6 pasos (generar clave nueva, firmar todo el repo actual con la nueva, publicar el nuevo keyring, añadir la clave nueva al keyring de los usuarios, revocar la antigua, actualizar `nimbus-keyring`).
- La regla: **la clave offline se guarda cifrada en dos sitios y el procedimiento de recuperación está escrito aquí**.

- [ ] **Step 6: Ejecuta los tests para verificar que pasan**

Run: `bats tests/promote.bats`
Expected: PASS — 4 passed. Si falla por `repo-add no encontrado`, instala el paquete: `sudo pacman -S repo`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: pin model with testing and stable channels and manual promotion"
```

---

### Task 4: Tokens de diseño y configuración del shell (`Theme` y `Config`)

**Files:**
- Create: `shell/src/Nimbus/qmldir`
- Create: `shell/src/Theme.qml`
- Create: `shell/src/Config.qml`
- Create: `shell/src/Translations.qml`
- Create: `shell/src/main.qml`
- Create: `shell/tests/tst_theme.qml`
- Create: `shell/tests/tst_config.qml`
- Create: `shell/nimbus-shell`
- Create: `packages/nimbus-shell/PKGBUILD`

**Interfaces:**
- Consumes: nada (arranca en paralelo con Task 2 y 3).
- Produces:
  - Módulo QML `Nimbus` con los singletons `Theme`, `Config` y `Translations`, registrado en
    **`shell/src/Nimbus/qmldir`** (no en `shell/src/qmldir`):
    ```
    module Nimbus
    singleton Theme 1.0 Theme.qml
    singleton Config 1.0 Config.qml
    ```
  - `Theme` — propiedades de solo lectura y setters:
    - `dark: bool`
    - `background: color`, `surface: color`, `surfaceAlt: color`, `text: color`, `textMuted: color`, `separator: color`, `accent: color`, `glass: color`, `glassOpaque: color`
    - `radius: int` (12), `spacing: int` (8), `barHeight: int` (28), `dockSize: int` (64)
    - `fontFamily: string` ("Inter")
    - `setMode(mode: string): void` — `"light"` | `"dark"` | `"auto"`
    - `setAccent(value: color): void`
  - `shell/src/Translations.qml` — singleton QML con la tabla ES/EN y la función de lookup con **fallback a inglés**:
    ```qml
    // SPDX-License-Identifier: GPL-3.0-or-later
    pragma Singleton
    import QtQuick

    QtObject {
        property var table: ({
            "es": {
                "app.store.title": "Nimbus Store",
                "app.settings.title": "Ajustes del sistema",
                "app.dock.title": "Dock"
            },
            "en": {
                "app.store.title": "Nimbus Store",
                "app.settings.title": "System Settings",
                "app.dock.title": "Dock"
            }
        })

        function lookup(locale, key) {
            var lang = String(locale || "en").split("-")[0]
            if (table[lang] && table[lang][key] !== undefined)
                return table[lang][key]
            if (table["en"] && table["en"][key] !== undefined)
                return table["en"][key]
            return key
        }
    }
    ```
    Se usa un singleton QML y **no** un `.js` con `pragma library` para evitar el
    `import Nimbus.Translations` frente a `import "Translations.js"`, que es la causa
    habitual de "Cannot find module" en Quickshell.
  - `Config` — propiedades y setters:
    - `schemaVersion: int` (2)
    - `mode: string` ("light" | "dark" | "auto")
    - `accent: string` (hex, sin `#`)
    - `locale: string` (código BCP-47, p. ej. `"es"`, `"en"`, `"de"`)
    - `setMode(mode: string): void`, `setAccent(hex: string): void`, `setLocale(tag: string): void`
    - `migrateFrom(oldVersion: int): void` — migra una configuración de un esquema anterior
    - `translated(key: string): string` — devuelve la cadena en el idioma activo, y **cae a inglés** si no existe traducción; si tampoco existe en inglés, devuelve la propia clave.
  - Paquete `nimbus-shell` — instala el shell en `/usr/lib/nimbus/shell/` y el launcher `/usr/bin/nimbus-shell`.

**Valores de color exactos** (el test los fija; no los cambies sin actualizar el test):

| Token | Claro | Oscuro |
|-------|-------|---------|
| `background` | `#F5F5F7` | `#1C1C1E` |
| `surface` | `#FFFFFF` | `#2C2C2E` |
| `surfaceAlt` | `#ECECEE` | `#3A3A3C` |
| `text` | `#1D1D1F` | `#F5F5F7` |
| `textMuted` | `#6E6E73` | `#98989D` |
| `separator` | `#D2D2D7` | `#38383A` |
| `accent` (por defecto) | `#007AFF` | `#0A84FF` |
| `glass` | `#80FFFFFF` (50 % blanco) | `#8C1C1C1E` (55 %) |
| `glassOpaque` | `#ECECEE` | `#3A3A3C` |

- [ ] **Step 1: Escribe los tests que fallan**

Crea `shell/tests/tst_theme.qml`:

```qml
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Theme"
    when: true

    function init() {
        Theme.setMode("light")
        Theme.setAccent("#007AFF")
    }

    function test_light_defaults() {
        compare(Theme.background, "#f5f5f7")
        compare(Theme.surface, "#ffffff")
        compare(Theme.surfaceAlt, "#ececee")
        compare(Theme.text, "#1d1d1f")
        compare(Theme.textMuted, "#6e6e73")
        compare(Theme.separator, "#d2d2d7")
        compare(Theme.accent, "#007aff")
        compare(Theme.radius, 12)
        compare(Theme.spacing, 8)
        compare(Theme.barHeight, 28)
        compare(Theme.dockSize, 64)
        compare(Theme.fontFamily, "Inter")
    }

    function test_dark_mode() {
        Theme.setMode("dark")
        compare(Theme.background, "#1c1c1e")
        compare(Theme.surface, "#2c2c2e")
        compare(Theme.surfaceAlt, "#3a3a3c")
        compare(Theme.text, "#f5f5f7")
        compare(Theme.textMuted, "#98989d")
        compare(Theme.separator, "#38383a")
        compare(Theme.accent, "#0a84ff")
        compare(Theme.dark, true)
    }

    function test_accent_is_overridable() {
        Theme.setAccent("#ff2d55")
        compare(Theme.accent, "#ff2d55")
    }

    function test_glass_has_opaque_fallback() {
        Theme.setMode("light")
        verify(Theme.glassOpaque.a === 1.0, "glassOpaque debe ser totalmente opaco")
        Theme.setMode("dark")
        verify(Theme.glassOpaque.a === 1.0, "glassOpaque debe ser totalmente opaco")
    }
}
```

Crea `shell/tests/tst_config.qml`:

```qml
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Nimbus

TestCase {
    name: "Config"
    when: true

    function test_defaults() {
        compare(Config.schemaVersion, 2)
        compare(Config.mode, "light")
        compare(Config.locale, "es")
    }

    function test_falls_back_to_english_for_unknown_locale() {
        Config.setLocale("de")
        compare(Config.locale, "de")
        compare(Config.translated("app.store.title"), "Nimbus Store")
    }

    function test_migrates_older_config_schema() {
        Config.setMode("dark")
        Config.setAccent("#ff2d55")
        Config.migrateFrom(1)
        compare(Config.schemaVersion, 2)
        compare(Config.mode, "dark")
        compare(Config.accent, "ff2d55")
    }
}
```

- [ ] **Step 2: Ejecuta los tests para verificar que fallan**

Run: `qmltestrunner -input shell/tests`
Expected: FAIL — `Cannot find module "Nimbus"` (el `qmldir` y los singletons aún no existen).

- [ ] **Step 3: Implementa `shell/src/Theme.qml`**

```qml
// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool _dark: false
    readonly property bool dark: _dark

    readonly property color background: dark ? "#1C1C1E" : "#F5F5F7"
    readonly property color surface: dark ? "#2C2C2E" : "#FFFFFF"
    readonly property color surfaceAlt: dark ? "#3A3A3C" : "#ECECEE"
    readonly property color text: dark ? "#F5F5F7" : "#1D1D1F"
    readonly property color textMuted: dark ? "#98989D" : "#6E6E73"
    readonly property color separator: dark ? "#38383A" : "#D2D2D7"
    readonly property color glass: dark ? "#8C1C1C1E" : "#80FFFFFF"
    readonly property color glassOpaque: dark ? "#3A3A3C" : "#ECECEE"

    readonly property int radius: 12
    readonly property int spacing: 8
    readonly property int barHeight: 28
    readonly property int dockSize: 64
    readonly property string fontFamily: "Inter"

    readonly property color _accentLight: "#007AFF"
    readonly property color _accentDark: "#0A84FF"
    // El acento elegido por el usuario gana en los DOS modos.
    property string _userAccent: ""   // string, no color: "" no es un inicializador valido para color
    readonly property color accent: _userAccent !== "" ? _userAccent
                                                       : (dark ? _accentDark : _accentLight)

    function setMode(mode) {
        if (mode === "dark") {
            _dark = true
            return
        }
        if (mode === "light") {
            _dark = false
            return
        }
        // "auto": se resuelve con el esquema de color del sistema. La comprobación
        // es defensiva porque Qt.application es null bajo qmltestrunner.
        _dark = (Qt.application !== null && Qt.application !== undefined
                 && Qt.application.styleHints !== undefined
                 && Qt.application.styleHints.colorScheme === Qt.Dark)
    }

    function setAccent(value) {
        _userAccent = value
    }

    function resetAccent() {
        _userAccent = ""
    }
}
```

**Sobre `setAccent`:** el acento es el mismo en claro y en oscuro para evitar que un acento elegido por el usuario se vuelva ilegible sobre el fondo oscuro. El test solo comprueba `Theme.accent`.

- [ ] **Step 4: Implementa `shell/src/Config.qml`**

```qml
// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick
import Nimbus

QtObject {
    id: root

    readonly property int schemaVersion: 2

    property string mode: "light"
    property string accent: "007aff"
    property string locale: "es"

    function setMode(value) {
        if (value === "light" || value === "dark" || value === "auto")
            mode = value
        Theme.setMode(mode)
    }

    function setAccent(hex) {
        if (typeof hex !== "string")
            return
        accent = hex.replace("#", "").toLowerCase()
        Theme.setAccent("#" + accent)
    }

    function setLocale(tag) {
        locale = tag
    }

    function migrateFrom(oldVersion) {
        if (oldVersion < 2) {
            // v1 usaba "accentColor" y no distinguía el acento claro del oscuro.
            mode = mode === "auto" ? "light" : mode
        }
    }

    function translated(key) {
        return Translations.lookup(locale, key)
    }
}
```

Crea además `shell/src/Translations.qml` con el singleton del bloque de Interfaces
(Step 4, segundo bloque de código).

- [ ] **Step 5: Crea `shell/src/Nimbus/qmldir` y `shell/src/main.qml`**

`shell/src/Nimbus/qmldir`:
```
module Nimbus
singleton Theme 1.0 Theme.qml
singleton Config 1.0 Config.qml
singleton Translations 1.0 Translations.qml
```

`shell/src/main.qml` — punto de entrada mínimo por ahora (el shell completo llega en el Plan 2):
```qml
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Nimbus

Window {
    width: 640
    height: 360
    visible: true
    color: Theme.background
    title: qsTr("Nimbus")
    Text {
        anchors.centerIn: parent
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 16
        text: Config.translated("app.store.title")
    }
}
```

- [ ] **Step 6: Ejecuta los tests para verificar que pasan**

Run: `QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH=$PWD/shell/src /usr/lib/qt6/bin/qmltestrunner -input shell/tests`
Expected: PASS — Theme: 4 passed, Config: 3 passed.

Si `qmltestrunner` no encuentra el módulo, añade `shell/src` al `QML2_IMPORT_PATH`. El
**El `qmldir` va en `shell/src/Nimbus/`, NO en `shell/src/`.** Verificado empiricamente: con
`shell/src/qmldir` el import `import Nimbus` falla con `module "Nimbus" is not installed`,
porque QML resuelve un modulo buscando un **directorio** con ese nombre en el `QML2_IMPORT_PATH`.
El layout plano solo resolveria `import src`.

- [ ] **Step 7: Crea `packages/nimbus-shell/PKGBUILD`**

```bash
# SPDX-License-Identifier: GPL-3.0-or-later
pkgname=nimbus-shell
pkgver=0.1.0
pkgrel=1
pkgdesc="Shell de escritorio Nimbus para Hyprland (Quickshell/QML)"
arch=('any')
license=('GPL-3.0-or-later')
depends=('quickshell>=0.3.2' 'hyprland>=0.56.2' 'qt6-declarative' 'qt6-wayland' 'qt6-shadertools' 'inter-font')
# Monorepo: el paquete se compila desde el árbol local, sin clonar de GitHub.
# Cuando el repo se divida por subsistema, esto pasa a
# source=('shell::git+https://github.com/juanpimg/NimbusOS.git').
source=()
sha256sums=()
package() {
  cp -r "$startdir/../../shell/src" "$pkgdir/usr/lib/nimbus/shell/src"
  install -Dm755 "$startdir/../../shell/nimbus-shell" "$pkgdir/usr/bin/nimbus-shell"
}
```

`shell/nimbus-shell`, un launcher de 3 líneas:
```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
export QML2_IMPORT_PATH="/usr/lib/nimbus/shell/src:${QML2_IMPORT_PATH}"
exec qs -c /usr/lib/nimbus/shell/src "$@"
```

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: design tokens and versioned config singletons for the Nimbus shell"
```

---

### Task 5: Configuración de Hyprland — layout flotante y atajos Apple

**Files:**
- Create: `dots/hypr/hyprland.lua`
- Create: `dots/hypr/quirks.conf`
- Create: `dots/nimbus/defaults.conf`
- Create: `dots/nimbus/nimbus-start`
- Create: `packages/nimbus-dots/PKGBUILD`
- Create: `tests/test_hyprland_config.py`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `dots/hypr/hyprland.lua` — config Lua de Hyprland 0.55+. Debe declarar `layout = floating`, los binds de la tabla de abajo, y una sesión de emergencia.
  - `dots/nimbus/defaults.conf` — fichero INI con las claves de configuración del shell que el usuario puede editar (fichero INI plano, sección `[nimbus]`).
  - Contrato de binds (clave → acción), verificado por test.

**Binds requeridos** (el test los fija):

| Tecla | Acción |
|-------|--------|
| `SUPER, Return` | abrir terminal (`kitty`) |
| `SUPER, D` | alternar dock |
| `SUPER, Space` | Spotlight |
| `SUPER, Tab` | switcher |
| `SUPER, Q` | cerrar ventana |
| `SUPER, W` | cerrar ventana |
| `SUPER, C` | copiar |
| `SUPER, V` | pegar |
| `SUPER, 1` … `SUPER, 9` | workspace N |
| `SUPER, L` | bloquear pantalla |
| `PRINT` | captura de región |

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_hyprland_config.py`:

```python
import pathlib
import re
import shutil
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONFIG = ROOT / "dots" / "hypr" / "hyprland.lua"
QUIRKS = ROOT / "dots" / "hypr" / "quirks.conf"

REQUIRED_BINDS = {
    "SUPER + Return": "kitty",
    "SUPER + D": "dock",
    "SUPER + Space": "spotlight",
    "SUPER + Tab": "switcher",
    "SUPER + Q": "window.close",
    "SUPER + W": "window.close",
    "SUPER + C": "send_shortcut",
    "SUPER + V": "send_shortcut",
    "SUPER + L": "lock",
    "PRINT": "screenshot",
}

# La config usa la API Lua de Hyprland 0.56: hl.bind("MOD + KEY", dispatcher).
# El primer argumento es un unico string combinado; el segundo es la accion,
# capturada hasta el fin de linea.
BIND_RE = re.compile(
    r'hl\.bind\(\s*"(?P<keys>[^"]+)"\s*,\s*(?P<action>[^\n]+)$',
    re.M,
)


def _binds():
    text = CONFIG.read_text(encoding="utf-8")
    out = []
    for match in BIND_RE.finditer(text):
        out.append((match.group("keys").strip(), match.group("action")))
    return out


def _find(keys, action):
    """Devuelve la accion del bind cuya combinacion de teclas coincide, o None."""
    for bound_keys, bound_action in _binds():
        if bound_keys == keys and action in bound_action:
            return bound_action
    return None


def test_config_file_exists():
    assert CONFIG.is_file()


def test_config_is_valid_lua():
    # OJO: luac -p valida SOLO la sintaxis. No comprueba que hl.bind o
    # hl.dsp.* existan en Hyprland 0.56: una llamada a una API inexistente es
    # Lua valido. La prueba real de carga es arrancar Hyprland con la config.
    if shutil.which("luac") is None:
        pytest.skip("luac no disponible")
    result = subprocess.run(["luac", "-p", str(CONFIG)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr


def test_layout_is_floating():
    quirks = QUIRKS.read_text(encoding="utf-8")
    assert re.search(r"^\s*layout\s*=\s*floating", quirks, re.M)
    assert "floating" in CONFIG.read_text(encoding="utf-8")


def test_required_bindings_are_present():
    missing = []
    for keys, action in REQUIRED_BINDS.items():
        if _find(keys, action) is None:
            missing.append(f"{keys} -> {action}")
    assert missing == [], "\n".join(missing)


def test_workspace_bindings_one_through_nine():
    missing = [
        str(n) for n in range(1, 10) if _find(f"SUPER + {n}", "workspace") is None
    ]
    assert missing == [], f"faltan binds de workspace: {missing}"


def test_emergency_session_is_declared_and_bound():
    # El bind de emergencia debe existir de verdad, no solo la palabra en un
    # comentario: se busca con el mismo regex que el resto.
    assert _find("SUPER + SHIFT + E", "emergency") is not None
    text = CONFIG.read_text(encoding="utf-8")
    assert "kitty" in text


def test_emergency_terminal_is_fullscreen():
    # La emergencia sirve para recuperar el escritorio: sin regla de ventana a
    # pantalla completa, el terminal sale flotante y no cumple su funcion.
    quirks = QUIRKS.read_text(encoding="utf-8")
    assert re.search(r"windowrule.*fullscreen.*emergency", quirks, re.I)
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `python -m pytest tests/test_hyprland_config.py -v`
Expected: FAIL — `CONFIG.is_file()` es False porque `dots/hypr/hyprland.lua` no existe.

- [ ] **Step 3: Escribe `dots/hypr/hyprland.lua`**

Config Lua de Hyprland 0.55+. Usa la API `hl.bind` / `hl.dsp` / `hl.on` / `hl.exec_cmd`. Contenido obligatorio:

**REGLA CRÍTICA DE Hyprland 0.56 EN MODO LUA.** Cuando la config principal es
`hyprland.lua`, **los ficheros `.conf` sueltos que la acompañen NO se cargan**: la wiki lo
dice — "Use `require()` to source other files into your config". Por eso **todo** (layout,
window rules, animaciones) va **dentro de `hyprland.lua`** con la API nativa
(`hl.config(...)`, `hl.window_rule(...)`). Un `quirks.conf` junto a la config Lua es un
fichero muerto.

**API REAL de Hyprland 0.56 (verificada contra `Hyprland/example/hyprland.lua` oficial;
el plan original usaba una API inexistente):**
`hl.bind` toma **dos** argumentos: el primero es un **único string con los modificadores
y la tecla separados por `+`** (`"SUPER + SHIFT + E"`), el segundo es el dispatcher.
Los dispatchers que existen son `hl.dsp.exec_cmd`, `hl.dsp.window.close`,
`hl.dsp.focus({workspace = "..."})` y `hl.dsp.send_shortcut`. **No** existen
`hl.dsp.closewindow`, `hl.dsp.copy`, `hl.dsp.paste` ni `hl.dsp.workspace(N)`.

```lua
-- SPDX-License-Identifier: GPL-3.0-or-later

local function shell(action)
    return hl.dsp.exec_cmd("nimbus-shell ipc call " .. action)
end

-- Layout flotante, de forma nativa (no con hyprctl, no en un .conf aparte).
hl.config({
    general = {
        layout = "floating",
    },
    decoration = {
        rounding = 12,
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
        },
    },
})

-- La sesion de emergencia se abre a pantalla completa.
hl.window_rule({
    name = "nimbus-emergency-fullscreen",
    match = { class = "emergency" },
    fullscreen = true,
})

hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + D", shell("dock toggle"))
hl.bind("SUPER + Space", shell("spotlight toggle"))
hl.bind("SUPER + Tab", shell("switcher next"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + W", hl.dsp.window.close())
hl.bind("SUPER + C", hl.dsp.send_shortcut("SUPER, C"))
hl.bind("SUPER + V", hl.dsp.send_shortcut("SUPER, V"))
hl.bind("SUPER + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("PRINT", shell("screenshot region"))

-- Los bindings de workspace se escriben de forma literal: el test los busca
-- uno a uno y un bucle con tostring() no sería detectable.
hl.bind("SUPER + 1", hl.dsp.focus({workspace = 1}))
hl.bind("SUPER + 2", hl.dsp.focus({workspace = 2}))
hl.bind("SUPER + 3", hl.dsp.focus({workspace = 3}))
hl.bind("SUPER + 4", hl.dsp.focus({workspace = 4}))
hl.bind("SUPER + 5", hl.dsp.focus({workspace = 5}))
hl.bind("SUPER + 6", hl.dsp.focus({workspace = 6}))
hl.bind("SUPER + 7", hl.dsp.focus({workspace = 7}))
hl.bind("SUPER + 8", hl.dsp.focus({workspace = 8}))
hl.bind("SUPER + 9", hl.dsp.focus({workspace = 9}))

-- Sesión de emergencia: si el shell de Nimbus falla, el usuario cae aquí con
-- un terminal a pantalla completa (la regla de ventana está en quirks.conf)
-- y puede matar el proceso o cambiar de sesión.
local function emergency()
    hl.dsp.exec_cmd("kitty --class emergency")
end
hl.bind("SUPER + SHIFT + E", emergency)

hl.on("hyprland.start", function()
    hl.exec_cmd("sh /usr/lib/nimbus/dots/nimbus-start")
end)
```

Además, el fichero debe:
1. Contener la cadena `emergency` (para la sesión de recuperación) — ya está en el código de arriba.
2. Poner el layout en flotante. La API Lua de Hyprland 0.56 expone el layout de forma distinta a la clásica, así que **el layout se fija en `dots/hypr/quirks.conf`** (paso siguiente) y la config Lua lo aplica al arrancar con `hyprctl keyword layout floating`. El test comprueba `quirks.conf` para el layout y `hyprland.lua` para la palabra `floating`.

**Nota para el implementador:** comprueba la API real de Hyprland 0.56.2 (`hyprctl dispatch 'hl.dsp.no_op()'` no debe dar error) y ajusta los nombres de función a los que existen. **El test fija el contrato, no la sintaxis exacta**; lo que no puede cambiar es qué binds existen y qué acción invocan.

- [ ] **Step 4: Escribe `dots/hypr/quirks.conf` y `dots/nimbus/defaults.conf`**

`dots/hypr/quirks.conf` — ajustes clásicos que no tienen equivalente en la API Lua:
```
# SPDX-License-Identifier: GPL-3.0-or-later
layout = floating
no_border_on_floating = true
float_on_open = 2
border_size = 2
gaps_in = 4
gaps_out = 8
animations.enabled = true
general.allow_session_lock_restore = true
cursor.no_hardware_cursors = true
misc.session_lock_restore = true
```

`dots/nimbus/defaults.conf`:
```ini
# SPDX-License-Identifier: GPL-3.0-or-later
[nimbus]
mode = light
accent = 007AFF
locale = es
dockPosition = bottom
dockSize = 64
dockAutohide = false
dockMagnification = 1.25
barPosition = top
barHeight = 28
glassEnabled = true
glassQuality = high
showWidgets = false
```

- [ ] **Step 5: Escribe `dots/nimbus/nimbus-start` y `packages/nimbus-dots/PKGBUILD`**

`dots/nimbus/nimbus-start` — arranque del shell desde Hyprland:
```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

# Aplica el layout flotante antes de que entre el shell.
hyprctl keyword layout floating >/dev/null 2>&1 || true

# Espera a que el compositor esté listo y arranca el shell.
exec /usr/bin/nimbus-shell
```

`packages/nimbus-dots/PKGBUILD`:
```bash
# SPDX-License-Identifier: GPL-3.0-or-later
pkgname=nimbus-dots
pkgver=0.1.0
pkgrel=1
pkgdesc="Configuración de Hyprland y defaults del sistema para Nimbus"
arch=('any')
license=('GPL-3.0-or-later')
depends=('hyprland>=0.56.2' 'nimbus-shell' 'kitty')
# Monorepo: se compila desde el árbol local. Al dividir el repo, esto pasa a
# source=('dots::git+https://github.com/juanpimg/NimbusOS.git').
source=()
sha256sums=()
package() {
  install -Dm644 "$startdir/../../dots/hypr/hyprland.lua" "$pkgdir/usr/lib/nimbus/dots/hypr/hyprland.lua"
  install -Dm644 "$startdir/../../dots/hypr/quirks.conf" "$pkgdir/usr/lib/nimbus/dots/hypr/quirks.conf"
  install -Dm644 "$startdir/../../dots/nimbus/defaults.conf" "$pkgdir/usr/lib/nimbus/dots/defaults.conf"
  install -Dm755 "$startdir/../../dots/nimbus/nimbus-start" "$pkgdir/usr/lib/nimbus/dots/nimbus-start"
}
```

- [ ] **Step 6: Ejecuta el test para verificar que pasa**

Run: `python -m pytest tests/test_hyprland_config.py -v`
Expected: PASS — 6 passed.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: floating Hyprland layout with macOS-style keybindings and emergency session"
```

---

### Task 6: Perfil archiso y constructor de la ISO

**Files:**
- Create: `iso/build.sh`
- Create: `iso/profiles/nimbus/airoot.sh`
- Create: `iso/profiles/nimbus/packages.x86_64`
- Create: `iso/profiles/nimbus/customize.sh`
- Create: `iso/profiles/nimbus/file-contexts.sh`
- Create: `iso/profiles/nimbus/overlay/usr/lib/systemd/system/nimbus-live.service`
- Create: `iso/profiles/nimbus/overlay/usr/lib/systemd/system/nimbus-live-ready.service`
- Create: `tests/test_iso_profile.py`

**Interfaces:**
- Consumes: `packages/nimbus-shell` (Task 4) y `packages/nimbus-dots` (Task 5).
- Produces:
  - `iso/build.sh --outdir <dir> [--local-repo]` → construye la ISO con `archiso` y produce `<outdir>/nimbus-<YYYYMMDD>-<git-short-sha>.iso`. `--local-repo` es una **bandera booleana sin argumento**: el directorio del repo local se deriva del directorio de trabajo. Exit != 0 si el perfil no valida o si el repo local queda vacío.
    - `--local-repo <dir>` es **imprescindible durante el bootstrap**: el repo `nimbus` todavía no está alojado en ningún servidor, así que `build.sh` compila los PKGBUILDs de `packages/` con `makepkg` en un repo local `file://` y lo añade al `pacman.conf` del perfil. Sin este flag la construcción falla, porque `nimbus-shell` no se puede resolver.
  - `nimbus-live.service` — unit systemd que **arranca el shell** en la sesión live.
  - `nimbus-live-ready.service` — unit systemd que escribe `NIMBUS_LIVE_READY` en `/dev/console` **solo si** `nimbus-live.service` arrancó bien. **Este es el marcador que Task 8 espera encontrar.**

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_iso_profile.py`:

```python
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROFILE = ROOT / "iso" / "profiles" / "nimbus"

REQUIRED_FILES = [
    "airoot.sh",
    "packages.x86_64",
    "customize.sh",
    "file-contexts.sh",
]

REQUIRED_PACKAGES = [
    "linux-cachyos",
    "hyprland",
    "quickshell",
    "nimbus-shell",
    "nimbus-dots",
    "sddm",
    "systemd",
    "xdg-desktop-portal-hyprland",
]


def test_required_profile_files_exist():
    missing = [name for name in REQUIRED_FILES if not (PROFILE / name).is_file()]
    assert missing == []


def test_profile_lists_required_packages():
    text = (PROFILE / "packages.x86_64").read_text(encoding="utf-8")
    packages = {line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")}
    missing = [p for p in REQUIRED_PACKAGES if p not in packages]
    assert missing == []


def test_customize_installs_the_nimbus_repo():
    text = (PROFILE / "customize.sh").read_text(encoding="utf-8")
    assert "nimbus" in text
    assert "nimbus-keyring" in text


def test_live_ready_marker_unit_exists_and_prints_marker():
    unit = PROFILE / "overlay" / "usr" / "lib" / "systemd" / "system" / "nimbus-live-ready.service"
    assert unit.is_file()
    text = unit.read_text(encoding="utf-8")
    assert "NIMBUS_LIVE_READY" in text
    assert "/dev/console" in text


def test_live_service_starts_the_shell_and_is_required_by_the_marker():
    live = PROFILE / "overlay" / "usr" / "lib" / "systemd" / "system" / "nimbus-live.service"
    ready = PROFILE / "overlay" / "usr" / "lib" / "systemd" / "system" / "nimbus-live-ready.service"
    assert live.is_file()
    assert "nimbus-shell" in live.read_text(encoding="utf-8")
    # El marcador no debe aparecer si el shell no arrancó: Requires= lo garantiza.
    assert "Requires=nimbus-live.service" in ready.read_text(encoding="utf-8")


def test_iso_is_smaller_than_3gb_budget():
    budget = 3 * 1024 * 1024 * 1024
    iso_dir = ROOT / "iso"
    for iso in iso_dir.glob("*.iso"):
        assert iso.stat().st_size < budget, f"{iso.name} excede el presupuesto de 3 GB"
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `python -m pytest tests/test_iso_profile.py -v`
Expected: FAIL — `REQUIRED_FILES` no existen.

- [ ] **Step 3: Escribe `iso/profiles/nimbus/packages.x86_64`**

```
# SPDX-License-Identifier: GPL-3.0-or-later
# Perfil de la ISO de Nimbus. Netinstall puro: aquí solo lo mínimo para
# arrancar la sesión live; el resto se descarga durante la instalación.
base
linux-cachyos
linux-firmware
linux-firmware-amdgpu
linux-firmware-intel
linux-firmware-nvidia
linux-firmware-other
linux-firmware-realtek
systemd
systemd-sysvcompat
pacman
pacman-contrib
hyprland
hyprlock
hypridle
hyprpicker
quickshell
qt6-declarative
qt6-wayland
qt6-shadertools
qt6-svg
xdg-desktop-portal-hyprland
xdg-desktop-portal
xdg-utils
kitty
wtype
foot
grim
slurp
wl-clipboard
pipewire
pipewire-pulse
wireplumber
networkmanager
iwd
bluez
bluez-utils
sddm
nimbus-shell
nimbus-dots
```

- [ ] **Step 4: Escribe `iso/profiles/nimbus/airoot.sh`**

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

echo "[nimbus] airoot: preparando la imagen"

# Mirrores por defecto de la ISO (los definitivos se configuran en la instalación).
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://archlinux.cachyos.org/repo/$repo/os/$arch
EOF

# El repo de Nimbus. Durante el bootstrap, build.sh lo inyecta como repo local
# file:// con el flag --local-repo; en producción, es la URL pública.
NIMBUS_REPO_URL="${NIMBUS_REPO_URL:-file:///run/archiso/bootmnt/nimbus-repo}"
cat > /etc/pacman.d/mirrorlist.nimbus <<EOF
Server = ${NIMBUS_REPO_URL}
EOF
cat >> /etc/pacman.conf <<'EOF'

[nimbus]
# TODO(bootstrap): el repo local de bootstrap va sin firmar, asi que la
# verificacion se relaja. Cuando el repo publico este alojado y firmado
# (repo de produccion), esto pasa a:
#   SigLevel = Required DatabaseOptional
SigLevel = Optional
Server = file:///run/archiso/bootmnt/nimbus-repo
EOF

pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm nimbus-keyring
pacman -S --noconfirm --needed nimbus-shell nimbus-dots

# Se activa el servicio que arranca el shell de la sesión live.
systemctl enable nimbus-live.service
```

- [ ] **Step 5: Escribe `iso/profiles/nimbus/customize.sh`**

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

echo "[nimbus] customize: ajustando la imagen"

# Marca de Nimbus en el sistema.
cat > /etc/os-release <<'EOF'
NAME="Nimbus"
PRETTY_NAME="Nimbus Linux"
ID=nimbus
ID_LIKE=arch cachyos
ANSI_COLOR="38;2;0;122;255"
HOME_URL="https://github.com/juanpimg/NimbusOS"
EOF

# Mot de passe y configuracion de la sesion live.
echo "root:nimbus" | chpasswd

# En la ISO live la sesion la aporta nimbus-live.service, no SDDM: dos gestores
# de display peleandose por la pantalla hacen que la sesion parpadee.
systemctl disable sddm.service 2>/dev/null || true
cat > /etc/sddm.conf <<'EOF'
[Autologin]
Session=hyprland
User=nimbus
EOF

# El repo de Nimbus queda disponible para la instalación.
pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm nimbus-keyring
pacman -S --noconfirm --needed nimbus-shell nimbus-dots
```

- [ ] **Step 6: Escribe `iso/profiles/nimbus/file-contexts.sh`**

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

# Contexto de SELinux (no se usa en Nimbus, pero archiso lo exige).
echo "system_u:object_r:usr_t:s0 /usr/lib/nimbus(/.*)?"
```

- [ ] **Step 7: Escribe los units de la sesión live**

`iso/profiles/nimbus/overlay/usr/lib/systemd/system/nimbus-live.service` — **arranca el shell**:
```ini
# SPDX-License-Identifier: GPL-3.0-or-later
[Unit]
Description=Nimbus live session
After=graphical.target
ConditionPathExists=/usr/bin/nimbus-shell

[Service]
Type=simple
User=nimbus
WorkingDirectory=/home/nimbus
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=HOME=/home/nimbus
Environment=QT_QPA_PLATFORM=wayland
Environment=QSG_RHI_BACKEND=opengl
ExecStart=/usr/bin/nimbus-shell
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical.target
```

`iso/profiles/nimbus/overlay/usr/lib/systemd/system/nimbus-live-ready.service` — **anuncia que todo está listo**:
```ini
# SPDX-License-Identifier: GPL-3.0-or-later
[Unit]
Description=Nimbus live session ready
Requires=nimbus-live.service
After=nimbus-live.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/sh -c 'echo NIMBUS_LIVE_READY > /dev/console'
```

La cadena `Requires=` es lo que hace fiable el test: si el shell no arranca,
`nimbus-live-ready.service` **tampoco** se ejecuta y el harness de Task 8 agota el
timeout en lugar de dar un falso positivo.

- [ ] **Step 8: Escribe `iso/build.sh`**

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

PROFILE="nimbus"
OUTDIR="."
LOCAL_REPO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --outdir) OUTDIR="${2:?falta el valor de --outdir}"; shift 2 ;;
    --profile) PROFILE="${2:?falta el valor de --profile}"; shift 2 ;;
    --local-repo) LOCAL_REPO="1"; shift ;;
    *) echo "opción desconocida: $1" >&2; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/iso/work"
DATE="$(date +%Y%m%d)"
SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
ISO_NAME="nimbus-${DATE}-${SHA}.iso"

if [ ! -f "$ROOT/iso/profiles/$PROFILE/airoot.sh" ]; then
  echo "perfil no encontrado: $PROFILE" >&2
  exit 1
fi

for bin in archiso makepkg repo-add; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "$bin no encontrado: instálalo antes de construir la ISO" >&2
    exit 1
  }
done

mkdir -p "$WORK" "$OUTDIR"
rm -rf "$WORK"/*
cp -r "$ROOT/iso/profiles/$PROFILE" "$WORK/profile"

# Repo local de bootstrap: se compilan los PKGBUILDs de Nimbus y se sirven
# por file:// desde el árbol de trabajo, montado en la ISO en
# /run/archiso/bootmnt/nimbus-repo.
if [ -n "$LOCAL_REPO" ]; then
  REPO_DIR="$WORK/nimbus-repo"
  mkdir -p "$REPO_DIR"
  for pkgdir in "$ROOT"/packages/*/; do
    name="$(basename "$pkgdir")"
    [ -f "$pkgdir/PKGBUILD" ] || continue
    echo "[nimbus] compilando $name"
    # PKGDEST es la variable que dice a makepkg donde dejar el paquete.
    # `--packagelist` NO construye nada: solo imprime las rutas que se producirian.
    ( cd "$pkgdir" && PKGDEST="$REPO_DIR" makepkg --nodeps --noconfirm ) \
      >"$WORK/build-${name}.log" 2>&1
  done
  # Si no ha salido ningun paquete, el repo local quedaria vacio y la ISO no
  # podria resolver nimbus-shell. Falla aqui, de forma ruidosa.
  compgen -G "$REPO_DIR/*.pkg.tar.*" >/dev/null || {
    echo "no se ha construido ningun paquete en $REPO_DIR" >&2
    exit 1
  }
  # pacman 7 exige una extension de archivo valida: repo-add crea
  # nimbus.db.tar.gz y el symlink nimbus.db -> nimbus.db.tar.gz.
  repo-add "$REPO_DIR/nimbus.db.tar.gz" "$REPO_DIR"/*.pkg.tar.*
  mkdir -p "$WORK/profile/overlay/run/archiso/bootmnt"
  cp -r "$REPO_DIR" "$WORK/profile/overlay/run/archiso/bootmnt/nimbus-repo"
fi

archiso -p "$WORK/profile" -O "$OUTDIR/$ISO_NAME"
echo "ISO construida: $OUTDIR/$ISO_NAME"
```

Dale permiso de ejecución: `chmod +x iso/build.sh`.

- [ ] **Step 9: Ejecuta el test para verificar que pasa**

Run: `python -m pytest tests/test_iso_profile.py -v`
Expected: PASS — 5 passed.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: archiso profile and ISO builder for Nimbus"
```

---

### Task 7: Flujo y módulos del instalador Calamares

**Files:**
- Create: `installer/calamares/settings.conf`
- Create: `installer/calamares/modules/nimbus-appearance/nimbus-appearance.conf`
- Create: `installer/calamares/modules/nimbus-appearance/nimbus-appearance.py`
- Create: `installer/calamares/modules/nimbus-software/nimbus-software.conf`
- Create: `installer/calamares/modules/nimbus-software/nimbus-software.py`
- Create: `installer/calamares/modules/nimbus-verify/nimbus-verify.conf`
- Create: `installer/calamares/modules/nimbus-verify/nimbus-verify.py`
- Create: `tests/test_calamares_settings.py`

**Interfaces:**
- Consumes: nada de otras tasks (los módulos referencian los perfiles por nombre).
- Produces:
  - `installer/calamares/settings.conf` — flujo de 11 pasos.
  - Módulos `nimbus-appearance`, `nimbus-software`, `nimbus-verify` con su `.conf` (configuración de Calamares) y su `.py` (implementación en Python, API ` calamares`).
  - Contrato verificado por test:
    - Secuencia exacta de módulos.
    - Perfiles de software: `base`, `gaming`, `creative`, `development`, `communication`, `office`.
    - El módulo de verificación comprueba al menos 8 comprobaciones.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_calamares_settings.py`:

```python
import configparser
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
CALAMARES = ROOT / "installer" / "calamares"
SETTINGS = CALAMARES / "settings.conf"

EXPECTED_SEQUENCE = [
    "welcome",
    "locale",
    "partition",
    "lukspass",
    "users",
    "nimbus-appearance",
    "nimbus-software",
    "hardware",
    "bootloader",
    "finished",
]

EXPECTED_PROFILES = {"base", "gaming", "creative", "development", "communication", "office"}


def _sequence():
    parser = configparser.ConfigParser()
    parser.read(SETTINGS, encoding="utf-8")
    return [
        line.strip()
        for line in parser["sequence"]["modules"].strip().splitlines()
        if line.strip()
    ]


def test_settings_conf_exists():
    assert SETTINGS.is_file()


def test_module_sequence_is_the_expected_one():
    assert _sequence() == EXPECTED_SEQUENCE


NIMBUS_OWNED_MODULES = {"nimbus-appearance", "nimbus-software", "nimbus-verify"}


def test_every_nimbus_module_has_a_conf_file():
    # welcome, locale, partition, lukspass, users, hardware, bootloader y finished
    # son modulos de Calamares upstream: los aporta el paquete cachyos-calamares-next,
    # no este repositorio. Solo exigimos los que son propiedad de Nimbus.
    missing = [
        name
        for name in _sequence()
        if name in NIMBUS_OWNED_MODULES
        and not (CALAMARES / "modules" / name / f"{name}.conf").is_file()
    ]
    assert missing == []


def test_software_profiles_are_complete():
    conf = CALAMARES / "modules" / "nimbus-software" / "nimbus-software.conf"
    text = conf.read_text(encoding="utf-8")
    for profile in EXPECTED_PROFILES:
        assert profile in text, f"falta el perfil {profile}"


def test_gaming_profile_contains_the_stack():
    conf = CALAMARES / "modules" / "nimbus-software" / "nimbus-software.conf"
    text = conf.read_text(encoding="utf-8")
    for package in ["steam", "proton-ge", "gamescope", "mangohud", "heroic"]:
        assert package in text, f"falta {package} en el perfil gaming"


def test_verify_module_runs_at_least_eight_checks():
    source = CALAMARES / "modules" / "nimbus-verify" / "nimbus-verify.py"
    text = source.read_text(encoding="utf-8")
    # Se cuentan las funciones check_*, no las llamadas a check( del decorador.
    assert text.count("def check_") >= 8


def test_installer_requires_connectivity_step():
    source = CALAMARES / "modules" / "nimbus-software" / "nimbus-software.py"
    text = source.read_text(encoding="utf-8")
    assert "connectivity" in text.lower()
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `python -m pytest tests/test_calamares_settings.py -v`
Expected: FAIL — `settings.conf` no existe.

- [ ] **Step 3: Escribe `installer/calamares/settings.conf`**

```ini
# SPDX-License-Identifier: GPL-3.0-or-later
[sequence]
modules:
  welcome
  locale
  partition
  lukspass
  users
  nimbus-appearance
  nimbus-software
  hardware
  bootloader
  finished

[general]
organizationName=Nimbus
organizationDomain=github.com
productName=Nimbus
productVersion=0.1.0
donationURL=https://github.com/juanpimg/NimbusOS

[locale]
locale=es_ES.UTF-8
keyboard=en_US
useSystemLocale=false

[partition]
defaultFileSystemType=ext4
availableFileSystemTypes=ext4
                   btrfs
                   xfs
                   fat32
                   ntfs
                   linuxswap

[lukspass]
required=false

[users]
username=nimbus
hostname=nimbus

[nimbus-appearance]
mode=light
accent=007AFF

[nimbus-software]
profiles=base,gaming

[hardware]
required=true
```

- [ ] **Step 4: Escribe los módulos**

`installer/calamares/modules/nimbus-appearance/nimbus-appearance.conf`:
```ini
# SPDX-License-Identifier: GPL-3.0-or-later
[appearance]
mode=light
accent=007AFF
wallpaper=nimbus-default
```

`installer/calamares/modules/nimbus-appearance/nimbus-appearance.py` — módulo Calamares con dos páginas: "Tema" (claro/oscuro/auto) y "Color de acento" (12 presets). Escribe el resultado en `/etc/nimbus/appearance.conf` y aplícalo con `kwriteconfig` sobre los ficheros de `~/.config/`.

`installer/calamares/modules/nimbus-software/nimbus-software.conf`:
```ini
# SPDX-License-Identifier: GPL-3.0-or-later
[software]
profiles=base,gaming,creative,development,communication,office

base=gui,nimbus-shell,nimbus-dots,kitty,foot,nautilus,firefox,evince,mpv,udisks2,gvfs,xdg-user-dirs
gaming=steam,proton-ge,proton-cachyos,gamescope,gamemode,mangohud,vkbasalt,heroic,lutris,bottles,protonup-qt,lib32-vulkan,vkd3d-proton
creative=gimp,krita,inkscape,kdenlive,blender,obs-studio
development=code,git,python,nodejs,docker,podman
communication=discord,telegram,signal,whatsapp
office=libreoffice-fresh,onlyoffice-desktopeditors
```

`installer/calamares/modules/nimbus-software/nimbus-software.py` — módulo Calamares que:
1. **Comprueba la conectividad antes de empezar** (usa `libcalamares.utils.check_network_connection()`). Si no hay red, muestra un mensaje accionable: `No hay conexión a Internet. Nimbus necesita conexión para descargar los drivers y las aplicaciones que elijas.` y ofrece continuar solo con el perfil `base` si el usuario lo acepta.
2. Recoge los perfiles marcados.
3. Traduce cada perfil a la lista de paquetes y los instala con `libcalamares.utils.target_env_command` invocando `pacman -S --needed --noconfirm`.

`installer/calamares/modules/nimbus-verify/nimbus-verify.conf`:
```ini
# SPDX-License-Identifier: GPL-3.0-or-later
[verify]
timeout=10
```

`installer/calamares/modules/nimbus-verify/nimbus-verify.py` — módulo Calamares con **al menos 8** funciones `check(...)` que devuelven `(bool, str)`:
```python
# SPDX-License-Identifier: GPL-3.0-or-later
CHECKS = []


def check(name):
    def decorator(fn):
        CHECKS.append((name, fn))
        return fn
    return decorator


@check("gpu")
def check_gpu():
    """Verifica que hay una GPU funcional presente."""
    ...

@check("audio")
def check_audio():
    ...

@check("network")
def check_network():
    ...

@check("webcam")
def check_webcam():
    ...

@check("suspend")
def check_suspend():
    ...

@check("disk-space")
def check_disk_space():
    ...

@check("bootloader")
def check_bootloader():
    ...

@check("dual-boot")
def check_dual_boot():
    ...
```

Cada `check_*` devuelve `(True, mensaje_ok)` o `(False, mensaje_con_acción)`. Ninguna debe lanzar excepción: un fallo de una comprobación **no** aborta la instalación.

- [ ] **Step 5: Ejecuta el test para verificar que pasa**

Run: `python -m pytest tests/test_calamares_settings.py -v`
Expected: PASS — 7 passed.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: calamares flow with appearance, software and verification modules"
```

---

### Task 8: Harness de integración en QEMU

**Files:**
- Create: `tests/integration/lib.sh`
- Create: `tests/integration/boot_live.sh`
- Create: `tests/integration/build_and_boot.sh`
- Create: `.github/workflows/iso.yml`

**Interfaces:**
- Consumes: `iso/build.sh` (Task 6) y el marcador `NIMBUS_LIVE_READY` del unit `nimbus-live-ready.service`.
- Produces:
  - `tests/integration/boot_live.sh --iso <ruta> [--timeout <segundos>]` → arranca la ISO en QEMU, captura la consola serie y busca el marcador `NIMBUS_LIVE_READY`. Exit 0 si lo encuentra dentro del timeout, exit 1 si no.
  - `tests/integration/build_and_boot.sh` → construye la ISO y llama a `boot_live.sh`.
  - Workflow `iso.yml` en GitHub Actions.

**Nota de CI:** los runners alojados por GitHub **no exponen `/dev/kvm`**. En CI hay que usar `-accel tcg` (emulación por software, lenta: ~5-10 minutos). En local, `-accel kvm` (el portátil del fundador tiene `/dev/kvm` y 20 hilos).

**Nota de GPU:** Hyprland necesita un dispositivo DRM con KMS. El VGA estándar de QEMU no sirve, por eso la VM usa `-device virtio-gpu-pci -vga none`; el invitado usa el driver `virtio-gpu` de Mesa con llvmpipe. Si el kernel del invitado no trae ese driver, la alternativa es `-device qemu-xga`, que es más lenta pero compatible con KMS.

- [ ] **Step 1: Escribe el test que falla**

El harness **es** el test. Crea `tests/integration/lib.sh`:

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

NIMBUS_MARKER="NIMBUS_LIVE_READY"

qemu_accel() {
  if [ -w /dev/kvm ]; then
    echo "kvm"
  else
    echo "tcg"
  fi
}

qemu_run() {
  local iso="$1" log="$2" accel="$3"
  qemu-system-x86_64 \
    -accel "$accel" \
    -m 4096 \
    -smp 2 \
    -display none \
    -device virtio-gpu-pci \
    -vga none \
    -serial "mon:stdio" \
    -cdrom "$iso" \
    -snapshot \
    -no-reboot \
    >"$log" 2>&1 &
  echo $!
}

wait_for_marker() {
  local log="$1" timeout="$2" waited=0
  while [ "$waited" -lt "$timeout" ]; do
    if grep -q "$NIMBUS_MARKER" "$log" 2>/dev/null; then
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done
  return 1
}
```

Crea `tests/integration/boot_live.sh`:

```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

ISO=""
TIMEOUT=600

while [ $# -gt 0 ]; do
  case "$1" in
    --iso) ISO="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "opción desconocida: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
  echo "ISO no encontrada: $ISO" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/tests/integration/lib.sh"

LOG="$(mktemp -t nimbus-qemu-XXXXXX.log)"
ACCEL="$(qemu_accel)"
PID="$(qemu_run "$ISO" "$LOG" "$ACCEL")"
trap 'kill "$PID" 2>/dev/null || true' EXIT

echo "Arrancando la ISO en QEMU (accel: $ACCEL), log: $LOG"

if wait_for_marker "$LOG" "$TIMEOUT"; then
  echo "OK: la sesión live de Nimbus está lista"
  exit 0
fi

echo "FALLO: no se encontró $NIMBUS_MARKER en $TIMEOUT segundos" >&2
tail -n 60 "$LOG" >&2
exit 1
```

- [ ] **Step 2: Ejecuta el harness para verificar que falla**

Run: `bash tests/integration/boot_live.sh --iso /nonexistent.iso`
Expected: FAIL (exit 1) con `ISO no encontrada: /nonexistent.iso`. Esto verifica que el harness falla de forma limpia ante una ISO inválida.

- [ ] **Step 3: Construye la ISO y verifica el arranque**

Run:
```bash
sudo pacman -S --needed --noconfirm archiso repo
bash iso/build.sh --outdir /tmp/opencode/nimbus-iso --local-repo
bash tests/integration/boot_live.sh --iso /tmp/opencode/nimbus-iso/nimbus-*.iso --timeout 900
```
Expected: `OK: la sesión live de Nimbus está lista` y exit 0.

El flag `--local-repo` es obligatorio en esta fase: el repo `nimbus` aún no está alojado, así que `build.sh` compila los PKGBUILDs de `packages/` y los sirve por `file://`. **No** publiques un repo fake para hacer pasar el test.

- [ ] **Step 4: Crea `.github/workflows/iso.yml`**

```yaml
name: iso

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-and-boot:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Preparar repos CachyOS
        run: |
          sudo tee -a /etc/pacman.d/mirrorlist >/dev/null <<'EOF'
          Server = https://archlinux.cachyos.org/repo/$repo/os/$arch
          EOF
          sudo tee /etc/pacman.d/mirrorlist.cachyos >/dev/null <<'EOF'
          Server = https://cdn77.cachyos.org/repo/$arch/$repo
          EOF
          sudo tee /etc/pacman.d/mirrorlist.cachyos-v3 >/dev/null <<'EOF'
          Server = https://cdn77.cachyos.org/repo/$arch_v3/$repo
          EOF
          for r in cachyos cachyos-v3; do
            echo "[$r]" | sudo tee -a /etc/pacman.conf
            echo "Include = /etc/pacman.d/mirrorlist.$r" | sudo tee -a /etc/pacman.conf
          done
      - name: Instalar dependencias
        run: sudo pacman -Sy --noconfirm archiso repo qemu-desktop
      - name: Construir la ISO
        run: bash iso/build.sh --outdir "$RUNNER_TEMP/iso" --local-repo
      - name: Comprobar el arranque en QEMU
        run: bash tests/integration/boot_live.sh --iso "$RUNNER_TEMP"/iso/nimbus-*.iso --timeout 900
      - name: Subir la ISO
        uses: actions/upload-artifact@v4
        with:
          name: nimbus-iso
          path: ${{ runner.temp }}/iso/*.iso
```

**En CI el arranque usa `-accel tcg` automáticamente** porque `/dev/kvm` no existe en los runners alojados. El harness lo decide solo.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test: QEMU integration harness that boots the live session"
```

---

## Criterio de terminación de M0

M0 está completo cuando **todas** estas condiciones se cumplen a la vez:

1. `python -m pytest tests -v` pasa entero.
2. `bats tests/keyring.bats tests/promote.bats` pasa entero.
3. `qmltestrunner -input shell/tests` pasa entero.
4. `bash iso/build.sh --outdir <dir> --local-repo` produce una ISO **< 3 GB**.
5. `bash tests/integration/boot_live.sh --iso <iso>` devuelve exit 0 con el marcador `NIMBUS_LIVE_READY`.
6. `tools/promote.sh` **firma** la DB de `stable` con una clave generada offline, y `tools/verify_repo.sh` la valida.
7. `tools/check_spdx.py` pasa sobre el árbol completo.
8. El CI de GitHub Actions está verde en `ci.yml` e `iso.yml`.

Cuando las ocho se cumplan, M0 está cerrado y el **Plan 2 (shell v0)** puede empezar.
