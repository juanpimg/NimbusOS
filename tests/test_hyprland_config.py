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
    "SUPER + Return": "kitty",
    "SUPER + D": "dock",
    "SUPER + Space": "spotlight",
    "SUPER + Tab": "switcher",
    "SUPER + Q": "window.close",
    "SUPER + W": "window.close",
    "SUPER + C": "send_shortcut",
    "SUPER + V": "send_shortcut",
    "SUPER + L": "lock",
    "PRINT": "screenshot",
}

# La config usa la API Lua real de Hyprland 0.56: hl.bind("MOD + TECLA", accion).
# El primer argumento es un UNICO string con modificadores y tecla separados
# por "+", el segundo es el dispatcher o la funcion. El grupo de accion se
# captura hasta el fin de linea: contiene el texto que se busca.
BIND_RE = re.compile(
    r'hl\.bind\(\s*"(?P<keys>[^"]+)"\s*,\s*(?P<action>[^\n]+)$',
    re.M,
)


def _binds():
    text = CONFIG.read_text(encoding="utf-8")
    out = []
    for match in BIND_RE.finditer(text):
        out.append((match.group("keys").strip(), match.group("action")))
    return out


def _find(keys, action):
    """Devuelve la accion del bind cuya combinacion de teclas coincide, o None."""
    for bound_keys, bound_action in _binds():
        if bound_keys == keys and action in bound_action:
            return bound_action
    return None


def test_config_file_exists():
    assert CONFIG.is_file()


def test_config_is_valid_lua():
    # OJO: luac -p valida SOLO la sintaxis. No comprueba que hl.bind o
    # hl.dsp.* existan en Hyprland 0.56: una llamada a una API inexistente es
    # Lua valido. La prueba real de carga es arrancar Hyprland con la config.
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
            missing.append(f"{keys} -> {action}")
    assert missing == [], "\n".join(missing)


def test_workspace_bindings_one_through_nine():
    missing = [str(n) for n in range(1, 10) if _find(f"SUPER + {n}", "workspace") is None]
    assert missing == [], f"faltan binds de workspace: {missing}"


def test_emergency_session_is_declared_and_bound():
    assert _find("SUPER + SHIFT + E", "emergency") is not None
    text = CONFIG.read_text(encoding="utf-8")
    assert "kitty" in text


def test_emergency_terminal_is_fullscreen():
    quirks = QUIRKS.read_text(encoding="utf-8")
    assert re.search(r"windowrule.*fullscreen.*emergency", quirks, re.I)
