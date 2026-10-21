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


def test_cli_requires_privileges():
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        pytest.skip("este test necesita un usuario sin privilegios")
    env = {"NIMBUS_ENERGY_NO_REEXEC": "1"}
    proc = run_energy("profile", "get", env_extra=env)
    assert proc.returncode != 0, "sin privilegios no puede ejecutarse"
    out = (proc.stdout + proc.stderr).lower()
    assert "polkit" in out or "pkexec" in out


def test_pkgbuild_depends_and_no_tlp():
    pkgbuild = (PKG / "PKGBUILD").read_text(encoding="utf-8")
    for dep in ("power-profiles-daemon", "auto-cpufreq", "ananicy-cpp"):
        assert dep in pkgbuild, f"PKGBUILD debe depender de {dep}"
    assert "nvidia-prime" in pkgbuild, "PKGBUILD debe contemplar nvidia-prime"
    import re

    for match in re.finditer(r"depends=\((.*?)\)", pkgbuild, re.DOTALL):
        assert "tlp" not in match.group(1), "tlp entra en conflicto con PPD"
