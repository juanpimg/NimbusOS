# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests conductuales de los modulos Calamares de Nimbus.

Importan las funciones puras directamente (los modulos son importables
con ``libcalamares is None``) en vez de buscar subcadenas en el fuente.
"""

import importlib.util
import json
import pathlib

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODULES = ROOT / "installer" / "calamares" / "modules"


def _load(name, relative):
    spec = importlib.util.spec_from_file_location(
        name, MODULES / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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
                    "message": sw.NO_CONNECTIVITY_MESSAGE}
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


def test_theme_label_maps_to_internal_mode():
    assert ap.theme_label_to_mode("claro") == "light"
    assert ap.theme_label_to_mode("oscuro") == "dark"
    assert ap.theme_label_to_mode("auto") == "auto"
    with pytest.raises(ValueError):
        ap.theme_label_to_mode("neon")


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
