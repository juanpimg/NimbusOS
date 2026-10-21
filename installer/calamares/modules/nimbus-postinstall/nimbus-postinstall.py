# SPDX-License-Identifier: GPL-3.0-or-later
"""Modulo Calamares de post-instalacion de Nimbus.

Invoca ``installer/tools/nimbus-postinstall --root <raiz>`` y muestra el
resultado en el resumen final, paso a paso, con un mensaje accionable
por cada fallo. Un paso opcional que falla avisa pero no hunde el job;
uno critico (keyring o repos) si lo hace fracasar, porque sin ellos el
sistema instalado no podria actualizarse.
"""

import json
import logging
import pathlib
import subprocess

try:  # Calamares provee libcalamares en el ISO live; ausente en CI/test.
    import libcalamares
except ImportError:  # pragma: no cover - entorno sin Calamares
    libcalamares = None

try:
    from nimbus_i18n import active_locale, translated, TRANSLATIONS
except ImportError:  # cargado por ruta (Calamares/test) sin paquete
    import importlib.util as _importlib_util
    import sys as _sys

    _i18n_module = _sys.modules.get("nimbus_i18n")
    if _i18n_module is None:
        _i18n_path = (
            pathlib.Path(__file__).resolve().parents[2]
            / "calamares" / "nimbus_i18n.py"
        )
    else:
        _i18n_path = None
    if _i18n_path is not None:
        _i18n_spec = _importlib_util.spec_from_file_location(
            "nimbus_i18n", _i18n_path)
        _i18n_module = _importlib_util.module_from_spec(_i18n_spec)
        _sys.modules["nimbus_i18n"] = _i18n_module
        _i18n_spec.loader.exec_module(_i18n_module)
    active_locale = _i18n_module.active_locale
    translated = _i18n_module.translated
    TRANSLATIONS = _i18n_module.TRANSLATIONS

# La tabla central la toca otra pista: estas claves se registran aqui en
# tiempo de ejecucion y el informe declara cada una con su ES/EN.
_MODULE_STRINGS = {
    "es": {
        "postinstall.pretty_name": "Post-instalación",
        "postinstall.pretty_status": "Dejando el sistema listo para usar.",
        "postinstall.module.failed": (
            "{step}: falló ({detail}). Acción: {hint}."
        ),
        "postinstall.module.no_tool": (
            "no se pudo ejecutar nimbus-postinstall ({detail}). "
            "Acción: repite a mano nimbus-postinstall --root {root} "
            "y revisa cada paso."
        ),
    },
    "en": {
        "postinstall.pretty_name": "Post-install",
        "postinstall.pretty_status": "Getting the system ready to use.",
        "postinstall.module.failed": (
            "{step}: failed ({detail}). Action: {hint}."
        ),
        "postinstall.module.no_tool": (
            "could not run nimbus-postinstall ({detail}). "
            "Action: rerun nimbus-postinstall --root {root} by hand "
            "and review each step."
        ),
    },
}

for _lang, _table in _MODULE_STRINGS.items():
    _central = TRANSLATIONS.setdefault(_lang, {})
    for _key, _text in _table.items():
        _central.setdefault(_key, _text)
del _lang, _table, _central, _key, _text

logger = logging.getLogger(__name__)

TOOL_PATH = (
    pathlib.Path(__file__).resolve().parents[2]
    / "tools" / "nimbus-postinstall"
)

RESULTS_KEY = "nimbusPostinstallResults"
OFFLINE_KEY = "nimbusPostinstallOffline"


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
    return translated("postinstall.pretty_name", _current_locale(locale))


def pretty_status_message(locale=None):
    return translated("postinstall.pretty_status", _current_locale(locale))


def _target_root():
    if libcalamares is None:
        return "/"
    try:
        return (
            libcalamares.globalstorage.value("rootMountPoint") or "/")
    except Exception:
        return "/"


def _wants_offline():
    """True si la configuracion o la falta de red piden --offline."""
    if libcalamares is not None:
        try:
            configured = libcalamares.job.configuration.get("offline")
            if isinstance(configured, str):
                if configured.strip().lower() in ("1", "true", "yes"):
                    return True
            elif configured:
                return True
        except Exception:
            pass
        try:
            return not bool(
                libcalamares.utils.check_network_connection())
        except Exception:
            pass
    return False


def _parse_results(stdout):
    """Convierte la salida --json en {nombre: [estado, mensaje]}."""
    items = json.loads(stdout)
    return {item["name"]: [item["status"], item["message"]]
            for item in items}


def run():
    """Punto de entrada de Calamares: informa paso a paso.

    Devuelve None cuando todo lo critico salio bien (los avisos ya
    quedaron registrados) o un mensaje accionable cuando un paso
    critico fallo o la herramienta ni siquiera corrio.
    """
    locale = _current_locale()
    root = _target_root()
    command = [str(TOOL_PATH), "--root", str(root), "--json",
               "--locale", locale]
    if _wants_offline():
        command.append("--offline")
    try:
        completed = subprocess.run(
            command, check=False, capture_output=True, text=True,
            timeout=300)
    except Exception as exc:
        message = translated(
            "postinstall.module.no_tool", locale).format(
                detail=exc, root=root)
        if libcalamares is not None:
            libcalamares.utils.warning(message)
        return message
    try:
        stored = _parse_results(completed.stdout)
    except (ValueError, KeyError, TypeError, AttributeError) as exc:
        message = translated(
            "postinstall.module.no_tool", locale).format(
                detail=exc, root=root)
        if libcalamares is not None:
            libcalamares.utils.warning(message)
        return message
    failed_steps = {name: (status, text)
                    for name, (status, text) in stored.items()
                    if status == "failed"}
    for name, (_status, text) in failed_steps.items():
        if libcalamares is not None:
            libcalamares.utils.warning(f"postinstall {name}: {text}")
        else:
            logger.warning("postinstall %s: %s", name, text)
    if libcalamares is not None:
        libcalamares.globalstorage.insert(RESULTS_KEY, stored)
    if failed_steps:
        # La herramienta sale con 1 solo si fallo un paso critico;
        # con 0 los fallos son opcionales y el job sigue adelante.
        if completed.returncode != 0:
            worst = next(iter(failed_steps))
            _status, text = failed_steps[worst]
            return str(text)
    return None
