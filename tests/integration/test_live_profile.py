# SPDX-License-Identifier: GPL-3.0-or-later
"""La sesion live: la arranca el greeter (SDDM) y el marcador es verdadero.

Comprueba, sobre los ficheros del perfil y de dots/, que:
- la sesion live la arranca el GREETER (SDDM con autologin del usuario
  nimbus), no un unit suelto: asi hay sesion de logind de verdad, que es lo
  que necesita el compositor para el asiento;
- el script de sesion arranca Hyprland (no el shell) con la config del home;
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


def test_live_session_runs_hyprland_with_home_config():
    """El script de sesion arranca Hyprland (no el shell) con la config del
    home del usuario live, a traves del wrapper start-hyprland (que es lo que
    evita el aviso "Hyprland was started without start-hyprland")."""
    text = (AIROOTFS / "usr" / "lib" / "nimbus" / "nimbus-session").read_text(encoding="utf-8")
    assert "/usr/bin/start-hyprland" in text
    assert "--config" in text
    # La config se busca en el HOME del usuario live (el home de la ISO) y,
    # si no esta, se usa la que instala el paquete nimbus-dots.
    assert '$HOME/.config/hypr/hyprland.lua' in text
    assert "/usr/lib/nimbus/dots/hypr/hyprland.lua" in text
    assert "/usr/bin/nimbus-shell" not in text


def test_live_session_is_offered_by_the_greeter():
    """La sesion live la ofrece el greeter, con autologin del usuario nimbus."""
    desktop = (AIROOTFS / "usr" / "share" / "wayland-sessions" / "nimbus.desktop").read_text(encoding="utf-8")
    assert "Exec=/usr/lib/nimbus/nimbus-session" in desktop
    assert "Type=Application" in desktop
    conf = (AIROOTFS / "etc" / "sddm.conf.d" / "nimbus.conf").read_text(encoding="utf-8")
    assert "[Autologin]" in conf
    assert "User=nimbus" in conf
    assert "Session=nimbus.desktop" in conf
    # El greeter tiene que estar habilitado: la via estandar es el symlink
    # display-manager.service -> sddm.service.
    system = AIROOTFS / "etc" / "systemd" / "system"
    dm = system / "display-manager.service"
    assert dm.is_symlink(), "falta el symlink que habilita el greeter"
    assert dm.resolve().name == "sddm.service"


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
    starts = _exec_start_lines(text)
    assert starts
    assert any("nimbus-live-ready" in line for line in starts), starts
    # El unit NUNCA escribe el marcador: lo escribe el script, y solo cuando
    # el shell ha dicho que esta listo.
    assert all("echo" not in line for line in starts), starts
    assert "NIMBUS_LIVE_READY" not in text or "nimbus-live-ready" in text


def test_nimbus_start_has_emergency_fallback_without_exec():
    text = (ROOT / "dots" / "nimbus" / "nimbus-start").read_text(encoding="utf-8")
    assert "kitty" in text
    assert re.search(r"^\s*exec\s+/usr/bin/nimbus-shell", text, re.MULTILINE) is None
    # El shell NO se exec: sigue siendo hijo para que el supervisor lo vea.
    # Puede llevar argumentos (--no-tour en la sesion live).
    assert re.search(r"/usr/bin/nimbus-shell[^\n]*&", text) is not None
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
