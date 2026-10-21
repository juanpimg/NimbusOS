# SPDX-License-Identifier: GPL-3.0-or-later
"""Modulo Calamares del gestor de arranque de Nimbus con rollback de un clic.

Elige **GRUB** si hay Windows (multiboot) y **systemd-boot** si el disco
es solo de Nimbus. Sobre Btrfs (el sistema por defecto) el menu ofrece,
ademas de la entrada normal, ``Nimbus (ultima version conocida buena)``
y ``Nimbus (modo seguro)``:

- con systemd-boot se sincronizan las entradas con los snapshots
  (estilo ``snapper-sync``: cada snapshot bueno genera su entrada);
- con GRUB se escribe un submenú de snapshots en ``custom.cfg``.

Sin Btrfs (ext4/xfs) no hay snapshots y por tanto no se promete
rollback: se instala el kernel LTS ``linux-cachyos-lts`` como red de
seguridad y se deja escrito en el resumen.

Sin Btrfs real ni snapper en el entorno de pruebas, toda la logica es
inyectable: recibe la raiz (``root``) y un ``snapshot_provider``
(callable ``provider(root) -> list[str]``). Los tests usan un proveedor
falso; el instalador real pasa el que lista ``/.snapshots``.
"""

import logging
import pathlib
import subprocess

try:  # Calamares provee libcalamares en el ISO live; ausente en CI/test.
    import libcalamares
except ImportError:  # pragma: no cover - entorno sin Calamares
    libcalamares = None

try:
    from nimbus_i18n import active_locale, translated
    import nimbus_i18n as _i18n_module
except ImportError:  # cargado por ruta (Calamares/test) sin paquete
    import importlib.util as _importlib_util
    import sys as _sys

    _i18n_module = _sys.modules.get("nimbus_i18n")
    if _i18n_module is None:
        _i18n_path = (
            pathlib.Path(__file__).resolve().parents[2] / "nimbus_i18n.py"
        )
        _i18n_spec = _importlib_util.spec_from_file_location(
            "nimbus_i18n", _i18n_path)
        _i18n_module = _importlib_util.module_from_spec(_i18n_spec)
        _sys.modules["nimbus_i18n"] = _i18n_module
        _i18n_spec.loader.exec_module(_i18n_module)
    active_locale = _i18n_module.active_locale
    translated = _i18n_module.translated

logger = logging.getLogger(__name__)

DEFAULT_KERNEL = "linux-cachyos"
LTS_KERNEL = "linux-cachyos-lts"

GRUB = "grub"
SYSTEMD_BOOT = "systemd-boot"

ENTRY_NORMAL = "normal"
ENTRY_LAST_GOOD = "last-good"
ENTRY_SAFE = "safe"

# Claves visibles del menu y del resumen. Se registran en la tabla
# ES/EN de nimbus_i18n al importar (ese fichero lo mantiene otra pista
# y no se puede editar aqui): asi translated() las resuelve en ambos
# idiomas sin tocar el fichero.
BOOTLOADER_TRANSLATIONS = {
    "es": {
        "bootloader.pretty_name": "Gestor de arranque",
        "bootloader.pretty_status": (
            "Configurando el gestor de arranque con rollback."
        ),
        "bootloader.entry.normal": "Nimbus",
        "bootloader.entry.last_good": (
            "Nimbus (última versión conocida buena)"
        ),
        "bootloader.entry.safe": "Nimbus (modo seguro)",
        "bootloader.summary.rollback": (
            "Rollback activado ({bootloader}): el menú ofrece "
            "«{last_good}» y «{safe}»."
        ),
        "bootloader.summary.lts": (
            "Sin rollback ({fs}): se instala {lts} como red de seguridad."
        ),
        "bootloader.grub.submenu": "Nimbus snapshots (rollback en un clic)",
    },
    "en": {
        "bootloader.pretty_name": "Bootloader",
        "bootloader.pretty_status": "Setting up the bootloader with rollback.",
        "bootloader.entry.normal": "Nimbus",
        "bootloader.entry.last_good": "Nimbus (last known good version)",
        "bootloader.entry.safe": "Nimbus (safe mode)",
        "bootloader.summary.rollback": (
            "Rollback enabled ({bootloader}): the menu offers "
            "«{last_good}» and «{safe}»."
        ),
        "bootloader.summary.lts": (
            "No rollback ({fs}): installing {lts} as a safety net."
        ),
        "bootloader.grub.submenu": "Nimbus snapshots (one-click rollback)",
    },
}

for _lang, _table in BOOTLOADER_TRANSLATIONS.items():
    _target = _i18n_module.TRANSLATIONS.setdefault(_lang, {})
    for _key, _value in _table.items():
        _target.setdefault(_key, _value)


def _current_locale(locale=None):
    """Idioma efectivo: parametro, ajuste del instalador o entorno."""
    if locale is not None:
        return locale
    if libcalamares is not None:
        try:
            storage = libcalamares.globalstorage
            for key in ("nimbusLocale", "locale", "lang"):
                value = storage.value(key)
                if value:
                    return str(value)
        except Exception:
            pass
    return active_locale()


def is_btrfs_filesystem(filesystem):
    """True solo para Btrfs, el unico con rollback completo."""
    return str(filesystem or "").strip().lower() == "btrfs"


def choose_bootloader(has_windows):
    """GRUB con Windows (multiboot), systemd-boot si el disco es Nimbus solo."""
    if bool(has_windows):
        return GRUB
    return SYSTEMD_BOOT


def detect_windows(os_prober_output=None, runner=None):
    """Detecta Windows para elegir GRUB en multiboot.

    Con ``os_prober_output`` (texto de ``os-prober``) no ejecuta nada:
    los tests inyectan el texto. Sin texto ejecuta ``["os-prober"]``
    con lista de argumentos (nunca shell) y busca "windows".
    ``runner`` inyectable evita tocar el sistema en pruebas.
    """
    if os_prober_output is not None:
        return "windows" in str(os_prober_output).lower()
    run = runner or subprocess.run
    try:
        completed = run(
            ["os-prober"], capture_output=True, text=True, timeout=30)
    except (FileNotFoundError, subprocess.SubprocessError, OSError):
        return False
    except Exception:
        return False
    output = getattr(completed, "stdout", "") or ""
    return "windows" in str(output).lower()


def entry_titles(locale=None):
    """Titulos del menu ya traducidos (normal, last-good, safe)."""
    lang = _current_locale(locale)
    return {
        ENTRY_NORMAL: translated("bootloader.entry.normal", lang),
        ENTRY_LAST_GOOD: translated("bootloader.entry.last_good", lang),
        ENTRY_SAFE: translated("bootloader.entry.safe", lang),
    }


def _resolve_snapshots(root, snapshot_provider):
    """Lista de snapshots via proveedor inyectable o via disco."""
    if snapshot_provider is not None:
        try:
            names = snapshot_provider(root)
        except TypeError:
            names = snapshot_provider()
        return [str(name) for name in (names or [])]
    if root is None:
        return []
    snapdir = pathlib.Path(str(root)) / ".snapshots"
    if not snapdir.is_dir():
        return []
    return sorted(p.name for p in snapdir.iterdir() if p.is_dir())


def build_boot_entries(filesystem="btrfs", root=None,
                       snapshot_provider=None, locale=None):
    """Entradas del menu de arranque.

    Sobre Btrfs devuelve normal + última-buena + modo seguro; la
    entrada de última-buena referencia el snapshot más reciente que
    devuelva el proveedor (None si no hay ninguno). Fuera de
    Btrfs devuelve solo la normal: no se promete lo que no se puede dar.
    """
    lang = _current_locale(locale)
    normal_title = translated("bootloader.entry.normal", lang)
    last_good_title = translated("bootloader.entry.last_good", lang)
    safe_title = translated("bootloader.entry.safe", lang)
    normal = {
        "kind": ENTRY_NORMAL,
        "title": normal_title,
        "kernel": DEFAULT_KERNEL,
        "snapshot": None,
    }
    if not is_btrfs_filesystem(filesystem):
        return [normal]
    snapshots = _resolve_snapshots(root, snapshot_provider)
    last_good_snapshot = snapshots[-1] if snapshots else None
    return [
        dict(normal),
        {
            "kind": ENTRY_LAST_GOOD,
            "title": last_good_title,
            "kernel": DEFAULT_KERNEL,
            "snapshot": last_good_snapshot,
        },
        {
            "kind": ENTRY_SAFE,
            "title": safe_title,
            "kernel": DEFAULT_KERNEL,
            "snapshot": last_good_snapshot,
            "safe_mode": True,
        },
    ]


def summary_message(plan, locale=None):
    """Resumen visible del paso: rollback o LTS, siempre traducido."""
    lang = _current_locale(locale)
    if plan.get("rollback"):
        return translated(
            "bootloader.summary.rollback", lang).format(
                bootloader=plan.get("bootloader", SYSTEMD_BOOT),
                last_good=translated("bootloader.entry.last_good", lang),
                safe=translated("bootloader.entry.safe", lang))
    return translated(
        "bootloader.summary.lts", lang).format(
            fs=plan.get("filesystem", "ext4"), lts=LTS_KERNEL)


def plan_install(root="/", filesystem="btrfs", has_windows=False,
                 snapshot_provider=None, locale=None):
    """Plan puro: que gestor, que entradas y que resumen mostrar.

    No escribe nada; ``configure_bootloader`` lo materializa bajo root.
    """
    lang = _current_locale(locale)
    bootloader = choose_bootloader(has_windows)
    rollback = is_btrfs_filesystem(filesystem)
    entries = build_boot_entries(
        filesystem=filesystem, root=root,
        snapshot_provider=snapshot_provider, locale=lang)
    if rollback:
        extra_packages = []
    else:
        extra_packages = [LTS_KERNEL]
    plan = {
        "bootloader": bootloader,
        "filesystem": str(filesystem or "").strip().lower() or "btrfs",
        "rollback": rollback,
        "entries": entries,
        "extra_packages": extra_packages,
        "snapper_sync": bool(rollback and bootloader == SYSTEMD_BOOT),
        "grub_snapshot_submenu": bool(rollback and bootloader == GRUB),
    }
    plan["summary"] = summary_message(plan, locale=lang)
    return plan


def _write_text(target, content):
    target = pathlib.Path(str(target))
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
    return target


def configure_bootloader(root="/", filesystem="btrfs", has_windows=False,
                         snapshot_provider=None, runner=None, locale=None):
    """Materializa el plan bajo ``root`` sin tocar el resto del sistema.

    - systemd-boot: escribe las tres entradas en
      ``boot/loader/entries/`` y marca ``snapper-sync`` activo.
    - GRUB: escribe ``boot/grub/custom.cfg`` con el submenú de
      snapshots (el "clic" extra del menu).
    - no-Btrfs: no escribe entradas de rollback y anota el kernel LTS.

    ``runner`` solo se usa para comandos en lista (p. ej. reinstalacion
    del gestor en el instalador real); los tests lo omiten.
    """
    lang = _current_locale(locale)
    plan = plan_install(
        root=root, filesystem=filesystem, has_windows=has_windows,
        snapshot_provider=snapshot_provider, locale=lang)
    base = pathlib.Path(str(root))
    if plan["rollback"]:
        if plan["bootloader"] == SYSTEMD_BOOT:
            entries_dir = base / "boot" / "loader" / "entries"
            for entry in plan["entries"]:
                options = "rootflags=subvol=@"
                if entry.get("snapshot"):
                    options = (
                        f"rootflags=subvol=@snapshots/"
                        f"{entry['snapshot']}"
                    )
                if entry.get("safe_mode"):
                    options += " systemd.unit=rescue.target nomodeset"
                content = (
                    "# SPDX-License-Identifier: GPL-3.0-or-later\n"
                    f"title   {entry['title']}\n"
                    "linux   /vmlinuz-linux-cachyos\n"
                    "initrd  /initramfs-linux-cachyos.img\n"
                    f"options {options}\n"
                )
                filename = {
                    ENTRY_NORMAL: "nimbus.conf",
                    ENTRY_LAST_GOOD: "nimbus-last-good.conf",
                    ENTRY_SAFE: "nimbus-safe.conf",
                }[entry["kind"]]
                _write_text(entries_dir / filename, content)
            _write_text(
                base / "etc" / "nimbus" / "snapper-sync.conf",
                "# SPDX-License-Identifier: GPL-3.0-or-later\n"
                "[snapper-sync]\n"
                "enabled=true\n",
            )
        else:
            submenu = translated("bootloader.grub.submenu", lang)
            lines = [
                "# SPDX-License-Identifier: GPL-3.0-or-later",
                f"submenu '{submenu}' {{",
            ]
            for entry in plan["entries"]:
                if entry["kind"] == ENTRY_NORMAL:
                    continue
                snapshot = entry.get("snapshot") or "@"
                lines.append(
                    f"  menuentry '{entry['title']} [{snapshot}]' {{")
                lines.append(
                    "    linux /vmlinuz-linux-cachyos "
                    f"rootflags=subvol=@snapshots/{snapshot}")
                if entry.get("safe_mode"):
                    lines[-1] += " systemd.unit=rescue.target nomodeset"
                lines.append("  }")
            lines.append("}")
            lines.append("")
            _write_text(
                base / "boot" / "grub" / "custom.cfg",
                "\n".join(lines))
    else:
        _write_text(
            base / "etc" / "nimbus" / "bootloader-lts.conf",
            "# SPDX-License-Identifier: GPL-3.0-or-later\n"
            "[bootloader]\n"
            f"fallback_kernel={LTS_KERNEL}\n"
            "rollback=false\n",
        )
    if runner is not None:
        if plan["bootloader"] == GRUB:
            runner(["grub-install", "--target=x86_64-efi"],
                   check=False)
        else:
            runner(["bootctl", "install"], check=False)
    return plan


def pretty_name(locale=None):
    return translated("bootloader.pretty_name", _current_locale(locale))


def pretty_status_message(locale=None):
    return translated("bootloader.pretty_status", _current_locale(locale))


def run():
    """Punto de entrada de Calamares."""
    locale = _current_locale()
    if libcalamares is not None:
        storage = libcalamares.globalstorage
        root = storage.value("rootMountPoint") or "/"
        filesystem = (
            storage.value("nimbusFilesystem")
            or storage.value("filesystem") or "btrfs")
        probe = storage.value("nimbusOsProber")
        if probe:
            has_windows = detect_windows(os_prober_output=str(probe))
        else:
            has_windows = detect_windows()
    else:  # pragma: no cover - solo instalador real
        root, filesystem, has_windows = "/", "btrfs", False
    plan = configure_bootloader(
        root=root, filesystem=filesystem, has_windows=has_windows,
        locale=locale)
    if libcalamares is not None:
        libcalamares.globalstorage.insert(
            "nimbusBootloaderSummary", plan["summary"])
    return None
