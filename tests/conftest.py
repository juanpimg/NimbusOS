# SPDX-License-Identifier: GPL-3.0-or-later
"""Carga unica de la tabla central de i18n del instalador.

Los modulos Calamares (`nimbus-verify`, `nimbus-postinstall`) y los tests
los importaban con `spec_from_file_location` bajo nombres distintos, lo
que creaba dos copias en `sys.modules`: la tabla que consultaba
`translated()` no era la que el modulo habia registrado y el usuario veia
la clave literal. Este conftest carga `nimbus_i18n.py` una sola vez bajo
el nombre estable `nimbus_i18n`; todos los importadores posteriores
reutilizan esa copia via `sys.modules.get("nimbus_i18n")`.
"""

import importlib.util
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
I18N_PATH = ROOT / "installer" / "calamares" / "nimbus_i18n.py"


def _ensure_single_i18n():
    existing = sys.modules.get("nimbus_i18n")
    if existing is not None and getattr(existing, "TRANSLATIONS", None):
        return existing
    spec = importlib.util.spec_from_file_location("nimbus_i18n", I18N_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules["nimbus_i18n"] = module
    spec.loader.exec_module(module)
    return module


_ensure_single_i18n()
