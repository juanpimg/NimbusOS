# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests del orquestador de post-instalacion de Nimbus.

El script ``installer/tools/nimbus-postinstall`` no puede hacer nada de
verdad sin root ni Calamares, pero su logica si es testeable: delega los
efectos de sistema en un ejecutor inyectable que estos tests sustituyen
por un doble en memoria.
"""

import ast
import importlib.util
import json
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOL_PATH = ROOT / "installer" / "tools" / "nimbus-postinstall"
MODULE_PATH = (
    ROOT / "installer" / "modules" / "nimbus-postinstall"
    / "nimbus-postinstall.py"
)
CONF_PATH = (
    ROOT / "installer" / "modules" / "nimbus-postinstall"
    / "nimbus-postinstall.conf"
)


def _load(path, name):
    from importlib.machinery import SourceFileLoader
    loader = SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_file_location(
        name, str(path), loader=loader)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def tool():
    return _load(TOOL_PATH, "nimbus_postinstall_under_test")


@pytest.fixture(scope="module")
def module():
    return _load(MODULE_PATH, "nimbus_postinstall_module_under_test")


CPUINFO_AVX2 = (
    "processor : 0\n"
    "vendor_id : AuthenticAMD\n"
    "flags : fpu vme sse sse2 ssse3 sse4_1 sse4_2 avx avx2 bmi1 bmi2\n"
)

CPUINFO_GENERIC = (
    "processor : 0\n"
    "vendor_id : GenuineIntel\n"
    "flags : fpu vme sse sse2 ssse3 sse4_1 sse4_2 avx\n"
)


class FakeExec:
    """Doble en memoria del ejecutor real del sistema."""

    def __init__(self, cpuinfo=CPUINFO_AVX2, nvidia=False,
                 battery=False, fail_on=()):
        self._cpuinfo = cpuinfo
        self._nvidia = nvidia
        self._battery = battery
        self.fail_on = set(fail_on)
        self.commands = []
        self.files = {}
        self.enabled_services = []
        self.charge_limit = None

    # -- primitivas que los pasos usan (misma firma que el ejecutor real)
    def run(self, cmd):
        assert isinstance(cmd, list), "el comando debe ser una lista"
        self.commands.append(list(cmd))
        if any(marker in " ".join(cmd) for marker in self.fail_on):
            raise RuntimeError(f"fallo simulado: {' '.join(cmd)}")

        class _Result:
            returncode = 0
            stdout = ""
            stderr = ""
        return _Result()

    def read_text(self, path, default=None):
        key = str(path)
        if key in self.files:
            return self.files[key]
        if default is not None:
            return default
        raise FileNotFoundError(key)

    def write_text(self, path, content):
        self.files[str(path)] = content

    def cpuinfo_text(self):
        return self._cpuinfo

    def has_nvidia_dgpu(self):
        return self._nvidia

    def battery_limit_supported(self):
        return self._battery

    def set_charge_limit(self, percent):
        if not self._battery:
            raise RuntimeError("sin soporte de limite de carga")
        self.charge_limit = percent

    def keyring_source_files(self):
        return [("nimbus.gpg", "GPG-DATA"),
                ("nimbus-trusted", "TRUST-DATA"),
                ("nimbus-revoked", "REVOKE-DATA")]

    def dots_files(self):
        return [("nimbus/defaults.conf", "[nimbus]\nmode = light\n")]

    def enable_service(self, name):
        self.enabled_services.append(name)

        class _Result:
            returncode = 0
            stdout = ""
            stderr = ""
        return _Result()


def _ctx(tool, fake, root="/target", offline=False, locale="en"):
    return tool.Ctx(root=root, offline=offline, locale=locale, ex=fake)


# --- orden de los pasos ------------------------------------------------------


def test_steps_run_in_documented_order(tool, monkeypatch):
    seen = []
    for name in tool.STEP_ORDER:
        fn = tool._STEP_FUNCS[name]

        def _recorder(ctx, _name=name, _fn=fn):
            seen.append(_name)
            return _fn(ctx)

        monkeypatch.setitem(tool._STEP_FUNCS, name, _recorder)
    fake = FakeExec()
    results, _code = tool.run_all(_ctx(tool, fake))
    assert seen == tool.STEP_ORDER
    assert [r["name"] for r in results] == tool.STEP_ORDER


def test_step_order_has_ten_steps(tool):
    assert tool.STEP_ORDER == [
        "keyring", "repo-nimbus", "repo-cachyos", "refresh-keys",
        "services", "greeter", "power", "hybrid", "skel", "os-release",
    ]


# --- un paso opcional que falla no aborta ------------------------------------


def test_optional_failure_does_not_abort(tool, monkeypatch):
    def _boom(ctx):
        raise RuntimeError("greeter roto")
    monkeypatch.setitem(tool._STEP_FUNCS, "greeter", _boom)
    fake = FakeExec()
    results, code = tool.run_all(_ctx(tool, fake))
    by_name = {r["name"]: r for r in results}
    assert by_name["greeter"]["status"] == "failed"
    assert by_name["greeter"]["message"].strip()  # accionable, no vacio
    # Los pasos posteriores siguen ejecutandose.
    assert by_name["os-release"]["status"] == "ok"
    assert code == 0  # un opcional no hunde el script


# --- un paso critico que falla si aborta -------------------------------------


def test_critical_failure_aborts(tool, monkeypatch):
    def _boom(ctx):
        raise RuntimeError("sin keyring no hay sistema")
    monkeypatch.setitem(tool._STEP_FUNCS, "keyring", _boom)
    fake = FakeExec()
    results, code = tool.run_all(_ctx(tool, fake))
    by_name = {r["name"]: r for r in results}
    assert by_name["keyring"]["status"] == "failed"
    assert code == 1
    # Aborta: lo no ejecutado queda marcado como omitido, no como ok.
    assert by_name["os-release"]["status"] == "skipped"


# --- idempotencia: dos ejecuciones no duplican el repo -----------------------


def test_repo_not_duplicated_on_second_run(tool):
    fake = FakeExec()
    ctx = _ctx(tool, fake)
    first, _ = tool.run_all(ctx)
    assert first[1]["status"] == "ok"  # repo-nimbus
    text_after_first = fake.files["/target/etc/pacman.conf"]
    assert text_after_first.count("[nimbus]") == 1
    second, code = tool.run_all(_ctx(tool, fake))
    assert code == 0
    assert fake.files["/target/etc/pacman.conf"].count("[nimbus]") == 1
    assert fake.files["/target/etc/pacman.conf"] == text_after_first


def test_existing_repo_block_is_left_alone(tool):
    block = tool.render_nimbus_repo_block()
    conf = "# previo\n[nimbus]\n" + block + "\n[extra]\nInclude = x\n"
    new_text, changed = tool.ensure_repo_block(conf, "[nimbus]", block)
    assert changed is False
    assert new_text == conf


def test_nimbus_repo_uses_required_siglevel(tool):
    block = tool.render_nimbus_repo_block()
    assert "[nimbus]" in block
    assert "SigLevel = Required DatabaseOptional" in block
    assert "nimbus" in block.lower()  # mirrorlist propia


# --- modo offline: lo que necesita red se omite, no falla -------------------


def test_offline_marks_network_steps_as_skipped(tool):
    fake = FakeExec()
    results, code = tool.run_all(_ctx(tool, fake, offline=True))
    by_name = {r["name"]: r for r in results}
    for name in tool.NETWORK_STEPS:
        assert by_name[name]["status"] == "skipped", name
        assert by_name[name]["message"].strip(), name
    assert code == 0
    # Nada que necesite red se marca como failed en offline.
    assert all(r["status"] != "failed" for r in results)


# --- seleccion de repo por CPU ------------------------------------------------


def test_cpu_with_avx2_gets_v3_repo(tool):
    assert tool.cpu_supports_avx2(CPUINFO_AVX2) is True
    fake = FakeExec(cpuinfo=CPUINFO_AVX2)
    results, _code = tool.run_all(_ctx(tool, fake))
    conf = fake.files["/target/etc/pacman.conf"]
    assert "[cachyos-v3]" in conf
    assert results[2]["name"] == "repo-cachyos"
    assert results[2]["status"] == "ok"


def test_cpu_without_avx2_keeps_generic_repo_and_never_v3(tool):
    assert tool.cpu_supports_avx2(CPUINFO_GENERIC) is False
    fake = FakeExec(cpuinfo=CPUINFO_GENERIC)
    results, code = tool.run_all(_ctx(tool, fake))
    assert code == 0
    conf = fake.files["/target/etc/pacman.conf"]
    assert "[cachyos]" in conf
    assert "[cachyos-v3]" not in conf  # nunca v3 sin AVX2


# --- hardware opcional: decir la verdad --------------------------------------


def test_hybrid_without_dgpu_is_skipped_not_faked(tool):
    fake = FakeExec(nvidia=False)
    status, message = tool.step_hybrid(_ctx(tool, fake))
    assert status == "skipped"
    assert message.strip()


def test_hybrid_with_dgpu_configures_on_demand(tool):
    fake = FakeExec(nvidia=True)
    status, _message = tool.step_hybrid(_ctx(tool, fake))
    assert status == "ok"
    assert "on-demand" in fake.files["/target/etc/nimbus/hybrid.conf"]


def test_power_with_battery_support_applies_limit(tool):
    fake = FakeExec(battery=True)
    status, message = tool.step_power(_ctx(tool, fake))
    assert status == "ok"
    assert fake.charge_limit == tool.CHARGE_LIMIT
    assert "no se ha aplicado" not in message.lower()
    assert "not faked" not in message.lower()


def test_power_without_battery_support_says_so(tool):
    for locale, words in (("es", ("carga", "límite")),
                          ("en", ("charge", "limit"))):
        fake = FakeExec(battery=False)
        status, message = tool.step_power(_ctx(tool, fake, locale=locale))
        assert status in ("ok", "skipped")
        # No se finge: el mensaje deja claro que el limite NO se aplico.
        lowered = message.lower()
        assert "no" in lowered, (locale, message)
        assert any(word in lowered for word in words), (locale, message)


# --- el modulo Calamares informa paso a paso ---------------------------------


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

    def warning(self, message):
        self.warnings.append(message)

    def debug(self, message):
        pass

    def check_network_connection(self):
        return self.online


class _FakeCalamares:
    def __init__(self, values=None, online=True):
        self.globalstorage = _FakeGlobalStorage(values)
        self.utils = _FakeUtils(online=online)


def _completed(stdout, returncode=0):
    class _Result:
        pass
    result = _Result()
    result.stdout = stdout
    result.stderr = ""
    result.returncode = returncode
    return result


def test_module_reports_each_step_and_passes_on_optional_failure(
        module, tool, monkeypatch):
    payload = [{"name": n, "status": "ok", "message": f"{n} bien"}
               for n in tool.STEP_ORDER]
    payload[5] = {"name": "greeter", "status": "failed",
                  "message": "greeter fallo. Accion: haz X."}
    calls = []

    def _fake_run(cmd, **kwargs):
        assert isinstance(cmd, list)  # lista, nunca shell
        calls.append(cmd)
        return _completed(json.dumps(payload))

    monkeypatch.setattr(module.subprocess, "run", _fake_run)
    fake = _FakeCalamares(values={"rootMountPoint": "/target"})
    monkeypatch.setattr(module, "libcalamares", fake)
    assert module.run() is None  # un opcional no hunde el job
    stored = fake.globalstorage.inserted["nimbusPostinstallResults"]
    assert stored["greeter"] == ["failed", "greeter fallo. Accion: haz X."]
    assert len(stored) == len(tool.STEP_ORDER)
    json.dumps(stored)  # serializable
    assert any("greeter" in w for w in fake.utils.warnings)
    assert calls and calls[0][0].endswith("nimbus-postinstall")


def test_module_fails_job_on_critical_failure(module, tool, monkeypatch):
    payload = [{"name": "keyring", "status": "failed",
                "message": "keyring fallo. Accion: repuebla a mano."}]
    monkeypatch.setattr(
        module.subprocess, "run",
        lambda cmd, **kwargs: _completed(json.dumps(payload),
                                        returncode=1))
    fake = _FakeCalamares(values={"rootMountPoint": "/target"})
    monkeypatch.setattr(module, "libcalamares", fake)
    result = module.run()
    assert isinstance(result, str) and result.strip()  # mensaje accionable


# --- higiene: sin shell=True, todo visible traducido --------------------------


def _assert_no_shell_true(path):
    tree = ast.parse(path.read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            for keyword in node.keywords:
                if keyword.arg == "shell":
                    value = keyword.value
                    assert not (
                        isinstance(value, ast.Constant) and value.value
                    ), f"{path}: shell=True prohibido"


def test_no_shell_true_anywhere():
    _assert_no_shell_true(TOOL_PATH)
    _assert_no_shell_true(MODULE_PATH)


def test_every_translated_key_has_es_and_en(tool):
    tree = ast.parse(TOOL_PATH.read_text(encoding="utf-8"))
    keys = set()
    for node in ast.walk(tree):
        if (isinstance(node, ast.Call)
                and getattr(node.func, "id", "") == "translated"
                and node.args
                and isinstance(node.args[0], ast.Constant)):
            keys.add(node.args[0].value)
    assert keys, "la herramienta debe usar translated()"
    for key in sorted(keys):
        assert key in tool.POSTINSTALL_STRINGS["es"], f"falta ES: {key}"
        assert key in tool.POSTINSTALL_STRINGS["en"], f"falta EN: {key}"
        assert tool.POSTINSTALL_STRINGS["es"][key].strip()
        assert tool.POSTINSTALL_STRINGS["en"][key].strip()


def test_module_visible_strings_go_through_translated():
    tree = ast.parse(MODULE_PATH.read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if node.name in ("pretty_name", "pretty_status_message"):
                src = ast.dump(node)
                assert "translated" in src, node.name
    keys = set()
    for node in ast.walk(tree):
        if (isinstance(node, ast.Call)
                and getattr(node.func, "id", "") == "translated"
                and node.args
                and isinstance(node.args[0], ast.Constant)):
            keys.add(node.args[0].value)
    assert keys


def test_spdx_headers_present():
    for path in (TOOL_PATH, MODULE_PATH, CONF_PATH,
                 pathlib.Path(__file__)):
        head = path.read_bytes()[:600].decode("utf-8", errors="replace")
        assert "SPDX-License-Identifier: GPL-3.0-or-later" in head, path


def test_conf_exists_and_names_module():
    text = CONF_PATH.read_text(encoding="utf-8")
    assert "postinstall" in text.lower()


def test_tool_executable_and_no_shell_shebang():
    assert TOOL_PATH.exists()
    first = TOOL_PATH.read_bytes().split(b"\n", 1)[0]
    assert b"python3" in first
