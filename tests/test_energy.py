# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests de `nimbus-energy`: perfiles, limite de carga y GPU hibrida (M3 T3).

Sin root, sin hardware y sin sysfs reales: la logica se prueba con
inyeccion de entorno (sysfs falso, `powerprofilesctl` falso, backend
forzado) tal como documentan los propios scripts.
"""

import os
import pathlib
import stat
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
PKG = ROOT / "packages" / "nimbus-energy"
FILES = PKG / "files"
ENERGY = FILES / "nimbus-energy"
CONF = FILES / "energy-helper.conf"


def run_energy(*args, env_extra=None):
    env = dict(os.environ)
    env.update(env_extra or {})
    return subprocess.run(
        ["bash", str(ENERGY), *args],
        capture_output=True, text=True, env=env,
    )


def write_fake_ppd(bin_dir: pathlib.Path):
    """Un `powerprofilesctl` falso que persiste en $PPD_STATE."""
    fake = bin_dir / "powerprofilesctl"
    fake.write_text(
        "#!/usr/bin/env bash\n"
        "set -u\n"
        'state="${PPD_STATE:-/tmp/nimbus-ppd-state}"\n'
        'if [ "${1:-}" = "get" ]; then\n'
        '  if [ -f "$state" ]; then cat "$state"; else echo "balanced"; fi\n'
        "fi\n"
        'if [ "${1:-}" = "set" ]; then\n'
        '  if [ "${PPD_STICKY:-1}" = "1" ]; then printf "%s" "$2" > "$state"; fi\n'
        "fi\n",
        encoding="utf-8",
    )
    fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
    return fake


def base_env(tmp_path, monkeypatch):
    state = tmp_path / "ppd-state"
    state.write_text("balanced", encoding="utf-8")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    write_fake_ppd(bin_dir)
    monkeypatch.setenv("PATH", str(bin_dir) + os.pathsep + os.environ["PATH"])
    return {
        "NIMBUS_ENERGY_ALLOW_UNPRIVILEGED": "1",
        "NIMBUS_ENERGY_CONF": str(tmp_path / "energy.conf"),
        "PPD_STATE": str(state),
    }


def test_energy_cli_exists_and_is_executable():
    assert ENERGY.is_file(), "falta packages/nimbus-energy/files/nimbus-energy"
    assert os.access(ENERGY, os.X_OK), "nimbus-energy debe ser ejecutable"


def test_defaults_are_balanced_80_on_demand():
    assert CONF.is_file(), "falta energy-helper.conf"
    values = {}
    for line in CONF.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, _, val = line.partition("=")
        values[key.strip()] = val.strip()
    assert values.get("profile") == "balanced"
    assert values.get("charge-limit") == "80"
    assert values.get("gpu") == "on-demand"


def test_charge_limit_set_95_rejected_as_out_of_range(tmp_path, monkeypatch):
    env = base_env(tmp_path, monkeypatch)
    proc = run_energy("charge-limit", "set", "95", env_extra=env)
    assert proc.returncode != 0, "95 debe rechazarse (rango valido: 40-80 u off)"
    assert "rango" in (proc.stdout + proc.stderr).lower()


def test_charge_limit_set_80_without_hw_fails_legibly(tmp_path, monkeypatch):
    env = base_env(tmp_path, monkeypatch)
    env["NIMBUS_CHARGE_BACKEND"] = "none"
    proc = run_energy("charge-limit", "set", "80", env_extra=env)
    assert proc.returncode != 0, "sin hardware no puede fingir que aplico el limite"
    out = (proc.stdout + proc.stderr).lower()
    assert "hardware" in out
    assert "límite de carga" in out or "limite de carga" in out


def test_charge_limit_set_80_with_fake_hw_applies(tmp_path, monkeypatch):
    env = base_env(tmp_path, monkeypatch)
    sysfs = tmp_path / "sys" / "class" / "power_supply" / "BAT0"
    sysfs.mkdir(parents=True)
    (sysfs / "charge_control_end_threshold").write_text("100", encoding="utf-8")
    env["NIMBUS_CHARGE_BACKEND"] = "amd"
    env["NIMBUS_SYSFS"] = str(tmp_path)
    proc = run_energy("charge-limit", "set", "80", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert (sysfs / "charge_control_end_threshold").read_text().strip() == "80"


def test_charge_get_without_hw_reports_unsupported(tmp_path, monkeypatch):
    """Sin hardware, `charge-limit get` distingue 'no soportado' de un valor."""
    env = base_env(tmp_path, monkeypatch)
    env["NIMBUS_CHARGE_BACKEND"] = "none"
    env["NIMBUS_SYSFS"] = str(tmp_path / "empty-sys")
    (tmp_path / "empty-sys").mkdir()
    proc = run_energy("charge-limit", "get", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert proc.stdout.strip() == "unsupported", \
        f"no debe informar un valor que nunca se aplico: {proc.stdout!r}"


def test_charge_get_with_fake_hw_reports_value(tmp_path, monkeypatch):
    env = base_env(tmp_path, monkeypatch)
    sysfs = tmp_path / "sys" / "class" / "power_supply" / "BAT0"
    sysfs.mkdir(parents=True)
    (sysfs / "charge_control_end_threshold").write_text("77\n", encoding="utf-8")
    env["NIMBUS_SYSFS"] = str(tmp_path)
    proc = run_energy("charge-limit", "get", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert proc.stdout.strip() == "77"


def test_gpu_set_always_without_nvidia_reports_na_and_exits_zero(
    tmp_path, monkeypatch
):
    env = base_env(tmp_path, monkeypatch)
    env["NIMBUS_GPU_HAS_NVIDIA"] = "0"
    proc = run_energy("gpu", "set", "always", env_extra=env)
    assert proc.returncode == 0, "sin dGPU NVIDIA debe salir con 0"
    assert "no aplica" in (proc.stdout + proc.stderr).lower()


def test_profile_set_performance_verifies_with_ppd(tmp_path, monkeypatch):
    env = base_env(tmp_path, monkeypatch)
    proc = run_energy("profile", "set", "performance", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert pathlib.Path(env["PPD_STATE"]).read_text().strip() == "performance"


def test_profile_set_detects_when_ppd_did_not_apply(tmp_path, monkeypatch):
    """Si `powerprofilesctl get` no refleja el cambio, es un error, no un 0."""
    env = base_env(tmp_path, monkeypatch)
    env["PPD_STICKY"] = "0"  # el falso PPD ignora el `set`
    proc = run_energy("profile", "set", "performance", env_extra=env)
    assert proc.returncode != 0, "debe fallar si el perfil no se aplico"


def test_cli_requires_privileges_for_set():
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        pytest.skip("este test necesita un usuario sin privilegios")
    env = {"NIMBUS_ENERGY_NO_REEXEC": "1"}
    proc = run_energy("profile", "set", "performance", env_extra=env)
    assert proc.returncode != 0, "set sin privilegios no puede ejecutarse"
    out = (proc.stdout + proc.stderr).lower()
    assert "polkit" in out or "pkexec" in out


def test_cli_get_does_not_require_privileges(tmp_path, monkeypatch):
    """Las lecturas no necesitan root (least privilege): `get` va sin puerta."""
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        pytest.skip("este test necesita un usuario sin privilegios")
    env = base_env(tmp_path, monkeypatch)
    env.pop("NIMBUS_ENERGY_ALLOW_UNPRIVILEGED", None)
    env["NIMBUS_ENERGY_NO_REEXEC"] = "1"
    for args in (("profile", "get"), ("gpu", "get")):
        proc = run_energy(*args, env_extra=env)
        assert proc.returncode == 0, f"{' '.join(args)} no debe pedir privilegios"


def test_pkgbuild_depends_and_no_tlp():
    pkgbuild = (PKG / "PKGBUILD").read_text(encoding="utf-8")
    for dep in ("power-profiles-daemon", "auto-cpufreq", "ananicy-cpp"):
        assert dep in pkgbuild, f"PKGBUILD debe depender de {dep}"
    assert "nvidia-prime" in pkgbuild, "PKGBUILD debe contemplar nvidia-prime"
    import re

    for match in re.finditer(r"depends=\((.*?)\)", pkgbuild, re.DOTALL):
        assert "tlp" not in match.group(1), "tlp entra en conflicto con PPD"


# --- M3 T4: scheduler, ananicy y rendimiento de escritorio --------------------

SCHEDULER = FILES / "nimbus-scheduler"
ANONICY = FILES / "nimbus-anonicy"
GAMING_RULES = FILES / "ananicy" / "ananicy.d" / "50-nimbus-gaming.rules"
GAMING_CONF = FILES / "90-nimbus-gaming.conf"

# Procesos que JAMAS deben perder prioridad: juegos y sistema de audio.
NEVER_DEPRIORITIZE = (
    "steam", "gamescope", "proton", "wine",
    "pipewire", "pulseaudio", "wireplumber", "jackd",
)


def run_scheduler(*args, env_extra=None):
    env = dict(os.environ)
    env.update(env_extra or {})
    return subprocess.run(
        ["bash", str(SCHEDULER), *args],
        capture_output=True, text=True, env=env,
    )


def run_anonicy(*args, env_extra=None):
    env = dict(os.environ)
    env.update(env_extra or {})
    return subprocess.run(
        ["bash", str(ANONICY), *args],
        capture_output=True, text=True, env=env,
    )


def fake_sched_sysdir(base: pathlib.Path, present):
    sysdir = base / "sched_ext"
    sysdir.mkdir(parents=True)
    for name in present:
        (sysdir / name).write_text("", encoding="utf-8")
    return sysdir


def test_scheduler_lists_only_available(tmp_path):
    sysdir = fake_sched_sysdir(tmp_path, ("lavd", "bore"))
    proc = run_scheduler("list", env_extra={"NIMBUS_SCHED_SYSBASE": str(sysdir)})
    assert proc.returncode == 0, proc.stdout + proc.stderr
    listed = proc.stdout.split()
    for name in ("lavd", "bore", "default"):
        assert name in listed, f"{name} deberia listarse"
    for name in ("sched-ext", "bmq"):
        assert name not in listed, f"{name} no esta disponible y no debe listarse"


def test_scheduler_set_warns_reboot(tmp_path):
    sysdir = fake_sched_sysdir(tmp_path, ("lavd",))
    state = tmp_path / "scheduler-state"
    env = {"NIMBUS_SCHED_SYSBASE": str(sysdir), "NIMBUS_SCHED_STATE": str(state)}
    proc = run_scheduler("set", "lavd", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "reinici" in (proc.stdout + proc.stderr).lower()
    assert state.read_text(encoding="utf-8").strip() == "lavd"


def test_scheduler_rejects_unknown(tmp_path):
    sysdir = fake_sched_sysdir(tmp_path, ("lavd",))
    env = {
        "NIMBUS_SCHED_SYSBASE": str(sysdir),
        "NIMBUS_SCHED_STATE": str(tmp_path / "scheduler-state"),
    }
    proc = run_scheduler("set", "noexiste", env_extra=env)
    assert proc.returncode != 0


def parse_ananicy_rules(path: pathlib.Path):
    import json

    rules = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        rules.append(json.loads(line))
    assert rules, "el fichero de reglas no puede estar vacio"
    return rules


def test_ananicy_rules_never_deprioritize_games_or_audio():
    assert GAMING_RULES.is_file(), "falta 50-nimbus-gaming.rules"
    for rule in parse_ananicy_rules(GAMING_RULES):
        name = str(rule.get("name", "")).lower()
        for forbidden in NEVER_DEPRIORITIZE:
            if forbidden in name:
                assert rule.get("nice", 0) <= 0, (
                    f"la regla de '{name}' baja la prioridad de un proceso "
                    "de juego o de audio: el juego iria lento"
                )


def test_ananicy_rules_boost_shell_and_calm_background():
    rules = {r["name"]: r for r in parse_ananicy_rules(GAMING_RULES)}
    for shell_proc in ("nimbus-shell", "quickshell"):
        assert shell_proc in rules, f"falta regla para {shell_proc}"
        assert rules[shell_proc]["nice"] < 0, f"{shell_proc} debe subir prioridad"
    lowered = [n for n, r in rules.items() if r.get("nice", 0) > 0]
    assert any("baloo" in n or "tracker" in n for n in lowered), \
        "los indexadores deben bajar prioridad"
    assert any("packagekit" in n or "pamac" in n for n in lowered), \
        "los actualizadores en segundo plano deben bajar prioridad"


def _write_fake_systemctl(bin_dir: pathlib.Path, log: pathlib.Path, fail=False):
    """Falso `systemctl` que registra sus argumentos; falla si se le pide."""
    script = (
        "#!/usr/bin/env bash\n"
        'echo "$@" >> "$SYSTEMCTL_LOG"\n'
    )
    if fail:
        script += 'echo "falso systemctl: no se pudo recargar" >&2\nexit 1\n'
    (bin_dir / "systemctl").write_text(script, encoding="utf-8")
    (bin_dir / "systemctl").chmod(0o755)
    return log


def _anonicy_env(tmp_path, monkeypatch, *, systemctl_fail=False):
    rules_dir = tmp_path / "ananicy.d"
    rules_dir.mkdir()
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    log = tmp_path / "systemctl.log"
    log.write_text("", encoding="utf-8")
    _write_fake_systemctl(bin_dir, log, fail=systemctl_fail)
    monkeypatch.setenv("PATH", str(bin_dir) + os.pathsep + os.environ["PATH"])
    monkeypatch.setenv("SYSTEMCTL_LOG", str(log))
    return {
        "NIMBUS_ANANICY_RULES_DIR": str(rules_dir),
        "NIMBUS_ANANICY_SOURCE": str(GAMING_RULES),
    }, rules_dir, log


def test_anonicy_disable_restores_defaults(tmp_path, monkeypatch):
    assert ANONICY.is_file(), "falta nimbus-anonicy"
    env, rules_dir, _log = _anonicy_env(tmp_path, monkeypatch)
    default_rules = rules_dir / "00-default.rules"
    default_rules.write_text('{"name": "default", "nice": 0}\n', encoding="utf-8")
    enabled = run_anonicy("enable", env_extra=env)
    assert enabled.returncode == 0, enabled.stdout + enabled.stderr
    assert (rules_dir / "50-nimbus-gaming.rules").is_file()
    disabled = run_anonicy("disable", env_extra=env)
    assert disabled.returncode == 0, disabled.stdout + disabled.stderr
    assert not (rules_dir / "50-nimbus-gaming.rules").exists()
    assert default_rules.is_file(), "disable no debe tocar las reglas por defecto"
    assert "defecto" in (disabled.stdout + disabled.stderr).lower()


def test_laptop_default_profile_is_balanced_not_performance():
    values = {}
    for line in CONF.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, _, val = line.partition("=")
        values[key.strip()] = val.strip()
    assert values.get("profile") == "balanced"
    assert values.get("profile") != "performance"


def test_anonicy_enable_reloads_service(tmp_path, monkeypatch):
    """`enable` recarga ananicy-cpp de verdad, no solo escribe ficheros."""
    env, _rules_dir, log = _anonicy_env(tmp_path, monkeypatch)
    proc = run_anonicy("enable", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "try-reload-or-restart ananicy-cpp.service" in log.read_text(encoding="utf-8"), \
        "enable debe recargar el servicio ananicy-cpp"


def test_anonicy_disable_reloads_service(tmp_path, monkeypatch):
    """`disable` recarga ananicy-cpp: el efecto en runtime no espera al reinicio."""
    env, _rules_dir, log = _anonicy_env(tmp_path, monkeypatch)
    assert run_anonicy("enable", env_extra=env).returncode == 0
    proc = run_anonicy("disable", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "try-reload-or-restart ananicy-cpp.service" in log.read_text(encoding="utf-8"), \
        "disable debe recargar el servicio ananicy-cpp"


def test_anonicy_reload_failure_is_loud(tmp_path, monkeypatch):
    """Si la recarga falla, enable/disable fallan en vez de fingir exito."""
    env, _rules_dir, _log = _anonicy_env(tmp_path, monkeypatch, systemctl_fail=True)
    assert run_anonicy("enable", env_extra=env).returncode != 0
    assert run_anonicy("disable", env_extra=env).returncode != 0


def test_no_unparsed_autoactivation_conf_is_shipped():
    """No se distribuye ningun conf con dialecto de auto-activacion sin lector.

    El 90-nimbus-gaming.conf afirmaba activacion 'al detectar un juego' con
    claves que ningun codigo parsea; se retira del paquete. La activacion es
    manual (`nimbus-anonicy enable/disable` + recarga del servicio).
    """
    pkgbuild = (PKG / "PKGBUILD").read_text(encoding="utf-8")
    assert "etc/ananicy" not in pkgbuild, \
        "nada sin consumidor real dentro del directorio de configuracion del demonio"
    assert not GAMING_CONF.is_file(), \
        "el conf con dialecto sin lector no debe existir en el arbol"
    text = ANONICY.read_text(encoding="utf-8").lower()
    assert "manual" in text, "nimbus-anonicy debe documentar el modelo manual"
