# SPDX-License-Identifier: GPL-3.0-or-later
"""Modulo Calamares de apariencia de Nimbus.

Dos paginas: "Tema" (claro/oscuro/auto) y "Color de acento" (12 presets).
Escribe el resultado en /etc/nimbus/appearance.conf del sistema instalado;
el shell lo lee en el primer arranque (ver CONTRATO más abajo).

CONTRATO DE FORMATO (estable, lo lee otra pista en shell/src/Nimbus/):
``/etc/nimbus/appearance.conf`` es un INI UTF-8 con cabecera SPDX y una
sola seccion ``[appearance]`` con tres claves, cada una en su linea:

    # SPDX-License-Identifier: GPL-3.0-or-later
    [appearance]
    mode=<light|dark|auto>
    accent=<HEX de 6 digitos en mayusculas, sin '#'>
    wallpaper=<nombre de fondo, una sola linea>

No se escribe nada en ``~/.config/`` ni en ``kdeglobals``: Nimbus no lleva
KDE y la ISO no trae ``kwriteconfig6`` (D1: invocarlo reventaba el paso).
El fichero se escribe solo con pathlib, sin pasar por ningun interprete
de comandos.
"""

import pathlib
import re

try:  # Calamares provee libcalamares en el ISO live; ausente en CI/test.
    import libcalamares
except ImportError:  # pragma: no cover - entorno sin Calamares
    libcalamares = None

try:
    from nimbus_i18n import active_locale, translated
except ImportError:  # cargado por ruta (Calamares/test) sin paquete
    import importlib.util as _importlib_util
    import sys as _sys

    _i18n_module = _sys.modules.get("nimbus_i18n")
    if _i18n_module is None:
        _i18n_path = (
            pathlib.Path(__file__).resolve().parents[2] / "nimbus_i18n.py"
        )
        _i18n_spec = _importlib_util.spec_from_file_location(
            "nimbus_i18n", _i18n_path)
        _i18n_module = _importlib_util.module_from_spec(_i18n_spec)
        _sys.modules["nimbus_i18n"] = _i18n_module
        _i18n_spec.loader.exec_module(_i18n_module)
    active_locale = _i18n_module.active_locale
    translated = _i18n_module.translated

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

THEME_PAGE_MODES = (
    "appearance.theme.light",
    "appearance.theme.dark",
    "appearance.theme.auto",
)

# Clave de traduccion -> modo interno. La pagina QML muestra
# ``translated(clave, locale)`` y el backend compara por clave.
THEME_LABEL_TO_MODE = {
    "appearance.theme.light": "light",
    "appearance.theme.dark": "dark",
    "appearance.theme.auto": "auto",
}

# Etiquetas en español de la pagina QML anterior (compatibilidad con
# instalaciones que aun envian el texto mostrado en vez de la clave).
LEGACY_THEME_LABEL_TO_MODE = {
    "claro": "light",
    "oscuro": "dark",
    "auto": "auto",
}

DEFAULT_WALLPAPER = "nimbus-default"

_WALLPAPER_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")


def normalize_accent(value, locale=None):
    """Normaliza un acento a hex RGB en mayusculas sin '#'.

    Acepta cualquiera de los 12 presets o un hex valido de 6 digitos.
    El mensaje de error se muestra al usuario, asi que sale traducido.
    """
    lang = _current_locale(locale)
    text = str(value).strip().lstrip("#").upper()
    if len(text) != 6 or any(c not in "0123456789ABCDEF" for c in text):
        raise ValueError(
            translated("appearance.accent.invalid", lang).format(
                value=repr(value)))
    return text


def validate_mode(mode, locale=None):
    """Valida el modo de tema (light/dark/auto).

    El mensaje de error se muestra al usuario, asi que sale traducido.
    """
    lang = _current_locale(locale)
    text = str(mode).strip().lower()
    if text not in VALID_MODES:
        raise ValueError(
            translated("appearance.mode.invalid", lang).format(
                mode=repr(mode), valid=", ".join(VALID_MODES)))
    return text


def theme_page_labels(locale=None):
    """Etiquetas de la pagina Tema ya traducidas, en el orden de la QML."""
    lang = _current_locale(locale)
    return [translated(key, lang) for key in THEME_PAGE_MODES]


def theme_mode_label(key, locale=None):
    """Texto traducido de una clave de THEME_PAGE_MODES."""
    return translated(key, _current_locale(locale))


def theme_label_to_mode(label, locale=None):
    """Convierte la etiqueta de la pagina Tema a modo interno.

    Acepta la clave de traduccion (lo que envia la pagina QML), el modo
    interno, la etiqueta legacy en español o el texto ya traducido
    (ES/EN, insensible a mayusculas). Cualquier otro valor lanza
    ValueError con el mensaje traducido, que Calamares muestra al usuario.
    """
    lang = _current_locale(locale)
    text = str(label).strip()
    if text in THEME_LABEL_TO_MODE:
        return THEME_LABEL_TO_MODE[text]
    lowered = text.lower()
    if lowered in VALID_MODES:
        return lowered
    if lowered in LEGACY_THEME_LABEL_TO_MODE:
        return LEGACY_THEME_LABEL_TO_MODE[lowered]
    for key, mode in THEME_LABEL_TO_MODE.items():
        for probe_locale in ("es", "en", lang):
            if lowered == str(translated(key, probe_locale)).strip().lower():
                return mode
    valid = ", ".join(translated(key, lang) for key in THEME_PAGE_MODES)
    raise ValueError(
        translated("appearance.theme.invalid", lang).format(
            label=repr(label), valid=valid))


def validate_wallpaper(value, locale=None):
    """Valida el nombre de fondo: una sola linea, charset restringido.

    El fichero lo parsea el shell linea a linea; un salto de linea lo
    corromperia, asi que se rechaza con ValueError traducido.
    """
    lang = _current_locale(locale)
    text = str(value)
    if not _WALLPAPER_RE.fullmatch(text):
        raise ValueError(
            translated("appearance.wallpaper.invalid", lang).format(
                value=repr(value)))
    return text


def render_appearance_conf(mode, accent, wallpaper=DEFAULT_WALLPAPER,
                           locale=None):
    """Genera el contenido de /etc/nimbus/appearance.conf (ver CONTRATO)."""
    mode = validate_mode(mode, locale=locale)
    accent = normalize_accent(accent, locale=locale)
    wallpaper = validate_wallpaper(wallpaper, locale=locale)
    return (
        "# SPDX-License-Identifier: GPL-3.0-or-later\n"
        "[appearance]\n"
        f"mode={mode}\n"
        f"accent={accent}\n"
        f"wallpaper={wallpaper}\n"
    )


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


def _current_locale(locale=None):
    """Idioma efectivo: parametro, ajuste del instalador o entorno."""
    if locale is not None:
        return locale
    if libcalamares is not None:
        try:
            storage = libcalamares.globalstorage
            for key in ("nimbusLocale", "locale", "lang"):
                value = storage.value(key)
                if value:
                    return str(value)
        except Exception:
            pass
    return active_locale()


def pretty_name(locale=None):
    return translated("appearance.pretty_name", _current_locale(locale))


def pretty_status_message(locale=None):
    return translated("appearance.pretty_status", _current_locale(locale))


def write_appearance_conf(content, root="/"):
    """Escribe appearance.conf en el sistema destino sin invocar shell.

    Usa solo pathlib con argumentos discretos: ni el fondo ni ningun
    otro valor que venga de globalstorage pasa por un interprete de
    comandos, asi que un salto de linea malicioso no puede inyectar nada.
    """
    target = pathlib.Path(str(root)) / "etc" / "nimbus" / "appearance.conf"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
    return target


def run(locale=None):
    """Punto de entrada de Calamares: escribe la apariencia.

    Solo escribe /etc/nimbus/appearance.conf (ver CONTRATO): no invoca
    ningun binario externo porque la ISO no trae kwriteconfig.

    Calamares muestra al usuario el texto de cualquier excepcion no
    capturada, por eso los validadores reciben el locale efectivo y
    lanzan ValueError ya traducidos.
    """
    effective = _current_locale(locale)
    selection = read_selection()
    mode = validate_mode(selection["mode"], locale=effective)
    accent = normalize_accent(selection["accent"], locale=effective)
    wallpaper = selection.get("wallpaper") or DEFAULT_WALLPAPER
    content = render_appearance_conf(mode, accent, wallpaper,
                                     locale=effective)
    if libcalamares is not None:
        root = libcalamares.globalstorage.value("rootMountPoint") or "/"
    else:  # pragma: no cover - solo en el instalador real
        root = "/"
    write_appearance_conf(content, root=root)
    return None
