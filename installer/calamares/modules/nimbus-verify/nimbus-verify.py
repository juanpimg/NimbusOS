# SPDX-License-Identifier: GPL-3.0-or-later
"""Modulo Calamares de verificacion post-instalacion de Nimbus.

Ejecuta una bateria de comprobaciones sobre el sistema instalado.
Cada ``check_*`` devuelve ``(bool, str)``: True con un mensaje ok, o
False con un mensaje que incluye una accion. Ninguna comprobacion lanza
excepcion y un fallo nunca aborta la instalacion.
"""

import pathlib
import shutil
import subprocess

try:  # Calamares provee libcalamares en el ISO live; ausente en CI/test.
    import libcalamares
except ImportError:  # pragma: no cover - entorno sin Calamares
    libcalamares = None

CHECKS = []


def check(name):
    def decorator(fn):
        CHECKS.append((name, fn))
        return fn
    return decorator


@check("gpu")
def check_gpu():
    """Verifica que hay una GPU funcional presente."""
    try:
        drm = pathlib.Path("/sys/class/drm")
        if drm.is_dir() and list(drm.glob("card*")):
            return True, "GPU detectada en /sys/class/drm."
        dri = pathlib.Path("/dev/dri")
        if dri.is_dir() and list(dri.iterdir()):
            return True, "GPU detectada en /dev/dri."
        return (False, "No se detecto GPU. Si usas NVIDIA, instala "
                "nvidia-open-dkms y reinicia.")
    except Exception as exc:  # nunca debe lanzar
        return False, f"No se pudo comprobar la GPU ({exc}). Revisala a mano."


@check("audio")
def check_audio():
    """Verifica que hay un dispositivo de audio disponible."""
    try:
        cards = pathlib.Path("/proc/asound/cards")
        if cards.is_file() and "[No soundcards]" not in cards.read_text():
            return True, "Tarjeta de sonido detectada."
        if pathlib.Path("/dev/snd").is_dir():
            return True, "Dispositivos de audio presentes en /dev/snd."
        return (False, "No se detecto audio. Comprueba que PipeWire esta "
                "activo: systemctl --user status pipewire.")
    except Exception as exc:  # nunca debe lanzar
        return False, f"No se pudo comprobar el audio ({exc}). Revisalo a mano."


@check("network")
def check_network():
    """Verifica que hay al menos una interfaz de red operativa."""
    try:
        net = pathlib.Path("/sys/class/net")
        for iface in net.iterdir():
            if iface.name == "lo":
                continue
            state = iface / "operstate"
            if state.is_file() and state.read_text().strip() in ("up", "dormant"):
                return True, f"Red operativa en {iface.name}."
        return (False, "Sin red operativa. Conecta un cable o configura "
                "el Wi-Fi en el centro de control.")
    except Exception as exc:  # nunca debe lanzar
        return False, f"No se pudo comprobar la red ({exc}). Revisala a mano."


@check("webcam")
def check_webcam():
    """Verifica la camara web si existe."""
    try:
        video = sorted(pathlib.Path("/dev").glob("video*"))
        if video:
            return True, f"Camara detectada en {video[0]}."
        return (True, "Sin camara detectada (opcional, se omite).")
    except Exception as exc:  # nunca debe lanzar
        return False, f"No se pudo comprobar la camara ({exc})."


@check("suspend")
def check_suspend():
    """Verifica que la suspension esta disponible."""
    try:
        state = pathlib.Path("/sys/power/state")
        if state.is_file():
            modes = state.read_text()
            if "mem" in modes or "disk" in modes:
                return True, "Suspension disponible."
        return (False, "Suspension no disponible. Revisa la swap "
                "o la configuracion de energia.")
    except Exception as exc:  # nunca debe lanzar
        return False, f"No se pudo comprobar la suspension ({exc})."


@check("disk-space")
def check_disk_space():
    """Verifica que queda espacio libre suficiente en /."""
    try:
        minimum_gib = 5
        total, used, free = shutil.disk_usage("/")
        free_gib = free / (1024 ** 3)
        if free_gib >= minimum_gib:
            return True, f"Espacio libre suficiente ({free_gib:.1f} GiB)."
        return (False, f"Solo quedan {free_gib:.1f} GiB libres. "
                f"Libera espacio (minimo {minimum_gib} GiB).")
    except Exception as exc:  # nunca debe lanzar
        return False, f"No se pudo comprobar el disco ({exc})."


@check("bootloader")
def check_bootloader():
    """Verifica que el gestor de arranque quedo instalado."""
    try:
        efi = pathlib.Path("/sys/firmware/efi")
        if efi.is_dir():
            entries = pathlib.Path("/boot/efi/EFI")
            if entries.is_dir() and list(entries.iterdir()):
                return True, "Entradas EFI del gestor instaladas."
            return (False, "Arrancaste en modo EFI pero no hay entradas "
                    "en /boot/efi/EFI. Reinstala el gestor.")
        grub = pathlib.Path("/boot/grub/grub.cfg")
        if grub.is_file():
            return True, "GRUB instalado (arranque BIOS)."
        loader = pathlib.Path("/boot/loader/entries")
        if loader.is_dir() and list(loader.iterdir()):
            return True, "systemd-boot instalado."
        return (False, "No se encontro configuracion del gestor. "
                "Reinstala GRUB o systemd-boot.")
    except Exception as exc:  # nunca debe lanzar
        return False, f"No se pudo comprobar el gestor ({exc})."


@check("dual-boot")
def check_dual_boot():
    """Detecta otros sistemas para avisar sobre arranque dual."""
    try:
        result = subprocess.run(
            ["os-prober"], capture_output=True, text=True, timeout=30)
        entries = [line for line in result.stdout.splitlines() if line.strip()]
        if entries:
            return True, f"Arranque dual detectado ({len(entries)} sistemas)."
        return True, "Sin otros sistemas (instalacion unica)."
    except (FileNotFoundError, subprocess.SubprocessError):
        return True, "os-prober no disponible; se omite el aviso dual-boot."
    except Exception as exc:  # nunca debe lanzar
        return False, f"No se pudo comprobar dual-boot ({exc})."


def run_all_checks():
    """Ejecuta todas las comprobaciones sin que ninguna aborte el resto."""
    results = []
    for name, fn in CHECKS:
        try:
            ok, message = fn()
            results.append((name, bool(ok), str(message)))
        except Exception as exc:  # cinturon y tirantes
            results.append((name, False,
                            f"Fallo interno de la comprobacion ({exc})."))
    return results


def pretty_name():
    return "Verificación"


def pretty_status_message():
    return "Verificando la instalación."


def run():
    """Punto de entrada de Calamares: informa, nunca aborta."""
    results = run_all_checks()
    failed = [name for name, ok, _ in results if not ok]
    if libcalamares is not None:
        storage = libcalamares.globalstorage
        storage.insert("nimbusVerifyResults", dict(results))
        for name, ok, message in results:
            if ok:
                libcalamares.utils.debug(f"verify {name}: {message}")
            else:
                libcalamares.utils.warning(f"verify {name}: {message}")
    return None if not failed else (
        "Avisos de verificación: " + ", ".join(failed)
        + ". La instalación continúa.")
