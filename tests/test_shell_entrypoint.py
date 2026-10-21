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


# --- Regression M4: el escritorio live arrancaba sin ninguna superficie ---
#
# La causa real (verificada con el binario de la ISO) fueron los imports:
# `IpcHandler` vive en `Quickshell.Io` y `PanelWindow`/`FloatingWindow` en
# `Quickshell`, asi que sin esos imports la config moria con exit 255 y no se
# veia NADA (ni siquiera el fondo del shell). Por diseno las superficies que
# son ventana se montan de forma imperativa (`Qt.createComponent` +
# `createObject(null)`, con conteo en `moduleFailures`) y los `Loader` se
# reservan para contenido `Item`; estos tests atan ese diseno sin necesitar
# compositor. Ademas atan que el Dock no dependa de un flag que arranque
# cerrado y que cada PanelWindow declare su capa coherente (`FloatingWindow`
# NO tiene capa en Quickshell 0.3.2: ponerle `layer` mataria la carga).
LOADER_SOURCE_RE = re.compile(r"^\s*source\s*:\s*\"([^\"]+)\"", re.M)
WINDOW_ROOT_RE = re.compile(r"^\s*(PanelWindow|FloatingWindow)\s*\{", re.M)


def _top_level_blocks(text, typename):
    """Bloques QML de primer nivel `typename { ... }` con conteo de llaves.

    Devuelve [(id, bloque)] donde id sale de `id: xxx` si existe. Sin
    compositor no hay parser QML: el conteo de llaves sobre el texto sin
    comentarios basta para localizar cada ventana.
    """
    code = _strip_line_comments(text)
    pattern = re.compile(r"^\s*" + typename + r"\s*\{", re.M)
    blocks = []
    for match in pattern.finditer(code):
        depth = 0
        i = match.end() - 1
        while i < len(code):
            if code[i] == "{":
                depth += 1
            elif code[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        block = code[match.start():i + 1]
        id_match = re.search(r"id\s*:\s*(\w+)", block)
        blocks.append((id_match.group(1) if id_match else "?", block))
    return blocks


def _resolve_loader_source(source):
    """Resuelve un `source:` de Loader a fichero bajo shell/src (o None)."""
    if source.startswith("Nimbus/"):
        return ROOT / "shell" / "src" / source
    return None


def _loader_sources(text):
    return LOADER_SOURCE_RE.findall(_strip_line_comments(text))


def test_no_loader_mounts_a_window():
    # Por diseno las ventanas se montan de forma imperativa (ver shell.qml:
    # `loadModule` + `createObject(null)` con conteo en `moduleFailures`) y
    # los Loader quedan para contenido Item. Ningun Loader puede apuntar a
    # un fichero cuya raiz sea una ventana.
    for source in _loader_sources(SHELL_QML.read_text(encoding="utf-8")):
        path = _resolve_loader_source(source)
        if path is None or not path.is_file():
            continue
        root = _root_type(path.read_text(encoding="utf-8"))
        assert root not in ("PanelWindow", "FloatingWindow"), (
            f"Loader carga ventana {source} (raiz {root}): las ventanas se montan de forma imperativa"
        )
    # Contrapueba: el detector reconoce las dos ventanas rotas.
    assert WINDOW_ROOT_RE.search(
        (ROOT / "shell" / "src" / "Nimbus" / "modules" / "TopBar.qml").read_text(
            encoding="utf-8"
        )
    ), "TopBar.qml ya no es PanelWindow"
    # Y el patron caza un Loader que cargue una ventana si se reintroduce.
    assert any("TopBar.qml" in s for s in _loader_sources('Loader {\nsource: "Nimbus/modules/TopBar.qml"\n}'))


def test_topbar_is_a_window_not_a_loader_source():
    topbar = (
        ROOT / "shell" / "src" / "Nimbus" / "modules" / "TopBar.qml"
    ).read_text(encoding="utf-8")
    assert _root_type(topbar) == "PanelWindow", "TopBar.qml debe seguir siendo ventana"
    sources = _loader_sources(SHELL_QML.read_text(encoding="utf-8"))
    assert not any("TopBar" in s for s in sources), (
        "TopBar.qml es una ventana y no puede montarse con source: de un Loader"
    )
    assert not any("Settings" in s for s in sources), (
        "Settings.qml es una ventana (FloatingWindow) y no puede montarse con source: de un Loader"
    )


def test_shell_qml_imports_quickshell_io_for_ipc():
    # Sin `import Quickshell.Io`, `IpcHandler` no es un tipo y la config
    # muere entera (exit 255): este fue el fallo real que dejaba el
    # escritorio vacio.
    text = SHELL_QML.read_text(encoding="utf-8")
    assert re.search(r"^\s*import\s+Quickshell\.Io\b", text, re.M), (
        "shell.qml usa IpcHandler sin importar Quickshell.Io"
    )
    assert "IpcHandler" in text


def test_ipc_handler_call_uses_typed_signature():
    # El endpoint IPC debe ir firmado: los argumentos sin tipo llegan como
    # QVariant y no cruzan el IPC ("cannot be used across IPC").
    text = _strip_line_comments(SHELL_QML.read_text(encoding="utf-8"))
    assert re.search(
        r"function\s+call\s*\(\s*target\s*:\s*string", text
    ), "el endpoint IPC debe firmar sus argumentos (target: string, ...)"


def test_topbar_imports_quickshell_for_panelwindow():
    # `PanelWindow` vive en el modulo raiz `Quickshell`, no en
    # `Quickshell.Wayland`: sin ese import TopBar.qml no carga.
    for rel in ("Nimbus/modules/TopBar.qml",):
        text = (ROOT / "shell" / "src" / rel).read_text(encoding="utf-8")
        assert re.search(r"^\s*import\s+Quickshell\b", text, re.M), (
            f"{rel} usa PanelWindow sin importar Quickshell"
        )


def test_floating_windows_declare_no_layer():
    # `FloatingWindow` NO tiene capa en Quickshell 0.3.2 (es xdg-toplevel):
    # asignarle `layer`/`WlrLayershell.layer` es un error fatal de carga.
    shell = SHELL_QML.read_text(encoding="utf-8")
    blocks = _top_level_blocks(shell, "FloatingWindow")
    assert blocks, "shell.qml debe declarar FloatingWindows"
    for window_id, block in blocks:
        assert "WlrLayershell.layer" not in block, (
            f"{window_id} declara WlrLayershell.layer: no existe en FloatingWindow 0.3.2"
        )
        assert not re.search(r"(?<![\w.])layer\s*:", block), (
            f"{window_id} declara layer: no existe en FloatingWindow 0.3.2"
        )
    # Contrapueba: el detector caza una capa intrusa si se reintroduce.
    assert re.search(r"(?<![\w.])layer\s*:", "FloatingWindow {\nlayer: 1\n}")


def test_dock_does_not_depend_on_a_flag_that_starts_closed():
    shell = SHELL_QML.read_text(encoding="utf-8")
    controller = (
        ROOT / "shell" / "src" / "Nimbus" / "ShellController.qml"
    ).read_text(encoding="utf-8")
    # El Dock es siempre visible en macOS: su ventana no puede depender de un
    # flag que arranque en false (dockOpen arrancaba en false y el Dock no se
    # veia nunca). O bien no se referencia el flag, o bien arranca en true.
    gated = "ShellController.dockOpen" in shell or "dockOpen" in shell
    starts_open = re.search(r"property\s+bool\s+dockOpen\s*:\s*true", controller)
    assert not gated or starts_open, (
        "el Dock depende de dockOpen y dockOpen arranca en false: el Dock nunca se ve"
    )


def test_panelwindows_declare_coherent_layers():
    shell = SHELL_QML.read_text(encoding="utf-8")
    # Cada PanelWindow declarado en shell.qml debe fijar su capa con el
    # attached WlrLayershell (import Quickshell.Wayland). Sin capa coherente
    # el compositor apila mal las superficies: el fondo opaco a pantalla
    # completa (capa Top por defecto) taparia la barra y el Dock.
    blocks = _top_level_blocks(shell, "PanelWindow")
    assert blocks, "shell.qml debe declarar PanelWindows"
    for window_id, block in blocks:
        assert "WlrLayershell.layer" in block, (
            f"{window_id} no declara WlrLayershell.layer"
        )
    topbar = (
        ROOT / "shell" / "src" / "Nimbus" / "modules" / "TopBar.qml"
    ).read_text(encoding="utf-8")
    assert "WlrLayershell.layer" in topbar, "TopBar.qml no declara su layer"
    assert "WlrLayer.Top" in topbar, "la barra debe estar en la capa Top"
    # Fondo abajo del todo, barra y dock sobre las ventanas, overlays arriba.
    assert "WlrLayer.Background" in shell, "el fondo debe usar WlrLayer.Background"
    assert "WlrLayer.Top" in shell, "el dock debe usar WlrLayer.Top"
    assert "WlrLayer.Overlay" in shell, "los overlays deben usar WlrLayer.Overlay"


# --- Regression M4 (bis): el config entero no cargaba en la ISO live ---
#
# Con el Loader arreglado el escritorio seguia vacio. El motivo real estaba
# una capa mas abajo: el CONFIG no compilaba, asi que no se montaba ni una
# sola superficie (ni el fondo). Las cuatro causas, todas verificadas en la
# ISO real arrancando `qs -c /usr/lib/nimbus/shell/src`:
#
#   1. `IpcHandler` lo exporta el modulo `Quickshell.Io`, no `Quickshell`:
#      sin ese import el config muere con "IpcHandler is not a type".
#   2. `PanelWindow`/`FloatingWindow` los exporta el modulo `Quickshell`
#      (por el import de modulo `Quickshell._WaylandOverlay`); el modulo
#      `Quickshell.Wayland` NO los reexporta. Un fichero que solo importa
#      `Quickshell.Wayland` no ve los tipos de ventana: por eso TopBar.qml
#      y Settings.qml se montaban con "PanelWindow is not a type".
#   3. La funcion del IpcHandler necesita argumentos TIPADOS: sin tipo llegan
#      como QVariant y Quickshell no puede cruzarlos ("cannot be used
#      across IPC"), o sea que el bus IPC no funcionaba.
#   4. `LockScreen.locked` vale true por defecto: si la ventana solo mira
#      `item.locked`, el escritorio arranca bloqueado en cada arranque.
IMPORT_RE = re.compile(r"^\s*import\s+([A-Za-z0-9_.]+)", re.M)

# Ficheros cuya raiz es una ventana de Quickshell.
WINDOW_MODULE_FILES = (
    ROOT / "shell" / "src" / "Nimbus" / "modules" / "TopBar.qml",
    ROOT / "shell" / "src" / "Nimbus" / "apps" / "Settings" / "Settings.qml",
)


def _imports(text):
    return set(IMPORT_RE.findall(_strip_line_comments(text)))


def test_shell_qml_imports_every_module_it_uses():
    imports = _imports(SHELL_QML.read_text(encoding="utf-8"))
    # IpcHandler es de Quickshell.Io: sin el import el config no carga.
    assert "Quickshell.Io" in imports, (
        "shell.qml usa IpcHandler pero no importa Quickshell.Io: el config "
        "falla con 'IpcHandler is not a type' y no se monta ninguna superficie"
    )
    # ShellRoot, PanelWindow y FloatingWindow son del modulo Quickshell.
    assert "Quickshell" in imports, (
        "shell.qml debe importar Quickshell (ShellRoot/PanelWindow/FloatingWindow)"
    )
    # WlrLayershell y WlrLayer son del modulo Quickshell.Wayland.
    assert "Quickshell.Wayland" in imports, (
        "shell.qml debe importar Quickshell.Wayland (WlrLayershell.layer)"
    )


def test_window_modules_import_quickshell():
    # Los tipos de ventana los exporta `Quickshell`; `Quickshell.Wayland` solo
    # aporta WlrLayershell/WlrLayer. Un modulo que raiz en una ventana y solo
    # importa `Quickshell.Wayland` no ve PanelWindow/FloatingWindow.
    for path in WINDOW_MODULE_FILES:
        assert path.is_file(), f"falta {path}"
        imports = _imports(path.read_text(encoding="utf-8"))
        assert "Quickshell" in imports, (
            f"{path.name} usa un tipo de ventana pero no importa Quickshell: "
            "no ve PanelWindow/FloatingWindow ('is not a type')"
        )
        assert "Quickshell.Wayland" in imports, (
            f"{path.name} debe importar Quickshell.Wayland (WlrLayershell.layer)"
        )


def test_ipc_handler_function_arguments_are_typed():
    # Sin tipo, los argumentos llegan como QVariant y Quickshell no puede
    # cruzarlos: el bus IPC queda muerto aunque el config cargue.
    shell = _strip_line_comments(SHELL_QML.read_text(encoding="utf-8"))
    match = re.search(r"function\s+call\s*\(([^)]*)\)", shell)
    assert match, "shell.qml debe declarar la funcion call del IpcHandler"
    params = [p.strip() for p in match.group(1).split(",") if p.strip()]
    assert params, "la funcion call del IpcHandler no declara argumentos"
    for param in params:
        assert ":" in param, (
            f"el argumento {param!r} del IpcHandler no declara tipo: "
            "llegaria como QVariant y no se puede cruzar por IPC"
        )


def test_lock_screen_starts_closed():
    # `LockScreen.locked` vale true por defecto (el modulo arranca
    # bloqueado): si la ventana solo mira `item.locked`, el escritorio live
    # aparece con la pantalla de bloqueo en cada arranque.
    shell = SHELL_QML.read_text(encoding="utf-8")
    gate = re.search(r"property\s+bool\s+(\w*[Ll]ock\w*)\s*:\s*false", shell)
    assert gate, (
        "shell.qml debe declarar un flag de bloqueo que arranque en false "
        "(p. ej. `property bool lockRequested: false`)"
    )
    flag = gate.group(1)
    assert re.search(rf"visible\s*:[^\n]*{flag}", shell), (
        f"la ventana de bloqueo debe usar {flag} en su `visible`: si no, "
        "aparece bloqueada en cada arranque"
    )


# --- T2: `nimbus-shell ipc call` despacha al shell en marcha ---
#
# Los atajos de Hyprland (`dots/hypr/hyprland.lua`, pista ajena) invocan
# `nimbus-shell ipc call <target> <fn>` (p. ej. `dock toggle`). El launcher
# debe traducirlo a `qs ipc call nimbus call <target> <fn>` (socket IPC de
# Quickshell 0.3.2 contra el `IpcHandler` con `target: "nimbus"` de
# shell.qml), no a arrancar otra instancia con `qs -c`.
import os
import stat
import subprocess


def _run_launcher_with_fake_qs(args):
    """Ejecuta el launcher con un `qs` falso que registra sus argumentos.

    Devuelve (rc, argv_recibidos, stderr). argv_recibidos es None si el
    `qs` falso nunca fue invocado.
    """
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        qs_path = os.path.join(tmp, "qs")
        log_path = os.path.join(tmp, "argv.log")
        with open(qs_path, "w", encoding="utf-8") as handle:
            handle.write(
                "#!/usr/bin/env bash\n"
                'printf \'%%s\\n\' "$@" > "%s"\n'
                "exit 0\n" % log_path
            )
        os.chmod(qs_path, os.stat(qs_path).st_mode | stat.S_IXUSR)
        env = dict(os.environ)
        env["PATH"] = tmp + os.pathsep + env.get("PATH", "")
        proc = subprocess.run(
            [str(LAUNCHER)] + list(args),
            capture_output=True,
            text=True,
            env=env,
            timeout=30,
        )
        argv = None
        if os.path.exists(log_path):
            with open(log_path, encoding="utf-8") as handle:
                argv = [line.rstrip("\n") for line in handle.readlines()]
        return proc.returncode, argv, proc.stderr


def test_launcher_ipc_call_dispatches_to_running_shell():
    # Lo que invocan los atajos: `nimbus-shell ipc call dock toggle`.
    rc, argv, _ = _run_launcher_with_fake_qs(["ipc", "call", "dock", "toggle"])
    assert rc == 0, "el despacho IPC debe salir con 0"
    assert argv == ["ipc", "call", "nimbus", "call", "dock", "toggle"], (
        "el launcher debe despachar por el socket IPC de Quickshell, no "
        "arrancar otra instancia: %r" % (argv,)
    )
    # Contrapueba: el formato viejo (pasar todo a `qs -c`) es el defecto.
    assert argv is None or argv[:2] != ["-c", "/usr/lib/nimbus/shell/src"], (
        "ipc call no puede terminar en `qs -c`"
    )


def test_launcher_ipc_call_accepts_redundant_nimbus_prefix():
    # Forma redundante `ipc call nimbus call <target> <fn>`: mismo destino.
    rc, argv, _ = _run_launcher_with_fake_qs(
        ["ipc", "call", "nimbus", "call", "spotlight", "toggle"]
    )
    assert rc == 0
    assert argv == ["ipc", "call", "nimbus", "call", "spotlight", "toggle"]


def test_launcher_ipc_call_rejects_malformed_calls():
    # Sin funcion o sin subcomando: error, sin invocar a `qs`.
    for args in (["ipc", "call", "dock"], ["ipc"], ["ipc", "llamar"]):
        rc, argv, stderr = _run_launcher_with_fake_qs(args)
        assert rc != 0, "la llamada malformada %r debe fallar" % (args,)
        assert argv is None, "la llamada malformada no debe invocar a qs"
        assert stderr.strip() != "", "debe explicar el uso en stderr"


def test_launcher_plain_launch_still_boots_shell():
    # Sin `ipc`: arranque normal via `qs -c <dir>` (contrato existente).
    rc, argv, _ = _run_launcher_with_fake_qs([])
    assert rc == 0
    assert argv == ["-c", "/usr/lib/nimbus/shell/src"], (
        "el arranque normal debe seguir siendo `qs -c <dir>`: %r" % (argv,)
    )
