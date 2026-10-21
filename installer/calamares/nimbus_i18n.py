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
        "appearance.theme.light": "Claro",
        "appearance.theme.dark": "Oscuro",
        "appearance.theme.auto": "Automático",
        "appearance.accent.invalid": (
            "Acento no válido: {value}. "
            "Usa un hexadecimal de 6 dígitos (p. ej. 007AFF)."
        ),
        "appearance.mode.invalid": (
            "Modo no válido: {mode} (usa {valid})."
        ),
        "appearance.theme.invalid": (
            "Tema no válido: {label} (usa {valid})."
        ),
        "appearance.wallpaper.invalid": (
            "Fondo no válido: {value}. Usa un nombre de una sola línea "
            "(letras, números, puntos, guiones)."
        ),
        "software.pretty_name": "Software",
        "software.pretty_status": "Instalando el software seleccionado.",
        "software.no_connectivity": (
            "No hay conexión a Internet. Nimbus necesita conexión para "
            "descargar los drivers y las aplicaciones que elijas."
        ),
        "software.unknown_profile": (
            "perfil de software desconocido: {profile} (se omite)"
        ),
        "dualboot.pretty_name": "Arranque dual",
        "dualboot.pretty_status": "Preparando el arranque dual con Windows.",
        "dualboot.fastboot.blocked": (
            "Fast Boot de Windows esta activo. Con el inicio rapido "
            "GRUB no aparece y Windows puede no arrancar. Desactivalo "
            "antes de continuar: en Windows ejecuta "
            "`powercfg /h off` como administrador y desactiva "
            "Fast Boot en la BIOS/UEFI."
        ),
        "dualboot.windows.found": "Windows detectado: se instalara junto a el.",
        "dualboot.windows.none": "Sin Windows detectable: instalacion unica.",
        "dualboot.backup.ok": "Tabla de particiones respaldada en {dest}.",
        "dualboot.backup.error": (
            "No se pudo respaldar la tabla de particiones ({detail})."
        ),
        "dualboot.efi.reuse": (
            "Se reutilizara la particion EFI existente en {efi}."
        ),
        "dualboot.efi.create": "No hay particion EFI: se creara una nueva.",
        "dualboot.bootloader.grub": "grub",
        "dualboot.bootloader.default": "systemd-boot",
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
        "verify.gpu.ok": "GPU lista: {nodes} con controlador {driver}.",
        "verify.gpu.no_driver": (
            "Hay render ({nodes}) pero sin controlador. Instala el driver "
            "de tu GPU (p. ej. mesa o nvidia-open-dkms) y reinicia."
        ),
        "verify.hybrid.on_demand": "Graficos hibridos en modo on-demand.",
        "verify.hybrid.single": (
            "Omitido: una sola GPU, no hay graficos hibridos."
        ),
        "verify.hybrid.not_ondemand": (
            "Hibrido en modo {mode}: cambialo a on-demand (p. ej. "
            "supergfxctl -m Hybrid o prime-select on-demand)."
        ),
        "verify.hybrid.unknown": "desconocido",
        "verify.audio.ok": "Audio listo: {device} con PipeWire activo.",
        "verify.audio.pipewire_inactive": (
            "Hay audio ({device}) pero PipeWire no esta activo. Activalo: "
            "systemctl --user enable --now pipewire pipewire-pulse."
        ),
        "verify.bluetooth.ok": "Bluetooth activo.",
        "verify.bluetooth.skipped": (
            "Omitido: este equipo no tiene bluetooth."
        ),
        "verify.bluetooth.inactive": (
            "Hay bluetooth pero el servicio esta parado. Activalo: "
            "systemctl enable --now bluetooth."
        ),
        "verify.webcam.unavailable": (
            "Hay camara ({device}) pero no esta disponible. Revisa los "
            "permisos o si otra aplicacion la esta usando."
        ),
        "verify.suspend.no_s2idle": (
            "Hay suspension ({modes}) pero s2idle no esta disponible. "
            "Revisa el firmware o el kernel."
        ),
        "verify.battery.ok": (
            "Bateria al {percent}% con limite de carga aplicado."
        ),
        "verify.battery.skipped": "Omitido: este equipo no tiene bateria.",
        "verify.battery.unreadable": (
            "Hay bateria pero no se lee el porcentaje. Revisa upower "
            "o el driver ACPI."
        ),
        "verify.battery.no_limit": (
            "Bateria al {percent}% sin limite de carga. Aplica el limite "
            "(p. ej. 80%) en el centro de control."
        ),
        "verify.bootloader.unexpected": (
            "Se esperaba {expected} pero hay {installed}. "
            "Reinstala el gestor esperado."
        ),
        "verify.dualboot.efi_not_shared": (
            "Hay Windows pero la particion EFI no es compartible. Usa una "
            "sola ESP FAT32 montada en /boot/efi."
        ),
        "verify.dualboot.no_grub": (
            "Hay Windows pero GRUB no esta instalado. Instala GRUB con "
            "os-prober activado."
        ),
        "verify.snapshots.ok": "Snapshots Btrfs disponibles ({count}).",
        "verify.snapshots.skipped": "Omitido: el disco no es Btrfs.",
        "verify.snapshots.none": (
            "Disco Btrfs sin snapshots. Crea uno (p. ej. snapper -c root "
            "create -d post-instalacion)."
        ),
        "verify.updates.ok": "Repo nimbus configurado con clave de confianza.",
        "verify.updates.no_repo": (
            "Falta el repo nimbus en pacman.conf. Anade [nimbus] y sincroniza."
        ),
        "verify.updates.untrusted": (
            "El repo nimbus esta pero su clave no es de confianza. Firma la "
            "clave o reinstala nimbus-keyring."
        ),
        "verify.keyring.ok": "Keyring nimbus poblado y clave importada.",
        "verify.keyring.not_populated": (
            "El keyring nimbus no esta poblado. "
            "Ejecuta pacman-key --populate nimbus."
        ),
        "verify.keyring.not_imported": (
            "Keyring poblado pero la clave nimbus no esta importada. "
            "Ejecuta pacman-key --populate nimbus y verifica."
        ),
        "postinstall.pretty_name": "Post-instalación",
        "postinstall.pretty_status": "Dejando el sistema listo para usar.",
        "postinstall.module.failed": (
            "{step}: falló ({detail}). Acción: {hint}."
        ),
        "postinstall.module.no_tool": (
            "no se pudo ejecutar nimbus-postinstall ({detail}). "
            "Acción: repite a mano nimbus-postinstall --root {root} "
            "y revisa cada paso."
        ),
    },
    "en": {
        "appearance.pretty_name": "Appearance",
        "appearance.pretty_status": "Setting up the Nimbus appearance.",
        "appearance.theme.light": "Light",
        "appearance.theme.dark": "Dark",
        "appearance.theme.auto": "Automatic",
        "appearance.accent.invalid": (
            "Invalid accent: {value}. "
            "Use a 6-digit hex code (e.g. 007AFF)."
        ),
        "appearance.mode.invalid": (
            "Invalid mode: {mode} (use {valid})."
        ),
        "appearance.theme.invalid": (
            "Invalid theme: {label} (use {valid})."
        ),
        "appearance.wallpaper.invalid": (
            "Invalid wallpaper: {value}. Use a single-line name "
            "(letters, digits, dots, dashes)."
        ),
        "software.pretty_name": "Software",
        "software.pretty_status": "Installing the selected software.",
        "software.no_connectivity": (
            "No Internet connection. Nimbus needs a connection to "
            "download the drivers and applications you choose."
        ),
        "software.unknown_profile": (
            "unknown software profile: {profile} (skipped)"
        ),
        "dualboot.pretty_name": "Dual boot",
        "dualboot.pretty_status": "Preparing dual boot with Windows.",
        "dualboot.fastboot.blocked": (
            "Windows Fast Boot is enabled. With fast startup GRUB "
            "will not show and Windows may fail to boot. Disable it "
            "before continuing: in Windows run "
            "`powercfg /h off` as administrator and disable "
            "Fast Boot in the BIOS/UEFI."
        ),
        "dualboot.windows.found": "Windows detected: installing alongside it.",
        "dualboot.windows.none": "No Windows detected: single installation.",
        "dualboot.backup.ok": "Partition table backed up to {dest}.",
        "dualboot.backup.error": (
            "Could not back up the partition table ({detail})."
        ),
        "dualboot.efi.reuse": "Reusing the existing EFI partition at {efi}.",
        "dualboot.efi.create": "No EFI partition: a new one will be created.",
        "dualboot.bootloader.grub": "grub",
        "dualboot.bootloader.default": "systemd-boot",
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
        "verify.gpu.ok": "GPU ready: {nodes} with {driver} driver.",
        "verify.gpu.no_driver": (
            "Render nodes ({nodes}) found but no driver. Install your GPU "
            "driver (e.g. mesa or nvidia-open-dkms) and reboot."
        ),
        "verify.hybrid.on_demand": "Hybrid graphics in on-demand mode.",
        "verify.hybrid.single": (
            "Skipped: single GPU, no hybrid graphics."
        ),
        "verify.hybrid.not_ondemand": (
            "Hybrid in {mode} mode: switch to on-demand (e.g. "
            "supergfxctl -m Hybrid or prime-select on-demand)."
        ),
        "verify.hybrid.unknown": "unknown",
        "verify.audio.ok": "Audio ready: {device} with PipeWire active.",
        "verify.audio.pipewire_inactive": (
            "Audio device ({device}) found but PipeWire is not active. "
            "Enable it: systemctl --user enable --now pipewire pipewire-pulse."
        ),
        "verify.bluetooth.ok": "Bluetooth active.",
        "verify.bluetooth.skipped": "Skipped: this machine has no bluetooth.",
        "verify.bluetooth.inactive": (
            "Bluetooth hardware found but the service is stopped. "
            "Enable it: systemctl enable --now bluetooth."
        ),
        "verify.webcam.unavailable": (
            "Camera ({device}) found but unavailable. Check permissions "
            "or whether another application is using it."
        ),
        "verify.suspend.no_s2idle": (
            "Suspend ({modes}) declared but s2idle is not available. "
            "Check firmware or kernel."
        ),
        "verify.battery.ok": "Battery at {percent}% with charge limit applied.",
        "verify.battery.skipped": "Skipped: this machine has no battery.",
        "verify.battery.unreadable": (
            "Battery found but percentage is unreadable. Check upower "
            "or the ACPI driver."
        ),
        "verify.battery.no_limit": (
            "Battery at {percent}% with no charge limit. Apply the limit "
            "(e.g. 80%) in the control center."
        ),
        "verify.bootloader.unexpected": (
            "Expected {expected} but found {installed}. "
            "Reinstall the expected bootloader."
        ),
        "verify.dualboot.efi_not_shared": (
            "Windows found but the EFI partition is not shareable. Use a "
            "single FAT32 ESP mounted at /boot/efi."
        ),
        "verify.dualboot.no_grub": (
            "Windows found but GRUB is not installed. Install GRUB with "
            "os-prober enabled."
        ),
        "verify.snapshots.ok": "Btrfs snapshots available ({count}).",
        "verify.snapshots.skipped": "Skipped: the disk is not Btrfs.",
        "verify.snapshots.none": (
            "Btrfs disk with no snapshots. Create one (e.g. snapper -c root "
            "create -d post-install)."
        ),
        "verify.updates.ok": "Nimbus repo configured with trusted key.",
        "verify.updates.no_repo": (
            "Missing nimbus repo in pacman.conf. Add [nimbus] and sync."
        ),
        "verify.updates.untrusted": (
            "Nimbus repo present but its key is untrusted. Sign the key "
            "or reinstall nimbus-keyring."
        ),
        "verify.keyring.ok": "Nimbus keyring populated and key imported.",
        "verify.keyring.not_populated": (
            "Nimbus keyring not populated. "
            "Run pacman-key --populate nimbus."
        ),
        "verify.keyring.not_imported": (
            "Keyring populated but the nimbus key is not imported. "
            "Run pacman-key --populate nimbus and verify."
        ),
        "postinstall.pretty_name": "Post-install",
        "postinstall.pretty_status": "Getting the system ready to use.",
        "postinstall.module.failed": (
            "{step}: failed ({detail}). Action: {hint}."
        ),
        "postinstall.module.no_tool": (
            "could not run nimbus-postinstall ({detail}). "
            "Action: rerun nimbus-postinstall --root {root} by hand "
            "and review each step."
        ),
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
