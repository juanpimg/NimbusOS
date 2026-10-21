# SPDX-License-Identifier: GPL-3.0-or-later
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
