# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests del metapaquete nimbus-gaming (M3 Task 1).

El interruptor "gameready" del instalador tiene que ser una promesa
cumplida: Steam instalado y configurado con Proton por defecto, sin que
instalar el paquete abra nada solo.
"""

import os
import pathlib
import re
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
PKG = ROOT / "packages" / "nimbus-gaming"
PKGBUILD = PKG / "PKGBUILD"
INSTALL = PKG / "nimbus-gaming.install"

EXPECTED_DEPS = frozenset({
    "steam",
    "proton-ge",
    "proton-cachyos",
    "gamescope",
    "gamemode",
    "mangohud",
    "vkbasalt",
    "lib32-vulkan",
    "vkd3d-proton",
    "heroic",
    "lutris",
    "bottles",
    "protonup-qt",
    "protontricks",
})


def _pkgbuild_text():
    assert PKGBUILD.is_file(), "falta packages/nimbus-gaming/PKGBUILD"
    return PKGBUILD.read_text(encoding="utf-8")


def _depends_set(text):
    match = re.search(r"depends=\((.*?)\)", text, re.DOTALL)
    assert match, "PKGBUILD sin depends=(...)"
    return frozenset(re.findall(r"['\"]([^'\"]+)['\"]", match.group(1)))


def _install_text():
    assert INSTALL.is_file(), "falta packages/nimbus-gaming/nimbus-gaming.install"
    return INSTALL.read_text(encoding="utf-8")


def _run_install_entrypoint(conf_dir):
    """Ejecuta el entrypoint idempotente del .install contra un dir temporal."""
    env = dict(os.environ, NIMBUS_GAMING_CONF_DIR=str(conf_dir))
    proc = subprocess.run(
        ["bash", "-c", 'source "$1"; nimbus_gaming_set_default_proton', "bash", str(INSTALL)],
        capture_output=True, text=True, env=env,
    )
    assert proc.returncode == 0, proc.stderr


def test_pkgbuild_declares_exact_dependency_set():
    deps = _depends_set(_pkgbuild_text())
    assert deps == EXPECTED_DEPS, f"dependencias inesperadas: {sorted(deps ^ EXPECTED_DEPS)}"


def test_pkgbuild_has_no_aur_dependencies():
    text = _pkgbuild_text()
    assert "aur" not in text.lower(), "el PKGBUILD no debe referenciar AUR"
    deps = _depends_set(text)
    assert not {d for d in deps if d.endswith("-git")}, "nada de -git (AUR)"
    assert deps <= EXPECTED_DEPS


def test_pkgbuild_license_and_spdx():
    text = _pkgbuild_text()
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in text.splitlines()[0]
    assert re.search(r"license=\([^)]*GPL-3\.0-or-later[^)]*\)", text)


def test_pkgbuild_builds_from_local_tree():
    text = _pkgbuild_text()
    assert re.search(r"source=\(\s*\)", text), "source=() vacio: build desde el arbol local"
    assert "http" not in text and "git+" not in text, "sin fuentes remotas"
    # Si package() instala ficheros, es via $startdir (estilo del monorepo);
    # un metapaquete puro puede no instalar ninguno (Task 5 anade los presets).
    installs = re.findall(r"^\s*install\s", text, re.MULTILINE)
    if installs:
        assert "$startdir" in text, "los ficheros se leen via $startdir"


def test_install_is_idempotent(tmp_path):
    _run_install_entrypoint(tmp_path)
    first = {p.name: p.read_bytes() for p in sorted(tmp_path.iterdir())}
    assert first, "el .install debe dejar configuracion escrita"
    _run_install_entrypoint(tmp_path)
    second = {p.name: p.read_bytes() for p in sorted(tmp_path.iterdir())}
    assert first == second, "ejecutarlo dos veces no debe duplicar nada"
    blob = b"\n".join(second.values())
    assert blob.count(b"proton-cachyos") >= 1, "el Proton por defecto debe quedar configurado"
    proton_file = tmp_path / "default-proton"
    assert proton_file.is_file()
    assert proton_file.read_text(encoding="utf-8").strip() == "proton-cachyos"
    assert proton_file.read_text(encoding="utf-8").count("proton-cachyos") == 1


def test_install_does_not_autolaunch():
    lines = [
        line for line in _install_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]
    code = "\n".join(lines)
    forbidden = [
        r"(^|[;&|]\s*|\s)(steam|steam-native)(\s|$|[;&])",
        r"\bxdg-open\b",
        r"\bsystemctl\b.*\b(start|enable)\b",
        r"\bgtk-launch\b",
        r"steam://.*rungameid",
    ]
    for pattern in forbidden:
        assert not re.search(pattern, code), f"el .install no debe lanzar nada ({pattern})"


def test_install_sets_default_proton():
    text = _install_text()
    assert "proton-cachyos" in text, "el Proton por defecto (proton-cachyos) debe configurarse"
    assert "nimbus_gaming_set_default_proton" in text
    assert "post_install" in text
