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


def test_gamescope_preset_declares_manual_use():
    """gamescope.conf: preset de referencia inactivo; nadie lo auto-aplica."""
    assert GAMESCOPE.is_file(), "falta files/gamescope.conf"
    text = GAMESCOPE.read_text(encoding="utf-8")
    lowered = text.lower()
    assert any(word in lowered for word in ("inactivo", "inactive", "referencia", "reference", "manual")), \
        "debe documentar que se distribuye inactivo, sin auto-activacion"
    for claim in ("se activa solo", "al detectar", "auto-activ", "automáticament se act"):
        assert claim not in lowered, \
            f"afirmacion de activacion automatica sin consumidor: {claim!r}"

