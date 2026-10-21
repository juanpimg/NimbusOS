# SPDX-License-Identifier: GPL-3.0-or-later
import pathlib
import re
import shutil
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONFIG = ROOT / "dots" / "hypr" / "hyprland.lua"
QUIRKS = ROOT / "dots" / "hypr" / "quirks.conf"

REQUIRED_BINDS = {
    ("SUPER", "Return"): "kitty",
    ("SUPER", "D"): "dock",
    ("SUPER", "Space"): "spotlight",
    ("SUPER", "Tab"): "switcher",
    ("SUPER", "Q"): "closewindow",
    ("SUPER", "W"): "closewindow",
    ("SUPER", "C"): "copy",
    ("SUPER", "V"): "paste",
    ("SUPER", "L"): "lock",
    ("PRINT",): "screenshot",
}

# La config usa la API Lua de Hyprland 0.55+: hl.bind("MOD", "KEY", accion).
# El grupo de acción se captura hasta el fin de línea: contiene el texto que
# se busca, y el resto de paréntesis no importa para la comprobación.
BIND_RE = re.compile(
    r'hl\.bind\(\s*(?P<keys>"[^"]+"(?:\s*,\s*"[^"]+")*)\s*,\s*(?P<action>[^\n]+)$',
    re.M,
)


def _binds():
    text = CONFIG.read_text(encoding="utf-8")
    out = []
    for match in BIND_RE.finditer(text):
        keys = tuple(k.strip().strip('"') for k in match.group("keys").split(","))
        out.append((keys, match.group("action")))
    return out


def _find(keys, action):
    """Devuelve la acción del bind cuyas teclas coinciden, o None."""
    for bound_keys, bound_action in _binds():
        if set(bound_keys) == set(keys) and action in bound_action:
            return bound_action
    return None


def test_config_file_exists():
    assert CONFIG.is_file()


def test_config_is_valid_lua():
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
            missing.append(f"{'+'.join(keys)} -> {action}")
    assert missing == [], "\n".join(missing)


def test_workspace_bindings_one_through_nine():
    missing = [
        str(n) for n in range(1, 10) if _find(("SUPER", str(n)), "workspace") is None
    ]
    assert missing == [], f"faltan binds de workspace: {missing}"


def test_emergency_session_is_declared():
    text = CONFIG.read_text(encoding="utf-8")
    assert "emergency" in text.lower()
    assert "kitty" in text
