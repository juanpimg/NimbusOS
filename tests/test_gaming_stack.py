# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests del metapaquete nimbus-gaming (M3 Task 1).

El interruptor "gameready" del instalador tiene que ser una promesa
cumplida: Steam instalado y configurado con Proton por defecto, sin que
instalar el paquete abra nada solo.
"""

import os
import pathlib
import re
import stat
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
PKG = ROOT / "packages" / "nimbus-gaming"
PKGBUILD = PKG / "PKGBUILD"
INSTALL = PKG / "nimbus-gaming.install"

EXPECTED_DEPS = frozenset({
    "steam",
    "proton-ge",
    "proton-cachyos",
    "gamescope",
    "gamemode",
    "mangohud",
    "vkbasalt",
    "lib32-vulkan",
    "vkd3d-proton",
    "heroic",
    "lutris",
    "bottles",
    "protonup-qt",
    "protontricks",
})


def _pkgbuild_text():
    assert PKGBUILD.is_file(), "falta packages/nimbus-gaming/PKGBUILD"
    return PKGBUILD.read_text(encoding="utf-8")


def _depends_set(text):
    match = re.search(r"depends=\((.*?)\)", text, re.DOTALL)
    assert match, "PKGBUILD sin depends=(...)"
    return frozenset(re.findall(r"['\"]([^'\"]+)['\"]", match.group(1)))


def _install_text():
    assert INSTALL.is_file(), "falta packages/nimbus-gaming/nimbus-gaming.install"
    return INSTALL.read_text(encoding="utf-8")


def _run_install_entrypoint(conf_dir):
    """Ejecuta el entrypoint idempotente del .install contra un dir temporal."""
    env = dict(os.environ, NIMBUS_GAMING_CONF_DIR=str(conf_dir))
    proc = subprocess.run(
        ["bash", "-c", 'source "$1"; nimbus_gaming_set_default_proton', "bash", str(INSTALL)],
        capture_output=True, text=True, env=env,
    )
    assert proc.returncode == 0, proc.stderr


def test_pkgbuild_declares_exact_dependency_set():
    deps = _depends_set(_pkgbuild_text())
    assert deps == EXPECTED_DEPS, f"dependencias inesperadas: {sorted(deps ^ EXPECTED_DEPS)}"


def test_pkgbuild_has_no_aur_dependencies():
    text = _pkgbuild_text()
    assert "aur" not in text.lower(), "el PKGBUILD no debe referenciar AUR"
    deps = _depends_set(text)
    assert not {d for d in deps if d.endswith("-git")}, "nada de -git (AUR)"
    assert deps <= EXPECTED_DEPS


def test_pkgbuild_license_and_spdx():
    text = _pkgbuild_text()
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in text.splitlines()[0]
    assert re.search(r"license=\([^)]*GPL-3\.0-or-later[^)]*\)", text)


def test_pkgbuild_builds_from_local_tree():
    text = _pkgbuild_text()
    assert re.search(r"source=\(\s*\)", text), "source=() vacio: build desde el arbol local"
    assert "http" not in text and "git+" not in text, "sin fuentes remotas"
    # Si package() instala ficheros, es via $startdir (estilo del monorepo);
    # un metapaquete puro puede no instalar ninguno (Task 5 anade los presets).
    installs = re.findall(r"^\s*install\s", text, re.MULTILINE)
    if installs:
        assert "$startdir" in text, "los ficheros se leen via $startdir"


def test_install_is_idempotent(tmp_path):
    _run_install_entrypoint(tmp_path)
    first = {p.name: p.read_bytes() for p in sorted(tmp_path.iterdir())}
    assert first, "el .install debe dejar configuracion escrita"
    _run_install_entrypoint(tmp_path)
    second = {p.name: p.read_bytes() for p in sorted(tmp_path.iterdir())}
    assert first == second, "ejecutarlo dos veces no debe duplicar nada"
    blob = b"\n".join(second.values())
    assert blob.count(b"proton-cachyos") >= 1, "el Proton por defecto debe quedar configurado"
    proton_file = tmp_path / "default-proton"
    assert proton_file.is_file()
    assert proton_file.read_text(encoding="utf-8").strip() == "proton-cachyos"
    assert proton_file.read_text(encoding="utf-8").count("proton-cachyos") == 1


def test_install_does_not_autolaunch():
    lines = [
        line for line in _install_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]
    code = "\n".join(lines)
    forbidden = [
        r"(^|[;&|]\s*|\s)(steam|steam-native)(\s|$|[;&])",
        r"\bxdg-open\b",
        r"\bsystemctl\b.*\b(start|enable)\b",
        r"\bgtk-launch\b",
        r"steam://.*rungameid",
    ]
    for pattern in forbidden:
        assert not re.search(pattern, code), f"el .install no debe lanzar nada ({pattern})"


def test_install_sets_default_proton():
    text = _install_text()
    assert "proton-cachyos" in text, "el Proton por defecto (proton-cachyos) debe configurarse"
    assert "nimbus_gaming_set_default_proton" in text
    assert "post_install" in text


# ---- M3 Task 5: telemetria de juegos y ajustes por juego ----

MANGOHUD = PKG / "files" / "mangohud.conf"
GAMESCOPE = PKG / "files" / "gamescope.conf"
TUNE = PKG / "files" / "nimbus-gaming-tune"

ORIG_GOVERNOR = "powersave"
ORIG_PROFILE = "balanced"
ORIG_GPU = "on-demand"
APPLIED_GPU = "always"


def _write_fake_tune_tools(bin_dir, sys_dir, *, ppd_fail_set=False, mangohud_log=None):
    """Falsos `powerprofilesctl`/`prime-select`/`gamemoderun`/`mangohud`
    (mas un `cpupower` de respaldo) para probar el tune sin root ni
    hardware. El governor real vive en el sysfs falso (scaling_governor);
    el `prime-select` falso solo acepta modos reales
    (nvidia|intel|on-demand): rechaza `on`.
    """
    ppd_state = sys_dir / "ppd-state"
    ppd_state.write_text(ORIG_PROFILE, encoding="utf-8")
    gpu_state = sys_dir / "gpu-real-state"
    gpu_state.write_text(ORIG_GPU, encoding="utf-8")
    prime_log = sys_dir / "prime-args.log"
    prime_log.write_text("", encoding="utf-8")
    gov_sysfs = sys_dir / "sys" / "devices" / "system" / "cpu" / "cpu0" / "cpufreq"
    gov_sysfs.mkdir(parents=True)
    (gov_sysfs / "scaling_governor").write_text(ORIG_GOVERNOR + "\n", encoding="utf-8")

    (bin_dir / "powerprofilesctl").write_text(
        "#!/usr/bin/env bash\n"
        "set -u\n"
        'state="${PPD_STATE:?}"\n'
        'if [ "${1:-}" = "get" ]; then cat "$state"; exit 0; fi\n'
        'if [ "${1:-}" = "set" ]; then\n'
        '  if [ "${PPD_FAIL_SET:-0}" = "1" ]; then echo "falso PPD: no se pudo aplicar" >&2; exit 1; fi\n'
        '  printf "%s" "$2" > "$state"; exit 0\n'
        "fi\n"
        'echo "uso falso: get|set" >&2; exit 2\n',
        encoding="utf-8",
    )
    (bin_dir / "cpupower").write_text(
        "#!/usr/bin/env bash\n"
        "set -u\n"
        'if [ "${1:-}" = "frequency-set" ] && [ "${2:-}" = "-g" ]; then exit 0; fi\n'
        'echo "falso cpupower: solo frequency-set -g" >&2; exit 2\n',
        encoding="utf-8",
    )
    (bin_dir / "prime-select").write_text(
        "#!/usr/bin/env bash\n"
        "set -u\n"
        'state="${GPU_REAL_STATE:?}"\n'
        'log="${PRIME_ARGS_LOG:?}"\n'
        'if [ "${1:-}" = "query" ]; then cat "$state"; exit 0; fi\n'
        'printf "%s\\n" "$1" >> "$log"\n'
        'case "$1" in\n'
        '  nvidia|intel|on-demand) printf "%s" "$1" > "$state";;\n'
        '  *) echo "falso prime-select: modo invalido \'$1\' (validos: nvidia|intel|on-demand)" >&2; exit 1;;\n'
        "esac\n",
        encoding="utf-8",
    )
    (bin_dir / "gamemoderun").write_text(
        "#!/usr/bin/env bash\nexec \"$@\"\n", encoding="utf-8",
    )
    if mangohud_log is not None:
        (bin_dir / "mangohud").write_text(
            "#!/usr/bin/env bash\n"
            'if [ "${1:-}" = "--dlsym" ]; then shift; fi\n'
            'printf "%s\\n" "${MANGOHUD_CONFIGFILE:-<vacio>}" >> "$MANGOHUD_LOG"\n'
            'exec "$@"\n',
            encoding="utf-8",
        )
    else:
        (bin_dir / "mangohud").write_text(
            "#!/usr/bin/env bash\n"
            'if [ "${1:-}" = "--dlsym" ]; then shift; fi\n'
            'exec "$@"\n',
            encoding="utf-8",
        )
    for name in ("powerprofilesctl", "cpupower", "prime-select", "gamemoderun", "mangohud"):
        p = bin_dir / name
        p.chmod(p.stat().st_mode | stat.S_IXUSR)
    gov_file = sys_dir / "sys" / "devices" / "system" / "cpu" / "cpu0" / "cpufreq" / "scaling_governor"
    return {
        "PPD_STATE": str(ppd_state),
        "CPU_GOVERNOR_FILE": str(gov_file),
        "GPU_REAL_STATE": str(gpu_state),
        "PRIME_ARGS_LOG": str(prime_log),
        "PPD_FAIL_SET": "1" if ppd_fail_set else "0",
        "NIMBUS_CPU_SYSFS": str(sys_dir),
        "NIMBUS_MANGOHUD_CONF": str(MANGOHUD),
    }


def _tune_env(tmp_path, monkeypatch, **kwargs):
    bin_dir = tmp_path / "fakebin"
    bin_dir.mkdir()
    sys_dir = tmp_path / "fakesys"
    sys_dir.mkdir()
    env = _write_fake_tune_tools(bin_dir, sys_dir, **kwargs)
    monkeypatch.setenv("PATH", str(bin_dir) + os.pathsep + os.environ["PATH"])
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    return env


def _seed_state(state_dir):
    state_dir.mkdir(parents=True, exist_ok=True)
    (state_dir / "cpu_governor").write_text(ORIG_GOVERNOR + "\n", encoding="utf-8")
    (state_dir / "energy_profile").write_text(ORIG_PROFILE + "\n", encoding="utf-8")
    (state_dir / "gpu_mode").write_text(ORIG_GPU + "\n", encoding="utf-8")
    return state_dir


def _read_state(state_dir):
    return {
        name: (state_dir / name).read_text(encoding="utf-8").strip()
        for name in ("cpu_governor", "energy_profile", "gpu_mode")
    }


def _run_tune(*args):
    assert TUNE.is_file(), "falta packages/nimbus-gaming/files/nimbus-gaming-tune"
    return subprocess.run(
        [str(TUNE), *args], capture_output=True, text=True, timeout=60,
    )


def test_mangohud_has_fps_and_frametime():
    assert MANGOHUD.is_file(), "falta files/mangohud.conf"
    text = MANGOHUD.read_text(encoding="utf-8")
    assert re.search(r"(?m)^\s*fps\b", text), "el preset debe mostrar FPS"
    assert re.search(r"(?m)^\s*frametime\b", text), "el preset debe mostrar frametime"


def test_mangohud_covers_gpu_cpu_ram_vram():
    text = MANGOHUD.read_text(encoding="utf-8")
    lowered = text.lower()
    assert "gpu_temp" in lowered, "temperatura de GPU"
    assert "cpu_temp" in lowered, "temperatura de CPU"
    assert "gpu_stats" in lowered or "gpu_core_clock" in lowered, "uso de GPU"
    assert re.search(r"(?m)^\s*ram\b", lowered), "uso de RAM"
    assert re.search(r"(?m)^\s*vram\b", lowered), "uso de VRAM"


def test_mangohud_has_no_exec():
    text = MANGOHUD.read_text(encoding="utf-8")
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        assert not re.match(r"(?i)exec\b", stripped), \
            f"nada de exec en el overlay: {line!r}"


def test_gamescope_has_no_static_vrr():
    assert GAMESCOPE.is_file(), "falta files/gamescope.conf"
    text = GAMESCOPE.read_text(encoding="utf-8")
    for token in ("vrr", "adaptive-sync", "adaptive_sync", "adaptivesync",
                  "freesync", "free-sync", "gsync", "g-sync", "variable-refresh"):
        assert token not in text.lower(), \
            f"el VRR se activa por deteccion, no estaticamente ({token})"


def test_gamescope_preset_is_valid():
    text = GAMESCOPE.read_text(encoding="utf-8")
    pairs = [
        line for line in text.splitlines()
        if "=" in line and not line.strip().startswith("#")
    ]
    assert pairs, "el preset debe definir ajustes KEY=VALUE"
    keys = {line.split("=", 1)[0].strip() for line in pairs}
    assert any("WIDTH" in key or "RESOLUTION" in key for key in keys)
    assert any("FULLSCREEN" in key for key in keys)


def test_pkgbuild_installs_gaming_files():
    text = _pkgbuild_text()
    for name in ("mangohud.conf", "gamescope.conf", "nimbus-gaming-tune"):
        assert name in text, f"package() debe instalar {name}"
    assert "$startdir" in text


def test_tune_usage_and_validation():
    assert _run_tune().returncode != 0, "sin appid debe fallar"
    assert _run_tune("no-numerico").returncode != 0, "el appid debe ser numerico"
    assert _run_tune("123", "--profile", "turbo").returncode != 0
    assert _run_tune("123", "--mangohud", "quizas").returncode != 0
    assert _run_tune("--help").returncode == 0


def test_tune_applies_and_restores(tmp_path, monkeypatch):
    state = _seed_state(tmp_path / "state")
    env = _tune_env(tmp_path, monkeypatch)
    probe = (
        'test "$(cat "$NIMBUS_PROBE/cpu_governor")" = performance && '
        'test "$(cat "$NIMBUS_PROBE/energy_profile")" = performance && '
        'test "$(cat "$NIMBUS_PROBE/gpu_mode")" = always'
    )
    env = dict(os.environ, NIMBUS_PROBE=str(state))
    proc = subprocess.run(
        [str(TUNE), "440", "--state-dir", str(state),
         "--", "bash", "-c", probe],
        capture_output=True, text=True, env=env, timeout=60,
    )
    assert proc.returncode == 0, proc.stderr
    assert _read_state(state) == {
        "cpu_governor": ORIG_GOVERNOR,
        "energy_profile": ORIG_PROFILE,
        "gpu_mode": ORIG_GPU,
    }, "al salir, todo vuelve a su valor anterior"


def test_tune_restores_balanced_profile(tmp_path, monkeypatch):
    state = _seed_state(tmp_path / "state")
    _tune_env(tmp_path, monkeypatch)
    probe = (
        'test "$(cat "$NIMBUS_PROBE/cpu_governor")" = performance && '
        'test "$(cat "$NIMBUS_PROBE/energy_profile")" = balanced && '
        'test "$(cat "$NIMBUS_PROBE/gpu_mode")" = always'
    )
    env = dict(os.environ, NIMBUS_PROBE=str(state))
    proc = subprocess.run(
        [str(TUNE), "440", "--profile", "balanced",
         "--state-dir", str(state), "--", "bash", "-c", probe],
        capture_output=True, text=True, env=env, timeout=60,
    )
    assert proc.returncode == 0, proc.stderr
    assert _read_state(state)["energy_profile"] == ORIG_PROFILE


def test_tune_propagates_game_exit_code_and_restores(tmp_path, monkeypatch):
    state = _seed_state(tmp_path / "state")
    env = _tune_env(tmp_path, monkeypatch)
    proc = _run_tune("440", "--state-dir", str(state),
                     "--", "bash", "-c", "exit 42")
    assert proc.returncode == 42, "el codigo de salida del juego manda"
    assert _read_state(state) == {
        "cpu_governor": ORIG_GOVERNOR,
        "energy_profile": ORIG_PROFILE,
        "gpu_mode": ORIG_GPU,
    }


def test_tune_restores_on_sigterm(tmp_path, monkeypatch):
    import signal
    import time
    state = _seed_state(tmp_path / "state")
    env = _tune_env(tmp_path, monkeypatch)
    # start_new_session + killpg: un supervisor (systemd, timeout) senala a
    # todo el grupo, no solo al tune. bash difiere el trap de SIGTERM hasta
    # que el hijo en primer plano termina; con TERM al grupo, el juego muere
    # y el trap restaura de inmediato. Senalar solo al tune dejaria al juego
    # corriendo y la espera seria su duracion (ver M7 del informe final).
    proc = subprocess.Popen(
        [str(TUNE), "440", "--state-dir", str(state), "--", "sleep", "30"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        start_new_session=True,
    )
    try:
        deadline = time.time() + 10
        while time.time() < deadline:
            if (state / "cpu_governor").read_text(encoding="utf-8").strip() == "performance":
                break
            time.sleep(0.05)
        assert (state / "cpu_governor").read_text(encoding="utf-8").strip() == "performance"
        os.killpg(proc.pid, signal.SIGTERM)
        rc = proc.wait(timeout=10)
    finally:
        if proc.poll() is None:
            proc.kill()
    assert rc == 143, f"tras SIGTERM debe salir con 143, salio con {rc}"
    assert _read_state(state) == {
        "cpu_governor": ORIG_GOVERNOR,
        "energy_profile": ORIG_PROFILE,
        "gpu_mode": ORIG_GPU,
    }, "SIGTERM tambien debe restaurar"
    assert _read_fake_state(env) == {
        "ppd": ORIG_PROFILE, "cpu": ORIG_GOVERNOR, "gpu": ORIG_GPU,
    }, "SIGTERM tambien debe restaurar el sistema real"


def test_tune_is_idempotent(tmp_path, monkeypatch):
    state = _seed_state(tmp_path / "state")
    _tune_env(tmp_path, monkeypatch)
    for _ in range(2):
        proc = _run_tune("440", "--state-dir", str(state),
                         "--", "bash", "-c", "true")
        assert proc.returncode == 0, proc.stderr
    for name in ("cpu_governor", "energy_profile", "gpu_mode"):
        lines = (state / name).read_text(encoding="utf-8").splitlines()
        assert len(lines) == 1, f"{name} sin lineas duplicadas"
    assert _read_state(state) == {
        "cpu_governor": ORIG_GOVERNOR,
        "energy_profile": ORIG_PROFILE,
        "gpu_mode": ORIG_GPU,
    }


def test_tune_uses_trap():
    assert TUNE.is_file(), "falta files/nimbus-gaming-tune"
    text = TUNE.read_text(encoding="utf-8")
    assert re.search(r"trap\s+\S*restore\S*\s+.*EXIT", text), "trap para restaurar al salir"
    assert "TERM" in text, "el trap debe cubrir SIGTERM"


def test_tune_shell_hygiene():
    text = TUNE.read_text(encoding="utf-8")
    head = "\n".join(text.splitlines()[:2])
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in head
    assert text.splitlines()[0].startswith("#!"), "ejecutable con shebang"
    assert "set -euo pipefail" in text
    code = "\n".join(
        line for line in text.splitlines() if not line.strip().startswith("#")
    )
    assert not re.search(r"(?m)(^|[;\s&|])eval(\s|$|[;&])", code), "nada de eval"
    assert "prime-select" in text, "en hibrido se fuerza la dGPU"
    assert "gamemode" in text.lower(), "gamemode segun se pida"
    assert "|| true" not in code, \
        "los efectos reales no pueden silenciarse: si no se aplican, el tune debe fallar"


# ---- Revision final I1: el tune revierte el sistema real, no solo ficheros ----

def _read_fake_state(env):
    return {
        "ppd": pathlib.Path(env["PPD_STATE"]).read_text(encoding="utf-8").strip(),
        "cpu": pathlib.Path(env["CPU_GOVERNOR_FILE"]).read_text(encoding="utf-8").strip(),
        "gpu": pathlib.Path(env["GPU_REAL_STATE"]).read_text(encoding="utf-8").strip(),
    }


def test_tune_restores_real_system_state(tmp_path, monkeypatch):
    """Al salir, PPD, governor y GPU reales vuelven a su valor anterior."""
    state = _seed_state(tmp_path / "state")
    env = _tune_env(tmp_path, monkeypatch)
    assert _read_fake_state(env) == {
        "ppd": ORIG_PROFILE, "cpu": ORIG_GOVERNOR, "gpu": ORIG_GPU,
    }
    proc = _run_tune("440", "--state-dir", str(state), "--", "bash", "-c", "true")
    assert proc.returncode == 0, proc.stderr
    assert _read_fake_state(env) == {
        "ppd": ORIG_PROFILE, "cpu": ORIG_GOVERNOR, "gpu": ORIG_GPU,
    }, "el perfil performance y la dGPU no pueden quedar puestos al salir"


def test_tune_applies_real_system_state_while_game_runs(tmp_path, monkeypatch):
    """Mientras el juego corre, el sistema real esta en performance/dGPU."""
    state = _seed_state(tmp_path / "state")
    env = _tune_env(tmp_path, monkeypatch)
    probe = (
        'test "$(cat "$PPD_STATE")" = performance && '
        'test "$(cat "$NIMBUS_CPU_SYSFS/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")" = performance && '
        'test "$(cat "$GPU_REAL_STATE")" = nvidia'
    )
    proc = subprocess.run(
        [str(TUNE), "440", "--state-dir", str(state), "--", "bash", "-c", probe],
        capture_output=True, text=True, env=dict(os.environ), timeout=60,
    )
    assert proc.returncode == 0, proc.stderr


def test_tune_forces_dgpu_with_valid_prime_mode(tmp_path, monkeypatch):
    """La dGPU se fuerza con `nvidia`, nunca con el modo inexistente `on`."""
    state = _seed_state(tmp_path / "state")
    env = _tune_env(tmp_path, monkeypatch)
    proc = _run_tune("440", "--state-dir", str(state), "--", "bash", "-c", "true")
    assert proc.returncode == 0, proc.stderr
    modes = pathlib.Path(env["PRIME_ARGS_LOG"]).read_text(encoding="utf-8").split()
    assert "nvidia" in modes, f"debe forzar la dGPU con 'nvidia', se llamo con: {modes}"
    assert "on" not in modes, f"'on' no es un modo de prime-select: {modes}"


def test_tune_fails_loudly_when_ppd_apply_fails(tmp_path, monkeypatch):
    """Si el perfil no se puede aplicar, el tune falla en vez de seguir mudo."""
    state = _seed_state(tmp_path / "state")
    env = _tune_env(tmp_path, monkeypatch, ppd_fail_set=True)
    proc = _run_tune("440", "--state-dir", str(state), "--", "bash", "-c", "true")
    assert proc.returncode != 0, "si PPD no aplica el perfil, el tune debe fallar"
    assert _read_state(state) == {
        "cpu_governor": ORIG_GOVERNOR,
        "energy_profile": ORIG_PROFILE,
        "gpu_mode": ORIG_GPU,
    }, "al fallar, los ficheros de estado tambien se restauran"


# ---- Revision final I4: los presets tienen consumidor o se declaran inactivos ----

def test_tune_passes_mangohud_preset_to_game(tmp_path, monkeypatch):
    """El preset mangohud.conf se consume: llega via MANGOHUD_CONFIGFILE."""
    mangohud_log = tmp_path / "mangohud-env.log"
    mangohud_log.write_text("", encoding="utf-8")
    state = _seed_state(tmp_path / "state")
    env = _tune_env(tmp_path, monkeypatch, mangohud_log=str(mangohud_log))
    monkeypatch.setenv("MANGOHUD_LOG", str(mangohud_log))
    proc = _run_tune("440", "--state-dir", str(state), "--", "bash", "-c", "true")
    assert proc.returncode == 0, proc.stderr
    logged = mangohud_log.read_text(encoding="utf-8").strip().splitlines()
    assert logged, "mangohud debio ejecutarse con el overlay activado"
    assert logged[-1] == str(MANGOHUD), \
        f"MANGOHUD_CONFIGFILE debe apuntar al preset, fue: {logged[-1]}"


def test_gamescope_preset_is_consumed_by_session():
    """gamescope.conf: preset ACTIVO; su consumidor es nimbus-gaming-session.

    (M4 T2: la sesion lo lee como KEY=VALUE y lo traduce a flags de
    gamescope. Ya no se distribuye inactivo.)
    """
    assert GAMESCOPE.is_file(), "falta files/gamescope.conf"
    text = GAMESCOPE.read_text(encoding="utf-8")
    lowered = text.lower()
    assert "nimbus-gaming-session" in text, \
        "debe documentar que la sesion de juegos lo consume"
    for claim in ("inactivo", "inactive", "sin auto-activacion"):
        assert claim not in lowered, \
            f"el preset ya tiene consumidor, no puede declararse inactivo: {claim!r}"


# ---- M4 T2: sesion de juegos (greeter + gamescope + VRR por deteccion) ----

SESSION = PKG / "files" / "nimbus-gaming-session"
VRR_CHECK = PKG / "files" / "gamescope-vrr-check"
DESKTOP = PKG / "files" / "nimbus-gaming.desktop"

REAL_PRESET_DIR = "/usr/share/nimbus/gaming"
REAL_SESSION_PATH = "/usr/lib/nimbus/nimbus-gaming-session"
REAL_VRR_PATH = "/usr/bin/gamescope-vrr-check"


def _write_executable(path, content):
    path.write_text(content, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def _symlink_coreutils(bin_dir):
    """PATH minimo: coreutils reales + lo que el test inyecte como falso."""
    bin_dir.mkdir(parents=True, exist_ok=True)
    for name in ("bash", "cat", "grep", "sed", "ls", "mkdir", "head", "tr"):
        target = pathlib.Path("/usr/bin") / name
        if target.exists():
            link = bin_dir / name
            if not link.exists():
                link.symlink_to(target)


def _fake_sysfs(root, connectors):
    """Crea un sysfs DRM falso.

    connectors: {nombre: {status, vrr_capable?, modes?, edid_bytes?}}.
    """
    base = root / "sys" / "class" / "drm"
    for name, attrs in connectors.items():
        d = base / f"card0-{name}"
        d.mkdir(parents=True)
        (d / "status").write_text(attrs.get("status", "disconnected") + "\n", encoding="utf-8")
        if "vrr_capable" in attrs:
            (d / "vrr_capable").write_text(attrs["vrr_capable"] + "\n", encoding="utf-8")
        if "modes" in attrs:
            (d / "modes").write_text(attrs["modes"], encoding="utf-8")
        if "edid_bytes" in attrs:
            (d / "edid").write_bytes(attrs["edid_bytes"])
    return root


def _session_base_env(tmp_path, monkeypatch):
    """PATH sin gamescope/steam (los tests los anaden como falsos a elegir)."""
    bin_dir = tmp_path / "session-bin"
    _symlink_coreutils(bin_dir)
    monkeypatch.setenv("PATH", str(bin_dir))
    preset = tmp_path / "presets"
    preset.mkdir(exist_ok=True)
    for name in ("gamescope.conf", "mangohud.conf"):
        (preset / name).write_bytes((PKG / "files" / name).read_bytes())
    return bin_dir, preset


def _run_session(*args, env_extra=None):
    assert SESSION.is_file(), "falta files/nimbus-gaming-session"
    env = dict(os.environ)
    env.update(env_extra or {})
    return subprocess.run(
        ["bash", str(SESSION), *args], capture_output=True, text=True, timeout=60, env=env,
    )


def _run_vrr(env_extra=None):
    assert VRR_CHECK.is_file(), "falta files/gamescope-vrr-check"
    env = dict(os.environ)
    env.update(env_extra or {})
    return subprocess.run(
        ["bash", str(VRR_CHECK)], capture_output=True, text=True, timeout=60, env=env,
    )


def test_session_script_hygiene():
    assert SESSION.is_file(), "falta files/nimbus-gaming-session"
    assert os.access(SESSION, os.X_OK), "la sesion debe ser ejecutable"
    lines = SESSION.read_text(encoding="utf-8").splitlines()
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in lines[0]
    assert lines[1].startswith("#!"), "ejecutable con shebang"
    assert "set -euo pipefail" in SESSION.read_text(encoding="utf-8")
    code = "\n".join(
        line for line in lines if not line.strip().startswith("#")
    )
    assert not re.search(r"(^|[;\s&|])eval(\s|$|[;&])", code), "nada de eval"


def test_vrr_check_hygiene():
    assert VRR_CHECK.is_file(), "falta files/gamescope-vrr-check"
    assert os.access(VRR_CHECK, os.X_OK), "el check debe ser ejecutable"
    lines = VRR_CHECK.read_text(encoding="utf-8").splitlines()
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in lines[0]
    assert lines[1].startswith("#!"), "ejecutable con shebang"
    assert "set -euo pipefail" in VRR_CHECK.read_text(encoding="utf-8")


def test_desktop_entry_is_valid_and_points_at_session():
    import configparser

    assert DESKTOP.is_file(), "falta files/nimbus-gaming.desktop"
    parser = configparser.ConfigParser(interpolation=None)
    parser.read(DESKTOP, encoding="utf-8")
    assert parser.has_section("Desktop Entry"), "seccion [Desktop Entry] obligatoria"
    assert parser.get("Desktop Entry", "Name").strip(), "Name obligatorio"
    assert parser.get("Desktop Entry", "Type").strip() == "Application"
    assert parser.get("Desktop Entry", "Exec").strip() == REAL_SESSION_PATH, \
        "Exec debe ser la ruta real de la sesion, no un nombre suelto"


def test_pkgbuild_installs_session_files():
    text = _pkgbuild_text()
    assert "nimbus-gaming.desktop" in text, "package() debe instalar el .desktop"
    assert "wayland-sessions" in text, "el .desktop va a /usr/share/wayland-sessions/"
    assert "nimbus-gaming-session" in text, "package() debe instalar la sesion"
    assert "/usr/lib/nimbus" in text, "la sesion vive en /usr/lib/nimbus/"
    assert "gamescope-vrr-check" in text, "package() debe instalar el check de VRR"
    assert "usr/bin" in text, "el check vive en /usr/bin/"


def test_session_uses_real_preset_paths_by_default():
    text = SESSION.read_text(encoding="utf-8")
    assert REAL_PRESET_DIR in text, \
        f"el preset por defecto es {REAL_PRESET_DIR}, no una ruta inventada"
    assert "mangohud.conf" in text, "la sesion debe cablear el preset de MangoHud"
    assert "MANGOHUD_CONFIGFILE" in text, "el preset llega via MANGOHUD_CONFIGFILE"
    assert REAL_VRR_PATH in text, \
        f"el VRR se consulta en {REAL_VRR_PATH} (NIMBUS_VRR_CHECK para tests)"


def test_session_requires_gamescope_steam_and_gpu(tmp_path, monkeypatch):
    _, preset = _session_base_env(tmp_path, monkeypatch)
    dri = tmp_path / "dri"
    dri.mkdir()
    (dri / "card0").write_bytes(b"")
    env = {
        "NIMBUS_GAMING_PRESET_DIR": str(preset),
        "NIMBUS_DRI_DIR": str(dri),
    }
    proc = _run_session(env_extra=env)
    assert proc.returncode != 0, "sin gamescope/steam no puede arrancar la sesion"
    assert "gamescope" in (proc.stdout + proc.stderr).lower()


def test_session_requires_gpu(tmp_path, monkeypatch):
    bin_dir, preset = _session_base_env(tmp_path, monkeypatch)
    _write_executable(bin_dir / "gamescope", "#!/usr/bin/env bash\necho falso-gamescope\n")
    _write_executable(bin_dir / "steam", "#!/usr/bin/env bash\necho falso-steam\n")
    env = {
        "NIMBUS_GAMING_PRESET_DIR": str(preset),
        "NIMBUS_DRI_DIR": str(tmp_path / "dri-vacio"),
    }
    (tmp_path / "dri-vacio").mkdir()
    proc = _run_session(env_extra=env)
    assert proc.returncode != 0, "sin GPU no se arranca gamescope"
    assert "gpu" in (proc.stdout + proc.stderr).lower()


def test_session_applies_presets_in_dryrun(tmp_path, monkeypatch):
    bin_dir, preset = _session_base_env(tmp_path, monkeypatch)
    _write_executable(bin_dir / "gamescope", "#!/usr/bin/env bash\necho falso-gamescope\n")
    _write_executable(bin_dir / "steam", "#!/usr/bin/env bash\necho falso-steam\n")
    dri = tmp_path / "dri"
    dri.mkdir()
    (dri / "card0").write_bytes(b"")
    sysroot = _fake_sysfs(tmp_path / "sysroot", {"HDMI-A-1": {"status": "disconnected"}})
    env = {
        "NIMBUS_GAMING_PRESET_DIR": str(preset),
        "NIMBUS_DRI_DIR": str(dri),
        "NIMBUS_DRM_SYSFS": str(sysroot),
        "NIMBUS_VRR_CHECK": str(VRR_CHECK),
        "NIMBUS_GAMING_DRYRUN": "1",
    }
    proc = _run_session(env_extra=env)
    assert proc.returncode == 0, proc.stderr
    cmd = proc.stdout.strip()
    assert cmd.startswith("gamescope "), f"dryrun imprime el comando final: {cmd!r}"
    for flag in ("-W 2560", "-H 1440", "-f", "-F fsr", "-e", "--mangoapp", "--", "steam"):
        assert flag in cmd, f"el preset debe traducirse al flag {flag}: {cmd!r}"
    assert "--adaptive-sync" not in cmd, "VRR a ciegas jamas: panel sin VRR"
    assert "MANGOHUD_CONFIGFILE=" in proc.stderr or "MANGOHUD_CONFIGFILE=" in cmd \
        or f"{preset}/mangohud.conf" in (proc.stdout + proc.stderr), \
        "el preset de MangoHud debe llegar como MANGOHUD_CONFIGFILE"


def test_vrr_check_reports_supported_panel(tmp_path, monkeypatch):
    sysroot = _fake_sysfs(tmp_path / "sysroot", {
        "HDMI-A-1": {"status": "connected", "vrr_capable": "1",
                     "modes": "2560x1440\n1920x1080\n"},
    })
    bin_dir = tmp_path / "bin"
    _symlink_coreutils(bin_dir)
    monkeypatch.setenv("PATH", str(bin_dir))
    proc = _run_vrr(env_extra={"NIMBUS_DRM_SYSFS": str(sysroot)})
    assert proc.returncode == 0, proc.stderr
    assert "vrr: supported" in proc.stdout, proc.stdout
    assert "connector: HDMI-A-1" in proc.stdout, proc.stdout


def test_vrr_check_reports_unsupported_panel(tmp_path, monkeypatch):
    sysroot = _fake_sysfs(tmp_path / "sysroot", {
        "HDMI-A-1": {"status": "connected", "modes": "1920x1080\n"},
    })
    bin_dir = tmp_path / "bin"
    _symlink_coreutils(bin_dir)
    monkeypatch.setenv("PATH", str(bin_dir))
    proc = _run_vrr(env_extra={"NIMBUS_DRM_SYSFS": str(sysroot)})
    assert proc.returncode == 0, proc.stderr
    assert "vrr: unsupported" in proc.stdout, proc.stdout


def test_vrr_check_fails_without_connected_outputs(tmp_path, monkeypatch):
    sysroot = _fake_sysfs(tmp_path / "sysroot", {
        "HDMI-A-1": {"status": "disconnected"},
    })
    bin_dir = tmp_path / "bin"
    _symlink_coreutils(bin_dir)
    monkeypatch.setenv("PATH", str(bin_dir))
    proc = _run_vrr(env_extra={"NIMBUS_DRM_SYSFS": str(sysroot)})
    assert proc.returncode != 0, "sin salidas conectadas no hay nada que detectar"


def test_vrr_check_detects_rate_from_edid(tmp_path, monkeypatch):
    sysroot = _fake_sysfs(tmp_path / "sysroot", {
        "DP-1": {"status": "connected", "edid_bytes": b"\x00\xff\x01\x02"},
    })
    bin_dir = tmp_path / "bin"
    _symlink_coreutils(bin_dir)
    _write_executable(bin_dir / "edid-decode", (
        "#!/usr/bin/env bash\n"
        "cat <<'EOF'\n"
        "Display Range Limits:\n"
        "  Monitor ranges (GTF): 48-144 Hz V, 30-160 kHz H\n"
        "Adaptive Sync Data Block:\n"
        "    VRRmin: 48 Hz\n"
        "    VRRmax: 144 Hz\n"
        "EOF\n"
    ))
    monkeypatch.setenv("PATH", str(bin_dir))
    proc = _run_vrr(env_extra={"NIMBUS_DRM_SYSFS": str(sysroot)})
    assert proc.returncode == 0, proc.stderr
    assert "vrr: supported" in proc.stdout, proc.stdout
    assert "rate: 144" in proc.stdout, proc.stdout


def test_session_enables_vrr_only_on_positive_detection(tmp_path, monkeypatch):
    bin_dir, preset = _session_base_env(tmp_path, monkeypatch)
    _write_executable(bin_dir / "gamescope", "#!/usr/bin/env bash\necho falso-gamescope\n")
    _write_executable(bin_dir / "steam", "#!/usr/bin/env bash\necho falso-steam\n")
    dri = tmp_path / "dri"
    dri.mkdir()
    (dri / "card0").write_bytes(b"")

    ok_root = _fake_sysfs(tmp_path / "ok", {
        "HDMI-A-1": {"status": "connected", "vrr_capable": "1", "modes": "2560x1440\n"},
    })
    env = {
        "NIMBUS_GAMING_PRESET_DIR": str(preset),
        "NIMBUS_DRI_DIR": str(dri),
        "NIMBUS_DRM_SYSFS": str(ok_root),
        "NIMBUS_VRR_CHECK": str(VRR_CHECK),
        "NIMBUS_GAMING_DRYRUN": "1",
        "PATH": str(bin_dir) + os.pathsep + "/usr/bin:/bin",
    }
    proc = _run_session(env_extra=env)
    assert proc.returncode == 0, proc.stderr
    assert "--adaptive-sync" in proc.stdout, \
        f"panel con VRR: la sesion lo activa: {proc.stdout!r}"


def test_session_never_deprioritizes_anything():
    text = SESSION.read_text(encoding="utf-8")
    code = "\n".join(
        line for line in text.splitlines() if not line.strip().startswith("#")
    )
    for tool in ("nice", "renice", "ionice", "chrt", "taskset", "schedtool"):
        assert not re.search(r"(^|[;\s&|])%s(\s|$|[;&])" % tool, code), \
            f"la sesion no toca prioridades ({tool})"


def test_ananicy_rules_still_never_deprioritize_games_or_audio():
    import json

    never = ("steam", "gamescope", "proton", "wine",
             "pipewire", "pulseaudio", "wireplumber", "jackd")
    rules_path = ROOT / "packages" / "nimbus-energy" / "files" / "ananicy" / "ananicy.d" / "50-nimbus-gaming.rules"
    rules = [json.loads(line) for line in rules_path.read_text(encoding="utf-8").splitlines()
             if line.strip()]
    assert rules, "el fichero de reglas no puede estar vacio"
    for rule in rules:
        name = str(rule.get("name", "")).lower()
        for forbidden in never:
            if forbidden in name:
                assert rule.get("nice", 0) <= 0, f"la regla de '{name}' no puede bajar prioridad"

