# SPDX-License-Identifier: GPL-3.0-or-later
import pathlib
import subprocess

import pytest
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def test_check_spdx_passes_on_clean_tree():
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "check_spdx.py"), "--root", str(ROOT)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_check_spdx_ignores_build_output_directories():
    """El chequeo no debe mirar dentro de los arboles de build.

    Sin esto, un desarrollador con un `iso/work/` a medias ve fallar el
    linter por ficheros que no son codigo fuente.
    """
    sys.path.insert(0, str(ROOT / "tools"))
    try:
        import check_spdx
    finally:
        sys.path.pop(0)
    for name in ("work", "build", "out", "__pycache__", ".venv", ".pytest_cache"):
        assert name in check_spdx.IGNORED_DIRS, f"{name} deberia ignorarse"


def test_check_spdx_does_not_ignore_real_source_under_src():
    """`shell/src/` es codigo fuente; solo `packages/*/src/` es scratch.

    Confundir los dos deja el shell entero sin comprobar.
    """
    sys.path.insert(0, str(ROOT / "tools"))
    try:
        import check_spdx
    finally:
        sys.path.pop(0)
    shell_src = ROOT / "shell" / "src"
    if not shell_src.is_dir():
        pytest.skip("shell/src no existe todavia")
    qml = [p for p in shell_src.rglob("*.qml") if p.is_file()]
    assert qml, "no hay ficheros QML que comprobar"
    for path in qml:
        assert not check_spdx.is_ignored(path), f"{path} no deberia ignorarse"


def test_check_spdx_detects_a_missing_header(tmp_path):
    """La herramienta tiene que FALLAR cuando falta una cabecera.

    Si no, un chequeo que siempre pasa no comprueba nada.
    """
    (tmp_path / "roto.py").write_text("print('sin cabecera')\n", encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "check_spdx.py"), "--root", str(tmp_path)],
        capture_output=True, text=True,
    )
    assert result.returncode == 1
    assert "falta SPDX GPL-3.0-or-later" in result.stdout


def test_licenses_md_exists_and_lists_third_party():
    text = (ROOT / "LICENSES.md").read_text(encoding="utf-8")
    assert "MacShell" in text
    assert "MIT" in text
