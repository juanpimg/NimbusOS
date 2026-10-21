# SPDX-License-Identifier: GPL-3.0-or-later
import configparser
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
CALAMARES = ROOT / "installer" / "calamares"
SETTINGS = CALAMARES / "settings.conf"

EXPECTED_SEQUENCE = [
    "welcome",
    "locale",
    "partition",
    "lukspass",
    "users",
    "nimbus-appearance",
    "nimbus-software",
    "hardware",
    "bootloader",
    "finished",
]

EXPECTED_PROFILES = {"base", "gaming", "creative", "development", "communication", "office"}


def _sequence():
    parser = configparser.ConfigParser()
    parser.read(SETTINGS, encoding="utf-8")
    return [
        line.strip()
        for line in parser["sequence"]["modules"].strip().splitlines()
        if line.strip()
    ]


def test_settings_conf_exists():
    assert SETTINGS.is_file()


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
