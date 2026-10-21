# SPDX-License-Identifier: GPL-3.0-or-later
import pathlib
import subprocess
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
    for name in ("work", "pkg", "src", "build", "out", "__pycache__", ".venv"):
        assert name in check_spdx.IGNORED_DIRS, f"{name} deberia ignorarse"


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
