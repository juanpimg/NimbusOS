# SPDX-License-Identifier: GPL-3.0-or-later
import pathlib
import re
import shutil
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONFIG = ROOT / "dots" / "hypr" / "hyprland.lua"
PKGBUILD = ROOT / "packages" / "nimbus-dots" / "PKGBUILD"

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
    # En modo Lua no se lee ningun .conf: el layout vive en hl.config().
    text = CONFIG.read_text(encoding="utf-8")
    assert re.search(r"hl\.config\s*\(", text)
    assert re.search(r'general\s*=\s*\{[^}]*layout\s*=\s*"floating"', text, re.S)


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
    # La regla de ventana es nativa (hl.window_rule), no sintaxis clasica.
    text = CONFIG.read_text(encoding="utf-8")
    assert re.search(r"hl\.window_rule\s*\(", text)
    assert re.search(r"fullscreen\s*=\s*true", text)
    assert re.search(r'match\s*=\s*\{\s*class\s*=\s*"emergency"\s*\}', text)


def test_no_classic_window_rules_in_repo():
    # En modo Lua los .conf no se cargan: ninguna regla clasica llegaria al
    # compositor, asi que el repo no debe contener ninguna. Los binarios
    # (fondos PNG) se saltan: no son texto buscable.
    offenders = []
    for path in sorted((ROOT / "dots").rglob("*")):
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if re.search(r"(?m)^\s*windowrule\s*=", text):
            offenders.append(str(path.relative_to(ROOT)))
    assert offenders == []


def test_quirks_conf_is_gone():
    # Regression: en modo Lua un .conf junto a hyprland.lua nunca se carga.
    assert not (ROOT / "dots" / "hypr" / "quirks.conf").exists()


def test_pkgbuild_does_not_install_quirks_conf():
    text = PKGBUILD.read_text(encoding="utf-8")
    assert "quirks.conf" not in text
    assert "hyprland.lua" in text


# --- Pista ISO (T1-T2): fondo de Nimbus y arranque con el wrapper. ---

NIMBUS_START = ROOT / "dots" / "nimbus" / "nimbus-start"
WALLPAPER_DARK = "/usr/share/nimbus/backgrounds/Nimbus.png"


def _misc_block():
    text = CONFIG.read_text(encoding="utf-8")
    match = re.search(r"misc\s*=\s*\{(.*?)\}", text, re.S)
    assert match is not None, "hyprland.lua debe declarar el bloque misc"
    return match.group(1)


def test_misc_disables_the_hyprland_branding():
    # La ISO no puede mostrar el fondo anime de Hyprland: el renderer base
    # integrado lee /usr/share/hypr/wall<N>.png y se apaga con
    # disable_hyprland_logo (verificado en el binario 0.56 y en la wiki).
    misc = _misc_block()
    assert re.search(r"disable_hyprland_logo\s*=\s*true", misc), misc
    assert re.search(r"disable_splash_rendering\s*=\s*true", misc), misc


def test_misc_base_color_is_the_nimbus_dark_tone():
    # Sin logo, la base la pinta background_color: tiene que ser el oscuro
    # de la paleta Nimbus (#1C1C1E), no el gris de Hyprland (0x111111).
    misc = _misc_block()
    match = re.search(r"background_color\s*=\s*\"([^\"]+)\"", misc)
    assert match is not None, misc
    assert "1c1c1e" in match.group(1).lower(), match.group(1)


def test_misc_pins_a_non_anime_fallback_wallpaper():
    # Si el fondo de Hyprland llegara a pintarse, que sea wall0 (no anime),
    # nunca aleatorio (-1).
    misc = _misc_block()
    match = re.search(r"force_default_wallpaper\s*=\s*(-?\d+)", misc)
    assert match is not None, misc
    assert match.group(1) in ("0", "1"), match.group(1)


def test_misc_disables_the_start_hyprland_warning():
    # Con el wrapper (start-hyprland) el aviso no sale; la clave es red de
    # seguridad para lanzamientos manuales en depuracion.
    misc = _misc_block()
    assert re.search(r"disable_watchdog_warning\s*=\s*true", misc), misc


def test_session_startup_shows_the_nimbus_wallpaper():
    text = NIMBUS_START.read_text(encoding="utf-8")
    assert "swaybg" in text
    assert WALLPAPER_DARK in text
    # Si el fondo o swaybg faltan, la sesion sigue: el shell pinta su base.
    assert re.search(r"command -v swaybg|if.*swaybg", text), text


def test_session_startup_keeps_launching_the_shell():
    text = NIMBUS_START.read_text(encoding="utf-8")
    assert "/usr/bin/nimbus-shell" in text
    assert "hyprland.start" in CONFIG.read_text(encoding="utf-8")
