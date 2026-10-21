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


BUILD_SH = ROOT / "iso" / "build.sh"


def test_build_uses_pkgdest_and_not_packagelist():
    text = BUILD_SH.read_text(encoding="utf-8")
    assert 'PKGDEST="$REPO_DIR" makepkg' in text
    assert "--packagelist" not in text


def test_build_indexes_repo_with_valid_db_extension():
    text = BUILD_SH.read_text(encoding="utf-8")
    assert "repo-add" in text
    assert "nimbus.db.tar.gz" in text


def test_build_fails_loudly_when_no_package_was_built():
    text = BUILD_SH.read_text(encoding="utf-8")
    assert 'compgen -G "$REPO_DIR/*.pkg.tar.*"' in text
    assert "no se ha construido ningun paquete" in text
    assert "build-*.log" in text


def test_build_checks_required_binaries():
    text = BUILD_SH.read_text(encoding="utf-8")
    assert "command -v archiso" in text
    assert "command -v makepkg" in text
    assert "command -v repo-add" in text


def test_local_repo_is_a_flag_without_argument():
    text = BUILD_SH.read_text(encoding="utf-8")
    assert "--local-repo) LOCAL_REPO=1; shift ;;" in text
    assert "--local-repo) LOCAL_REPO=\"$2\"" not in text
    assert 'if [ "$LOCAL_REPO" -eq 1 ]' in text
