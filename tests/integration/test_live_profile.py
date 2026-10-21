# SPDX-License-Identifier: GPL-3.0-or-later
"""Fix A: la sesion live la gestiona Hyprland y el marcador es verdadero.

Comprueba, sobre los ficheros del perfil y de dots/, que:
- nimbus-live.service arranca Hyprland (no el shell) como nimbus;
- el marcador NIMBUS_LIVE_READY sale del script de readiness, no del unit;
- la config de Hyprland esta en el home del usuario live;
- dots/ y el paquete nimbus-dots son coherentes con la sesion live;
- el harness distingue READY de TIMEOUT.
"""
import pathlib
import re
import stat
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
PROFILE = ROOT / "iso" / "profiles" / "nimbus"
AIROOTFS = PROFILE / "airootfs"
READY_SCRIPT = AIROOTFS / "usr" / "lib" / "nimbus" / "nimbus-live-ready"


def _exec_start_lines(text):
    return [line.strip() for line in text.splitlines() if line.strip().startswith("ExecStart=")]


def test_live_service_runs_hyprland_with_home_config():
    text = (AIROOTFS / "etc" / "systemd" / "system" / "nimbus-live.service").read_text(encoding="utf-8")
    assert "User=nimbus" in text
    starts = _exec_start_lines(text)
    assert any(
        "/usr/bin/Hyprland" in line
        and "--config" in line
        and "/home/nimbus/.config/hypr/hyprland.lua" in line
        for line in starts
    ), starts
    assert all("/usr/bin/nimbus-shell" not in line for line in starts), starts


def test_live_service_sets_wayland_session_env():
    text = (AIROOTFS / "etc" / "systemd" / "system" / "nimbus-live.service").read_text(encoding="utf-8")
    for var in (
        "HOME=/home/nimbus",
        "XDG_RUNTIME_DIR=/run/user/1000",
        "WAYLAND_DISPLAY=",
        "XDG_CURRENT_DESKTOP=Hyprland",
    ):
        assert var in text, var


def test_ready_script_gates_the_marker():
    assert READY_SCRIPT.is_file()
    assert READY_SCRIPT.stat().st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    body = READY_SCRIPT.read_text(encoding="utf-8")
    assert "NIMBUS_LIVE_READY" in body
    assert "NIMBUS_LIVE_TIMEOUT" in body
    assert "/dev/console" in body
    # Espera al shell (qs/quickshell) del usuario live y a Hyprland.
    assert "pgrep" in body and "nimbus" in body
    assert "qs" in body and "quickshell" in body
    assert "hyprctl" in body
    # Tiempo de espera de 90 s con salida de fallo sin marcador.
    assert "90" in body
    assert "exit 1" in body


def test_ready_unit_delegates_to_the_script():
    text = (AIROOTFS / "etc" / "systemd" / "system" / "nimbus-live-ready.service").read_text(encoding="utf-8")
    assert "Requires=nimbus-live.service" in text
    starts = _exec_start_lines(text)
    assert starts
    assert any("nimbus-live-ready" in line for line in starts), starts
    assert all("echo" not in line for line in starts), starts


def test_nimbus_start_has_emergency_fallback_without_exec():
    text = (ROOT / "dots" / "nimbus" / "nimbus-start").read_text(encoding="utf-8")
    assert "kitty" in text
    assert re.search(r"^\s*exec\s+/usr/bin/nimbus-shell", text, re.MULTILINE) is None
    assert re.search(r"/usr/bin/nimbus-shell\s+&", text) is not None
    assert "$!" in text


def test_hyprland_autostart_matches_dots_package():
    lua = (ROOT / "dots" / "hypr" / "hyprland.lua").read_text(encoding="utf-8")
    assert "/usr/lib/nimbus/dots/nimbus-start" in lua
    pkgbuild = (ROOT / "packages" / "nimbus-dots" / "PKGBUILD").read_text(encoding="utf-8")
    assert "usr/lib/nimbus/dots/nimbus-start" in pkgbuild
    packages = {
        line.strip()
        for line in (PROFILE / "packages.x86_64").read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    }
    assert {"hyprland", "nimbus-shell", "nimbus-dots"} <= packages


def test_no_hl_dispatch_in_hyprland_config():
    text = (ROOT / "dots" / "hypr" / "hyprland.lua").read_text(encoding="utf-8")
    assert "hl.dispatch" not in text
    assert 'hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("kitty --class emergency"))' in text


def _wait_for_marker(log_text, timeout="5"):
    lib = ROOT / "tests" / "integration" / "lib.sh"
    script = (
        f'source "{lib}"; '
        f'LOG="$(mktemp)"; printf %s "$LOG_TEXT" > "$LOG"; '
        f'rc=0; wait_for_marker "$LOG" {timeout} || rc=$?; echo "rc=$rc"; rm -f "$LOG"'
    )
    result = subprocess.run(
        ["bash", "-c", script],
        capture_output=True, text=True, env={"LOG_TEXT": log_text, "PATH": "/usr/bin:/bin"},
    )
    match = re.search(r"rc=(\d+)", result.stdout)
    assert match is not None, result.stdout + result.stderr
    return int(match.group(1))


def test_harness_returns_two_on_timeout_marker():
    assert _wait_for_marker("arrancando...\nNIMBUS_LIVE_TIMEOUT: sesion no lista\n") == 2


def test_harness_returns_zero_on_ready_marker():
    assert _wait_for_marker("algo\nNIMBUS_LIVE_READY\n") == 0


def test_harness_prefers_timeout_over_ready():
    assert _wait_for_marker("NIMBUS_LIVE_READY\nNIMBUS_LIVE_TIMEOUT\n") == 2


def test_boot_live_handles_timeout_status():
    text = (ROOT / "tests" / "integration" / "boot_live.sh").read_text(encoding="utf-8")
    assert "NIMBUS_TIMEOUT_MARKER" in text
    assert "-eq 2" in text
