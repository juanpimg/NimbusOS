# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests del backend de la Nimbus Store.

El backend es un modulo independiente de la GUI: aqui se ejercita sin
Flatpak (forzando su ausencia) y sin QML.
"""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
STORE_DIR = ROOT / "shell" / "src" / "Nimbus" / "apps" / "Store"
sys.path.insert(0, str(STORE_DIR))

import store_backend


@pytest.fixture(autouse=True)
def restore_flatpak_override():
    yield
    store_backend.set_flatpak_available(None)


def test_search_filters_by_title_case_insensitive():
    store_backend.set_flatpak_available(True)
    lower = store_backend.search("gimp")
    upper = store_backend.search("GIMP")
    mixed = store_backend.search("gImP")
    assert lower, "se esperaba al menos un resultado para 'gimp'"
    assert [a["id"] for a in lower] == [a["id"] for a in upper] == [a["id"] for a in mixed]


def test_list_apps_unknown_category_returns_empty():
    store_backend.set_flatpak_available(True)
    assert store_backend.list_apps("categoria-que-no-existe") == []


def test_no_flatpak_does_not_raise_and_reports_readable_error():
    store_backend.set_flatpak_available(False)
    # Ninguna llamada lanza.
    apps = store_backend.list_apps()
    updates = store_backend.list_updates()
    assert isinstance(apps, list)
    assert updates == []
    # Solo quedan las nativas.
    assert apps, "sin Flatpak deben seguir listandose las apps nativas"
    assert all(a["origin"] == "Nativo" for a in apps)
    # El error llega como texto legible, nunca como excepcion.
    ok, message = store_backend.install("org.gimp.GIMP")
    assert ok is False
    assert isinstance(message, str) and message != ""


def test_list_updates_returns_a_list():
    store_backend.set_flatpak_available(True)
    updates = store_backend.list_updates()
    assert isinstance(updates, list)


def test_install_uninstall_native_roundtrip():
    store_backend.set_flatpak_available(False)
    native_id = next(a["id"] for a in store_backend.list_apps() if a["origin"] == "Nativo")
    store_backend.uninstall(native_id)
    assert store_backend.is_installed(native_id) is False
    ok, _ = store_backend.install(native_id)
    assert ok is True
    assert store_backend.is_installed(native_id) is True


def test_uninstall_distinguishes_not_installed_from_error():
    store_backend.set_flatpak_available(True)
    flathub_id = next(a["id"] for a in store_backend.list_apps() if a["origin"] == "Flathub")
    store_backend.uninstall(flathub_id)
    ok, not_installed_msg = store_backend.uninstall(flathub_id)
    assert ok is False
    ok, unknown_msg = store_backend.uninstall("app.que.no.existe")
    assert ok is False
    assert not_installed_msg != unknown_msg


def test_get_app_unknown_returns_empty_without_raising():
    assert store_backend.get_app("app.que.no.existe") == {}


# Directorios que no contienen codigo fuente del repo: su contenido nunca
# es una fuga de la suite (ver tools/check_spdx.py para el criterio).
_IGNORED_DIRS = {
    ".git",
    ".superpowers",
    "__pycache__",
    ".pytest_cache",
    ".hypothesis",
    "build",
    "out",
    "work",
    "node_modules",
    ".venv",
}

# `pkg/` y `src/` son los directorios de trabajo de makepkg, pero SOLO
# dentro de packages/ (igual que en tools/check_spdx.py).
_MAKEDIR_SCRATCH = {"pkg", "src"}


def test_no_test_files_live_outside_tests_dir():
    """Guarda anti-fuga: pytest solo recoge lo que hay bajo `tests/`.

    `pytest.ini` fija `testpaths = tests`, asi que un `test_*.py` fuera de
    `tests/` pytest no lo ve: ni en local ni en la CI pasa, y nadie se
    entera. Ya mordio una vez con el backend de la Store
    (`shell/src/Nimbus/apps/Store/test_store_backend.py`, 7 tests sin
    ejecutarse). Si este test falla, mueve el fichero listado a `tests/`
    en vez de ignorarlo.
    """
    offenders = []
    for path in ROOT.rglob("test_*.py"):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if _IGNORED_DIRS & set(rel.parts):
            continue
        if "packages" in rel.parts and _MAKEDIR_SCRATCH & set(rel.parts):
            continue
        if "tests" in rel.parts:
            continue
        offenders.append(str(rel))
    assert not offenders, (
        "ficheros de test fuera de tests/: pytest no los ve "
        f"(testpaths = tests), muevelos a tests/: {sorted(offenders)}"
    )
