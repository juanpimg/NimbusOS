# SPDX-License-Identifier: GPL-3.0-or-later
"""Modulo Calamares de seleccion de software de Nimbus.

Recoge los perfiles marcados, comprueba la conectividad a Internet antes
de empezar y traduce cada perfil a su lista de paquetes, que instala con
``pacman -S --needed --noconfirm`` via target_env_command.
"""

import socket
import warnings

try:  # Calamares provee libcalamares en el ISO live; ausente en CI/test.
    import libcalamares
except ImportError:  # pragma: no cover - entorno sin Calamares
    libcalamares = None

try:
    from nimbus_i18n import active_locale, translated
except ImportError:  # cargado por ruta (Calamares/test) sin paquete
    import importlib.util as _importlib_util
    import pathlib as _pathlib
    import sys as _sys

    _i18n_module = _sys.modules.get("nimbus_i18n")
    if _i18n_module is None:
        _i18n_path = (
            _pathlib.Path(__file__).resolve().parents[2] / "nimbus_i18n.py"
        )
        _i18n_spec = _importlib_util.spec_from_file_location(
            "nimbus_i18n", _i18n_path)
        _i18n_module = _importlib_util.module_from_spec(_i18n_spec)
        _sys.modules["nimbus_i18n"] = _i18n_module
        _i18n_spec.loader.exec_module(_i18n_module)
    active_locale = _i18n_module.active_locale
    translated = _i18n_module.translated

NO_CONNECTIVITY_KEY = "software.no_connectivity"
NO_CONNECTIVITY_MESSAGE = translated(NO_CONNECTIVITY_KEY)

CONNECTIVITY_HOST = ("8.8.8.8", 53)
CONNECTIVITY_TIMEOUT = 5

# Perfil -> paquetes. Debe mantenerse sincronizado con nimbus-software.conf.
PROFILE_PACKAGES = {
    "base": [
        "gui", "nimbus-shell", "nimbus-dots", "kitty", "foot", "nautilus",
        "firefox", "evince", "mpv", "udisks2", "gvfs", "xdg-user-dirs",
    ],
    "gaming": [
        "steam", "proton-ge", "proton-cachyos", "gamescope", "gamemode",
        "mangohud", "vkbasalt", "heroic", "lutris", "bottles",
        "protonup-qt", "lib32-vulkan", "vkd3d-proton",
    ],
    "creative": [
        "gimp", "krita", "inkscape", "kdenlive", "blender", "obs-studio",
    ],
    "development": [
        "code", "git", "python", "nodejs", "docker", "podman",
    ],
    "communication": [
        "discord", "telegram", "signal", "whatsapp",
    ],
    "office": [
        "libreoffice-fresh", "onlyoffice-desktopeditors",
    ],
}


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


def no_connectivity_message(locale=None):
    """Mensaje accionable de falta de red en el idioma efectivo."""
    return translated(NO_CONNECTIVITY_KEY, _current_locale(locale))


def packages_for_profiles(profiles, locale=None):
    """Traduce perfiles marcados a la lista ordenada y sin duplicados.

    Los perfiles desconocidos se omiten con un aviso: nunca fallan
    en silencio.
    """
    packages = []
    for profile in profiles:
        if profile not in PROFILE_PACKAGES:
            message = translated(
                "software.unknown_profile",
                _current_locale(locale)).format(profile=repr(profile))
            if libcalamares is not None:
                libcalamares.utils.warning(message)
            warnings.warn(message, stacklevel=2)
            continue
        for package in PROFILE_PACKAGES[profile]:
            if package not in packages:
                packages.append(package)
    return packages


def check_connectivity(timeout=CONNECTIVITY_TIMEOUT):
    """Comprueba la conectividad a Internet antes de empezar.

    En el instalador usa libcalamares.utils.check_network_connection();
    fuera de Calamares (tests) hace una conexion TCP ligera.
    """
    if libcalamares is not None:
        try:
            return bool(libcalamares.utils.check_network_connection())
        except Exception:  # cualquier error del framework -> via socket
            pass
    try:
        socket.create_connection(CONNECTIVITY_HOST, timeout=timeout).close()
        return True
    except OSError:
        return False


def read_selected_profiles():
    """Lee los perfiles marcados desde el globalstorage de Calamares."""
    if libcalamares is None:
        return ["base"]
    storage = libcalamares.globalstorage
    selected = storage.value("nimbusSoftwareProfiles")
    if not selected:
        return ["base"]
    if isinstance(selected, str):
        return [p.strip() for p in selected.split(",") if p.strip()]
    return list(selected)


# Clave de globalstorage donde la pagina QML guarda si el usuario acepto
# continuar solo con el perfil base cuando no hay conexion.
OFFLINE_ACCEPT_KEY = "nimbusSoftwareOfflineAccepted"


def read_offline_accepted():
    """Lee si el usuario acepto continuar solo con base sin red.

    La pagina QML del modulo muestra el mensaje accionable y, si el
    usuario pulsa "Continuar solo con base", guarda True en
    OFFLINE_ACCEPT_KEY del globalstorage antes de avanzar.
    """
    if libcalamares is None:
        return False
    value = libcalamares.globalstorage.value(OFFLINE_ACCEPT_KEY)
    if isinstance(value, str):
        return value.strip().lower() in ("1", "true", "yes")
    return bool(value)


def connectivity_gate(accepted_offline=False, locale=None):
    """Puerta de conectividad: decide con que perfiles continuar.

    Si hay red, continua con los perfiles elegidos. Si no hay red,
    muestra el mensaje accionable y solo permite continuar con el
    perfil ``base`` cuando el usuario lo acepta; en caso contrario
    senala que la instalacion no debe seguir descargando software.
    """
    effective = _current_locale(locale)
    selected = read_selected_profiles()
    if check_connectivity():
        return {"online": True, "profiles": selected, "message": ""}
    if accepted_offline:
        return {"online": False, "profiles": ["base"],
                "message": translated(NO_CONNECTIVITY_KEY, effective)}
    return {"online": False, "profiles": [],
            "message": translated(NO_CONNECTIVITY_KEY, effective)}


def install_packages(packages, runner=None):
    """Instala paquetes con pacman en el sistema destino."""
    if not packages:
        return 0
    command = ["pacman", "-S", "--needed", "--noconfirm", *packages]
    if runner is not None:
        result = runner(command)
        return getattr(result, "returncode", 0)
    if libcalamares is not None:
        return libcalamares.utils.target_env_command(*command)
    import subprocess  # pragma: no cover - solo instalador real sin lib
    completed = subprocess.run(command, check=False)
    return completed.returncode


def pretty_name(locale=None):
    return translated("software.pretty_name", _current_locale(locale))


def pretty_status_message(locale=None):
    return translated("software.pretty_status", _current_locale(locale))


def run():
    """Punto de entrada de Calamares."""
    # La aceptacion la escribe la pagina QML en el globalstorage; sin
    # leerla aqui la rama de solo-base seria inalcanzable en el flujo real.
    locale = _current_locale()
    gate = connectivity_gate(accepted_offline=read_offline_accepted(),
                             locale=locale)
    if not gate["online"] and not gate["profiles"]:
        message = translated(NO_CONNECTIVITY_KEY, locale)
        if libcalamares is not None:
            libcalamares.utils.warning(message)
        return message
    packages = packages_for_profiles(gate["profiles"])
    install_packages(packages)
    return None
