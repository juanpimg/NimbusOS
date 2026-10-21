# SPDX-License-Identifier: GPL-3.0-or-later
"""Modulo Calamares de verificacion post-instalacion de Nimbus.

Ejecuta 22 comprobaciones, en el orden del spec:

``gpu``, ``graphics-hybrid``, ``audio``, ``network``, ``bluetooth``,
``webcam``, ``suspend``, ``battery``, ``disk-space``, ``bootloader``,
``dual-boot``, ``snapshots``, ``updates``, ``keyring`` (las 14 originales)
mas ``cpu``, ``video-amd``, ``video-intel``, ``nvidia``, ``wifi``,
``codecs``, ``printers`` y ``laptop`` (las 8 filas de la matriz §4.13
que no tenian comprobacion: CPU x86-64, AMD GCN3+/RADV, Intel iGPU/Arc,
NVIDIA Turing+, WiFi por chip, codecs ffmpeg, impresoras CUPS y
portatiles tapa/brillo).

Cada ``check_*`` devuelve ``(bool, str)``: True con un mensaje ok, o False
con un mensaje que incluye una accion. Las de hardware opcional
(``bluetooth``, ``webcam``, ``battery``, ``dual-boot``, ``snapshots``)
devuelven True con mensaje de omision cuando el equipo no tiene ese
hardware; nunca devuelven True sin comprobar.

Sin hardware y sin root cada comprobacion es inyectable: todo lo que el
check consulta del entorno (nodos DRI, baterias, filesystems...) se puede
pasar como parametro. El valor por defecto ``_AUTO`` significa
"autodetectar del sistema real"; pasar un valor explicito (incluido None,
False o []) desactiva la autodeteccion de ese aspecto. Asi los tests
pasan un entorno falso y el instalador usa el real.

Ninguna comprobacion lanza excepcion y un fallo nunca aborta la
instalacion: una excepcion dentro de un check se captura y se convierte
en ``(False, mensaje)``, y ``run_all_checks`` aisla ademas cualquier
fallo del propio envoltorio.
"""

import logging
import os
import pathlib
import re
import shutil
import subprocess
import sys

try:  # Calamares provee libcalamares en el ISO live; ausente en CI/test.
    import libcalamares
except ImportError:  # pragma: no cover - entorno sin Calamares
    libcalamares = None

try:
    from nimbus_i18n import active_locale, translated
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

#: Marca de "autodetectar del sistema real" para los parametros inyectables.
#: Pasar cualquier otro valor (incluido None/False/[]) lo usa tal cual.
_AUTO = object()

#: Modos hibridos que cuentan como PRIME bajo demanda.
ON_DEMAND_MODES = ("on-demand", "ondemand", "on_demand", "hybrid")

# Las claves ES/EN de este modulo viven en la tabla central
# (installer/calamares/nimbus_i18n.py), unica fuente. Este modulo
# no registra nada al importarse para evitar dobles copias en
# sys.modules (ver informe de integracion del M1).

CHECKS = []


def check(name):
    def decorator(fn):
        CHECKS.append((name, fn))
        return fn
    return decorator


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


def _run(cmd, timeout=5):
    """Ejecuta cmd como lista (nunca con shell) y devuelve el resultado."""
    return subprocess.run(
        list(cmd), capture_output=True, text=True, timeout=timeout)


def _as_list(value, placeholder="entry"):
    """Normaliza un entorno inyectado a lista (None/False -> vacia)."""
    if value is None:
        return []
    if isinstance(value, bool):
        return [placeholder] if value else []
    if isinstance(value, str):
        return [value]
    return list(value)


def _detect_dri_render_nodes():
    """Nombres renderD* presentes en /dev/dri."""
    dri = pathlib.Path("/dev/dri")
    return sorted(p.name for p in dri.iterdir()
                  if p.name.startswith("renderD"))


def _detect_gpu_driver():
    """Nombre del controlador GPU activo, o None si no hay."""
    drm = pathlib.Path("/sys/class/drm")
    if drm.is_dir():
        cards = sorted(p for p in drm.iterdir()
                       if re.fullmatch(r"card\d+", p.name))
        for card in cards:
            link = card / "device" / "driver"
            try:
                if link.is_symlink():
                    target = os.readlink(link)
                    if target:
                        return os.path.basename(target.rstrip("/"))
                elif link.is_dir():
                    return link.resolve().name
            except OSError:
                continue
    modules = pathlib.Path("/sys/module")
    for name in ("amdgpu", "i915", "xe", "nvidia", "nouveau", "radeon",
                 "virtio_gpu", "vmwgfx"):
        if (modules / name).is_dir():
            return name
    return None


def _detect_gpus():
    """Tarjetas DRM presentes (cardN en /sys/class/drm, sin conectores)."""
    drm = pathlib.Path("/sys/class/drm")
    if drm.is_dir():
        return sorted(p.name for p in drm.iterdir()
                      if re.fullmatch(r"card\d+", p.name))
    return []


def _detect_prime_mode():
    """Modo PRIME actual, o None si no se puede determinar."""
    for cmd in (["prime-select", "query"], ["supergfxctl", "-g"]):
        try:
            proc = _run(cmd)
        except (FileNotFoundError, subprocess.SubprocessError, OSError):
            continue
        if proc.returncode == 0 and proc.stdout.strip():
            return proc.stdout.strip().split()[0]
    return None


def _detect_audio_devices():
    """Dispositivos de salida de audio (nombres), posiblemente vacio."""
    devices = []
    try:
        text = pathlib.Path("/proc/asound/cards").read_text(encoding="utf-8")
    except OSError:
        text = ""
    for line in text.splitlines():
        line = line.strip()
        if line and line[0].isdigit() and "[No soundcards" not in line:
            devices.append(line)
    if not devices:
        try:
            snd = pathlib.Path("/dev/snd")
            if snd.is_dir():
                devices = sorted(p.name for p in snd.iterdir())
        except OSError:
            pass
    return devices


def _detect_pipewire_active():
    """True si PipeWire esta activo; False si no se puede confirmar."""
    try:
        proc = _run(["systemctl", "--user", "is-active", "pipewire"])
    except (FileNotFoundError, subprocess.SubprocessError, OSError):
        proc = None
    if proc is not None and proc.returncode == 0:
        return True
    try:
        return _run(["pgrep", "-x", "pipewire"]).returncode == 0
    except (FileNotFoundError, subprocess.SubprocessError, OSError):
        return proc is not None


def _detect_interfaces():
    """Mapa {interfaz: operstate} de /sys/class/net."""
    result = {}
    for iface in pathlib.Path("/sys/class/net").iterdir():
        state = iface / "operstate"
        try:
            result[iface.name] = (
                state.read_text(encoding="utf-8").strip()
                if state.is_file() else "unknown")
        except OSError:
            result[iface.name] = "unknown"
    return result


def _detect_bluetooth_hardware():
    """True si hay algun controlador bluetooth en sysfs."""
    node = pathlib.Path("/sys/class/bluetooth")
    try:
        return node.is_dir() and any(node.iterdir())
    except OSError:
        return False


def _detect_service_active(name):
    """True si `systemctl is-active name` sale con exito."""
    return _run(["systemctl", "is-active", name]).returncode == 0


def _detect_video_devices():
    """Nodos /dev/video* presentes."""
    try:
        return sorted(str(p) for p in pathlib.Path("/dev").glob("video*"))
    except OSError:
        return []


def _detect_sleep_modes():
    """Contenido de /sys/power/state (modos declarados)."""
    return pathlib.Path("/sys/power/state").read_text(encoding="utf-8")


def _detect_s2idle():
    """True si s2idle aparece en /sys/power/mem_sleep."""
    text = pathlib.Path("/sys/power/mem_sleep").read_text(encoding="utf-8")
    return "s2idle" in text


def _battery_dirs():
    """Directorios power_supply que son baterias."""
    base = pathlib.Path("/sys/class/power_supply")
    found = []
    if not base.is_dir():
        return found
    for entry in sorted(base.iterdir()):
        try:
            if entry.name.startswith("BAT"):
                found.append(entry)
                continue
            type_file = entry / "type"
            if (type_file.is_file()
                    and type_file.read_text(
                        encoding="utf-8").strip() == "Battery"):
                found.append(entry)
        except OSError:
            continue
    return found


def _detect_has_battery():
    return bool(_battery_dirs())


def _detect_battery_capacity():
    """Porcentaje 0-100, o None si no se puede leer."""
    for battery in _battery_dirs():
        node = battery / "capacity"
        if node.is_file():
            return int(node.read_text(encoding="utf-8").strip())
    return None


def _detect_charge_limit_applied():
    """True si hay un umbral de carga por debajo del 100%."""
    for battery in _battery_dirs():
        for name in ("charge_control_end_threshold",
                     "charge_control_start_threshold",
                     "charge_stop_threshold"):
            node = battery / name
            if not node.is_file():
                continue
            try:
                if int(node.read_text(encoding="utf-8").strip()) < 100:
                    return True
            except ValueError:
                continue
    return False


def _detect_efi_system():
    return pathlib.Path("/sys/firmware/efi").is_dir()


def _detect_efi_entries():
    node = pathlib.Path("/boot/efi/EFI")
    if node.is_dir():
        return sorted(p.name for p in node.iterdir())
    return []


def _detect_grub_config():
    return pathlib.Path("/boot/grub/grub.cfg").is_file()


def _detect_systemd_entries():
    node = pathlib.Path("/boot/loader/entries")
    if node.is_dir():
        return sorted(p.name for p in node.iterdir() if p.suffix == ".conf")
    return []


def _detect_os_prober_systems():
    proc = _run(["os-prober"], timeout=10)
    return [line for line in proc.stdout.splitlines() if line.strip()]


def _detect_efi_shared():
    """True si hay una ESP con contenido en /boot/efi/EFI."""
    node = pathlib.Path("/boot/efi/EFI")
    try:
        return node.is_dir() and any(node.iterdir())
    except OSError:
        return False


def _detect_grub_installed():
    if pathlib.Path("/boot/grub/grub.cfg").is_file():
        return True
    node = pathlib.Path("/boot/efi/EFI")
    try:
        return any(p.is_file() and p.name.lower() in ("grubx64.efi",
                                                      "grub.efi")
                   for p in node.rglob("*"))
    except OSError:
        return False


def _detect_is_btrfs():
    """True si / es Btrfs (findmnt o /proc/mounts)."""
    try:
        proc = _run(["findmnt", "-n", "-o", "FSTYPE", "/"])
        if proc.returncode == 0 and proc.stdout.strip():
            return proc.stdout.strip().split()[0] == "btrfs"
    except (FileNotFoundError, subprocess.SubprocessError, OSError):
        pass
    try:
        text = pathlib.Path("/proc/mounts").read_text(encoding="utf-8")
    except OSError:
        return False
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[1] == "/":
            return parts[2] == "btrfs"
    return False


def _detect_snapshots():
    """Nombres de snapshots de /, o [] si no hay (o no hay con que verlos).

    Devuelve None cuando / es Btrfs pero no hay herramientas para
    comprobarlo: el check lo convierte en fallo honesto en vez de fingir.
    """
    try:
        proc = _run(["snapper", "-c", "root", "list", "--columns", "number"])
    except (FileNotFoundError, subprocess.SubprocessError, OSError):
        proc = None
    if proc is not None:
        if proc.returncode == 0:
            return [line.strip() for line in proc.stdout.splitlines()
                    if line.strip().isdigit()]
        if "command not found" not in (proc.stderr or "").lower():
            return []
    try:
        proc = _run(["btrfs", "subvolume", "list", "/"])
    except (FileNotFoundError, subprocess.SubprocessError, OSError):
        proc = None
    if proc is not None and proc.returncode == 0:
        return [line for line in proc.stdout.splitlines() if line.strip()]
    node = pathlib.Path("/.snapshots")
    try:
        if node.is_dir():
            return sorted(p.name for p in node.iterdir())
    except OSError:
        pass
    if proc is None:
        return None
    return []


def _detect_repo_configured():
    """True si [nimbus] aparece en la configuracion de pacman."""
    candidates = [pathlib.Path("/etc/pacman.conf")]
    try:
        candidates += sorted(
            p for p in pathlib.Path("/etc/pacman.conf.d").glob("*.conf")
            if p.is_file())
    except OSError:
        pass
    for path in candidates:
        try:
            if "[nimbus]" in path.read_text(encoding="utf-8"):
                return True
        except OSError:
            continue
    return False


def _detect_key_trusted():
    """True si la clave nimbus esta en el llavero pacman."""
    return _run(["pacman-key", "--list-keys", "nimbus"],
                timeout=10).returncode == 0


def _detect_keyring_populated():
    """True si el paquete nimbus-keyring dejo sus ficheros."""
    if pathlib.Path("/usr/share/pacman/keyrings/nimbus.gpg").exists():
        return True
    try:
        return _run(["pacman", "-Q", "nimbus-keyring"],
                    timeout=10).returncode == 0
    except (FileNotFoundError, subprocess.SubprocessError, OSError):
        return False


def _detect_key_imported():
    """True si la clave nimbus esta importada en pacman-key."""
    return _run(["pacman-key", "--list-keys", "nimbus"],
                timeout=10).returncode == 0


# --- D3: deteccion para la matriz §4.13 ---------------------------------------

#: Prefijos de controlador WiFi dentro de la matriz soportada (§4.13).
WIFI_DRIVER_PREFIXES = ("iwlwifi", "rtw88", "rtl8xxx", "rtl8192",
                        "rtl8188", "rtl8723", "b43", "brcmfmac")

#: Tipos de chasis SMBIOS que son portatiles (DMI type 3, chassis type).
LAPTOP_CHASSIS_TYPES = {8, 9, 10, 14, 31}

_INTEL_PCI_VENDOR = "8086"
_AMD_PCI_VENDOR = "1002"
_NVIDIA_PCI_VENDOR = "10de"


def _normalize_pci_vendor(value):
    """'0x8086'/'8086' -> '8086' (minusculas, sin prefijo)."""
    return str(value or "").strip().lower().removeprefix("0x")


def _detect_gpu_vendors():
    """Mapa {cardN: vendor} leido de /sys/class/drm (posible vacio)."""
    vendors = {}
    drm = pathlib.Path("/sys/class/drm")
    if not drm.is_dir():
        return vendors
    for card in sorted(p for p in drm.iterdir()
                       if re.fullmatch(r"card\d+", p.name)):
        node = card / "device" / "vendor"
        try:
            if node.is_file():
                vendors[card.name] = _normalize_pci_vendor(
                    node.read_text(encoding="utf-8"))
        except OSError:
            continue
    return vendors


def _cards_with_vendor(vendors, wanted):
    """Nombres de tarjetas cuyo vendor coincide (inyectable)."""
    wanted_norm = _normalize_pci_vendor(wanted)
    if isinstance(vendors, dict):
        items = list(vendors.items())
    else:
        items = [(f"card{i}", raw)
                 for i, raw in enumerate(_as_list(vendors))]
    return [card for card, raw in items
            if _normalize_pci_vendor(raw) == wanted_norm]


def _detect_vulkan_icds(substring):
    """Ficheros ICD de Vulkan que contienen `substring`."""
    node = pathlib.Path("/usr/share/vulkan/icd.d")
    try:
        return sorted(p.name for p in node.glob("*.json")
                      if substring in p.name)
    except OSError:
        return []


def _detect_media_driver():
    """True si esta intel-media-driver (iHD_drv_video.so)."""
    return pathlib.Path("/usr/lib/dri/iHD_drv_video.so").is_file()


def _detect_nvidia_driver():
    """Controlador NVIDIA ligado (nvidia/nouveau), o None."""
    for name in ("nvidia", "nouveau"):
        if (pathlib.Path("/sys/module") / name).is_dir():
            return name
    return None


def _detect_cpuinfo():
    """Texto de /proc/cpuinfo (puede lanzar; el check lo convierte)."""
    return pathlib.Path("/proc/cpuinfo").read_text(encoding="utf-8")


def _cpu_flags(cpuinfo_text):
    """Conjunto de flags de CPU unidos de todos los procesadores."""
    flags = set()
    for line in str(cpuinfo_text or "").splitlines():
        if line.split(":")[0].strip() == "flags":
            flags.update(line.partition(":")[2].split())
    return flags


def _cpu_level(flags):
    """Nivel x86-64 por flags: v4, v3, v1 o "" (bajo el minimo)."""
    if "avx512f" in flags:
        return "x86-64-v4 (AVX-512)"
    if "avx2" in flags:
        return "x86-64-v3 (AVX2)"
    if "sse4_2" in flags:
        return "x86-64-v1"
    return ""


def _detect_wireless():
    """Mapa {interfaz: controlador} de las WiFi presentes (posible vacio)."""
    result = {}
    base = pathlib.Path("/sys/class/net")
    try:
        ifaces = sorted(p for p in base.iterdir())
    except OSError:
        return result
    for iface in ifaces:
        try:
            if not (iface / "wireless").exists():
                continue
            link = iface / "device" / "driver"
            if link.is_symlink():
                result[iface.name] = os.readlink(link).split("/")[-1]
            elif link.is_dir():
                result[iface.name] = link.resolve().name
            else:
                result[iface.name] = "unknown"
        except OSError:
            continue
    return result


def _wifi_driver_supported(driver):
    """True si el controlador esta en la matriz §4.13."""
    lowered = str(driver or "").strip().lower()
    return lowered.startswith(WIFI_DRIVER_PREFIXES)


def _detect_ffmpeg():
    """Ruta de ffmpeg, o None si no esta instalado."""
    return shutil.which("ffmpeg")


def _detect_encoders(ffmpeg):
    """Salida de `ffmpeg -encoders` (cadena vacia si falla)."""
    try:
        proc = _run([ffmpeg, "-hide_banner", "-encoders"])
    except (FileNotFoundError, subprocess.SubprocessError, OSError):
        return ""
    if proc.returncode != 0:
        return ""
    return proc.stdout or ""


def _detect_cups():
    """True si CUPS esta instalado (cupsd disponible)."""
    return shutil.which("cupsd") is not None


def _detect_ipp_usb():
    """True si ipp-usb esta instalado."""
    return shutil.which("ipp-usb") is not None


def _detect_chassis_type():
    """Tipo de chasis DMI (entero SMBIOS); lanza si no se puede leer."""
    return int(pathlib.Path(
        "/sys/class/dmi/id/chassis_type").read_text(
            encoding="utf-8").strip())


def _detect_backlight():
    """Controles de brillo en /sys/class/backlight (posible vacio)."""
    node = pathlib.Path("/sys/class/backlight")
    try:
        if node.is_dir():
            return sorted(p.name for p in node.iterdir())
    except OSError:
        pass
    return []


def _detect_lid_present():
    """True si hay interruptor de tapa ACPI."""
    node = pathlib.Path("/proc/acpi/button/lid")
    try:
        return node.is_dir() and any(node.iterdir())
    except OSError:
        return False


@check("gpu")
def check_gpu(locale=None, dri_nodes=_AUTO, driver=_AUTO):
    """La GPU aparece en /dev/dri/renderD* y tiene controlador."""
    lang = _current_locale(locale)
    try:
        nodes = (_detect_dri_render_nodes() if dri_nodes is _AUTO
                 else [str(node) for node in _as_list(dri_nodes)])
        if not nodes:
            return (False, translated("verify.gpu.missing", lang))
        found = _detect_gpu_driver() if driver is _AUTO else driver
        if not found:
            return False, translated(
                "verify.gpu.no_driver", lang).format(
                    nodes=", ".join(nodes))
        return True, translated(
            "verify.gpu.ok", lang).format(
                nodes=", ".join(nodes), driver=found)
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.gpu.error", lang).format(detail=exc)


@check("graphics-hybrid")
def check_graphics_hybrid(locale=None, gpus=_AUTO, prime_mode=_AUTO):
    """Con iGPU y dGPU, PRIME esta en modo on-demand."""
    lang = _current_locale(locale)
    try:
        cards = (_detect_gpus() if gpus is _AUTO
                 else [str(card) for card in _as_list(gpus)])
        if len(cards) < 2:
            return True, translated("verify.hybrid.single", lang)
        mode = _detect_prime_mode() if prime_mode is _AUTO else prime_mode
        if (isinstance(mode, str)
                and mode.strip().lower() in ON_DEMAND_MODES):
            return True, translated("verify.hybrid.on_demand", lang)
        shown = (mode.strip() if isinstance(mode, str) and mode.strip()
                 else translated("verify.hybrid.unknown", lang))
        return False, translated(
            "verify.hybrid.not_ondemand", lang).format(mode=shown)
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("audio")
def check_audio(locale=None, output_devices=_AUTO, pipewire_active=_AUTO):
    """Hay un dispositivo de salida y PipeWire esta activo."""
    lang = _current_locale(locale)
    try:
        devices = (_detect_audio_devices() if output_devices is _AUTO
                   else [str(dev) for dev in _as_list(output_devices)])
        if not devices:
            return (False, translated("verify.audio.missing", lang))
        active = (_detect_pipewire_active() if pipewire_active is _AUTO
                  else bool(pipewire_active))
        if not active:
            return False, translated(
                "verify.audio.pipewire_inactive", lang).format(
                    device=devices[0])
        return True, translated(
            "verify.audio.ok", lang).format(device=devices[0])
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.audio.error", lang).format(detail=exc)


@check("network")
def check_network(locale=None, interfaces=_AUTO):
    """Hay una conexion de red configurada y operativa."""
    lang = _current_locale(locale)
    try:
        if interfaces is _AUTO:
            table = _detect_interfaces()
        elif isinstance(interfaces, dict):
            table = dict(interfaces)
        else:
            table = {str(name): "up" for name in _as_list(interfaces)}
        for name, state in table.items():
            if name == "lo":
                continue
            if str(state).strip() in ("up", "dormant"):
                return True, translated(
                    "verify.network.ok", lang).format(iface=name)
        return (False, translated("verify.network.missing", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.network.error", lang).format(detail=exc)


@check("bluetooth")
def check_bluetooth(locale=None, has_hardware=_AUTO, service_active=_AUTO):
    """El servicio bluetooth esta activo si el equipo lo tiene."""
    lang = _current_locale(locale)
    try:
        present = (_detect_bluetooth_hardware() if has_hardware is _AUTO
                   else bool(has_hardware))
        if not present:
            return True, translated("verify.bluetooth.skipped", lang)
        active = (_detect_service_active("bluetooth")
                  if service_active is _AUTO else bool(service_active))
        if active:
            return True, translated("verify.bluetooth.ok", lang)
        return (False, translated("verify.bluetooth.inactive", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("webcam")
def check_webcam(locale=None, video_devices=_AUTO, accessible=_AUTO):
    """Si hay dispositivo de video, esta disponible."""
    lang = _current_locale(locale)
    try:
        devices = (_detect_video_devices() if video_devices is _AUTO
                   else [str(dev) for dev in _as_list(video_devices)])
        if not devices:
            return (True, translated("verify.webcam.none", lang))
        if accessible is _AUTO:
            try:
                available = os.access(devices[0], os.R_OK)
            except OSError:
                available = True
        else:
            available = bool(accessible)
        if available:
            return True, translated(
                "verify.webcam.found", lang).format(device=devices[0])
        return False, translated(
            "verify.webcam.unavailable", lang).format(device=devices[0])
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.webcam.error", lang).format(detail=exc)


@check("suspend")
def check_suspend(locale=None, sleep_modes=_AUTO, s2idle_available=_AUTO):
    """El sistema declara suspension y s2idle esta disponible."""
    lang = _current_locale(locale)
    try:
        if sleep_modes is _AUTO:
            modes = _detect_sleep_modes()
        elif isinstance(sleep_modes, str):
            modes = sleep_modes
        else:
            modes = " ".join(str(mode) for mode in _as_list(sleep_modes))
        if "mem" not in modes and "disk" not in modes:
            return (False, translated("verify.suspend.missing", lang))
        deep = (_detect_s2idle() if s2idle_available is _AUTO
                else bool(s2idle_available))
        if not deep:
            return False, translated(
                "verify.suspend.no_s2idle", lang).format(modes=modes.strip())
        return (True, translated("verify.suspend.ok", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.suspend.error", lang).format(detail=exc)


@check("battery")
def check_battery(locale=None, has_battery=_AUTO, capacity=_AUTO,
                  charge_limit_applied=_AUTO):
    """Si hay bateria, el porcentaje se lee y el limite esta aplicado."""
    lang = _current_locale(locale)
    try:
        present = (_detect_has_battery() if has_battery is _AUTO
                   else bool(has_battery))
        if not present:
            return True, translated("verify.battery.skipped", lang)
        percent = (_detect_battery_capacity() if capacity is _AUTO
                   else capacity)
        if percent is None:
            return (False, translated("verify.battery.unreadable", lang))
        limited = (_detect_charge_limit_applied()
                   if charge_limit_applied is _AUTO
                   else bool(charge_limit_applied))
        if not limited:
            return False, translated(
                "verify.battery.no_limit", lang).format(percent=percent)
        return True, translated(
            "verify.battery.ok", lang).format(percent=percent)
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("disk-space")
def check_disk_space(locale=None, free_gib=_AUTO, minimum_gib=5):
    """Queda espacio libre suficiente en /."""
    lang = _current_locale(locale)
    try:
        free = ((shutil.disk_usage("/").free / (1024 ** 3))
                if free_gib is _AUTO else float(free_gib))
        if free >= float(minimum_gib):
            return True, translated(
                "verify.disk.ok", lang).format(free=f"{free:.1f}")
        return (False, translated(
            "verify.disk.low", lang).format(
                free=f"{free:.1f}", minimum=minimum_gib))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.disk.error", lang).format(detail=exc)


@check("bootloader")
def check_bootloader(locale=None, efi_system=_AUTO, efi_entries=_AUTO,
                     grub_config=_AUTO, systemd_entries=_AUTO,
                     expected=_AUTO):
    """El cargador esperado esta instalado y es arrancable."""
    lang = _current_locale(locale)
    try:
        efi = (_detect_efi_system() if efi_system is _AUTO
               else bool(efi_system))
        wanted = None if expected is _AUTO else expected
        if efi:
            entries = (_detect_efi_entries() if efi_entries is _AUTO
                       else _as_list(efi_entries))
            if entries:
                return True, translated("verify.bootloader.efi_ok", lang)
            return (False, translated(
                "verify.bootloader.efi_missing", lang))
        grub = (_detect_grub_config() if grub_config is _AUTO
                else bool(grub_config))
        loader = (_detect_systemd_entries() if systemd_entries is _AUTO
                  else _as_list(systemd_entries))
        installed = "grub" if grub else ("systemd-boot" if loader else None)
        if (wanted is not None and wanted != "any"
                and installed is not None and wanted != installed):
            return False, translated(
                "verify.bootloader.unexpected", lang).format(
                    expected=wanted, installed=installed)
        if installed == "grub":
            return True, translated("verify.bootloader.grub_ok", lang)
        if installed == "systemd-boot":
            return True, translated("verify.bootloader.systemd_ok", lang)
        return (False, translated("verify.bootloader.missing", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.bootloader.error", lang).format(detail=exc)


@check("dual-boot")
def check_dual_boot(locale=None, windows_present=_AUTO, efi_shared=_AUTO,
                    grub_installed=_AUTO, other_systems=_AUTO):
    """Junto a Windows, la EFI es compartible y GRUB esta instalado."""
    lang = _current_locale(locale)
    try:
        if other_systems is _AUTO:
            try:
                systems = _detect_os_prober_systems()
            except (FileNotFoundError, subprocess.SubprocessError, OSError):
                return True, translated("verify.dualboot.no_prober", lang)
        else:
            systems = [str(item) for item in _as_list(other_systems)]
        windows = (any("windows" in item.lower() for item in systems)
                   if windows_present is _AUTO else bool(windows_present))
        if not systems and not windows:
            return True, translated("verify.dualboot.none", lang)
        if not windows:
            return True, translated(
                "verify.dualboot.found", lang).format(count=len(systems))
        shared = (_detect_efi_shared() if efi_shared is _AUTO
                  else bool(efi_shared))
        if not shared:
            return (False, translated(
                "verify.dualboot.efi_not_shared", lang))
        grub = (_detect_grub_installed() if grub_installed is _AUTO
                else bool(grub_installed))
        if not grub:
            return False, translated("verify.dualboot.no_grub", lang)
        return True, translated(
            "verify.dualboot.found", lang).format(
                count=len(systems) if systems else 1)
    except (FileNotFoundError, subprocess.SubprocessError, OSError):
        return True, translated("verify.dualboot.no_prober", lang)
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.dualboot.error", lang).format(detail=exc)


@check("snapshots")
def check_snapshots(locale=None, is_btrfs=_AUTO, snapshots=_AUTO):
    """Si el disco es Btrfs, hay al menos un snapshot."""
    lang = _current_locale(locale)
    try:
        btrfs = (_detect_is_btrfs() if is_btrfs is _AUTO
                 else bool(is_btrfs))
        if not btrfs:
            return True, translated("verify.snapshots.skipped", lang)
        found = (_detect_snapshots() if snapshots is _AUTO
                 else _as_list(snapshots))
        if found is None:
            return False, translated(
                "verify.snapshots.no_tools", lang)
        if found:
            return True, translated(
                "verify.snapshots.ok", lang).format(count=len(found))
        return (False, translated("verify.snapshots.none", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("updates")
def check_updates(locale=None, repo_configured=_AUTO, key_trusted=_AUTO):
    """El repo nimbus esta configurado y su clave es de confianza."""
    lang = _current_locale(locale)
    try:
        repo = (_detect_repo_configured() if repo_configured is _AUTO
                else bool(repo_configured))
        if not repo:
            return (False, translated("verify.updates.no_repo", lang))
        trusted = (_detect_key_trusted() if key_trusted is _AUTO
                   else bool(key_trusted))
        if not trusted:
            return (False, translated("verify.updates.untrusted", lang))
        return (True, translated("verify.updates.ok", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("keyring")
def check_keyring(locale=None, populated=_AUTO, key_imported=_AUTO):
    """`pacman-key --populate nimbus` se ejecuto y la clave esta."""
    lang = _current_locale(locale)
    try:
        done = (_detect_keyring_populated() if populated is _AUTO
                else bool(populated))
        if not done:
            return (False, translated("verify.keyring.not_populated", lang))
        imported = (_detect_key_imported() if key_imported is _AUTO
                    else bool(key_imported))
        if not imported:
            return (False, translated("verify.keyring.not_imported", lang))
        return (True, translated("verify.keyring.ok", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("cpu")
def check_cpu(locale=None, cpuinfo_text=_AUTO):
    """La CPU llega al minimo x86-64 (SSE4.2); informa el nivel v1/v3/v4."""
    lang = _current_locale(locale)
    try:
        text = (_detect_cpuinfo() if cpuinfo_text is _AUTO
                else str(cpuinfo_text or ""))
        level = _cpu_level(_cpu_flags(text))
        if not level:
            return (False, translated("verify.cpu.too_old", lang))
        return True, translated(
            "verify.cpu.ok", lang).format(level=level)
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("video-amd")
def check_video_amd(locale=None, vendors=_AUTO, radv_present=_AUTO):
    """Con GPU AMD, RADV (vulkan-radeon) esta instalado."""
    lang = _current_locale(locale)
    try:
        table = (_detect_gpu_vendors() if vendors is _AUTO else vendors)
        nodes = _cards_with_vendor(table, _AMD_PCI_VENDOR)
        if not nodes:
            return True, translated("verify.amd.skipped", lang)
        present = (bool(_detect_vulkan_icds("radeon"))
                   if radv_present is _AUTO else bool(radv_present))
        if not present:
            return False, translated(
                "verify.amd.missing", lang).format(
                    nodes=", ".join(nodes))
        return True, translated(
            "verify.amd.ok", lang).format(nodes=", ".join(nodes))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("video-intel")
def check_video_intel(locale=None, vendors=_AUTO, anvil_present=_AUTO,
                      media_driver_present=_AUTO):
    """Con graficos Intel (incluido Arc), anvil e intel-media-driver."""
    lang = _current_locale(locale)
    try:
        table = (_detect_gpu_vendors() if vendors is _AUTO else vendors)
        nodes = _cards_with_vendor(table, _INTEL_PCI_VENDOR)
        if not nodes:
            return True, translated("verify.intel.skipped", lang)
        anvil = (bool(_detect_vulkan_icds("intel"))
                 if anvil_present is _AUTO else bool(anvil_present))
        media = (_detect_media_driver() if media_driver_present is _AUTO
                 else bool(media_driver_present))
        missing = []
        if not anvil:
            missing.append("anvil (Vulkan)")
        if not media:
            missing.append("intel-media-driver")
        if missing:
            return False, translated(
                "verify.intel.missing", lang).format(
                    nodes=", ".join(nodes), what=" y ".join(missing))
        return True, translated(
            "verify.intel.ok", lang).format(nodes=", ".join(nodes))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("nvidia")
def check_nvidia(locale=None, has_nvidia=_AUTO, driver=_AUTO,
                 vendors=_AUTO):
    """Con hardware NVIDIA, hay un controlador ligado (nvidia/nouveau)."""
    lang = _current_locale(locale)
    try:
        if has_nvidia is _AUTO:
            table = (_detect_gpu_vendors() if vendors is _AUTO
                     else vendors)
            present = bool(_cards_with_vendor(table, _NVIDIA_PCI_VENDOR))
        else:
            present = bool(has_nvidia)
        if not present:
            return True, translated("verify.nvidia.skipped", lang)
        found = (_detect_nvidia_driver() if driver is _AUTO else driver)
        if not found:
            return (False, translated("verify.nvidia.missing", lang))
        return True, translated(
            "verify.nvidia.ok", lang).format(driver=found)
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("wifi")
def check_wifi(locale=None, wireless=_AUTO):
    """Cada WiFi presente usa un controlador de la matriz §4.13."""
    lang = _current_locale(locale)
    try:
        table = (_detect_wireless() if wireless is _AUTO
                 else dict(wireless or {}))
        if not table:
            return True, translated("verify.wifi.skipped", lang)
        iface = sorted(table)[0]
        driver = table[iface]
        if _wifi_driver_supported(driver):
            return True, translated(
                "verify.wifi.ok", lang).format(iface=iface, driver=driver)
        return False, translated(
            "verify.wifi.unknown_driver", lang).format(
                iface=iface, driver=driver)
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("codecs")
def check_codecs(locale=None, ffmpeg=_AUTO, encoders=_AUTO):
    """ffmpeg esta instalado con H.264 (libx264) y AAC."""
    lang = _current_locale(locale)
    try:
        binary = (_detect_ffmpeg() if ffmpeg is _AUTO else ffmpeg)
        if not binary:
            return False, translated(
                "verify.codecs.missing", lang).format(what="ffmpeg")
        text = (_detect_encoders(binary) if encoders is _AUTO
                else str(encoders or ""))
        missing = []
        if "libx264" not in text:
            missing.append("H.264 (libx264)")
        if "aac" not in text:
            missing.append("AAC")
        if missing:
            return False, translated(
                "verify.codecs.missing", lang).format(
                    what=" y ".join(missing))
        return (True, translated("verify.codecs.ok", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("printers")
def check_printers(locale=None, cups=_AUTO, ipp_usb=_AUTO):
    """CUPS e ipp-usb instalados (impresion sin drivers de fabricante)."""
    lang = _current_locale(locale)
    try:
        has_cups = (_detect_cups() if cups is _AUTO else bool(cups))
        has_ipp = (_detect_ipp_usb() if ipp_usb is _AUTO
                   else bool(ipp_usb))
        missing = []
        if not has_cups:
            missing.append("CUPS")
        if not has_ipp:
            missing.append("ipp-usb")
        if missing:
            return False, translated(
                "verify.printers.missing", lang).format(
                    what=" y ".join(missing))
        return (True, translated("verify.printers.ok", lang))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


@check("laptop")
def check_laptop(locale=None, chassis_type=_AUTO, backlight=_AUTO,
                 lid_present=_AUTO):
    """En portatil, hay control de brillo e interruptor de tapa."""
    lang = _current_locale(locale)
    try:
        chassis = (_detect_chassis_type() if chassis_type is _AUTO
                   else chassis_type)
        try:
            kind = int(str(chassis).strip())
        except (TypeError, ValueError):
            kind = -1
        if kind not in LAPTOP_CHASSIS_TYPES:
            return True, translated("verify.laptop.skipped", lang)
        lights = (_detect_backlight() if backlight is _AUTO
                  else [str(item) for item in _as_list(backlight)])
        lid = (_detect_lid_present() if lid_present is _AUTO
               else bool(lid_present))
        missing = []
        if not lights:
            missing.append(translated("verify.laptop.no_backlight", lang))
        if not lid:
            missing.append(translated("verify.laptop.no_lid", lang))
        if missing:
            return False, translated(
                "verify.laptop.missing", lang).format(
                    what=" y ".join(missing))
        return True, translated(
            "verify.laptop.ok", lang).format(backlight=", ".join(lights))
    except Exception as exc:  # nunca debe lanzar
        return False, translated(
            "verify.internal_error", lang).format(detail=exc)


def run_all_checks(locale=None):
    """Ejecuta todas las comprobaciones sin que ninguna aborte el resto."""
    results = []
    for name, fn in CHECKS:
        try:
            if locale is None:
                ok, message = fn()
            else:
                try:
                    ok, message = fn(locale)
                except TypeError:
                    ok, message = fn()
            results.append((name, bool(ok), str(message)))
        except Exception as exc:  # cinturon y tirantes
            lang = _current_locale(locale)
            results.append((name, False,
                            translated(
                                "verify.internal_error",
                                lang).format(detail=exc)))
    return results


def pretty_name(locale=None):
    return translated("verify.pretty_name", _current_locale(locale))


def pretty_status_message(locale=None):
    return translated("verify.pretty_status", _current_locale(locale))


def serializable_results(results):
    """Convierte [(name, ok, message)] a {name: [ok, message]}.

    ``dict(results)`` reventaria con tuplas de 3 elementos (ValueError);
    este formato es seguro para globalstorage y serializable a JSON.
    """
    return {name: [ok, message] for name, ok, message in results}


def run():
    """Punto de entrada de Calamares: informa, nunca aborta.

    Siempre devuelve None: en Calamares, devolver cualquier otro valor
    marca el job como fallido. Los avisos se registran con utils.warning.
    """
    results = run_all_checks()
    for name, ok, message in results:
        if libcalamares is not None:
            if ok:
                libcalamares.utils.debug(f"verify {name}: {message}")
            else:
                libcalamares.utils.warning(f"verify {name}: {message}")
        elif not ok:
            logger.warning("verify %s: %s", name, message)
    if libcalamares is not None:
        libcalamares.globalstorage.insert(
            "nimbusVerifyResults", serializable_results(results))
    return None
