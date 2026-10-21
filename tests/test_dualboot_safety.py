# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests de seguridad del arranque dual con Windows (Nimbus M2).

Sin tocar discos reales: todo opera sobre ficheros temporales con
tablas de particiones falsas y entradas EFI simuladas.

Cubre el contrato de ``installer/tools/nimbus-partitionsafe`` y del
modulo Calamares ``nimbus-dualboot``:

- ``backup`` crea respaldo + checksum.
- ``verify`` sale con 0 si no cambio y con 1 si cambio.
- ``verify`` detecta el cambio grave: distinto numero de particiones.
- El modulo bloquea (estado de error) con Fast Boot activo.
- El modulo reutiliza la EFI existente y no propone crear otra.
"""

import importlib.machinery
import importlib.util
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
PARTITIONSAFE_PATH = ROOT / "installer" / "tools" / "nimbus-partitionsafe"
DUALBOOT_PATH = (
    ROOT / "installer" / "calamares" / "modules"
    / "nimbus-dualboot" / "nimbus-dualboot.py"
)
I18N_PATH = ROOT / "installer" / "calamares" / "nimbus_i18n.py"


def _load_i18n():
    spec = importlib.util.spec_from_file_location("nimbus_i18n", I18N_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules.setdefault("nimbus_i18n", module)
    # Recargar para que los tests vean la tabla real del arbol.
    spec.loader.exec_module(sys.modules["nimbus_i18n"])
    return sys.modules["nimbus_i18n"]


def _load_partitionsafe():
    loader = importlib.machinery.SourceFileLoader(
        "nimbus_partitionsafe_under_test", str(PARTITIONSAFE_PATH))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def _load_dualboot():
    spec = importlib.util.spec_from_file_location(
        "nimbus_dualboot_under_test", DUALBOOT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


i18n = _load_i18n()

FAKE_DUMP_SDA = """\
label: gpt
device: /dev/sda
unit: sectors
first-lba: 34
last-lba: 209715166

/dev/sda1 : start=2048, size=1024000, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=AAAA, name="EFI"
/dev/sda2 : start=1026048, size=52428800, type=EBD0A0A2-B741-E11C-A8EB-00A0C93EC93B, uuid=BBBB, name="Windows"
/dev/sda3 : start=53454848, size=52428800, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=CCCC, name="Nimbus"
"""

FAKE_DUMP_SDA_CHANGED_SIZE = FAKE_DUMP_SDA.replace(
    "size=52428800, type=EBD0A0A2", "size=52428801, type=EBD0A0A2")

FAKE_DUMP_SDA_EXTRA_PARTITION = FAKE_DUMP_SDA + (
    '/dev/sda4 : start=105883648, size=1048576, '
    'type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=DDDD, name="Extra"\n'
)

FAKE_DUMP_NO_EFI = """\
label: gpt
device: /dev/sda
unit: sectors
first-lba: 34
last-lba: 209715166

/dev/sda1 : start=2048, size=52428800, type=EBD0A0A2-B741-E11C-A8EB-00A0C93EC93B, uuid=BBBB, name="Windows"
/dev/sda2 : start=52430848, size=52428800, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=CCCC, name="Nimbus"
"""


# --- nimbus-partitionsafe: backup -------------------------------------------


def test_backup_creates_dump_and_checksum(tmp_path):
    """backup vuelca la tabla y guarda un checksum en el destino."""
    ps = _load_partitionsafe()
    dest = tmp_path / "respaldo"
    result = ps.backup_device(
        "/dev/sda", dest, dumper=lambda device: FAKE_DUMP_SDA)
    dump_path = pathlib.Path(result["dump"])
    assert dump_path.is_file()
    assert FAKE_DUMP_SDA.splitlines()[4] in dump_path.read_text(
        encoding="utf-8")
    checksum_path = pathlib.Path(result["checksum"])
    assert checksum_path.is_file()
    assert checksum_path.read_text(encoding="utf-8").strip()


def test_backup_checksum_matches_dump_content(tmp_path):
    """El checksum permite detectar una manipulacion posterior."""
    import hashlib

    ps = _load_partitionsafe()
    dest = tmp_path / "respaldo"
    result = ps.backup_device(
        "/dev/sda", dest, dumper=lambda device: FAKE_DUMP_SDA)
    dump_text = pathlib.Path(result["dump"]).read_text(encoding="utf-8")
    expected = hashlib.sha256(dump_text.encode("utf-8")).hexdigest()
    stored = pathlib.Path(result["checksum"]).read_text(
        encoding="utf-8").strip()
    assert expected in stored


def test_backup_rejects_invalid_device(tmp_path):
    """La entrada externa se valida: un dispositivo raro no se acepta."""
    ps = _load_partitionsafe()
    with pytest.raises(ValueError):
        ps.backup_device(
            "/dev/sda; rm -rf /", tmp_path,
            dumper=lambda device: FAKE_DUMP_SDA)


# --- nimbus-partitionsafe: verify -------------------------------------------


def test_verify_returns_zero_when_table_unchanged(tmp_path):
    """Sin cambios la verificacion sale con 0."""
    ps = _load_partitionsafe()
    dest = tmp_path / "respaldo"
    ps.backup_device("/dev/sda", dest, dumper=lambda device: FAKE_DUMP_SDA)
    code = ps.verify_device(
        "/dev/sda", dest, dumper=lambda device: FAKE_DUMP_SDA)
    assert code == 0


def test_verify_returns_one_when_table_changed(tmp_path):
    """Cualquier cambio no autorizado sale con 1, no con 0."""
    ps = _load_partitionsafe()
    dest = tmp_path / "respaldo"
    ps.backup_device("/dev/sda", dest, dumper=lambda device: FAKE_DUMP_SDA)
    code = ps.verify_device(
        "/dev/sda", dest,
        dumper=lambda device: FAKE_DUMP_SDA_CHANGED_SIZE)
    assert code == 1


def test_verify_detects_partition_count_change(tmp_path):
    """El caso grave (particion anadida/eliminada) tambien sale con 1."""
    ps = _load_partitionsafe()
    dest = tmp_path / "respaldo"
    ps.backup_device("/dev/sda", dest, dumper=lambda device: FAKE_DUMP_SDA)
    ok, reason = ps.verify_tables(
        FAKE_DUMP_SDA, FAKE_DUMP_SDA_EXTRA_PARTITION)
    assert ok is False
    assert reason.strip()
    code = ps.verify_device(
        "/dev/sda", dest,
        dumper=lambda device: FAKE_DUMP_SDA_EXTRA_PARTITION)
    assert code == 1


def test_verify_cli_exits_nonzero_on_change(tmp_path, monkeypatch):
    """El CLI `verify` sale con codigo != 0 ante una tabla distinta."""
    ps = _load_partitionsafe()
    dest = tmp_path / "respaldo"
    ps.backup_device("/dev/sda", dest, dumper=lambda device: FAKE_DUMP_SDA)
    monkeypatch.setattr(
        ps, "sfdisk_dump", lambda device, runner=None: FAKE_DUMP_SDA_CHANGED_SIZE)
    assert ps.main(["verify", "/dev/sda", str(dest)]) == 1


def test_verify_cli_exits_zero_when_unchanged(tmp_path, monkeypatch):
    """El CLI `verify` sale con 0 cuando nada cambio."""
    ps = _load_partitionsafe()
    dest = tmp_path / "respaldo"
    ps.backup_device("/dev/sda", dest, dumper=lambda device: FAKE_DUMP_SDA)
    monkeypatch.setattr(
        ps, "sfdisk_dump", lambda device, runner=None: FAKE_DUMP_SDA)
    assert ps.main(["verify", "/dev/sda", str(dest)]) == 0


# --- nimbus-partitionsafe: efi ----------------------------------------------


def test_efi_finds_existing_partition_without_modifying():
    """`efi` localiza la EFI existente a partir del volcado."""
    ps = _load_partitionsafe()
    found = ps.find_efi_from_dump(FAKE_DUMP_SDA)
    assert found == "/dev/sda1"


def test_efi_empty_when_no_efi_partition():
    """Sin EFI no se inventa ninguna: devuelve cadena vacia."""
    ps = _load_partitionsafe()
    assert ps.find_efi_from_dump(FAKE_DUMP_NO_EFI) == ""


# --- nimbus-dualboot: Fast Boot ----------------------------------------------


def test_fast_boot_detection_blocks_instead_of_allowing(tmp_path):
    """Con Fast Boot activo el modulo se niega a continuar."""
    db = _load_dualboot()
    efivars = tmp_path / "efivars"
    efivars.mkdir()
    (efivars / "FastBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c").write_bytes(
        b"\x01FastBootEnabled")
    assert db.is_fast_boot_enabled(efivars_dir=efivars) is True
    result = db.run_with_paths(
        efivars_dir=efivars, locale="en",
        os_prober_lines=["/dev/sda1:Windows 10:Windows:chain"],
        dump_text=FAKE_DUMP_SDA,
        backup_dir=tmp_path / "respaldo-bloqueo",
    )
    assert result is not None
    assert result.strip()


def test_fast_boot_block_message_explains_how_to_disable(tmp_path):
    """El bloqueo dice como desactivarlo: powercfg y la BIOS (ES/EN)."""
    db = _load_dualboot()
    efivars = tmp_path / "efivars"
    efivars.mkdir()
    (efivars / "FastBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c").write_bytes(
        b"\x01FastBootEnabled")
    msg_es = db.run_with_paths(
        efivars_dir=efivars, locale="es",
        os_prober_lines=["/dev/sda1:Windows 10:Windows:chain"],
        dump_text=FAKE_DUMP_SDA,
        backup_dir=tmp_path / "respaldo-es",
    )
    msg_en = db.run_with_paths(
        efivars_dir=efivars, locale="en",
        os_prober_lines=["/dev/sda1:Windows 10:Windows:chain"],
        dump_text=FAKE_DUMP_SDA,
        backup_dir=tmp_path / "respaldo-en",
    )
    assert msg_es != msg_en
    for msg in (msg_es, msg_en):
        assert "powercfg /h off" in msg
        assert "BIOS" in msg


def test_no_fast_boot_allows_continuing(tmp_path):
    """Sin Fast Boot no hay bloqueo por esa causa."""
    db = _load_dualboot()
    efivars = tmp_path / "efivars-vacias"
    efivars.mkdir()
    assert db.is_fast_boot_enabled(efivars_dir=efivars) is False


# --- nimbus-dualboot: EFI existente ------------------------------------------


def test_existing_efi_is_reused_not_recreated():
    """Con EFI existente el modulo no propone crear otra."""
    db = _load_dualboot()
    assert db.find_existing_efi(FAKE_DUMP_SDA) == "/dev/sda1"
    assert db.should_create_efi("/dev/sda1") is False


def test_missing_efi_requests_creation():
    """Sin EFI si hay que crearla."""
    db = _load_dualboot()
    assert db.find_existing_efi(FAKE_DUMP_NO_EFI) == ""
    assert db.should_create_efi("") is True


# --- nimbus-dualboot: Windows -> GRUB ----------------------------------------


def test_windows_detection_from_os_prober():
    """os-prober con Windows se detecta como arranque dual."""
    db = _load_dualboot()
    assert db.windows_detected(
        os_prober_lines=["/dev/sda1:Windows 10:Windows:chain"]) is True
    assert db.windows_detected(os_prober_lines=[]) is False


def test_windows_requests_grub_instead_of_systemd_boot(tmp_path):
    """Con Windows el aviso al bootloader pide GRUB, no systemd-boot."""
    db = _load_dualboot()
    efivars = tmp_path / "efivars-limpias"
    efivars.mkdir()
    outcome = db.run_with_paths(
        efivars_dir=efivars, locale="en",
        os_prober_lines=["/dev/sda2:Windows 11:Windows:chain"],
        dump_text=FAKE_DUMP_SDA,
        backup_dir=tmp_path / "respaldo-grub",
    )
    assert outcome is None
    assert db.bootloader_choice(True) == "grub"
    assert db.bootloader_choice(False) != "grub"


def test_dualboot_strings_come_from_i18n_table():
    """Las cadenas visibles del modulo salen de translated() ES/EN."""
    db = _load_dualboot()
    assert db.pretty_name("es") != db.pretty_name("en")
    assert db.pretty_status_message("es") != db.pretty_status_message("en")
    assert "powercfg /h off" in db.fast_boot_message("es")
    assert "powercfg /h off" in db.fast_boot_message("en")
