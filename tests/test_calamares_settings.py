# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
import pathlib
import sys

import pytest
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
CALAMARES = ROOT / "installer" / "calamares"
SETTINGS = CALAMARES / "settings.conf"
VERIFY_PY = CALAMARES / "modules" / "nimbus-verify" / "nimbus-verify.py"


def _load_verify():
    spec = importlib.util.spec_from_file_location(
        "nimbus_verify_settings_under_test", VERIFY_PY)
    module = importlib.util.module_from_spec(spec)
    sys.modules.setdefault("nimbus_verify_settings_under_test", module)
    spec.loader.exec_module(module)
    return module


vv = _load_verify()

EXPECTED_SEQUENCE = [
    "welcome",
    "locale",
    # nimbus-dualboot copia la tabla de particiones y detecta Fast Boot:
    # tiene que ejecutarse ANTES de que Calamares toque el disco.
    "nimbus-dualboot",
    "partition",
    "lukspass",
    "users",
    "nimbus-appearance",
    "nimbus-software",
    "hardware",
    "bootloader",
    # nimbus-bootloader anade las entradas de rollback al menu de arranque.
    "nimbus-bootloader",
    "nimbus-postinstall",
    "nimbus-verify",
    "finished",
]

EXPECTED_PROFILES = {"base", "gaming", "creative", "development", "communication", "office"}


def _settings():
    """Calamares lee este fichero con un parser YAML, no con INI."""
    return yaml.safe_load(SETTINGS.read_text(encoding="utf-8"))


def _sequence():
    return [step["module"] for step in _settings()["sequence"]]


def test_settings_conf_exists():
    assert SETTINGS.is_file()


def test_settings_conf_is_valid_yaml_for_calamares():
    # Calamares::Settings usa YAML::LoadFile: un settings.conf en INI (o en
    # YAML invalido) hace que el instalador NO ARRANQUE. Esta es la guarda que
    # faltaba cuando el fichero estaba en formato INI.
    data = yaml.safe_load(SETTINGS.read_text(encoding="utf-8"))
    assert isinstance(data, dict)
    for key in ("sequence", "general", "locale", "partition", "users"):
        assert key in data, f"falta la seccion {key}"
    assert isinstance(data["sequence"], list)
    for step in data["sequence"]:
        assert "module" in step, step


def test_module_sequence_is_the_expected_one():
    assert _sequence() == EXPECTED_SEQUENCE


NIMBUS_OWNED_MODULES = {"nimbus-appearance", "nimbus-software", "nimbus-verify"}


def test_every_nimbus_module_has_a_conf_file():
    # welcome, locale, partition, lukspass, users, hardware, bootloader y finished
    # son modulos de Calamares upstream: los aporta el paquete cachyos-calamares-next,
    # no este repositorio. Solo exigimos los que son propiedad de Nimbus.
    missing = [
        name
        for name in _sequence()
        if name in NIMBUS_OWNED_MODULES
        and not (CALAMARES / "modules" / name / f"{name}.conf").is_file()
    ]
    assert missing == []


def test_nimbus_module_dirs_match_sequence_exactly():
    """Todo modulo nimbus-* con directorio debe estar en la secuencia.

    Si alguien crea un modulo nuevo y no lo enchufa, este test falla.
    El fichero compartido de traducciones (nimbus_i18n.py) vive fuera de
    modules/ a proposito para no romper esta correspondencia.
    """
    dirs = {p.name for p in (CALAMARES / "modules").glob("nimbus-*")
            if p.is_dir()}
    in_sequence = {name for name in _sequence() if name.startswith("nimbus-")}
    assert dirs == in_sequence, (
        f"directorios sin secuencia: {sorted(dirs - in_sequence)}; "
        f"en secuencia sin directorio: {sorted(in_sequence - dirs)}"
    )


def test_nimbus_verify_runs_between_bootloader_and_finished():
    seq = _sequence()
    assert seq.index("bootloader") < seq.index("nimbus-verify") < seq.index("finished")


def test_software_profiles_are_complete():
    conf = CALAMARES / "modules" / "nimbus-software" / "nimbus-software.conf"
    text = conf.read_text(encoding="utf-8")
    for profile in EXPECTED_PROFILES:
        assert profile in text, f"falta el perfil {profile}"


def test_gaming_profile_contains_the_stack():
    conf = CALAMARES / "modules" / "nimbus-software" / "nimbus-software.conf"
    text = conf.read_text(encoding="utf-8")
    for package in ["steam", "proton-ge", "gamescope", "mangohud", "heroic"]:
        assert package in text, f"falta {package} en el perfil gaming"


def test_verify_module_runs_at_least_eight_checks():
    source = CALAMARES / "modules" / "nimbus-verify" / "nimbus-verify.py"
    text = source.read_text(encoding="utf-8")
    # Se cuentan las funciones check_*, no las llamadas a check( del decorador.
    assert text.count("def check_") >= 8


def test_installer_requires_connectivity_step():
    source = CALAMARES / "modules" / "nimbus-software" / "nimbus-software.py"
    text = source.read_text(encoding="utf-8")
    assert "connectivity" in text.lower()


# --- D2: Btrfs por defecto + subvolumenes del contrato de rollback ----------


def _partition_section():
    return _settings()["partition"]


def test_default_filesystem_is_btrfs():
    """D2: el spec (D6, §4.4) exige Btrfs; sin el no hay rollback (§9.7)."""
    assert _partition_section()["defaultFileSystemType"].strip() == "btrfs"


def test_btrfs_is_offered_first():
    """D2: Btrfs abre la lista de sistemas de ficheros ofertados."""
    offered = _partition_section()["availableFileSystemTypes"]
    assert isinstance(offered, list), "en YAML la lista es una lista, no un texto"
    assert offered[0] == "btrfs"
    assert "ext4" in offered  # sigue disponible, con aviso (sin rollback)


def test_partition_section_documents_subvolume_layout():
    """D2: el layout @ / @home / @snapshots queda escrito en settings.conf
    (contrato con nimbus-bootloader y nimbus-snapshots)."""
    text = SETTINGS.read_text(encoding="utf-8")
    for subvol in ("@", "@home", "@snapshots"):
        assert subvol in text, f"falta el subvolumen {subvol}"


# --- nimbus-verify: las 14 comprobaciones honestas (M2 tarea 5) ---------------

EXPECTED_VERIFY_CHECKS = [
    "gpu",
    "graphics-hybrid",
    "audio",
    "network",
    "bluetooth",
    "webcam",
    "suspend",
    "battery",
    "disk-space",
    "bootloader",
    "dual-boot",
    "snapshots",
    "updates",
    "keyring",
    # D3: filas de la matriz §4.13 sin comprobacion (CPU, GPU por marca,
    # NVIDIA, WiFi por chip, codecs, impresoras, portatil).
    "cpu",
    "video-amd",
    "video-intel",
    "nvidia",
    "wifi",
    "codecs",
    "printers",
    "laptop",
]

OPTIONAL_CHECKS = {"bluetooth", "webcam", "battery", "dual-boot", "snapshots",
                   "wifi", "video-amd", "video-intel", "nvidia", "laptop"}


def _check(name):
    return dict(vv.CHECKS)[name]


def test_verify_checks_are_exactly_the_fourteen_expected():
    assert [name for name, _ in vv.CHECKS] == EXPECTED_VERIFY_CHECKS


def test_every_check_returns_bool_str_and_never_raises():
    for name, fn in vv.CHECKS:
        ok, message = fn("en")
        assert isinstance(ok, bool), name
        assert isinstance(message, str) and message, name


def test_verify_module_uses_no_shell_true():
    assert "shell=True" not in VERIFY_PY.read_text(encoding="utf-8")


@pytest.mark.parametrize("name", sorted(OPTIONAL_CHECKS))
def test_optional_hardware_absent_skips_true(name):
    absent_env = {
        "bluetooth": {"has_hardware": False},
        "webcam": {"video_devices": []},
        "battery": {"has_battery": False},
        "dual-boot": {"windows_present": False, "other_systems": []},
        "snapshots": {"is_btrfs": False},
        "wifi": {"wireless": {}},
        "video-amd": {"vendors": []},
        "video-intel": {"vendors": []},
        "nvidia": {"has_nvidia": False},
        "laptop": {"chassis_type": 3},
    }[name]
    ok, message = _check(name)("es", **absent_env)
    assert ok is True
    assert isinstance(message, str) and message


@pytest.mark.parametrize("name", ["bluetooth", "battery", "snapshots",
                                   "wifi", "video-amd", "video-intel",
                                   "nvidia", "laptop"])
def test_optional_absent_message_says_skipped(name):
    absent_env = {
        "bluetooth": {"has_hardware": False},
        "battery": {"has_battery": False},
        "snapshots": {"is_btrfs": False},
        "wifi": {"wireless": {}},
        "video-amd": {"vendors": []},
        "video-intel": {"vendors": []},
        "nvidia": {"has_nvidia": False},
        "laptop": {"chassis_type": 3},
    }[name]
    _, message_es = _check(name)("es", **absent_env)
    _, message_en = _check(name)("en", **absent_env)
    assert "Omitido" in message_es, message_es
    assert "Skipped" in message_en, message_en


def test_broken_matrix_is_false_with_actionable_message():
    broken = {
        "gpu": ({"dri_nodes": []}, "GPU"),
        "graphics-hybrid": (
            {"gpus": ["card0", "card1"], "prime_mode": "performance"},
            "on-demand"),
        "audio": ({"output_devices": [], "pipewire_active": False}, "PipeWire"),
        "network": ({"interfaces": {"eth0": "down"}}, "red"),
        "bluetooth": (
            {"has_hardware": True, "service_active": False}, "bluetooth"),
        "webcam": (
            {"video_devices": ["video0"], "accessible": False}, "video0"),
        "suspend": (
            {"sleep_modes": "mem", "s2idle_available": False},
            "s2idle"),
        "battery": (
            {"has_battery": True, "capacity": None,
             "charge_limit_applied": True}, "bater"),
        "disk-space": ({"free_gib": 0.1}, "ibera"),
        "bootloader": (
            {"efi_system": False, "grub_config": False,
             "systemd_entries": []}, "gestor"),
        "dual-boot": (
            {"windows_present": True, "efi_shared": False,
             "grub_installed": True, "other_systems": ["Windows"]}, "EFI"),
        "snapshots": ({"is_btrfs": True, "snapshots": []}, "snapshot"),
        "updates": (
            {"repo_configured": False, "key_trusted": False}, "nimbus"),
        "keyring": (
            {"populated": False, "key_imported": False}, "populate"),
        "cpu": ({"cpuinfo_text": "processor : 0\nflags : fpu sse sse2\n"},
                "mínimo"),
        "video-amd": ({"vendors": ["0x1002"], "radv_present": False},
                      "RADV"),
        "video-intel": ({"vendors": ["0x8086"], "anvil_present": False,
                         "media_driver_present": True}, "anvil"),
        "nvidia": ({"has_nvidia": True, "driver": None}, "nvidia"),
        "wifi": ({"wireless": {"wlan0": "rtl8821ce"}}, "controlador"),
        "codecs": ({"ffmpeg": False, "encoders": ""}, "ffmpeg"),
        "printers": ({"cups": True, "ipp_usb": False}, "ipp-usb"),
        "laptop": ({"chassis_type": 9, "backlight": [],
                    "lid_present": True}, "brillo"),
    }
    assert set(broken) == set(EXPECTED_VERIFY_CHECKS)
    for name, (env, hint) in broken.items():
        ok, message = _check(name)("es", **env)
        assert ok is False, name
        assert hint.lower() in message.lower(), f"{name}: {message!r}"


def test_healthy_matrix_is_true():
    healthy = {
        "gpu": {"dri_nodes": ["renderD128"], "driver": "amdgpu"},
        "graphics-hybrid": {"gpus": ["card0"], "prime_mode": None},
        "audio": {"output_devices": ["card0"], "pipewire_active": True},
        "network": {"interfaces": {"eth0": "up"}},
        "bluetooth": {"has_hardware": True, "service_active": True},
        "webcam": {"video_devices": ["video0"], "accessible": True},
        "suspend": {"sleep_modes": "mem", "s2idle_available": True},
        "battery": {"has_battery": True, "capacity": 55,
                    "charge_limit_applied": True},
        "disk-space": {"free_gib": 50.0},
        "bootloader": {"efi_system": True, "efi_entries": ["BOOTX64.EFI"]},
        "dual-boot": {"windows_present": True, "efi_shared": True,
                      "grub_installed": True,
                      "other_systems": ["Windows Boot Manager"]},
        "snapshots": {"is_btrfs": True, "snapshots": ["post-instalacion"]},
        "updates": {"repo_configured": True, "key_trusted": True},
        "keyring": {"populated": True, "key_imported": True},
        "cpu": {"cpuinfo_text": "processor : 0\n"
                "flags : fpu sse sse2 ssse3 sse4_1 sse4_2 avx avx2\n"},
        "video-amd": {"vendors": ["0x1002"], "radv_present": True},
        "video-intel": {"vendors": ["0x8086"], "anvil_present": True,
                        "media_driver_present": True},
        "nvidia": {"has_nvidia": True, "driver": "nvidia"},
        "wifi": {"wireless": {"wlan0": "iwlwifi"}},
        "codecs": {"ffmpeg": "/usr/bin/ffmpeg",
                   "encoders": " V..... libx264\n A..... aac\n"},
        "printers": {"cups": True, "ipp_usb": True},
        "laptop": {"chassis_type": 9, "backlight": ["intel_backlight"],
                   "lid_present": True},
    }
    assert set(healthy) == set(EXPECTED_VERIFY_CHECKS)
    for name, env in healthy.items():
        ok, message = _check(name)("es", **env)
        assert ok is True, f"{name}: {message!r}"


def test_raising_check_does_not_stop_the_others():
    def boom(locale=None):
        raise RuntimeError("boom")

    original = list(vv.CHECKS)
    vv.CHECKS[:] = [("boom", boom)] + original
    try:
        results = vv.run_all_checks("es")
    finally:
        vv.CHECKS[:] = original
    assert len(results) == len(original) + 1
    assert results[0][0] == "boom"
    assert results[0][1] is False
    assert [name for name, _, _ in results[1:]] == EXPECTED_VERIFY_CHECKS
