# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests de la pista de actualizaciones y rollback (`nimbus-update`, M4 §9.7).

TDD: este fichero se escribió ANTES que `packages/nimbus-update/` y que el
arreglo del postinstall (RED primero): con el paquete ausente, todo lo que
toque disco falla. Los behaviours cubiertos:

- existe el paquete y sus ficheros (CLI, 4 units, config);
- el snapshot se crea ANTES de aplicar (orden verificable en el log);
- si el snapshot falla, no se aplica nada y el error es legible (rc != 0);
- `apply` sin actualizaciones no hace nada (sin snapshots basura);
- si la actualización falla, se restaura el snapshot;
- `rollback` restaura y VERIFICA (y falla alto si la verificación falla);
- `check` distingue "hay" (rc 2 + lista) de "no hay" (rc 0);
- `auto` respeta la ventana de mantenimiento y el usuario interactivo;
- el repo del sistema instalado no apunta a un dominio inexistente;
- las dos unidades que activa el postinstall existen y no forman ciclos.

Sin root ni Btrfs real: la lógica se prueba con binarios falsos (`btrfs`,
`pacman`, `flatpak` en un `PATH` temporal que registran sus invocaciones
en `$NIMBUS_UPDATE_LOG`) e inyección de entorno, como documenta el propio
`nimbus-update` (mismo modelo que `nimbus-energy`).
"""

import os
import pathlib
import re
import shutil
import socket
import stat
import subprocess
import sys
import urllib.parse

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
PKG = ROOT / "packages" / "nimbus-update"
FILES = PKG / "files"
SCRIPT = FILES / "nimbus-update"
CONF = FILES / "update.conf"

SNAPSHOT_SERVICE = FILES / "nimbus-snapshots.service"
SNAPSHOT_TIMER = FILES / "nimbus-snapshots.timer"
AUTO_SERVICE = FILES / "nimbus-auto-update.service"
AUTO_TIMER = FILES / "nimbus-auto-update.timer"
ALL_UNITS = (SNAPSHOT_SERVICE, SNAPSHOT_TIMER, AUTO_SERVICE, AUTO_TIMER)

TOOL_PATH = ROOT / "installer" / "tools" / "nimbus-postinstall"


# --- ayudas: binarios falsos -------------------------------------------------


FAKE_BTRFS = """\
#!/usr/bin/env bash
set -u
log="${NIMBUS_UPDATE_LOG:-/dev/null}"
echo "btrfs $*" >>"$log"
if [ "${1:-}" = "subvolume" ] && [ "${2:-}" = "snapshot" ]; then
  if [ "${FAKE_BTRFS_SNAPSHOT_FAIL:-0}" = "1" ]; then
    echo "falso btrfs: no se pudo crear el snapshot" >&2
    exit 1
  fi
  exit 0
fi
if [ "${1:-}" = "subvolume" ] && [ "${2:-}" = "set-default" ]; then
  printf '%s' "${3:-}" >"${FAKE_BTRFS_DEFAULT_FILE:-/dev/null}"
  exit 0
fi
if [ "${1:-}" = "subvolume" ] && [ "${2:-}" = "get-default" ]; then
  if [ "${FAKE_BTRFS_VERIFY_FAIL:-0}" = "1" ]; then
    echo "ID 0 top level 0 path nada-que-ver"
    exit 0
  fi
  if [ -n "${FAKE_BTRFS_DEFAULT_FILE:-}" ] \\
      && [ -f "$FAKE_BTRFS_DEFAULT_FILE" ]; then
    cat "$FAKE_BTRFS_DEFAULT_FILE"
  else
    echo "ID 5 top level 5 path @"
  fi
  exit 0
fi
exit 0
"""

FAKE_PACMAN = """\
#!/usr/bin/env bash
set -u
log="${NIMBUS_UPDATE_LOG:-/dev/null}"
echo "pacman $*" >>"$log"
case "${1:-}" in
  -Qu)
    if [ -n "${FAKE_PACMAN_UPDATES_FILE:-}" ] \\
        && [ -f "$FAKE_PACMAN_UPDATES_FILE" ]; then
      cat "$FAKE_PACMAN_UPDATES_FILE"
    fi
    exit 0 ;;
  -Q)
    printf 'nimbus-shell 0.1.0\\npacman 7.1.0\\n'
    exit 0 ;;
  -Sy)
    exit 0 ;;
  -Su)
    if [ "${FAKE_PACMAN_FAIL:-0}" = "1" ]; then
      echo "falso pacman: fallo simulado en $*" >&2
      exit 1
    fi
    exit 0 ;;
esac
echo "falso pacman: args no soportados: $*" >&2
exit 1
"""

FAKE_FLATPAK = """\
#!/usr/bin/env bash
set -u
log="${NIMBUS_UPDATE_LOG:-/dev/null}"
echo "flatpak $*" >>"$log"
if [ "${1:-}" = "remote-ls" ]; then
  if [ -n "${FAKE_FLATPAK_UPDATES_FILE:-}" ] \\
      && [ -f "$FAKE_FLATPAK_UPDATES_FILE" ]; then
    cat "$FAKE_FLATPAK_UPDATES_FILE"
  fi
  exit 0
fi
if [ "${1:-}" = "update" ]; then
  exit 0
fi
echo "falso flatpak: args no soportados: $*" >&2
exit 1
"""


def _write_fake(bin_dir: pathlib.Path, name: str, content: str):
    fake = bin_dir / name
    fake.write_text(content, encoding="utf-8")
    fake.chmod(fake.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP)
    return fake


def make_fakes(tmp_path: pathlib.Path, monkeypatch, *,
               pacman_updates="", flatpak_updates="",
               with_flatpak=True):
    """Binarios falsos en un PATH temporal; devuelve (env_base, log)."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    _write_fake(bin_dir, "btrfs", FAKE_BTRFS)
    _write_fake(bin_dir, "pacman", FAKE_PACMAN)
    if with_flatpak:
        _write_fake(bin_dir, "flatpak", FAKE_FLATPAK)
    monkeypatch.setenv("PATH",
                       str(bin_dir) + os.pathsep + os.environ["PATH"])
    updates = tmp_path / "pacman-updates.txt"
    updates.write_text(pacman_updates, encoding="utf-8")
    fupdates = tmp_path / "flatpak-updates.txt"
    fupdates.write_text(flatpak_updates, encoding="utf-8")
    log = tmp_path / "calls.log"
    log.write_text("", encoding="utf-8")
    env = {
        "NIMBUS_UPDATE_ALLOW_UNPRIVILEGED": "1",
        "NIMBUS_UPDATE_STATE_DIR": str(tmp_path / "state"),
        "NIMBUS_UPDATE_SNAP_ROOT": str(tmp_path / "snapshots"),
        "NIMBUS_UPDATE_CONF": str(tmp_path / "update.conf"),
        "NIMBUS_UPDATE_FS_TYPE": "btrfs",
        "NIMBUS_UPDATE_LOG": str(log),
        "FAKE_PACMAN_UPDATES_FILE": str(updates),
        "FAKE_FLATPAK_UPDATES_FILE": str(fupdates),
        "FAKE_BTRFS_DEFAULT_FILE": str(tmp_path / "default-subvol"),
    }
    (tmp_path / "update.conf").write_text(
        "UPDATE_WINDOW_START=02:00\n"
        "UPDATE_WINDOW_END=05:00\n"
        "REQUIRE_IDLE=1\n",
        encoding="utf-8",
    )
    return env, log


def run_update(*args, env_extra=None):
    env = dict(os.environ)
    env.update(env_extra or {})
    return subprocess.run(
        ["bash", str(SCRIPT), *args],
        capture_output=True, text=True, env=env,
    )


def log_lines(log: pathlib.Path):
    return log.read_text(encoding="utf-8").splitlines()


# --- el paquete y sus ficheros ------------------------------------------------


def test_package_layout_exists():
    assert (PKG / "PKGBUILD").is_file(), "falta packages/nimbus-update/PKGBUILD"
    assert SCRIPT.is_file(), "falta files/nimbus-update"
    assert os.access(SCRIPT, os.X_OK), "nimbus-update debe ser ejecutable"
    assert CONF.is_file(), "falta files/update.conf"
    for unit in ALL_UNITS:
        assert unit.is_file(), f"falta la unit {unit.name}"


def test_script_hygiene():
    text = SCRIPT.read_text(encoding="utf-8")
    head = SCRIPT.read_bytes()[:600].decode("utf-8", errors="replace")
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in head
    assert "set -euo pipefail" in text
    assert re.search(r"(?m)^\s*eval\b", text) is None, "eval prohibido"
    lowered = text.lower()
    for nasty in ("curl", "wget", "ssh ", "http://", "https://"):
        assert nasty not in lowered, f"sin telemetría ni red: {nasty!r}"


def test_pkgbuild_declares_dep_and_no_snapper():
    import re
    pkgbuild = (PKG / "PKGBUILD").read_text(encoding="utf-8")
    assert "SPDX-License-Identifier" in pkgbuild[:600]
    assert "pkgname=nimbus-update" in pkgbuild
    assert "source=()" in pkgbuild
    assert "btrfs-progs" in pkgbuild, "el snapshot usa el CLI btrfs"
    deps = " ".join(re.findall(r"(?:opt)?depends=\((.*?)\)",
                              pkgbuild, re.DOTALL))
    assert "snapper" not in deps, "sin snapper: btrfs directo basta"
    assert "etc/nimbus/update.conf" in pkgbuild
    for unit in ("nimbus-snapshots", "nimbus-auto-update"):
        assert f"{unit}.service" in pkgbuild, unit
        assert f"{unit}.timer" in pkgbuild, unit


def test_scripts_pass_bash_syntax():
    proc = subprocess.run(["bash", "-n", str(SCRIPT)],
                          capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    if shutil.which("shellcheck") is None:
        pytest.skip("shellcheck no instalado aquí")
    proc = subprocess.run(["shellcheck", "-S", "warning", str(SCRIPT)],
                          capture_output=True, text=True)
    assert proc.returncode == 0, proc.stdout + proc.stderr


# --- check: hay / no hay -------------------------------------------------------


def test_check_reports_no_updates_exit_zero(tmp_path, monkeypatch):
    env, _log = make_fakes(tmp_path, monkeypatch)
    proc = run_update("check", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "día" in (proc.stdout + proc.stderr).lower()


def test_check_lists_updates_and_exits_nonzero(tmp_path, monkeypatch):
    env, _log = make_fakes(
        tmp_path, monkeypatch,
        pacman_updates="linux-cachyos 6.14.1-1 -> 6.14.2-1\n",
        flatpak_updates="org.mozilla.firefox\n",
    )
    proc = run_update("check", env_extra=env)
    assert proc.returncode != 0, "con actualizaciones debe salir != 0"
    out = proc.stdout + proc.stderr
    assert "linux-cachyos" in out
    assert "org.mozilla.firefox" in out


def test_check_without_flatpak_still_works(tmp_path, monkeypatch):
    env, _log = make_fakes(tmp_path, monkeypatch, with_flatpak=False,
                           pacman_updates="vim 9.1 -> 9.2\n")
    env.pop("FAKE_FLATPAK_UPDATES_FILE", None)
    proc = run_update("check", env_extra=env)
    assert proc.returncode != 0
    assert "vim" in proc.stdout + proc.stderr


# --- apply: snapshot antes, idempotencia, restauración --------------------------


def test_apply_is_idempotent_without_updates(tmp_path, monkeypatch):
    env, log = make_fakes(tmp_path, monkeypatch)
    proc = run_update("apply", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    calls = "\n".join(log_lines(log))
    assert "subvolume snapshot" not in calls, \
        "sin actualizaciones no se crean snapshots basura"
    state = tmp_path / "state"
    if state.is_dir():
        assert list(state.iterdir()) == [], "nada que guardar sin cambios"


def test_apply_snapshots_before_updating(tmp_path, monkeypatch):
    env, log = make_fakes(tmp_path, monkeypatch,
                          pacman_updates="linux-cachyos 6.14.1-1 -> 6.14.2-1\n")
    proc = run_update("apply", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    calls = log_lines(log)
    snap_idx = next(i for i, l in enumerate(calls)
                    if "subvolume snapshot" in l)
    su_idx = next(i for i, l in enumerate(calls) if l.startswith("pacman -Su"))
    assert snap_idx < su_idx, f"el snapshot va primero: {calls}"
    assert "linux-cachyos" in proc.stdout, proc.stdout + proc.stderr


def test_apply_aborts_when_snapshot_fails(tmp_path, monkeypatch):
    env, log = make_fakes(tmp_path, monkeypatch,
                          pacman_updates="vim 9.1 -> 9.2\n")
    env["FAKE_BTRFS_SNAPSHOT_FAIL"] = "1"
    proc = run_update("apply", env_extra=env)
    assert proc.returncode != 0, "sin snapshot no se aplica nada"
    calls = "\n".join(log_lines(log))
    assert "pacman -Su" not in calls, "no toca el sistema sin snapshot"
    out = (proc.stdout + proc.stderr).lower()
    assert "snapshot" in out, "el error debe decir por qué"


def test_apply_restores_snapshot_when_update_fails(tmp_path, monkeypatch):
    env, log = make_fakes(tmp_path, monkeypatch,
                          pacman_updates="vim 9.1 -> 9.2\n")
    env["FAKE_PACMAN_FAIL"] = "1"
    proc = run_update("apply", env_extra=env)
    assert proc.returncode != 0
    calls = log_lines(log)
    assert any("subvolume snapshot" in l for l in calls)
    assert any(l.startswith("pacman -Su") for l in calls)
    assert any("set-default" in l for l in calls), \
        "al fallar, restaura el snapshot"
    out = (proc.stdout + proc.stderr).lower()
    assert "restaur" in out, "debe decir que restauró"


# --- snapshot / history / rollback ------------------------------------------------


def test_snapshot_then_history_lists_it(tmp_path, monkeypatch):
    env, _log = make_fakes(tmp_path, monkeypatch)
    proc = run_update("snapshot", "antes-de-probar", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    hist = run_update("history", env_extra=env)
    assert hist.returncode == 0, hist.stdout + hist.stderr
    assert re.search(r"nimbus-\d{8}-\d{6}", hist.stdout), hist.stdout
    assert re.search(r"\d{4}-\d{2}-\d{2}", hist.stdout), "fecha visible"
    assert "snapshot" in hist.stdout.lower(), "estado visible"


def test_rollback_restores_and_verifies(tmp_path, monkeypatch):
    env, log = make_fakes(tmp_path, monkeypatch)
    assert run_update("snapshot", "previo", env_extra=env).returncode == 0
    hist = run_update("history", env_extra=env).stdout
    snap_id = re.search(r"(nimbus-\S+)", hist).group(1)
    log.write_text("", encoding="utf-8")
    proc = run_update("rollback", snap_id, env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    calls = log_lines(log)
    assert any("set-default" in l and snap_id in l for l in calls), \
        "restaura ese snapshot"
    assert any("get-default" in l for l in calls), "y lo verifica"
    assert "reinici" in (proc.stdout + proc.stderr).lower(), \
        "avisa de que falta reiniciar"


def test_rollback_defaults_to_latest(tmp_path, monkeypatch):
    env, _log = make_fakes(tmp_path, monkeypatch)
    assert run_update("snapshot", "primero", env_extra=env).returncode == 0
    proc = run_update("rollback", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr


def test_rollback_fails_legibly_when_verify_fails(tmp_path, monkeypatch):
    env, _log = make_fakes(tmp_path, monkeypatch)
    assert run_update("snapshot", "previo", env_extra=env).returncode == 0
    env["FAKE_BTRFS_VERIFY_FAIL"] = "1"
    proc = run_update("rollback", env_extra=env)
    assert proc.returncode != 0, "verificación fallida != éxito fingido"
    assert "verific" in (proc.stdout + proc.stderr).lower()


def test_snapshot_on_non_btrfs_fails_legibly(tmp_path, monkeypatch):
    env, _log = make_fakes(tmp_path, monkeypatch)
    env["NIMBUS_UPDATE_FS_TYPE"] = "ext4"
    proc = run_update("snapshot", env_extra=env)
    assert proc.returncode != 0
    assert "btrfs" in (proc.stdout + proc.stderr).lower()


def test_rollback_on_non_btrfs_fails_legibly(tmp_path, monkeypatch):
    env, _log = make_fakes(tmp_path, monkeypatch)
    env["NIMBUS_UPDATE_FS_TYPE"] = "ext4"
    proc = run_update("rollback", env_extra=env)
    assert proc.returncode != 0
    assert "btrfs" in (proc.stdout + proc.stderr).lower()


# --- auto: ventana de mantenimiento ------------------------------------------------


def test_auto_defers_outside_window(tmp_path, monkeypatch):
    env, log = make_fakes(tmp_path, monkeypatch,
                          pacman_updates="vim 9.1 -> 9.2\n")
    env["NIMBUS_UPDATE_HOUR"] = "12:00"
    env["NIMBUS_UPDATE_IDLE"] = "idle"
    proc = run_update("auto", env_extra=env)
    assert proc.returncode != 0, "diferido != aplicado"
    calls = "\n".join(log_lines(log))
    assert "pacman -Su" not in calls
    assert "subvolume snapshot" not in calls
    out = (proc.stdout + proc.stderr).lower()
    assert "ventana" in out or "difer" in out or "mantenimiento" in out


def test_auto_applies_inside_window_when_idle(tmp_path, monkeypatch):
    env, log = make_fakes(tmp_path, monkeypatch,
                          pacman_updates="vim 9.1 -> 9.2\n")
    env["NIMBUS_UPDATE_HOUR"] = "03:30"
    env["NIMBUS_UPDATE_IDLE"] = "idle"
    proc = run_update("auto", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert any(l.startswith("pacman -Su") for l in log_lines(log))


def test_auto_defers_when_user_active(tmp_path, monkeypatch):
    env, log = make_fakes(tmp_path, monkeypatch,
                          pacman_updates="vim 9.1 -> 9.2\n")
    env["NIMBUS_UPDATE_HOUR"] = "03:30"
    env["NIMBUS_UPDATE_IDLE"] = "busy"
    proc = run_update("auto", env_extra=env)
    assert proc.returncode != 0
    assert "pacman -Su" not in "\n".join(log_lines(log))


def test_auto_with_nothing_to_do_is_zero(tmp_path, monkeypatch):
    env, _log = make_fakes(tmp_path, monkeypatch)
    env["NIMBUS_UPDATE_HOUR"] = "12:00"
    proc = run_update("auto", env_extra=env)
    assert proc.returncode == 0, proc.stdout + proc.stderr


# --- privilegios: pkexec para escribir, lectura libre ---------------------------------


def test_apply_requires_privileges():
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        pytest.skip("este test necesita un usuario sin privilegios")
    env = {"NIMBUS_UPDATE_NO_REEXEC": "1",
           "PATH": os.environ["PATH"]}
    proc = run_update("apply", env_extra=env)
    assert proc.returncode != 0
    out = (proc.stdout + proc.stderr).lower()
    assert "polkit" in out or "pkexec" in out


def test_check_needs_no_privileges(tmp_path, monkeypatch):
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        pytest.skip("este test necesita un usuario sin privilegios")
    env, _log = make_fakes(tmp_path, monkeypatch)
    env.pop("NIMBUS_UPDATE_ALLOW_UNPRIVILEGED", None)
    env["NIMBUS_UPDATE_NO_REEXEC"] = "1"
    for args in (("check",), ("history",)):
        proc = run_update(*args, env_extra=env)
        assert proc.returncode in (0, 2), \
            f"{' '.join(args)} no debe pedir privilegios"


# --- units de systemd -----------------------------------------------------------------


def _unit_sections(path: pathlib.Path):
    sections = {}
    current = None
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections.setdefault(current, [])
        elif current is not None:
            sections[current].append(line)
    return sections


def test_timers_have_coherent_wantedby():
    for timer in (SNAPSHOT_TIMER, AUTO_TIMER):
        sections = _unit_sections(timer)
        assert "Timer" in sections, timer.name
        assert any(l.startswith("OnCalendar=") for l in sections["Timer"])
        assert any(l.startswith("Persistent=") for l in sections["Timer"])
        wanted = [l for l in sections.get("Install", [])
                  if l.startswith("WantedBy=")]
        # Coherente con el symlink que crearía `systemctl enable`
        # (mismo criterio que tests/test_iso_profile.py).
        assert wanted == ["WantedBy=timers.target"], (timer.name, wanted)


def test_services_match_their_timers():
    pairs = ((SNAPSHOT_SERVICE, SNAPSHOT_TIMER, "snapshot"),
             (AUTO_SERVICE, AUTO_TIMER, "auto"))
    for service, timer, verb in pairs:
        ssec = _unit_sections(service)
        assert "Service" in ssec, service.name
        assert any(l == "Type=oneshot" for l in ssec["Service"])
        assert any("ExecStart=/usr/bin/nimbus-update" in l
                   and verb in l for l in ssec["Service"]), service.name
        # Patrón timer+servicio: el [Install] vive en el timer.
        assert "Install" not in ssec, \
            f"{service.name}: el servicio se activa vía su timer"
        tsec = _unit_sections(timer)
        assert any("WantedBy=timers.target" in l
                   for l in tsec.get("Install", [])), timer.name


def test_units_form_no_order_cycle():
    names = {p.name for p in ALL_UNITS}
    edges = {name: set() for name in names}
    for path in ALL_UNITS:
        for lines in _unit_sections(path).values():
            for line in lines:
                for key in ("After=", "Before=", "Requires=",
                            "Wants=", "Requisite=", "BindsTo="):
                    if line.startswith(key):
                        for target in line[len(key):].split():
                            target = target.strip()
                            if target in names and target != path.name:
                                if key == "Before=":
                                    edges[target].add(path.name)
                                else:
                                    edges[path.name].add(target)
    # DFS: sin aristas hacia atrás = sin ciclo de orden/dependencia.
    visiting, done = set(), set()

    def _visit(node, stack):
        assert node not in stack, f"ciclo de orden entre units: {stack}"
        if node in done:
            return
        visiting.add(node)
        for nxt in sorted(edges[node]):
            _visit(nxt, stack + [node])
        visiting.discard(node)
        done.add(node)

    for name in sorted(names):
        _visit(name, [])


# --- postinstall: repo real y timers que existen -----------------------------------------


def _load_tool():
    from importlib.machinery import SourceFileLoader
    import importlib.util
    loader = SourceFileLoader("nimbus_postinstall_update_track",
                              str(TOOL_PATH))
    spec = importlib.util.spec_from_file_location(
        "nimbus_postinstall_update_track", str(TOOL_PATH), loader=loader)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakePostExec:
    """Doble mínimo del ejecutor para los pasos repo-nimbus y services."""

    def __init__(self):
        self.files = {}
        self.commands = []
        self.enabled = []

    def run(self, cmd):
        assert isinstance(cmd, list), "el comando debe ser una lista"
        self.commands.append(list(cmd))

        class _Result:
            returncode = 0
            stdout = ""
            stderr = ""
        return _Result()

    def read_text(self, path, default=None):
        if str(path) in self.files:
            return self.files[str(path)]
        if default is not None:
            return default
        raise FileNotFoundError(str(path))

    def write_text(self, path, content):
        self.files[str(path)] = (content.decode("utf-8")
                                 if isinstance(content, bytes)
                                 else content)

    def cpuinfo_text(self):
        return "flags : fpu avx avx2\n"

    def enable_service(self, name):
        self.enabled.append(name)

        class _Result:
            returncode = 0
            stdout = ""
            stderr = ""
        return _Result()


def _active_servers(text):
    servers = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = re.match(r"Server\s*=\s*(\S+)", stripped)
        if match:
            servers.append(match.group(1))
    return servers


def _http_hosts(urls):
    hosts = []
    for url in urls:
        if url.startswith("http://") or url.startswith("https://"):
            hosts.append(urllib.parse.urlsplit(url).hostname)
    return [h for h in hosts if h]


def test_postinstall_repo_has_no_bogus_domain():
    tool = _load_tool()
    assert "mirror.nimbus.org" not in pathlib.Path(TOOL_PATH).read_text(
        encoding="utf-8"), "el dominio inexistente no puede seguir aquí"
    fake = FakePostExec()
    ctx = tool.Ctx(root="/target", offline=False, locale="en", ex=fake)
    status, message = tool.step_repo_nimbus(ctx)
    assert status == "ok", message
    # Compatibilidad: el bloque [nimbus] sigue declarándose igual.
    conf = fake.files["/target/etc/pacman.conf"]
    assert "[nimbus]" in conf
    assert "SigLevel = Required DatabaseOptional" in conf
    # Ningún fichero escrito menciona el dominio inexistente.
    for path, content in fake.files.items():
        assert "mirror.nimbus.org" not in content, path
    # Toda URL http(s) activa debe resolverse (no inventar dominios).
    urls = [u for content in fake.files.values()
            for u in _active_servers(content)]
    hosts = _http_hosts(urls)
    try:
        socket.getaddrinfo("archlinux.org", 443)
    except OSError:
        pytest.skip("sin DNS externa: no se puede verificar resolución")
    for host in hosts:
        try:
            socket.getaddrinfo(host, 443)
        except OSError:
            pytest.fail(f"el repo apunta a un host que no existe: {host}")


def test_postinstall_repo_declares_bootstrap_status():
    tool = _load_tool()
    fake = FakePostExec()
    ctx = tool.Ctx(root="/target", offline=False, locale="en", ex=fake)
    status, message = tool.step_repo_nimbus(ctx)
    assert status == "ok", message
    assert ("pendiente" in message.lower() or "pending" in message.lower()
            or "bootstrap" in message.lower()), \
        f"el paso debe decir que el repo público está pendiente: {message!r}"
    repo_conf = fake.files.get("/target/etc/nimbus/repo.conf", "")
    assert repo_conf.strip(), "falta /etc/nimbus/repo.conf con el estado"
    lowered = repo_conf.lower()
    assert "bootstrap" in lowered
    assert "pending" in lowered or "pendiente" in lowered
    assert "mirror.nimbus.org" not in repo_conf


def test_postinstall_enables_units_that_exist():
    tool = _load_tool()
    shipped = {p.name for p in ALL_UNITS}
    timers_in_tool = set(re.findall(r"nimbus-[\w-]+\.timer",
                                   pathlib.Path(TOOL_PATH).read_text(
                                       encoding="utf-8")))
    assert timers_in_tool, "el postinstall debe nombrar sus timers"
    missing = timers_in_tool - shipped
    assert missing == set(), \
        f"el postinstall activa units que no existen: {missing}"
    fake = FakePostExec()
    ctx = tool.Ctx(root="/target", offline=False, locale="en", ex=fake)
    status, _message = tool.step_services(ctx)
    assert status == "ok"
    assert set(fake.enabled) == timers_in_tool


def test_installed_system_pacman_conf_has_no_bogus_server():
    """La config que deja el postinstall: `pacman -Syu` no falla por el repo.

    Verificación por construcción (aquí no hay un sistema instalado real):
    la única `Server` de `[nimbus]` es `file://` (verificada aparte con
    `fakeroot pacman -Sy`, ver informe) y no hay dominios inexistentes.
    """
    tool = _load_tool()
    fake = FakePostExec()
    ctx = tool.Ctx(root="/target", offline=False, locale="en", ex=fake)
    assert tool.step_repo_nimbus(ctx)[0] == "ok"
    conf = fake.files["/target/etc/pacman.conf"]
    section = conf.split("[nimbus]")[1].split("[")[0]
    servers = _active_servers(section)
    assert servers, "sin Server, `pacman -Syu` falla (verificado aparte)"
    for url in servers:
        assert url.startswith("file://"), \
            f"solo file:// local hasta el repo público: {url}"
