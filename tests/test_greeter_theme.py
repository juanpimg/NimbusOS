# SPDX-License-Identifier: GPL-3.0-or-later
"""Tema SDDM de Nimbus: estructura, metadatos, API QML y marca.

No necesita SDDM instalado: todo se comprueba por estatico sobre los
ficheros del tema en installer/greeter/nimbus-greeter/.
"""
import configparser
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
THEME = ROOT / "installer" / "greeter" / "nimbus-greeter"

REQUIRED_FILES = ("metadata.desktop", "Main.qml", "theme.conf", "background.svg")

# Restos de marca que no pueden aparecer en ningun fichero del tema.
APPLE_MARKS = (
    "",
    "apple",
    "macintosh",
    "macos_screenshot",
    "SF Pro",
    "SFPro",
    "San Francisco",
    "-apple-system",
)

# Propiedades que delatarian que la contrasena se guarda en el tema.
PASSWORD_STORE_RES = (
    re.compile(r"property\s+string\s+\w*(password|passwd|secret)\w*\s*:", re.I),
    re.compile(r"property\s+string\s+stored\w*\s*:", re.I),
    re.compile(r"\b(storedPassword|savedPassword|lastPassword|cachedPassword)\b"),
)


def _theme_text(suffixes=(".qml", ".desktop", ".conf", ".svg")):
    blobs = {}
    for path in sorted(THEME.rglob("*")):
        if path.is_file() and path.suffix.lower() in suffixes:
            blobs[path.relative_to(THEME).as_posix()] = path.read_text(encoding="utf-8")
    return blobs


def test_required_files_are_present():
    missing = [name for name in REQUIRED_FILES if not (THEME / name).is_file()]
    assert missing == [], f"faltan ficheros que SDDM exige: {missing}"


def test_metadata_declares_sddm_theme_type():
    parser = configparser.ConfigParser(interpolation=None)
    parser.read(THEME / "metadata.desktop", encoding="utf-8")
    values = {}
    for section in parser.sections():
        values.update({k.lower(): v for k, v in parser.items(section)})
    assert values.get("type") == "sddm-theme", (
        "metadata.desktop debe declarar Type=sddm-theme"
    )


def test_metadata_theme_name_is_nimbus():
    text = (THEME / "metadata.desktop").read_text(encoding="utf-8")
    assert re.search(r"(?m)^Theme-Name\s*=\s*Nimbus\s*$", text), (
        "metadata.desktop debe declarar Theme-Name=Nimbus"
    )


def test_metadata_points_at_main_qml_and_theme_conf():
    text = (THEME / "metadata.desktop").read_text(encoding="utf-8")
    assert re.search(r"(?m)^MainScript\s*=\s*Main\.qml\s*$", text)
    assert re.search(r"(?m)^ConfigFile\s*=\s*theme\.conf\s*$", text)


def test_main_qml_declares_current_user_property():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert re.search(r"property\s+string\s+currentUser\s*:", text), (
        "Main.qml debe declarar `property string currentUser`"
    )


def test_main_qml_declares_password_wrong_property():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert re.search(r"property\s+bool\s+passwordWrong\s*:", text)


def test_main_qml_declares_busy_property():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert re.search(r"property\s+bool\s+busy\s*:", text)


def test_main_qml_declares_login_requested_signal():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert re.search(
        r"signal\s+loginRequested\s*\(\s*string\s+user\s*,\s*string\s+password\s*\)",
        text,
    )


def test_main_qml_declares_reboot_signal():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert re.search(r"signal\s+rebootRequested\s*\(\s*\)", text)


def test_main_qml_declares_shutdown_signal():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert re.search(r"signal\s+shutdownRequested\s*\(\s*\)", text)


def test_main_qml_is_plain_qtquick_item():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert "PanelWindow" not in text, "el tema SDDM no usa Quickshell PanelWindow"
    assert "ShellRoot" not in text, "el tema SDDM no usa Quickshell ShellRoot"
    assert "Quickshell" not in text, "el tema SDDM no importa Quickshell"
    assert re.search(r"^\s*Item\s*\{", text, re.M), (
        "la raiz del tema debe ser un Item normal de QtQuick"
    )


def test_main_qml_has_big_clock_and_localised_date():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert "Timer" in text, "el reloj necesita un Timer que lo actualice"
    assert "Qt.locale()" in text, "la fecha/hora deben usar el idioma del sistema"
    assert re.search(r"format(Date|Time)", text), (
        "el reloj debe formatear hora y fecha"
    )


def test_main_qml_lists_users_with_avatar():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert "userModel" in text, "la lista de usuarios usa el userModel de SDDM"
    assert re.search(r"ListView|Repeater", text)
    assert re.search(r"avatar|icon", text, re.I), (
        "cada usuario muestra su avatar"
    )


def test_password_error_shows_inline_and_keeps_user():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert "passwordWrong" in text
    # El mensaje de error se muestra en el sitio (visible ligado a passwordWrong).
    assert re.search(r"visible\s*:\s*.*passwordWrong", text), (
        "el error de contrasena debe mostrarse en el sitio"
    )
    # Al fallar no se borra el usuario: ningun handler de passwordWrong
    # puede vaciar currentUser.
    for match in re.finditer(r"onPasswordWrongChanged[^\n]*\n(?:.*\n){0,3}", text):
        assert "currentUser" not in match.group(0) or '""' not in match.group(0), (
            "fallar el login no debe borrar el usuario"
        )
    assert not re.search(r"onPasswordWrongChanged\s*:\s*\{[^}]*currentUser\s*=\s*\"\"", text, re.S)


def test_password_is_emitted_not_stored():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    for pattern in PASSWORD_STORE_RES:
        assert not pattern.search(text), (
            f"la contrasena no se guarda en propiedades: {pattern.pattern}"
        )
    # Se emite en la senal y se descarta: tras emitir, el campo se vacia.
    assert re.search(r"loginRequested\s*\(", text), (
        "la contrasena debe emitirse en loginRequested"
    )
    assert re.search(r"\.text\s*=\s*\"\"", text), (
        "tras emitir la senal, el campo de contrasena se descarta"
    )


def test_no_apple_trademarked_assets():
    blobs = _theme_text()
    assert blobs, "el tema no contiene ficheros analizables"
    offenders = [
        name
        for name, text in blobs.items()
        if any(mark.lower() in text.lower() for mark in APPLE_MARKS)
    ]
    assert offenders == [], f"assets de Apple en: {offenders}"
    asset_names = [p.name.lower() for p in THEME.rglob("*") if p.is_file()]
    bad_names = [n for n in asset_names if "apple" in n or "sfpro" in n or "sf-pro" in n]
    assert bad_names == [], f"nombres de fichero con marca Apple: {bad_names}"


def test_greeter_uses_inter_font():
    blobs = _theme_text()
    joined = "\n".join(blobs.values())
    assert "Inter" in joined, "la tipografia del greeter es Inter, la del proyecto"


def test_avatar_has_placeholder_fallback():
    text = (THEME / "Main.qml").read_text(encoding="utf-8")
    assert re.search(r"placeholder|fallback|onStatusChanged|onStatusChanged|defaultAvatar", text, re.I), (
        "el greeter no debe romperse si falta un avatar: usa un placeholder"
    )
    placeholders = list(THEME.glob("*placeholder*")) + list(THEME.glob("*avatar*"))
    assert placeholders or "placeholder" in text.lower(), (
        "debe existir un asset o dibujo placeholder para avatares ausentes"
    )


def test_nimbus_logo_is_referenced():
    blobs = _theme_text()
    joined = "\n".join(blobs.values()).lower()
    assert "nimbus" in joined, "el greeter debe mostrar el logo de Nimbus"
