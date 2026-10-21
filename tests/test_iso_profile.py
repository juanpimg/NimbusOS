# SPDX-License-Identifier: GPL-3.0-or-later
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROFILE = ROOT / "iso" / "profiles" / "nimbus"

REQUIRED_FILES = [
    "airoot.sh",
    "packages.x86_64",
    "customize.sh",
    "file-contexts.sh",
]

REQUIRED_PACKAGES = [
    "linux-cachyos",
    "hyprland",
    "quickshell",
    "nimbus-shell",
    "nimbus-dots",
    "sddm",
    "systemd",
    "xdg-desktop-portal-hyprland",
]


def test_required_profile_files_exist():
    missing = [name for name in REQUIRED_FILES if not (PROFILE / name).is_file()]
    assert missing == []


def test_profile_lists_required_packages():
    text = (PROFILE / "packages.x86_64").read_text(encoding="utf-8")
    packages = {line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")}
    missing = [p for p in REQUIRED_PACKAGES if p not in packages]
    assert missing == []


def test_customize_installs_the_nimbus_repo():
    text = (PROFILE / "customize.sh").read_text(encoding="utf-8")
    assert "nimbus" in text
    assert "nimbus-keyring" in text


def test_live_ready_marker_unit_exists_and_prints_marker():
    unit = PROFILE / "overlay" / "usr" / "lib" / "systemd" / "system" / "nimbus-live-ready.service"
    assert unit.is_file()
    text = unit.read_text(encoding="utf-8")
    assert "NIMBUS_LIVE_READY" in text
    assert "/dev/console" in text


def test_live_service_starts_the_shell_and_is_required_by_the_marker():
    live = PROFILE / "overlay" / "usr" / "lib" / "systemd" / "system" / "nimbus-live.service"
    ready = PROFILE / "overlay" / "usr" / "lib" / "systemd" / "system" / "nimbus-live-ready.service"
    assert live.is_file()
    assert "nimbus-shell" in live.read_text(encoding="utf-8")
    # El marcador no debe aparecer si el shell no arrancó: Requires= lo garantiza.
    assert "Requires=nimbus-live.service" in ready.read_text(encoding="utf-8")


def test_iso_is_smaller_than_3gb_budget():
    budget = 3 * 1024 * 1024 * 1024
    iso_dir = ROOT / "iso"
    for iso in iso_dir.glob("*.iso"):
        assert iso.stat().st_size < budget, f"{iso.name} excede el presupuesto de 3 GB"
