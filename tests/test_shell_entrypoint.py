# SPDX-License-Identifier: GPL-3.0-or-later
"""Entry point del shell Quickshell: qs -c debe encontrar shell.qml.

La cadena completa es: Hyprland -> dots/nimbus/nimbus-start -> /usr/bin/nimbus-shell
-> qs -c /usr/lib/nimbus/shell/src -> shell.qml (raiz ShellRoot con un PanelWindow
gestionado por Quickshell). Si falta shell.qml, o su raiz no es un tipo de
Quickshell, qs muere al instante y no hay proceso de shell.
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
# El tipo raiz: la primera declaracion de componente del fichero (tras
# imports, pragmas y comentarios).
ROOT_TYPE_RE = re.compile(r"^\s*(\w+)\s*\{", re.M)


def _strip_line_comments(text):
    return "\n".join(
        line.split("//", 1)[0] for line in text.splitlines()
    )


def _root_type(text):
    """Tipo raiz del QML (ignora imports, pragmas y comentarios)."""
    code = _strip_line_comments(text)
    code = re.sub(r"^\s*import\s+\S+.*$", "", code, flags=re.M)
    code = re.sub(r"^\s*pragma\s+\S+.*$", "", code, flags=re.M)
    match = ROOT_TYPE_RE.search(code)
    assert match, "no se encontro ningun tipo raiz en el QML"
    return match.group(1)


def test_shell_qml_exists_and_has_spdx():
    assert SHELL_QML.is_file(), "falta shell/src/shell.qml: qs -c moriria al instante"
    head = SHELL_QML.read_text(encoding="utf-8")[:600]
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in head


def test_shell_qml_root_is_shellroot():
    text = SHELL_QML.read_text(encoding="utf-8")
    # El modulo que provee ShellRoot debe importarse (no basta mencionarlo).
    assert re.search(r"^\s*import\s+Quickshell\b", text, re.M), (
        "shell.qml no importa el modulo Quickshell que provee ShellRoot"
    )
    assert _root_type(text) == "ShellRoot", (
        f"la raiz de shell.qml es {_root_type(text)!r}, no ShellRoot"
    )
    # Contrapueba: el detector distingue una raiz Item de una ShellRoot.
    assert _root_type("import QtQuick\nItem {\n}") == "Item"


def test_shell_qml_has_no_loose_qtquick_window():
    text = _strip_line_comments(SHELL_QML.read_text(encoding="utf-8"))
    # Ni Window como raiz (o anidado), ni un Loader cargando main.qml como antes.
    assert not re.search(r"^\s*Window\s*\{", text, re.M), (
        "shell.qml usa Window de QtQuick: las superficies las crea PanelWindow"
    )
    assert "main.qml" not in text
    # Integracion M1: cada modulo va tras un Loader defensivo (status +
    # onStatusChanged). Se prohibe el Loader fragil sin guarda, no todo Loader.
    loaders = re.findall(r"^\s*Loader\s*\{", text, re.M)
    assert loaders, "shell.qml debe montar los modulos con Loader defensivo"
    assert "onStatusChanged" in text, (
        "los Loader de shell.qml deben vigilar status (carga defensiva)"
    )
    assert "Loader.Error" in text, (
        "los Loader de shell.qml deben tratar Loader.Error"
    )
    # Contrapueba: el patron caza el Loader de la ronda anterior.
    assert re.search(r"^\s*Loader\s*\{", "Loader {\nsource: \"main.qml\"\n}", re.M)


def test_no_loose_window_main_qml():
    # main.qml dejo de existir como Window suelto: su contenido vive en shell.qml.
    if MAIN_QML.is_file():
        text = _strip_line_comments(MAIN_QML.read_text(encoding="utf-8"))
        assert not re.search(r"^\s*Window\s*\{", text, re.M), (
            "main.qml no debe ser un Window suelto cargado via Loader"
        )


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


def test_shell_qml_uses_design_system():
    text = SHELL_QML.read_text(encoding="utf-8")
    assert "Theme." in text, "shell.qml no usa Theme"
    assert "Config.translated(" in text, "shell.qml no usa Config.translated"


def test_shell_qml_has_no_hardcoded_user_strings():
    text = _strip_line_comments(SHELL_QML.read_text(encoding="utf-8"))
    assert "qsTr(" not in text, "shell.qml usa qsTr: debe usar Config.translated"
    assert "qsTranslate(" not in text
    assert "QT_TR_NOOP" not in text
    assert not USER_TEXT_RE.search(text), (
        "shell.qml asigna literales a propiedades de texto visible"
    )
    # Contrapueba: el patron caza text: "literal" si alguien lo introduce.
    assert USER_TEXT_RE.search('Text { text: "Hola" }'), "el patron no caza literales"


def test_shell_qml_colors_and_metrics_come_from_theme():
    text = SHELL_QML.read_text(encoding="utf-8")
    assert "Theme.background" in text, "el fondo no sale de Theme"
    assert re.search(r"Theme\.(spacing|radius|barHeight|dockSize)", text), (
        "ninguna metrica sale de Theme (spacing/radius/barHeight/dockSize)"
    )
    assert not HEX_COLOR_RE.search(text), (
        f"shell.qml contiene colores literales: {HEX_COLOR_RE.findall(text)}"
    )
    # Contrapueba: el patron caza un color literal tipico.
    assert HEX_COLOR_RE.search('color: "#ff0000"'), "el patron no caza colores"


def test_pkgbuild_installs_shell_qml_and_launcher():
    text = PKGBUILD.read_text(encoding="utf-8")
    # El cp -r del arbol src es lo que entrega shell.qml instalado.
    assert re.search(r"cp\s+-r.*shell/src.*usr/lib/nimbus/shell/src", text), (
        "PKGBUILD no instala el arbol shell/src (donde vive shell.qml)"
    )
    assert "shell/nimbus-shell" in text
    assert "/usr/bin/nimbus-shell" in text
