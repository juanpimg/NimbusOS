# SPDX-License-Identifier: GPL-3.0-or-later
"""Modulo Calamares de verificacion post-instalacion de Nimbus.

Ejecuta una bateria de comprobaciones sobre el sistema instalado.
Cada ``check_*`` devuelve ``(bool, str)``: True con un mensaje ok, o
False con un mensaje que incluye una accion. Ninguna comprobacion lanza
excepcion y un fallo nunca aborta la instalacion.
"""

import logging
import pathlib
import shutil
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

CHECKS = []


def check(name):
    def decorator(fn):
        CHECKS.append((name, fn))
        return fn
    return decorator


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


@check("gpu")
def check_gpu(locale=None):
    """Verifica que hay una GPU funcional presente."""
    lang = _current_locale(locale)
    try:
        drm = pathlib.Path("/sys/class/drm")
        if drm.is_dir() and list(drm.glob("card*")):
            return True, translated("verify.gpu.drm_ok", lang)
        dri = pathlib.Path("/dev/dri")
        if dri.is_dir() and list(dri.iterdir()):
            return True, translated("verify.gpu.dri_ok", lang)
        return (False, translated("verify.gpu.missing", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.gpu.error", lang).format(detail=exc)


@check("audio")
def check_audio(locale=None):
    """Verifica que hay un dispositivo de audio disponible."""
    lang = _current_locale(locale)
    try:
        cards = pathlib.Path("/proc/asound/cards")
        if cards.is_file() and "[No soundcards]" not in cards.read_text():
            return True, translated("verify.audio.cards_ok", lang)
        if pathlib.Path("/dev/snd").is_dir():
            return True, translated("verify.audio.snd_ok", lang)
        return (False, translated("verify.audio.missing", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.audio.error", lang).format(detail=exc)


@check("network")
def check_network(locale=None):
    """Verifica que hay al menos una interfaz de red operativa."""
    lang = _current_locale(locale)
    try:
        net = pathlib.Path("/sys/class/net")
        for iface in net.iterdir():
            if iface.name == "lo":
                continue
            state = iface / "operstate"
            if state.is_file() and state.read_text().strip() in ("up", "dormant"):
                return True, translated(
                    "verify.network.ok", lang).format(iface=iface.name)
        return (False, translated("verify.network.missing", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.network.error", lang).format(detail=exc)


@check("webcam")
def check_webcam(locale=None):
    """Verifica la camara web si existe."""
    lang = _current_locale(locale)
    try:
        video = sorted(pathlib.Path("/dev").glob("video*"))
        if video:
            return True, translated(
                "verify.webcam.found", lang).format(device=video[0])
        return (True, translated("verify.webcam.none", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.webcam.error", lang).format(detail=exc)


@check("suspend")
def check_suspend(locale=None):
    """Verifica que la suspension esta disponible."""
    lang = _current_locale(locale)
    try:
        state = pathlib.Path("/sys/power/state")
        if state.is_file():
            modes = state.read_text()
            if "mem" in modes or "disk" in modes:
                return True, translated("verify.suspend.ok", lang)
        return (False, translated("verify.suspend.missing", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.suspend.error", lang).format(detail=exc)


@check("disk-space")
def check_disk_space(locale=None):
    """Verifica que queda espacio libre suficiente en /."""
    lang = _current_locale(locale)
    try:
        minimum_gib = 5
        total, used, free = shutil.disk_usage("/")
        free_gib = free / (1024 ** 3)
        if free_gib >= minimum_gib:
            return True, translated(
                "verify.disk.ok", lang).format(free=f"{free_gib:.1f}")
        return (False, translated(
            "verify.disk.low", lang).format(
                free=f"{free_gib:.1f}", minimum=minimum_gib))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.disk.error", lang).format(detail=exc)


@check("bootloader")
def check_bootloader(locale=None):
    """Verifica que el gestor de arranque quedo instalado."""
    lang = _current_locale(locale)
    try:
        efi = pathlib.Path("/sys/firmware/efi")
        if efi.is_dir():
            entries = pathlib.Path("/boot/efi/EFI")
            if entries.is_dir() and list(entries.iterdir()):
                return True, translated("verify.bootloader.efi_ok", lang)
            return (False, translated(
                "verify.bootloader.efi_missing", lang))
        grub = pathlib.Path("/boot/grub/grub.cfg")
        if grub.is_file():
            return True, translated("verify.bootloader.grub_ok", lang)
        loader = pathlib.Path("/boot/loader/entries")
        if loader.is_dir() and list(loader.iterdir()):
            return True, translated("verify.bootloader.systemd_ok", lang)
        return (False, translated("verify.bootloader.missing", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.bootloader.error", lang).format(detail=exc)


@check("dual-boot")
def check_dual_boot(locale=None):
    """Detecta otros sistemas para avisar sobre arranque dual."""
    lang = _current_locale(locale)
    try:
        result = subprocess.run(
            ["os-prober"], capture_output=True, text=True, timeout=30)
        entries = [line for line in result.stdout.splitlines() if line.strip()]
        if entries:
            return True, translated(
                "verify.dualboot.found", lang).format(count=len(entries))
        return True, translated("verify.dualboot.none", lang)
    except (FileNotFoundError, subprocess.SubprocessError):
        return True, translated("verify.dualboot.no_prober", lang)
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.dualboot.error", lang).format(detail=exc)


def run_all_checks(locale=None):
    """Ejecuta todas las comprobaciones sin que ninguna aborte el resto."""
    results = []
    for name, fn in CHECKS:
        try:
            if locale is None:
                ok, message = fn()
            else:
                try:
                    ok, message = fn(locale)
                except TypeError:
                    ok, message = fn()
            results.append((name, bool(ok), str(message)))
        except Exception as exc:  # cinturon y tirantes
            lang = _current_locale(locale)
            results.append((name, False,
                            translated(
                                "verify.internal_error",
                                lang).format(detail=exc)))
    return results


def pretty_name(locale=None):
    return translated("verify.pretty_name", _current_locale(locale))


def pretty_status_message(locale=None):
    return translated("verify.pretty_status", _current_locale(locale))


def serializable_results(results):
    """Convierte [(name, ok, message)] a {name: [ok, message]}.

    ``dict(results)`` reventaria con tuplas de 3 elementos (ValueError);
    este formato es seguro para globalstorage y serializable a JSON.
    """
    return {name: [ok, message] for name, ok, message in results}


def run():
    """Punto de entrada de Calamares: informa, nunca aborta.

    Siempre devuelve None: en Calamares, devolver cualquier otro valor
    marca el job como fallido. Los avisos se registran con utils.warning.
    """
    results = run_all_checks()
    for name, ok, message in results:
        if libcalamares is not None:
            if ok:
                libcalamares.utils.debug(f"verify {name}: {message}")
            else:
                libcalamares.utils.warning(f"verify {name}: {message}")
        elif not ok:
            logger.warning("verify %s: %s", name, message)
    if libcalamares is not None:
        libcalamares.globalstorage.insert(
            "nimbusVerifyResults", serializable_results(results))
    return None
