# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests del bootloader con rollback de un clic y de nimbus-snapshots.

El entorno de pruebas no tiene Btrfs real ni snapper (ni root): toda la
logica recibe la raiz y un "proveedor de snapshots" inyectable, y los
tests usan un proveedor falso o un tmp_path. Nada toca el sistema.
"""

import ast
import importlib.util
import pathlib
import subprocess
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODULE_PATH = (
    ROOT / "installer" / "calamares" / "modules" / "nimbus-bootloader"
    / "nimbus-bootloader.py"
)
TOOL_PATH = ROOT / "installer" / "tools" / "nimbus-snapshots"
I18N_PATH = ROOT / "installer" / "calamares" / "nimbus_i18n.py"


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def bl():
    return _load("nimbus_bootloader_under_test", MODULE_PATH)


@pytest.fixture(scope="module")
def i18n(bl):
    # El modulo registra sus claves en el nimbus_i18n que importa
    # (sys.modules["nimbus_i18n"]): hay que leer ese mismo objeto,
    # no una copia fresca del fichero, o las claves no aparecen.
    import sys as _sys

    return _sys.modules.get("nimbus_i18n")


def _fake_provider(names):
    def _provider(root=None):
        return list(names)
    return _provider


# --- eleccion de bootloader --------------------------------------------------


def test_grub_when_windows_is_present(bl):
    assert bl.choose_bootloader(True) == "grub"
    assert bl.choose_bootloader(has_windows=True) == "grub"


def test_systemd_boot_when_disk_is_nimbus_only(bl):
    assert bl.choose_bootloader(False) == "systemd-boot"
    assert bl.choose_bootloader(has_windows=False) == "systemd-boot"


def test_detect_windows_parses_os_prober_output(bl):
    assert bl.detect_windows("Windows Boot Manager on /dev/sda1") is True
    assert bl.detect_windows("/dev/sda1:Windows 11:Windows:chain") is True
    assert bl.detect_windows("/dev/sda2:Linux:Nimbus:linux") is False
    assert bl.detect_windows("") is False
    assert bl.detect_windows(None, runner=lambda *a, **k: None) is False


def test_detect_windows_uses_injected_runner_without_touching_system(bl):
    class _Out:
        stdout = "/dev/sda1:Windows Boot Manager:Windows:chain\n"

    def _runner(cmd, **kwargs):
        assert isinstance(cmd, list)
        assert cmd == ["os-prober"]
        return _Out()

    assert bl.detect_windows(runner=_runner) is True

    def _empty(cmd, **kwargs):
        assert isinstance(cmd, list)
        return type("O", (), {"stdout": ""})()

    assert bl.detect_windows(runner=_empty) is False


# --- menu de rollback --------------------------------------------------------


def test_menu_offers_last_good_and_safe_mode(bl):
    entries = bl.build_boot_entries(
        filesystem="btrfs",
        root="/tmp/fake-root",
        snapshot_provider=_fake_provider(["2026-10-01_00-00-01"]),
        locale="es",
    )
    titles = [e["title"] for e in entries]
    assert any("última versión conocida buena" in t for t in titles)
    assert any("modo seguro" in t for t in titles)


def test_menu_entries_are_translated_es_en(bl):
    es = bl.build_boot_entries(
        filesystem="btrfs",
        root="/tmp/fake-root",
        snapshot_provider=_fake_provider(["s1"]),
        locale="es",
    )
    en = bl.build_boot_entries(
        filesystem="btrfs",
        root="/tmp/fake-root",
        snapshot_provider=_fake_provider(["s1"]),
        locale="en",
    )
    es_titles = [e["title"] for e in es]
    en_titles = [e["title"] for e in en]
    assert any("última versión conocida buena" in t for t in es_titles)
    assert any("last known good" in t.lower() for t in en_titles)
    assert any("modo seguro" in t for t in es_titles)
    assert any("safe mode" in t.lower() for t in en_titles)
    assert es_titles != en_titles


def test_btrfs_entries_include_normal_plus_two_rollback(bl):
    entries = bl.build_boot_entries(
        filesystem="btrfs",
        root="/tmp/fake-root",
        snapshot_provider=_fake_provider(["snap1"]),
        locale="en",
    )
    assert len(entries) >= 3
    kinds = {e["kind"] for e in entries}
    assert {"normal", "last-good", "safe"} <= kinds


def test_snapshot_provider_is_injectable_and_no_system_touched(bl, tmp_path):
    seen = []

    def _provider(root=None):
        seen.append(str(root))
        return ["snap-a", "snap-b"]

    entries = bl.build_boot_entries(
        filesystem="btrfs",
        root=str(tmp_path),
        snapshot_provider=_provider,
        locale="es",
    )
    assert seen == [str(tmp_path)]
    assert any("snap-b" in (e.get("snapshot") or "") for e in entries)
    # El tmp_path sigue vacio: el proveedor falso no toca el sistema.
    assert list(tmp_path.iterdir()) == []


# --- disco no-Btrfs: sin rollback, con LTS ------------------------------------


def test_non_btrfs_has_no_rollback_entries(bl):
    for fs in ("ext4", "xfs", "EXT4", "XFS"):
        entries = bl.build_boot_entries(
            filesystem=fs,
            root="/tmp/fake-root",
            snapshot_provider=_fake_provider(["snap1"]),
            locale="es",
        )
        titles = " ".join(e["title"] for e in entries)
        assert "conocida buena" not in titles
        assert "modo seguro" not in titles
        kinds = {e["kind"] for e in entries}
        assert "last-good" not in kinds
        assert "safe" not in kinds


def test_non_btrfs_adds_lts_kernel(bl, tmp_path):
    plan = bl.plan_install(
        root=str(tmp_path),
        filesystem="ext4",
        has_windows=False,
        snapshot_provider=_fake_provider(["snap1"]),
        locale="es",
    )
    assert bl.LTS_KERNEL in plan["extra_packages"]
    assert "rollback" in plan["summary"].lower() or "lts" in plan["summary"].lower()


def test_non_btrfs_summary_mentions_lts_in_both_locales(bl, tmp_path):
    for locale in ("es", "en"):
        plan = bl.plan_install(
            root=str(tmp_path),
            filesystem="xfs",
            has_windows=False,
            snapshot_provider=_fake_provider([]),
            locale=locale,
        )
        assert bl.LTS_KERNEL in plan["summary"]
        assert bl.LTS_KERNEL in plan["extra_packages"]
        assert plan["rollback"] is False


def test_btrfs_plan_enables_rollback_without_lts(bl, tmp_path):
    plan = bl.plan_install(
        root=str(tmp_path),
        filesystem="btrfs",
        has_windows=False,
        snapshot_provider=_fake_provider(["snap1"]),
        locale="es",
    )
    assert plan["rollback"] is True
    assert plan["extra_packages"] == []
    assert plan["bootloader"] == "systemd-boot"


def test_windows_multiboot_selects_grub_with_rollback_submenu(bl, tmp_path):
    plan = bl.plan_install(
        root=str(tmp_path),
        filesystem="btrfs",
        has_windows=True,
        snapshot_provider=_fake_provider(["snap1"]),
        locale="es",
    )
    assert plan["bootloader"] == "grub"
    assert plan["rollback"] is True


def test_pretty_strings_come_from_translated_table(bl, i18n):
    assert bl.pretty_name("es") == i18n.TRANSLATIONS["es"]["bootloader.pretty_name"]
    assert bl.pretty_name("en") == i18n.TRANSLATIONS["en"]["bootloader.pretty_name"]
    assert bl.pretty_status_message("es") == i18n.TRANSLATIONS["es"]["bootloader.pretty_status"]
    assert bl.pretty_status_message("en") == i18n.TRANSLATIONS["en"]["bootloader.pretty_status"]
    assert bl.pretty_name("es") != bl.pretty_name("en")


def test_grub_submenu_header_is_translated(bl, tmp_path):
    es_root = tmp_path / "es"
    plan_es = bl.configure_bootloader(
        root=str(es_root),
        filesystem="btrfs",
        has_windows=True,
        snapshot_provider=_fake_provider(["snap1"]),
        locale="es",
    )
    custom = (es_root / "boot" / "grub" / "custom.cfg").read_text(
        encoding="utf-8")
    assert "rollback en un clic" in custom

    en_root = tmp_path / "en"
    plan_en = bl.configure_bootloader(
        root=str(en_root),
        filesystem="btrfs",
        has_windows=True,
        snapshot_provider=_fake_provider(["snap1"]),
        locale="en",
    )
    custom_en = (en_root / "boot" / "grub" / "custom.cfg").read_text(
        encoding="utf-8")
    assert "one-click rollback" in custom_en
    assert custom != custom_en
    assert plan_es["grub_snapshot_submenu"] is True
    assert plan_en["grub_snapshot_submenu"] is True


def test_configure_writes_entries_under_given_root_only(bl, tmp_path):
    plan = bl.configure_bootloader(
        root=str(tmp_path),
        filesystem="btrfs",
        has_windows=False,
        snapshot_provider=_fake_provider(["snap1"]),
        locale="es",
    )
    assert plan["rollback"] is True
    # Todo queda bajo tmp_path: nada se escribe fuera.
    written = [p for p in tmp_path.rglob("*") if p.is_file()]
    assert written, "deberia escribir entradas bajo root"
    blob = " ".join(p.read_text(encoding="utf-8") for p in written)
    assert "ltima versi" in blob or "last known good" in blob.lower() or "snap1" in blob


# --- nimbus-snapshots CLI ------------------------------------------------------


def _run_tool(*args):
    return subprocess.run(
        [sys.executable, str(TOOL_PATH), *args],
        capture_output=True, text=True, timeout=30,
    )


def test_snapshots_setup_is_idempotent(tmp_path):
    first = _run_tool("setup", str(tmp_path))
    assert first.returncode == 0, first.stdout + first.stderr
    before = sorted(p.name for p in tmp_path.rglob("*"))
    second = _run_tool("setup", str(tmp_path))
    assert second.returncode == 0, second.stdout + second.stderr
    after = sorted(p.name for p in tmp_path.rglob("*"))
    assert before == after


def test_snapshots_list_and_last_good(tmp_path):
    assert _run_tool("setup", str(tmp_path)).returncode == 0
    snapdir = tmp_path / ".snapshots"
    for name in ("2026-10-01_00-00-01", "2026-10-02_00-00-01"):
        (snapdir / name).mkdir(parents=True, exist_ok=True)
    listed = _run_tool("list", str(tmp_path))
    assert listed.returncode == 0, listed.stdout + listed.stderr
    assert "2026-10-01_00-00-01" in listed.stdout
    assert "2026-10-02_00-00-01" in listed.stdout
    last = _run_tool("last-good", str(tmp_path))
    assert last.returncode == 0, last.stdout + last.stderr
    assert "2026-10-02_00-00-01" in last.stdout


def test_snapshots_cleanup_keeps_exactly_n_most_recent(tmp_path):
    assert _run_tool("setup", str(tmp_path)).returncode == 0
    snapdir = tmp_path / ".snapshots"
    names = [f"2026-10-0{d}_00-00-01" for d in range(1, 6)]
    for name in names:
        (snapdir / name).mkdir(parents=True, exist_ok=True)
    result = _run_tool("cleanup", str(tmp_path), "2")
    assert result.returncode == 0, result.stdout + result.stderr
    remaining = sorted(p.name for p in snapdir.iterdir() if p.is_dir())
    assert remaining == names[-2:]


def test_snapshots_tool_uses_list_form_subprocess():
    source = TOOL_PATH.read_text(encoding="utf-8")
    assert "shell=True" not in source
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            func = node.func
            name = ""
            if isinstance(func, ast.Attribute):
                name = func.attr
            elif isinstance(func, ast.Name):
                name = func.id
            if name in ("run", "call", "check_call", "check_output", "Popen"):
                for kw in node.keywords:
                    if kw.arg == "shell":
                        assert not (
                            isinstance(kw.value, ast.Constant)
                            and kw.value.value is True
                        ), "nada de shell=True"


def test_bootloader_module_uses_list_form_subprocess(bl):
    source = MODULE_PATH.read_text(encoding="utf-8")
    assert "shell=True" not in source
