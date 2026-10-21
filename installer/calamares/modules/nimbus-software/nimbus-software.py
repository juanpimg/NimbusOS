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

NO_CONNECTIVITY_MESSAGE = (
    "No hay conexión a Internet. Nimbus necesita conexión para descargar "
    "los drivers y las aplicaciones que elijas."
)

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


def packages_for_profiles(profiles):
    """Traduce perfiles marcados a la lista ordenada y sin duplicados.

    Los perfiles desconocidos se omiten con un aviso: nunca fallan
    en silencio.
    """
    packages = []
    for profile in profiles:
        if profile not in PROFILE_PACKAGES:
            message = f"perfil de software desconocido: {profile!r} (se omite)"
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


def connectivity_gate(accepted_offline=False):
    """Puerta de conectividad: decide con que perfiles continuar.

    Si hay red, continua con los perfiles elegidos. Si no hay red,
    muestra el mensaje accionable y solo permite continuar con el
    perfil ``base`` cuando el usuario lo acepta; en caso contrario
    senala que la instalacion no debe seguir descargando software.
    """
    selected = read_selected_profiles()
    if check_connectivity():
        return {"online": True, "profiles": selected, "message": ""}
    if accepted_offline:
        return {"online": False, "profiles": ["base"],
                "message": NO_CONNECTIVITY_MESSAGE}
    return {"online": False, "profiles": [],
            "message": NO_CONNECTIVITY_MESSAGE}


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


def pretty_name():
    return "Software"


def pretty_status_message():
    return "Instalando el software seleccionado."


def run():
    """Punto de entrada de Calamares."""
    # La aceptacion la escribe la pagina QML en el globalstorage; sin
    # leerla aqui la rama de solo-base seria inalcanzable en el flujo real.
    gate = connectivity_gate(accepted_offline=read_offline_accepted())
    if not gate["online"] and not gate["profiles"]:
        if libcalamares is not None:
            libcalamares.utils.warning(NO_CONNECTIVITY_MESSAGE)
        return NO_CONNECTIVITY_MESSAGE
    packages = packages_for_profiles(gate["profiles"])
    install_packages(packages)
    return None
