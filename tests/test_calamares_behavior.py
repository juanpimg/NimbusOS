# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests conductuales de los modulos Calamares de Nimbus.

Importan las funciones puras directamente (los modulos son importables
con ``libcalamares is None``) en vez de buscar subcadenas en el fuente.
"""

import importlib.util
import json
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODULES = ROOT / "installer" / "calamares" / "modules"
I18N_PATH = ROOT / "installer" / "calamares" / "nimbus_i18n.py"


def _load(name, relative):
    spec = importlib.util.spec_from_file_location(
        name, MODULES / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_i18n_loaded = sys.modules.get("nimbus_i18n")
if _i18n_loaded is None or getattr(_i18n_loaded, "TRANSLATIONS", None) is None:
    _i18n_spec = importlib.util.spec_from_file_location(
        "nimbus_i18n", I18N_PATH)
    i18n = importlib.util.module_from_spec(_i18n_spec)
    sys.modules["nimbus_i18n"] = i18n
    _i18n_spec.loader.exec_module(i18n)
else:
    i18n = _i18n_loaded


sw = _load("nimbus_software_under_test",
           "nimbus-software/nimbus-software.py")
ap = _load("nimbus_appearance_under_test",
           "nimbus-appearance/nimbus-appearance.py")
vv = _load("nimbus_verify_under_test",
           "nimbus-verify/nimbus-verify.py")


class _FakeGlobalStorage:
    def __init__(self, values=None):
        self._values = dict(values or {})
        self.inserted = {}

    def value(self, key):
        return self._values.get(key)

    def insert(self, key, value):
        self.inserted[key] = value


class _FakeUtils:
    def __init__(self, online=True):
        self.online = online
        self.warnings = []
        self.commands = []

    def warning(self, message):
        self.warnings.append(message)

    def debug(self, message):
        pass

    def check_network_connection(self):
        return self.online

    def target_env_command(self, *args):
        self.commands.append(list(args))
        return 0


class _FakeCalamares:
    def __init__(self, values=None, online=True):
        self.globalstorage = _FakeGlobalStorage(values)
        self.utils = _FakeUtils(online=online)


def _pacman_commands(fake):
    return [cmd for cmd in fake.utils.commands if cmd[:1] == ["pacman"]]


# --- nimbus-software: perfil -> paquetes ------------------------------------


def test_gaming_profile_maps_to_expected_packages():
    packages = sw.packages_for_profiles(["gaming"])
    assert packages == sw.PROFILE_PACKAGES["gaming"]
    for package in ["steam", "proton-ge", "gamescope", "mangohud", "heroic"]:
        assert package in packages


def test_unknown_profile_warns_and_yields_nothing():
    with pytest.warns(UserWarning, match="noexiste"):
        assert sw.packages_for_profiles(["noexiste"]) == []


def test_gate_offline_without_acceptance_installs_nothing(monkeypatch):
    monkeypatch.setattr(sw, "check_connectivity", lambda timeout=5: False)
    monkeypatch.setattr(
        sw, "read_selected_profiles", lambda: ["gaming", "office"])
    gate = sw.connectivity_gate(accepted_offline=False)
    assert gate == {"online": False, "profiles": [],
                    "message": sw.no_connectivity_message()}
    assert sw.packages_for_profiles(gate["profiles"]) == []


def test_gate_offline_with_acceptance_installs_only_base(monkeypatch):
    monkeypatch.setattr(sw, "check_connectivity", lambda timeout=5: False)
    monkeypatch.setattr(
        sw, "read_selected_profiles", lambda: ["gaming", "office"])
    gate = sw.connectivity_gate(accepted_offline=True)
    assert gate["online"] is False
    assert gate["profiles"] == ["base"]
    assert sw.packages_for_profiles(gate["profiles"]) == \
        sw.PROFILE_PACKAGES["base"]


def test_gate_online_installs_selected_profiles(monkeypatch):
    monkeypatch.setattr(sw, "check_connectivity", lambda timeout=5: True)
    monkeypatch.setattr(
        sw, "read_selected_profiles", lambda: ["gaming", "office"])
    gate = sw.connectivity_gate(accepted_offline=False)
    assert gate["online"] is True
    assert gate["profiles"] == ["gaming", "office"]
    packages = sw.packages_for_profiles(gate["profiles"])
    assert "steam" in packages
    assert "libreoffice-fresh" in packages


def test_run_offline_with_acceptance_installs_base(monkeypatch):
    """La aceptacion del globalstorage debe alcanzar a la puerta.

    Con el codigo viejo run() nunca leia la aceptacion y este test falla:
    devuelve el mensaje de error y no ejecuta pacman.
    """
    fake = _FakeCalamares(
        values={"nimbusSoftwareProfiles": ["gaming", "office"],
                sw.OFFLINE_ACCEPT_KEY: True},
        online=False)
    monkeypatch.setattr(sw, "libcalamares", fake)
    result = sw.run()
    assert result is None
    commands = _pacman_commands(fake)
    assert len(commands) == 1
    installed = commands[0][4:]
    assert installed == sw.PROFILE_PACKAGES["base"]
    assert "steam" not in installed


def test_run_online_installs_selected(monkeypatch):
    fake = _FakeCalamares(
        values={"nimbusSoftwareProfiles": ["creative"]}, online=True)
    monkeypatch.setattr(sw, "libcalamares", fake)
    assert sw.run() is None
    commands = _pacman_commands(fake)
    assert len(commands) == 1
    assert "gimp" in commands[0]
    assert "steam" not in commands[0]


def test_check_connectivity_survives_unexpected_framework_errors(monkeypatch):
    class _ExplodingUtils(_FakeUtils):
        def check_network_connection(self):
            raise ValueError("error inesperado del framework")

    class _Conn:
        def close(self):
            pass

    fake = _FakeCalamares(online=True)
    fake.utils = _ExplodingUtils()
    monkeypatch.setattr(sw, "libcalamares", fake)
    monkeypatch.setattr(
        sw.socket, "create_connection", lambda *a, **k: _Conn())
    assert sw.check_connectivity() is True


# --- nimbus-appearance --------------------------------------------------------

THEME_KEYS_BY_MODE = {
    "light": "appearance.theme.light",
    "dark": "appearance.theme.dark",
    "auto": "appearance.theme.auto",
}


def test_theme_label_maps_to_internal_mode():
    # La pagina QML envia claves, no texto: el backend compara por clave.
    assert ap.theme_label_to_mode("appearance.theme.light") == "light"
    assert ap.theme_label_to_mode("appearance.theme.dark") == "dark"
    assert ap.theme_label_to_mode("appearance.theme.auto") == "auto"
    # Compat: la pagina antigua enviaba el texto en español.
    assert ap.theme_label_to_mode("claro") == "light"
    assert ap.theme_label_to_mode("oscuro") == "dark"
    assert ap.theme_label_to_mode("auto") == "auto"
    # Modo interno y texto ya traducido (ES/EN) tambien se aceptan.
    assert ap.theme_label_to_mode("light") == "light"
    assert ap.theme_label_to_mode("Claro") == "light"
    assert ap.theme_label_to_mode("Light") == "light"
    with pytest.raises(ValueError):
        ap.theme_label_to_mode("neon")


def test_theme_labels_are_translated():
    """Las etiquetas de la pagina Tema salen de la tabla ES/EN."""
    assert ap.THEME_PAGE_MODES == (
        "appearance.theme.light",
        "appearance.theme.dark",
        "appearance.theme.auto",
    )
    assert ap.theme_page_labels("es") == [
        i18n.TRANSLATIONS["es"]["appearance.theme.light"],
        i18n.TRANSLATIONS["es"]["appearance.theme.dark"],
        i18n.TRANSLATIONS["es"]["appearance.theme.auto"],
    ]
    assert ap.theme_page_labels("en") == [
        i18n.TRANSLATIONS["en"]["appearance.theme.light"],
        i18n.TRANSLATIONS["en"]["appearance.theme.dark"],
        i18n.TRANSLATIONS["en"]["appearance.theme.auto"],
    ]
    # ES y EN difieren al menos en claro/oscuro (no es la clave suelta).
    assert ap.theme_page_labels("es") != ap.theme_page_labels("en")
    for key in ap.THEME_PAGE_MODES:
        assert ap.theme_mode_label(key, "es") == i18n.TRANSLATIONS["es"][key]
        assert ap.theme_mode_label(key, "en") == i18n.TRANSLATIONS["en"][key]


def test_accent_error_message_is_localized():
    with pytest.raises(ValueError, match="Acento no válido"):
        ap.normalize_accent("ZZZZZZ", locale="es")
    with pytest.raises(ValueError, match="Invalid accent"):
        ap.normalize_accent("ZZZZZZ", locale="en")
    assert "nohex!" in str(
        _capture_value_error(ap.normalize_accent, "nohex!", "es"))
    assert "nohex!" in str(
        _capture_value_error(ap.normalize_accent, "nohex!", "en"))


def test_mode_error_message_is_localized():
    with pytest.raises(ValueError, match="Modo no válido"):
        ap.validate_mode("neon", locale="es")
    with pytest.raises(ValueError, match="Invalid mode"):
        ap.validate_mode("neon", locale="en")


def test_theme_error_message_is_localized():
    with pytest.raises(ValueError, match="Tema no válido"):
        ap.theme_label_to_mode("neon", locale="es")
    with pytest.raises(ValueError, match="Invalid theme"):
        ap.theme_label_to_mode("neon", locale="en")
    # El mensaje en español lista las etiquetas en español, no las claves.
    try:
        ap.theme_label_to_mode("neon", locale="es")
    except ValueError as exc:
        assert "Claro" in str(exc)
        assert "appearance.theme" not in str(exc)
    try:
        ap.theme_label_to_mode("neon", locale="en")
    except ValueError as exc:
        assert "Light" in str(exc)


def _capture_value_error(func, *args, **kwargs):
    try:
        func(*args, **kwargs)
    except ValueError as exc:
        return exc
    raise AssertionError(f"{func.__name__} no lanzo ValueError")


def test_write_appearance_conf_roundtrips_malicious_wallpaper(tmp_path):
    evil = "playa\nEOF\ntouch /tmp/pwned"
    content = ap.render_appearance_conf("dark", "ff2d55", evil)
    target = ap.write_appearance_conf(content, root=tmp_path)
    assert target.read_text(encoding="utf-8") == content
    assert "touch /tmp/pwned" in target.read_text(encoding="utf-8")


# --- nimbus-verify -------------------------------------------------------------


def test_run_all_checks_yields_name_bool_str_tuples():
    results = vv.run_all_checks()
    assert len(results) == len(vv.CHECKS) >= 8
    for name, ok, message in results:
        assert isinstance(name, str)
        assert isinstance(ok, bool)
        assert isinstance(message, str) and message


def test_raising_check_does_not_stop_the_others(monkeypatch):
    def boom():
        raise RuntimeError("boom")

    monkeypatch.setattr(vv, "CHECKS", [("boom", boom)] + list(vv.CHECKS))
    results = vv.run_all_checks()
    assert len(results) == len(vv.CHECKS)
    assert results[0][0] == "boom"
    assert results[0][1] is False


def test_run_always_returns_none_and_stores_serializable(monkeypatch):
    fake = _FakeCalamares(values={}, online=True)
    monkeypatch.setattr(vv, "libcalamares", fake)
    monkeypatch.setattr(
        vv, "CHECKS",
        [("ok-thing", lambda: (True, "todo bien")),
         ("bad-thing", lambda: (False, "haz X para arreglarlo"))])
    assert vv.run() is None
    stored = fake.globalstorage.inserted["nimbusVerifyResults"]
    assert stored == {"ok-thing": [True, "todo bien"],
                      "bad-thing": [False, "haz X para arreglarlo"]}
    json.dumps(stored)  # debe ser serializable, sin ValueError
    assert any("bad-thing" in warning for warning in fake.utils.warnings)


# --- nimbus i18n (ES/EN desde el primer dia) ---------------------------------

import ast as _ast
import re as _re

_I18N_MODULE_SOURCES = {
    "appearance": MODULES / "nimbus-appearance" / "nimbus-appearance.py",
    "software": MODULES / "nimbus-software" / "nimbus-software.py",
    "verify": MODULES / "nimbus-verify" / "nimbus-verify.py",
}


def _translated_literal_keys(path):
    """Claves literales pasadas a translated() en un fichero."""
    tree = _ast.parse(path.read_text(encoding="utf-8"))
    keys = set()
    for node in _ast.walk(tree):
        if (isinstance(node, _ast.Call)
                and getattr(node.func, "id", "") == "translated"
                and node.args
                and isinstance(node.args[0], _ast.Constant)
                and isinstance(node.args[0].value, str)):
            keys.add(node.args[0].value)
    return keys


def _key_constant_values(path):
    """Valores de asignaciones *_KEY = "..." que sean claves i18n.

    Solo cuentan los valores con pinta de clave de traduccion (con punto,
    p. ej. ``software.no_connectivity``); claves de globalstorage como
    ``nimbusSoftwareOfflineAccepted`` no son cadenas visibles.
    """
    tree = _ast.parse(path.read_text(encoding="utf-8"))
    values = set()
    for node in _ast.walk(tree):
        if isinstance(node, _ast.Assign):
            for target in node.targets:
                if (isinstance(target, _ast.Name)
                        and target.id.endswith("_KEY")
                        and isinstance(node.value, _ast.Constant)
                        and isinstance(node.value.value, str)
                        and "." in node.value.value):
                    values.add(node.value.value)
    return values


def _theme_page_mode_keys():
    """Claves de THEME_PAGE_MODES (la QML las muestra traducidas)."""
    try:
        return set(ap.THEME_PAGE_MODES)
    except AttributeError:
        return set()


def _all_used_keys():
    keys = set()
    for path in _I18N_MODULE_SOURCES.values():
        keys |= _translated_literal_keys(path)
        keys |= _key_constant_values(path)
    # THEME_PAGE_MODES no se pasa como literal a translated() (se itera
    # con `translated(key, lang)`), asi que se recoge por separado.
    keys |= _theme_page_mode_keys()
    return keys


def test_every_visible_string_exists_in_es_and_en():
    keys = _all_used_keys()
    assert keys, "no se detecto ninguna clave translated() en los modulos"
    for key in sorted(keys):
        assert key in i18n.TRANSLATIONS["es"], f"falta ES: {key}"
        assert key in i18n.TRANSLATIONS["en"], f"falta EN: {key}"
        assert isinstance(i18n.TRANSLATIONS["es"][key], str)
        assert i18n.TRANSLATIONS["es"][key].strip()
        assert isinstance(i18n.TRANSLATIONS["en"][key], str)
        assert i18n.TRANSLATIONS["en"][key].strip()


def test_pretty_and_connectivity_strings_come_from_the_table():
    assert ap.pretty_name("es") == i18n.TRANSLATIONS["es"]["appearance.pretty_name"]
    assert ap.pretty_name("en") == i18n.TRANSLATIONS["en"]["appearance.pretty_name"]
    assert ap.pretty_status_message("es") == i18n.TRANSLATIONS["es"]["appearance.pretty_status"]
    assert ap.pretty_status_message("en") == i18n.TRANSLATIONS["en"]["appearance.pretty_status"]
    assert sw.pretty_name("es") == i18n.TRANSLATIONS["es"]["software.pretty_name"]
    assert sw.pretty_name("en") == i18n.TRANSLATIONS["en"]["software.pretty_name"]
    assert sw.pretty_status_message("es") == i18n.TRANSLATIONS["es"]["software.pretty_status"]
    assert sw.pretty_status_message("en") == i18n.TRANSLATIONS["en"]["software.pretty_status"]
    assert vv.pretty_name("es") == i18n.TRANSLATIONS["es"]["verify.pretty_name"]
    assert vv.pretty_name("en") == i18n.TRANSLATIONS["en"]["verify.pretty_name"]
    assert vv.pretty_status_message("es") == i18n.TRANSLATIONS["es"]["verify.pretty_status"]
    assert vv.pretty_status_message("en") == i18n.TRANSLATIONS["en"]["verify.pretty_status"]
    assert sw.no_connectivity_message("es") == i18n.TRANSLATIONS["es"]["software.no_connectivity"]
    assert sw.no_connectivity_message("en") == i18n.TRANSLATIONS["en"]["software.no_connectivity"]
    # NO_CONNECTIVITY_MESSAGE ya no es una cadena congelada en el import:
    # es una funcion que resuelve por locale (mejora I-2).
    assert callable(sw.NO_CONNECTIVITY_MESSAGE)
    assert not isinstance(sw.NO_CONNECTIVITY_MESSAGE, str)
    assert sw.NO_CONNECTIVITY_MESSAGE("es") == i18n.TRANSLATIONS["es"]["software.no_connectivity"]
    assert sw.NO_CONNECTIVITY_MESSAGE("en") == i18n.TRANSLATIONS["en"]["software.no_connectivity"]
    # Los dos nombres son el mismo mecanismo.
    assert sw.NO_CONNECTIVITY_MESSAGE("es") == sw.no_connectivity_message("es")


def test_no_frozen_no_connectivity_string():
    """El mensaje de falta de red no queda congelado con el locale inicial."""
    source = (MODULES / "nimbus-software" / "nimbus-software.py").read_text(
        encoding="utf-8")
    tree = _ast.parse(source)
    for node in _ast.walk(tree):
        if isinstance(node, _ast.Assign) and any(
                getattr(t, "id", "") == "NO_CONNECTIVITY_MESSAGE"
                for t in node.targets):
            raise AssertionError(
                "NO_CONNECTIVITY_MESSAGE no debe ser una asignacion "
                "congelada en el import; debe ser funcion por locale")
    assert sw.no_connectivity_message("es") != sw.no_connectivity_message("en")


def test_unknown_key_returns_the_key_itself():
    assert i18n.translated("this.key.does.not.exist") == "this.key.does.not.exist"
    assert i18n.translated("this.key.does.not.exist", "es") == "this.key.does.not.exist"
    assert i18n.translated("this.key.does.not.exist", "en") == "this.key.does.not.exist"


def test_unknown_locale_falls_back_to_english():
    key = "appearance.pretty_name"
    for weird in ("xx", "fr", "C", "", "de_DE.UTF-8"):
        assert i18n.translated(key, weird) == i18n.TRANSLATIONS["en"][key], weird


def test_active_locale_defaults_to_english():
    assert i18n.active_locale(env={}) == "en"
    assert i18n.active_locale(env={"LANG": "C.UTF-8", "LC_ALL": "", "LANGUAGE": ""}) == "en"
    assert i18n.active_locale(env={"LANG": "fr_FR.UTF-8"}) == "en"
    assert i18n.active_locale(env={"LANG": "es_ES.UTF-8"}) == "es"
    assert i18n.active_locale(env={"LC_ALL": "en_US.UTF-8"}) == "en"
    assert i18n.active_locale(env={"LANGUAGE": "es"}) == "es"


def _returns_through_translated(func_node):
    """Todo str devuelto por la funcion pasa por translated().

    Acepta ``return translated(...)`` y ``return translated(...).format(...)``;
    cualquier otro literal (``return "..."``, f-string, ``%``) falla.
    """
    for node in _ast.walk(func_node):
        if not isinstance(node, _ast.Return) or node.value is None:
            continue
        value = node.value
        candidates = []
        if isinstance(value, _ast.Tuple):
            candidates = list(value.elts)
        elif isinstance(value, _ast.Dict):
            candidates = list(value.values)
        else:
            candidates = [value]
        for item in candidates:
            if isinstance(item, _ast.Constant) and isinstance(item.value, str):
                # Solo importan las cadenas de usuario; las claves internas
                # ("", "online", "base"...) no son visibles. Si el literal
                # parece un mensaje (contiene un espacio), debe traducirse.
                if " " in item.value.strip():
                    return False
            elif isinstance(item, _ast.JoinedStr):
                return False
            elif isinstance(item, _ast.Call):
                func = item.func
                if getattr(func, "id", "") == "translated":
                    continue
                if (isinstance(func, _ast.Attribute)
                        and func.attr == "format"
                        and isinstance(func.value, _ast.Call)
                        and getattr(func.value.func, "id", "") == "translated"):
                    continue
                # Otras llamadas (str(...), repr, llamadas internas): no son
                # literales de usuario; se revisan por separado abajo.
                continue
            elif isinstance(item, (_ast.Name, _ast.Constant)):
                continue
    return True


def _function_uses_translated(tree, name):
    for node in _ast.walk(tree):
        if isinstance(node, (_ast.FunctionDef, _ast.AsyncFunctionDef)) and node.name == name:
            for child in _ast.walk(node):
                if (isinstance(child, _ast.Call)
                        and getattr(child.func, "id", "") == "translated"):
                    return True
    return False


def test_no_user_string_bypasses_translated():
    """Ninguna cadena visible queda fuera del mecanismo i18n.

    Revisa el AST de los tres modulos: todo pretty_name/pretty_status_message,
    NO_CONNECTIVITY_MESSAGE (ahora funcion, no cadena congelada) y todo
    str devuelto por un check_* debe resolverse por translated(); todo
    ``raise`` con texto para el usuario (los ValueError de appearance, que
    Calamares muestra) tambien; y THEME_PAGE_MODES deben ser claves de la
    tabla, no texto en español. Un literal nuevo sin traducir hace fallar.
    """
    for label, path in _I18N_MODULE_SOURCES.items():
        tree = _ast.parse(path.read_text(encoding="utf-8"))
        for node in _ast.walk(tree):
            if not isinstance(node, (_ast.FunctionDef, _ast.AsyncFunctionDef)):
                continue
            # Los check_* con mensajes de usuario son los de verificacion;
            # check_connectivity (sonda de red) no devuelve texto visible.
            is_user_check = node.name.startswith("check_") and label == "verify"
            if node.name in ("pretty_name", "pretty_status_message") or is_user_check:
                assert _function_uses_translated(tree, node.name), (
                    f"{label}.{node.name} no usa translated()"
                )
                assert _returns_through_translated(node), (
                    f"{label}.{node.name} devuelve un literal sin traducir"
                )
        if label == "software":
            assert _function_uses_translated(tree, "connectivity_gate")
            assert _function_uses_translated(tree, "packages_for_profiles")
            assert _function_uses_translated(tree, "run")
            assert _function_uses_translated(tree, "no_connectivity_message")
            assert _function_uses_translated(tree, "NO_CONNECTIVITY_MESSAGE")
            # NO_CONNECTIVITY_MESSAGE ya no es una cadena congelada.
            for node in _ast.walk(tree):
                if (isinstance(node, _ast.Assign)
                        and any(getattr(t, "id", "") == "NO_CONNECTIVITY_MESSAGE"
                                for t in node.targets)):
                    raise AssertionError(
                        "NO_CONNECTIVITY_MESSAGE debe ser funcion, "
                        "no asignacion congelada")
            for node in _ast.walk(tree):
                if (isinstance(node, (_ast.FunctionDef, _ast.AsyncFunctionDef))
                        and node.name == "run"):
                    assert _returns_through_translated(node), (
                        "software.run devuelve un literal sin traducir")
        if label == "appearance":
            for name in ("normalize_accent", "validate_mode",
                         "theme_label_to_mode", "theme_page_labels",
                         "theme_mode_label"):
                assert _function_uses_translated(tree, name), (
                    f"appearance.{name} no usa translated()")
            for node in _ast.walk(tree):
                if (isinstance(node, (_ast.FunctionDef, _ast.AsyncFunctionDef))
                        and node.name in ("normalize_accent", "validate_mode",
                                          "theme_label_to_mode")):
                    assert _raises_through_translated(node), (
                        f"appearance.{node.name} lanza sin translated()")
            # Las etiquetas de la pagina QML son claves, no texto.
            assert _theme_page_modes_are_keys(tree), (
                "THEME_PAGE_MODES debe contener claves de traduccion, "
                "no texto en español")
    # Guardarraíl generico: cualquier raise con texto en los tres modulos
    # debe pasar por translated(). Si mañana alguien añade un
    # `raise ValueError("...")` en español, este test se rompe.
    for label, path in _I18N_MODULE_SOURCES.items():
        tree = _ast.parse(path.read_text(encoding="utf-8"))
        for node in _ast.walk(tree):
            if isinstance(node, (_ast.FunctionDef, _ast.AsyncFunctionDef)):
                if any(isinstance(child, _ast.Raise)
                       for child in _ast.walk(node)):
                    assert _raises_through_translated(node), (
                        f"{label}.{node.name} lanza sin translated()")


def _raises_through_translated(func_node):
    """Todo raise con texto para el usuario pasa por translated().

    Acepta ``raise ValueError(translated(...))`` y
    ``raise ValueError(translated(...).format(...))``; cualquier f-string
    o literal con pinta de mensaje fuera de translated() falla.
    """
    for node in _ast.walk(func_node):
        if not isinstance(node, _ast.Raise) or node.exc is None:
            continue
        exc = node.exc
        translated_calls = [
            child for child in _ast.walk(exc)
            if (isinstance(child, _ast.Call)
                and getattr(child.func, "id", "") == "translated")
        ]
        if not translated_calls:
            return False
        # Un f-string en el raise es texto sin traducir (el codigo usa
        # translated(...).format(...), nunca f-strings para mensajes).
        if any(isinstance(child, _ast.JoinedStr)
               for child in _ast.walk(exc)):
            return False
        # Literales con pinta de mensaje fuera de translated() tampoco valen.
        translated_args = set()
        for call in translated_calls:
            for arg in call.args:
                if (isinstance(arg, _ast.Constant)
                        and isinstance(arg.value, str)):
                    translated_args.add(id(arg))
        for child in _ast.walk(exc):
            if (isinstance(child, _ast.Constant)
                    and isinstance(child.value, str)
                    and " " in child.value.strip()
                    and id(child) not in translated_args):
                return False
    return True


def _theme_page_modes_are_keys(tree):
    """THEME_PAGE_MODES solo contiene claves existentes en ES y EN."""
    for node in _ast.walk(tree):
        if (isinstance(node, _ast.Assign)
                and any(getattr(t, "id", "") == "THEME_PAGE_MODES"
                        for t in node.targets)):
            elements = []
            if isinstance(node.value, (_ast.Tuple, _ast.List)):
                elements = node.value.elts
            else:
                return False
            if not elements:
                return False
            for item in elements:
                if not (isinstance(item, _ast.Constant)
                        and isinstance(item.value, str)
                        and "." in item.value):
                    return False
                key = item.value
                if key not in i18n.TRANSLATIONS["es"]:
                    return False
                if key not in i18n.TRANSLATIONS["en"]:
                    return False
            return True
    return False
