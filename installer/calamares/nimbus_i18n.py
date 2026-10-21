# SPDX-License-Identifier: GPL-3.0-or-later
"""Pequeño mecanismo de traducciones ES/EN para el instalador de Nimbus.

Sigue el mismo estilo que ``shell/src/Nimbus/Translations.qml``: una tabla
ES/EN y una funcion de busqueda con fallback al ingles. No depende de
``libcalamares`` para que los modulos sigan siendo importables en CI/test.

Uso::

    from nimbus_i18n import translated

    pretty = translated("appearance.pretty_name", locale)
    # con huecos dinamicos:
    msg = translated("verify.disk.ok", locale).format(free=f"{free_gib:.1f}")

``locale`` puede ser ``"es"``, ``"en"`` o un locale completo como
``"es_ES.UTF-8"``; solo se usa la parte del idioma. Si ``locale`` es None,
se detecta con :func:`active_locale` (``LC_ALL``/``LANG``/``LANGUAGE`` o
ajuste del instalador pasado explicitamente). Si no se puede determinar,
ingles.
"""

import os

SUPPORTED_LOCALES = ("es", "en")
DEFAULT_LOCALE = "en"

TRANSLATIONS = {
    "es": {
        "appearance.pretty_name": "Apariencia",
        "appearance.pretty_status": "Configurando la apariencia de Nimbus.",
        "software.pretty_name": "Software",
        "software.pretty_status": "Instalando el software seleccionado.",
        "software.no_connectivity": (
            "No hay conexión a Internet. Nimbus necesita conexión para "
            "descargar los drivers y las aplicaciones que elijas."
        ),
        "software.unknown_profile": (
            "perfil de software desconocido: {profile} (se omite)"
        ),
        "verify.pretty_name": "Verificación",
        "verify.pretty_status": "Verificando la instalación.",
        "verify.gpu.drm_ok": "GPU detectada en /sys/class/drm.",
        "verify.gpu.dri_ok": "GPU detectada en /dev/dri.",
        "verify.gpu.missing": (
            "No se detecto GPU. Si usas NVIDIA, instala "
            "nvidia-open-dkms y reinicia."
        ),
        "verify.gpu.error": (
            "No se pudo comprobar la GPU ({detail}). Revisala a mano."
        ),
        "verify.audio.cards_ok": "Tarjeta de sonido detectada.",
        "verify.audio.snd_ok": "Dispositivos de audio presentes en /dev/snd.",
        "verify.audio.missing": (
            "No se detecto audio. Comprueba que PipeWire esta "
            "activo: systemctl --user status pipewire."
        ),
        "verify.audio.error": (
            "No se pudo comprobar el audio ({detail}). Revisalo a mano."
        ),
        "verify.network.ok": "Red operativa en {iface}.",
        "verify.network.missing": (
            "Sin red operativa. Conecta un cable o configura "
            "el Wi-Fi en el centro de control."
        ),
        "verify.network.error": (
            "No se pudo comprobar la red ({detail}). Revisala a mano."
        ),
        "verify.webcam.found": "Camara detectada en {device}.",
        "verify.webcam.none": "Sin camara detectada (opcional, se omite).",
        "verify.webcam.error": "No se pudo comprobar la camara ({detail}).",
        "verify.suspend.ok": "Suspension disponible.",
        "verify.suspend.missing": (
            "Suspension no disponible. Revisa la swap "
            "o la configuracion de energia."
        ),
        "verify.suspend.error": (
            "No se pudo comprobar la suspension ({detail})."
        ),
        "verify.disk.ok": "Espacio libre suficiente ({free} GiB).",
        "verify.disk.low": (
            "Solo quedan {free} GiB libres. "
            "Libera espacio (minimo {minimum} GiB)."
        ),
        "verify.disk.error": "No se pudo comprobar el disco ({detail}).",
        "verify.bootloader.efi_ok": "Entradas EFI del gestor instaladas.",
        "verify.bootloader.efi_missing": (
            "Arrancaste en modo EFI pero no hay entradas "
            "en /boot/efi/EFI. Reinstala el gestor."
        ),
        "verify.bootloader.grub_ok": "GRUB instalado (arranque BIOS).",
        "verify.bootloader.systemd_ok": "systemd-boot instalado.",
        "verify.bootloader.missing": (
            "No se encontro configuracion del gestor. "
            "Reinstala GRUB o systemd-boot."
        ),
        "verify.bootloader.error": (
            "No se pudo comprobar el gestor ({detail})."
        ),
        "verify.dualboot.found": "Arranque dual detectado ({count} sistemas).",
        "verify.dualboot.none": "Sin otros sistemas (instalacion unica).",
        "verify.dualboot.no_prober": (
            "os-prober no disponible; se omite el aviso dual-boot."
        ),
        "verify.dualboot.error": (
            "No se pudo comprobar dual-boot ({detail})."
        ),
        "verify.internal_error": "Fallo interno de la comprobacion ({detail}).",
    },
    "en": {
        "appearance.pretty_name": "Appearance",
        "appearance.pretty_status": "Setting up the Nimbus appearance.",
        "software.pretty_name": "Software",
        "software.pretty_status": "Installing the selected software.",
        "software.no_connectivity": (
            "No Internet connection. Nimbus needs a connection to "
            "download the drivers and applications you choose."
        ),
        "software.unknown_profile": (
            "unknown software profile: {profile} (skipped)"
        ),
        "verify.pretty_name": "Verification",
        "verify.pretty_status": "Verifying the installation.",
        "verify.gpu.drm_ok": "GPU detected at /sys/class/drm.",
        "verify.gpu.dri_ok": "GPU detected at /dev/dri.",
        "verify.gpu.missing": (
            "No GPU detected. If you use NVIDIA, install "
            "nvidia-open-dkms and reboot."
        ),
        "verify.gpu.error": (
            "Could not check the GPU ({detail}). Please check it manually."
        ),
        "verify.audio.cards_ok": "Sound card detected.",
        "verify.audio.snd_ok": "Audio devices present at /dev/snd.",
        "verify.audio.missing": (
            "No audio detected. Check that PipeWire is "
            "active: systemctl --user status pipewire."
        ),
        "verify.audio.error": (
            "Could not check audio ({detail}). Please check it manually."
        ),
        "verify.network.ok": "Network up on {iface}.",
        "verify.network.missing": (
            "No working network. Plug in a cable or set up "
            "Wi-Fi in the control center."
        ),
        "verify.network.error": (
            "Could not check the network ({detail}). "
            "Please check it manually."
        ),
        "verify.webcam.found": "Camera detected at {device}.",
        "verify.webcam.none": "No camera detected (optional, skipped).",
        "verify.webcam.error": "Could not check the camera ({detail}).",
        "verify.suspend.ok": "Suspend available.",
        "verify.suspend.missing": (
            "Suspend not available. Check swap "
            "or power settings."
        ),
        "verify.suspend.error": "Could not check suspend ({detail}).",
        "verify.disk.ok": "Enough free space ({free} GiB).",
        "verify.disk.low": (
            "Only {free} GiB left. "
            "Free up space (minimum {minimum} GiB)."
        ),
        "verify.disk.error": "Could not check the disk ({detail}).",
        "verify.bootloader.efi_ok": "Bootloader EFI entries installed.",
        "verify.bootloader.efi_missing": (
            "You booted in EFI mode but there are no entries "
            "in /boot/efi/EFI. Reinstall the bootloader."
        ),
        "verify.bootloader.grub_ok": "GRUB installed (BIOS boot).",
        "verify.bootloader.systemd_ok": "systemd-boot installed.",
        "verify.bootloader.missing": (
            "No bootloader configuration found. "
            "Reinstall GRUB or systemd-boot."
        ),
        "verify.bootloader.error": (
            "Could not check the bootloader ({detail})."
        ),
        "verify.dualboot.found": "Dual boot detected ({count} systems).",
        "verify.dualboot.none": "No other systems (single installation).",
        "verify.dualboot.no_prober": (
            "os-prober not available; skipping dual-boot notice."
        ),
        "verify.dualboot.error": "Could not check dual-boot ({detail}).",
        "verify.internal_error": "Internal check failure ({detail}).",
    },
}

# Alias con el nombre que usa el shell (``table``) por si alguien lo busca.
TABLE = TRANSLATIONS


def _base_language(value):
    """Extrae ``es`` de ``es_ES.UTF-8``/``es-ES``/``es:en``/``ES``."""
    text = str(value).strip().split(":")[0]
    text = text.replace("_", "-")
    lang = text.split("-")[0].split(".")[0].split("@")[0].strip().lower()
    return lang


def normalize_locale(locale):
    """Normaliza cualquier locale a ``es`` o ``en`` (desconocido -> ``en``)."""
    if locale is None:
        return DEFAULT_LOCALE
    if _base_language(locale) in SUPPORTED_LOCALES:
        return _base_language(locale)
    return DEFAULT_LOCALE


def active_locale(env=None):
    """Idioma activo: ``LC_ALL``/``LANG``/``LANGUAGE`` o ingles.

    ``env`` es un mapping opcional (por defecto ``os.environ``) para
    poder testear sin tocar el entorno. Solo ``es`` se devuelve como
    espanol; cualquier otro valor o la ausencia caen a ingles.
    """
    source = os.environ if env is None else env
    for var in ("LC_ALL", "LANG", "LANGUAGE"):
        try:
            value = source.get(var)
        except AttributeError:
            value = None
        if not value:
            continue
        if _base_language(value) in SUPPORTED_LOCALES:
            return _base_language(value)
        # Variable fijada pero idioma no soportado (p. ej. "C.UTF-8")
        # -> ingles.
        return DEFAULT_LOCALE
    return DEFAULT_LOCALE


def translated(key, locale=None):
    """Devuelve la cadena del idioma activo con fallback al ingles.

    - Si ``locale`` es None se usa :func:`active_locale`.
    - Un locale desconocido cae a ingles.
    - Una clave inexistente en ambos idiomas devuelve la propia clave,
      para que nunca se vea una clave suelta en pantalla... mejor dicho,
      para que al menos se vea algo legible en vez de romper.
    """
    lang = normalize_locale(
        locale if locale is not None else active_locale())
    table = TRANSLATIONS.get(lang, {})
    if key in table:
        return table[key]
    if key in TRANSLATIONS["en"]:
        return TRANSLATIONS["en"][key]
    return key


def available_keys():
    """Claves con traduccion ES y EN (ordenadas)."""
    return sorted(TRANSLATIONS["en"])
