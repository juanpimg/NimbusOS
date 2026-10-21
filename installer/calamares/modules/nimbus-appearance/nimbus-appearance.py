# SPDX-License-Identifier: GPL-3.0-or-later
"""Modulo Calamares de apariencia de Nimbus.

Dos paginas: "Tema" (claro/oscuro/auto) y "Color de acento" (12 presets).
Escribe el resultado en /etc/nimbus/appearance.conf del sistema instalado
y lo aplica sobre los ficheros de ~/.config/ con kwriteconfig.
"""

import pathlib
import shutil
import subprocess

try:  # Calamares provee libcalamares en el ISO live; ausente en CI/test.
    import libcalamares
except ImportError:  # pragma: no cover - entorno sin Calamares
    libcalamares = None

VALID_MODES = ("light", "dark", "auto")

# 12 presets de color de acento (hex RGB sin '#', 007AFF es el defecto).
ACCENT_PRESETS = (
    "007AFF",  # azul Nimbus
    "5856D6",  # violeta
    "AF52DE",  # purpura
    "FF2D55",  # rosa
    "FF3B30",  # rojo
    "FF9500",  # naranja
    "FFCC00",  # amarillo
    "34C759",  # verde
    "00C7BE",  # turquesa
    "32ADE6",  # celeste
    "0A84FF",  # azul noche
    "8E8E93",  # gris
)

THEME_PAGE_MODES = ("claro", "oscuro", "auto")

DEFAULT_WALLPAPER = "nimbus-default"

KWRITECONFIG_BINARIES = ("kwriteconfig6", "kwriteconfig5", "kwriteconfig")


def normalize_accent(value):
    """Normaliza un acento a hex RGB en mayusculas sin '#'.

    Acepta cualquiera de los 12 presets o un hex valido de 6 digitos.
    """
    text = str(value).strip().lstrip("#").upper()
    if len(text) != 6 or any(c not in "0123456789ABCDEF" for c in text):
        raise ValueError(f"acento no valido: {value!r}")
    return text


def validate_mode(mode):
    """Valida el modo de tema (light/dark/auto)."""
    text = str(mode).strip().lower()
    if text not in VALID_MODES:
        raise ValueError(f"modo no valido: {mode!r} (usa {VALID_MODES})")
    return text


def render_appearance_conf(mode, accent, wallpaper=DEFAULT_WALLPAPER):
    """Genera el contenido de /etc/nimbus/appearance.conf."""
    mode = validate_mode(mode)
    accent = normalize_accent(accent)
    return (
        "# SPDX-License-Identifier: GPL-3.0-or-later\n"
        "[appearance]\n"
        f"mode={mode}\n"
        f"accent={accent}\n"
        f"wallpaper={wallpaper}\n"
    )


def find_kwriteconfig():
    """Localiza el binario kwriteconfig disponible, o None."""
    for binary in KWRITECONFIG_BINARIES:
        path = shutil.which(binary)
        if path:
            return path
    return None


def kwriteconfig_commands(mode, accent):
    """Comandos kwriteconfig que aplican tema y acento en ~/.config/."""
    accent = normalize_accent(accent)
    mode = validate_mode(mode)
    color_scheme = {
        "light": "NimbusLight",
        "dark": "NimbusDark",
        "auto": "NimbusAuto",
    }[mode]
    binary = find_kwriteconfig() or KWRITECONFIG_BINARIES[0]
    return [
        [binary, "--file", "kdeglobals", "--group", "General",
         "--key", "ColorScheme", color_scheme],
        [binary, "--file", "kdeglobals", "--group", "General",
         "--key", "AccentColor", accent],
        [binary, "--file", "nimbus-appearance", "--group", "Appearance",
         "--key", "Mode", mode],
    ]


def apply_with_kwriteconfig(mode, accent, runner=None):
    """Aplica tema y acento con kwriteconfig. Devuelve la lista ejecutada."""
    runner = runner or subprocess.run
    executed = []
    for command in kwriteconfig_commands(mode, accent):
        runner(command, check=False)
        executed.append(command)
    return executed


def read_selection():
    """Lee la seleccion del usuario desde el globalstorage de Calamares."""
    if libcalamares is None:
        return {"mode": "light", "accent": "007AFF",
                "wallpaper": DEFAULT_WALLPAPER}
    storage = libcalamares.globalstorage
    return {
        "mode": storage.value("nimbusAppearanceMode") or "light",
        "accent": storage.value("nimbusAppearanceAccent") or "007AFF",
        "wallpaper": storage.value("nimbusAppearanceWallpaper")
        or DEFAULT_WALLPAPER,
    }


def pretty_name():
    return "Apariencia"


def pretty_status_message():
    return "Configurando la apariencia de Nimbus."


def run():
    """Punto de entrada de Calamares: escribe y aplica la apariencia."""
    selection = read_selection()
    mode = validate_mode(selection["mode"])
    accent = normalize_accent(selection["accent"])
    wallpaper = selection.get("wallpaper") or DEFAULT_WALLPAPER
    content = render_appearance_conf(mode, accent, wallpaper)
    if libcalamares is not None:
        libcalamares.utils.target_env_command(
            "mkdir", "-p", "/etc/nimbus")
        libcalamares.utils.target_env_command(
            "sh", "-c", f"cat > /etc/nimbus/appearance.conf <<'EOF'\n{content}EOF")
    else:  # pragma: no cover - solo en el instalador real
        target = pathlib.Path("/etc/nimbus/appearance.conf")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
    apply_with_kwriteconfig(mode, accent)
    return None
