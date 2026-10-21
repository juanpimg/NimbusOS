# SPDX-License-Identifier: GPL-3.0-or-later
"""Modulo Calamares de arranque dual con Windows (Nimbus).

Se ejecuta **antes** de `partition` y hace:

1. Detectar una instalacion de Windows (os-prober o `*/Windows/System32`).
2. Detectar Fast Boot / inicio rapido: si esta activo, **bloquea** con un
   mensaje que explica como desactivarlo en Windows (`powercfg /h off` y
   en la BIOS). Continuar garantizaria un arranque roto.
3. Respaldar la tabla de particiones con `nimbus-partitionsafe backup`
   **antes** de que Calamares toque el disco, en **todos** los discos
   detectados (`/sys/block`: sda, nvme...; nunca loop/dm/sr/zram).
4. Reutilizar la particion EFI existente de Windows (no crear una segunda).
5. Avisar a los pasos siguientes (globalstorage) de que hay Windows para
   que `bootloader` use **GRUB** y no systemd-boot.

SEGURIDAD ANTE CANCELACION: el modulo solo **lee** los discos
(`sfdisk --dump` via partitionsafe) y escribe fuera de ellos, en
``DEFAULT_BACKUP_DIR`` del live. Cancelar a mitad (o reiniciar) deja
todos los discos intactos; el respaldo se sobrescribe sin problema si
se reintenta. Nunca abre un dispositivo para escribir.

Toda cadena visible pasa por `translated()` (ES/EN). Las claves
`dualboot.*` viven en la tabla central `nimbus_i18n.py` (única fuente).
"""

import logging
import pathlib
import re
import subprocess

try:  # Calamares provee libcalamares en el ISO live; ausente en CI/test.
    import libcalamares
except ImportError:  # pragma: no cover - entorno sin Calamares
    libcalamares = None

try:
    from nimbus_i18n import active_locale, translated
except ImportError:  # cargado por ruta (Calamares/test) sin paquete
    import importlib.util as _importlib_util
    import sys as _sys

    _i18n_module = _sys.modules.get("nimbus_i18n")
    if _i18n_module is None:
        _i18n_path = (
            pathlib.Path(__file__).resolve().parents[2] / "nimbus_i18n.py"
        )
        _i18n_spec = _importlib_util.spec_from_file_location(
            "nimbus_i18n", _i18n_path)
        _i18n_module = _importlib_util.module_from_spec(_i18n_spec)
        _sys.modules["nimbus_i18n"] = _i18n_module
        _i18n_spec.loader.exec_module(_i18n_module)
    active_locale = _i18n_module.active_locale
    translated = _i18n_module.translated

logger = logging.getLogger(__name__)

# Directorio persistente del respaldo (no temporal): sobrevive al live y
# queda disponible para `verify` tras particionar.
DEFAULT_BACKUP_DIR = pathlib.Path("/var/lib/nimbus/partitionsafe")

# Deteccion de Windows via os-prober y via arbol NTFS montado.
WINDOWS_SYSTEM32 = pathlib.Path("Windows/System32")

# Las claves ES/EN de este modulo viven en la tabla central
# (installer/calamares/nimbus_i18n.py), unica fuente. Este modulo
# no registra nada al importar (ver informe de la pista del instalador).

_EFI_GUID = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
_PARTITION_LINE_RE = re.compile(r"^\s*(/dev/\S+)\s*:.*\bstart\s*=")

PARTITIONSAFE_BIN = (
    pathlib.Path(__file__).resolve().parents[3]
    / "tools" / "nimbus-partitionsafe"
)


def _current_locale(locale=None):
    """Idioma efectivo: parametro, ajuste del instalador o entorno."""
    if locale is not None:
        return locale
    if libcalamares is not None:
        try:
            storage = libcalamares.globalstorage
            for key in ("nimbusLocale", "locale", "lang"):
                value = storage.value(key)
                if value:
                    return str(value)
        except Exception:
            pass
    return active_locale()


def pretty_name(locale=None):
    return translated("dualboot.pretty_name", _current_locale(locale))


def pretty_status_message(locale=None):
    return translated("dualboot.pretty_status", _current_locale(locale))


def fast_boot_message(locale=None):
    return translated("dualboot.fastboot.blocked", _current_locale(locale))


def _read_first_bytes(path, limit=65536):
    try:
        with open(str(path), "rb") as handle:
            return handle.read(limit)
    except OSError:
        return b""


def is_fast_boot_enabled(efivars_dir="/sys/firmware/efi/efivars",
                         bootmgfw_paths=None, read_bytes=None):
    """Detecta Fast Boot / inicio rapido de Windows.

    Senales (cualquiera basta para bloquear, por seguridad):

    - Una variable EFI cuyo nombre contenga ``fastboot`` (p. ej. un
      marcador `FastBoot-*`), o cuyo contenido mencione FastBoot.
    - El gestor `bootmgfw.efi` de Windows contiene la marca FastBoot y
      el contenido indica inicio rapido.

    Nunca lanza: ante la duda devuelve False (sin pruebas) solo si no
    hay ninguna senal legible. ``read_bytes`` permite inyectar lectura
    en tests.
    """
    try:
        base = pathlib.Path(str(efivars_dir))
        if base.is_dir():
            for entry in base.iterdir():
                try:
                    name = entry.name
                except OSError:
                    continue
                if "fastboot" in name.lower():
                    return True
                try:
                    if read_bytes is not None:
                        content = read_bytes(entry)
                    else:
                        content = _read_first_bytes(entry, limit=4096)
                except Exception:
                    continue
                if isinstance(content, str):
                    content = content.encode("utf-8", "replace")
                if b"fastboot" in content.lower():
                    return True
    except Exception:
        pass
    candidates = tuple(bootmgfw_paths) if bootmgfw_paths is not None else (
        "/boot/efi/EFI/Microsoft/Boot/bootmgfw.efi",
    )
    for candidate in candidates:
        try:
            path = pathlib.Path(str(candidate))
            if not path.is_file():
                continue
            content = _read_first_bytes(path)
            if b"fastboot" in content.lower():
                return True
        except Exception:
            continue
    return False


def _run_os_prober_lines():
    try:
        result = subprocess.run(
            ["os-prober"], capture_output=True, text=True, timeout=30)
    except (FileNotFoundError, subprocess.SubprocessError, OSError):
        return []
    except Exception:
        return []
    return [line for line in result.stdout.splitlines() if line.strip()]


def windows_detected(os_prober_lines=None, roots=None, exists=None):
    """True si hay una instalacion de Windows detectable."""
    if os_prober_lines is None:
        lines = _run_os_prober_lines()
    else:
        lines = list(os_prober_lines)
    for line in lines:
        if "windows" in str(line).lower():
            return True
    check_exists = exists or pathlib.Path.exists
    for root in (roots or []):
        try:
            candidate = pathlib.Path(str(root)) / WINDOWS_SYSTEM32
            if check_exists(candidate):
                return True
        except Exception:
            continue
    return False


def find_existing_efi(dump_text):
    """Particion EFI existente en el volcado, o "" (no crea nada)."""
    for line in str(dump_text or "").splitlines():
        match = _PARTITION_LINE_RE.match(line)
        if not match:
            continue
        lowered = line.lower()
        if _EFI_GUID in lowered:
            return match.group(1)
        if re.search(r"type\s*=\s*u\b", lowered):
            return match.group(1)
        if "efi" in lowered:
            return match.group(1)
    return ""


def should_create_efi(existing_efi):
    """False si ya hay EFI (reutilizar); True solo si falta."""
    return not bool((existing_efi or "").strip())


def bootloader_choice(windows_found):
    """Con Windows se exige GRUB; sin el, systemd-boot."""
    lang = _current_locale()
    if windows_found:
        return translated("dualboot.bootloader.grub", lang)
    return translated("dualboot.bootloader.default", lang)


# Prefijos de /sys/block que son discos fisicos reales. Se excluyen a
# proposito loop/ram/dm/sr/zram/fd (no son discos instalables).
_DISK_PREFIXES = ("sd", "hd", "vd", "nvme", "mmcblk")
_VIRTUAL_BLOCK_PREFIXES = ("loop", "ram", "dm-", "sr", "zram", "fd")


def _enumerate_disks(sys_block="/sys/block"):
    """Discos reales como /dev/sda, ordenados; [] si no se puede leer."""
    try:
        entries = sorted(pathlib.Path(str(sys_block)).iterdir())
    except OSError:
        return []
    disks = []
    for entry in entries:
        name = entry.name
        if name.startswith(_VIRTUAL_BLOCK_PREFIXES):
            continue
        if name.startswith(_DISK_PREFIXES):
            disks.append(f"/dev/{name}")
    return sorted(disks)


def _resolve_targets(device="/dev/sda", devices=None, sys_block=None):
    """Discos a respaldar: lista explicita, enumeracion o el historico."""
    if devices is not None:
        return [str(item) for item in devices]
    if sys_block is not None:
        return _enumerate_disks(sys_block) or [str(device)]
    return [str(device)]


def _backup_table(device, dest_dir, locale=None):
    """Respalda con nimbus-partitionsafe (lista de args, sin shell)."""
    lang = _current_locale(locale)
    dest = pathlib.Path(str(dest_dir))
    dest.mkdir(parents=True, exist_ok=True)
    try:
        completed = subprocess.run(
            [str(PARTITIONSAFE_BIN), "backup", str(device), str(dest)],
            capture_output=True, text=True, timeout=120, check=False,
        )
    except (FileNotFoundError, subprocess.SubprocessError, OSError) as exc:
        raise RuntimeError(str(exc)) from exc
    if getattr(completed, "returncode", 1) != 0:
        detail = (getattr(completed, "stderr", "")
                  or getattr(completed, "stdout", "") or "").strip()
        raise RuntimeError(
            detail or translated("dualboot.backup.tool_failed", lang))
    return dest


def _live_dump_text(device):
    try:
        completed = subprocess.run(
            [str(PARTITIONSAFE_BIN), "efi", str(device)],
            capture_output=True, text=True, timeout=60, check=False,
        )
        return getattr(completed, "stdout", "")
    except Exception:
        return ""


def run_with_paths(efivars_dir=None, bootmgfw_paths=None, locale=None,
                   os_prober_lines=None, roots=None, dump_text=None,
                   backup_dir=None, device="/dev/sda", exists=None,
                   devices=None, sys_block=None):
    """Flujo testeable: bloquea con Fast Boot, respalda, reutiliza EFI.

    Respalda **todos** los discos (`devices` explicitos o enumerados de
    `sys_block`; por defecto el historico `device` para no cambiar el
    comportamiento de quien ya lo llama con un disco). Solo lee los
    discos, asi que cancelar a mitad los deja intactos.

    Devuelve None al exito o el mensaje de bloqueo/error (Calamares marca
    el job como fallido con cualquier retorno no None).
    """
    lang = _current_locale(locale)
    probe_dir = efivars_dir if efivars_dir is not None else (
        "/sys/firmware/efi/efivars")
    probe_boot = bootmgfw_paths if bootmgfw_paths is not None else (
        "/boot/efi/EFI/Microsoft/Boot/bootmgfw.efi",
    )
    if is_fast_boot_enabled(efivars_dir=probe_dir,
                            bootmgfw_paths=probe_boot):
        message = translated("dualboot.fastboot.blocked", lang)
        if libcalamares is not None:
            libcalamares.utils.warning(message)
        else:
            logger.warning("%s", message)
        return message
    if os_prober_lines is None and roots is None and exists is None:
        windows = windows_detected()
    else:
        windows = windows_detected(
            os_prober_lines=os_prober_lines, roots=roots, exists=exists)
    dest = pathlib.Path(str(backup_dir)) if backup_dir is not None else (
        DEFAULT_BACKUP_DIR)
    targets = _resolve_targets(
        device=device, devices=devices, sys_block=sys_block)
    backups = {}
    try:
        dest.mkdir(parents=True, exist_ok=True)
        for target in targets:
            if dump_text is not None:
                import hashlib as _hashlib

                text = str(dump_text)
                basename = pathlib.Path(str(target)).name
                dump_path = dest / f"{basename}.sfdisk.dump"
                dump_path.write_text(text, encoding="utf-8")
                digest = _hashlib.sha256(text.encode("utf-8")).hexdigest()
                (dest / f"{dump_path.name}.sha256").write_text(
                    f"{digest}  {dump_path.name}\n", encoding="utf-8")
            else:
                _backup_table(target, dest, locale=lang)
                basename = pathlib.Path(str(target)).name
                dump_path = dest / f"{basename}.sfdisk.dump"
            backups[str(target)] = str(dump_path)
    except Exception as exc:
        message = translated(
            "dualboot.backup.error", lang).format(detail=exc)
        if libcalamares is not None:
            libcalamares.utils.warning(message)
        else:
            logger.warning("%s", message)
        return message
    if dump_text is not None:
        efi = find_existing_efi(dump_text)
    else:
        combined = "".join(
            _live_dump_text(target) for target in targets)
        efi = find_existing_efi(combined)
    if efi:
        notice = translated(
            "dualboot.efi.reuse", lang).format(efi=efi)
    else:
        notice = translated("dualboot.efi.create", lang)
    choice = "grub" if windows else bootloader_choice(False)
    if windows:
        info = translated("dualboot.windows.found", lang)
    else:
        info = translated("dualboot.windows.none", lang)
    if libcalamares is not None:
        try:
            libcalamares.utils.debug(
                translated("dualboot.backup.ok", lang).format(dest=dest))
            if windows:
                libcalamares.utils.debug(info)
            libcalamares.utils.debug(notice)
            libcalamares.globalstorage.insert(
                "nimbusDualbootHasWindows", bool(windows))
            libcalamares.globalstorage.insert(
                "nimbusDualbootEfiPartition", efi)
            libcalamares.globalstorage.insert(
                "nimbusBootloaderChoice", choice)
            libcalamares.globalstorage.insert(
                "nimbusPartitionBackups", dict(backups))
        except Exception:
            pass
    else:
        logger.debug("%s %s %s", info, notice, choice)
    return None


def run():
    """Punto de entrada de Calamares (antes de `partition`).

    Enumera los discos reales de /sys/block: en NVMe/multidisco el
    historico /dev/sda no existe y respaldar solo ese dejaria al resto
    sin salvaguarda.
    """
    return run_with_paths(sys_block="/sys/block")
