# SPDX-License-Identifier: GPL-3.0-or-later
"""Entry point del shell Quickshell: qs -c debe encontrar shell.qml.

La cadena completa es: Hyprland -> dots/nimbus/nimbus-start -> /usr/bin/nimbus-shell
-> qs -c /usr/lib/nimbus/shell/src -> shell.qml -> main.qml. Si falta shell.qml,
qs muere al instante y no hay proceso de shell.
"""
import pathlib
import re

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHELL_QML = ROOT / "shell" / "src" / "shell.qml"
MAIN_QML = ROOT / "shell" / "src" / "main.qml"
QMLDIR = ROOT / "shell" / "src" / "Nimbus" / "qmldir"
LAUNCHER = ROOT / "shell" / "nimbus-shell"
PKGBUILD = ROOT / "packages" / "nimbus-shell" / "PKGBUILD"

# Propiedades QML cuyo valor es texto visible por el usuario. Asignarles un
# literal ("...") en vez de Config.translated(...) es el defecto que se caza.
USER_TEXT_PROPS = (
    "text",
    "title",
    "label",
    "placeholderText",
    "placeholder",
    "tooltip",
    "description",
    "message",
    "subtitle",
)
USER_TEXT_RE = re.compile(
    r"(?<![\w.])(?:" + "|".join(USER_TEXT_PROPS) + r")\s*:\s*[\"']",
)
HEX_COLOR_RE = re.compile(r"#[0-9a-fA-F]{3,8}\b")


def _strip_line_comments(text):
    return "\n".join(
        line.split("//", 1)[0] for line in text.splitlines()
    )


def test_shell_qml_exists_and_has_spdx():
    assert SHELL_QML.is_file(), "falta shell/src/shell.qml: qs -c moriria al instante"
    head = SHELL_QML.read_text(encoding="utf-8")[:600]
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in head


def test_qmldir_registers_the_three_singletons():
    assert QMLDIR.is_file()
    text = QMLDIR.read_text(encoding="utf-8")
    assert text.splitlines()[0].strip() == "module Nimbus"
    for singleton in ("Theme", "Config", "Translations"):
        assert re.search(
            rf"^singleton\s+{singleton}\s+1\.0\s+{singleton}\.qml",
            text,
            re.M,
        ), f"qmldir no registra el singleton {singleton}"


def test_launcher_qs_c_points_to_dir_containing_shell_qml():
    text = LAUNCHER.read_text(encoding="utf-8")
    match = re.search(r"qs\s+-c\s+([^\s\"']+)", text)
    assert match, "el launcher no pasa ningun directorio a qs -c"
    qs_dir = match.group(1)
    # Layout instalado: el paquete copia shell/src a esta ruta.
    assert qs_dir == "/usr/lib/nimbus/shell/src", (
        f"qs -c apunta a {qs_dir!r}, se esperaba /usr/lib/nimbus/shell/src"
    )
    # Esa ruta instalada corresponde a shell/src en el arbol de fuentes y
    # debe contener shell.qml (lo que qs busca).
    assert SHELL_QML.is_file(), (
        f"qs -c {qs_dir} no encontraria shell.qml: falta {SHELL_QML}"
    )


def test_launcher_import_path_contains_nimbus_module():
    text = LAUNCHER.read_text(encoding="utf-8")
    assert "QML2_IMPORT_PATH" in text
    # El import path debe ser el directorio que contiene la carpeta Nimbus/.
    assert "/usr/lib/nimbus/shell/src" in text
    assert (ROOT / "shell" / "src" / "Nimbus").is_dir()
    assert QMLDIR.is_file()


def test_shell_qml_loads_main_qml():
    text = SHELL_QML.read_text(encoding="utf-8")
    assert "main.qml" in text, "shell.qml no carga main.qml: no habria ventana en M0"


def test_shell_qml_uses_design_system():
    text = SHELL_QML.read_text(encoding="utf-8")
    assert "Theme." in text, "shell.qml no usa Theme"
    assert "Config.translated(" in text, "shell.qml no usa Config.translated"


def test_shell_qml_has_no_hardcoded_user_strings():
    text = _strip_line_comments(SHELL_QML.read_text(encoding="utf-8"))
    assert "qsTr(" not in text, "shell.qml usa qsTr: debe usar Config.translated"
    assert "qsTranslate(" not in text
    assert "QT_TR_NOOP" not in text
    offenders = USER_TEXT_RE.findall(text)
    assert not USER_TEXT_RE.search(text), (
        f"shell.qml asigna literales a propiedades de texto visible: {offenders}"
    )
    # Contrapueba: el patron caza text: "literal" si alguien lo introduce.
    assert USER_TEXT_RE.search('Text { text: "Hola" }'), "el patron no caza literales"


def test_main_qml_has_no_hardcoded_colors():
    text = MAIN_QML.read_text(encoding="utf-8")
    assert "Theme." in text
    assert not HEX_COLOR_RE.search(text), (
        f"main.qml contiene colores literales: {HEX_COLOR_RE.findall(text)}"
    )
    # Contrapueba: el patron caza un color literal tipico.
    assert HEX_COLOR_RE.search('color: "#ff0000"'), "el patron no caza colores"


def test_main_qml_has_no_hardcoded_user_strings():
    text = _strip_line_comments(MAIN_QML.read_text(encoding="utf-8"))
    assert "Config.translated(" in text
    assert "qsTr(" not in text, "main.qml usa qsTr: debe usar Config.translated"
    assert "qsTranslate(" not in text
    assert not USER_TEXT_RE.search(text), "main.qml asigna literales a texto visible"


def test_pkgbuild_installs_shell_qml_and_launcher():
    text = PKGBUILD.read_text(encoding="utf-8")
    # El cp -r del arbol src es lo que entrega shell.qml instalado.
    assert re.search(r"cp\s+-r.*shell/src.*usr/lib/nimbus/shell/src", text), (
        "PKGBUILD no instala el arbol shell/src (donde vive shell.qml)"
    )
    assert "shell/nimbus-shell" in text
    assert "/usr/bin/nimbus-shell" in text
