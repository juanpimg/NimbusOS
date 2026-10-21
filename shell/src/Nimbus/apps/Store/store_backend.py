# SPDX-License-Identifier: GPL-3.0-or-later
"""Backend de la Nimbus Store: catalogo y operaciones de instalacion.

Modulo independiente de la GUI: solo devuelve datos planos
(dict/list/str/bool) para que el QML los consuma y los tests se ejerciten
sin Flatpak instalado. Nunca lanza ante Flatpak ausente: degrada a modo
"solo nativas" e informa con texto legible via `flatpak_error()` y en el
mensaje de `install()`/`uninstall()`.

Origenes: "Flathub" (requiere Flatpak) y "Nativo" (siempre disponible).
"""
import shutil

FLATPAK_REMOTE = "flathub"

FLATPAK_MISSING_MESSAGE = (
    "Flatpak no está disponible: solo se muestran las aplicaciones nativas."
)

CATEGORIES = [
    "games",
    "productivity",
    "communication",
    "creative",
    "media",
    "development",
    "utilities",
]

_NOT_FOUND_MESSAGE = "Aplicación no encontrada: {app_id}."
_NOT_INSTALLED_MESSAGE = "{title} no está instalada."


def _app(app_id, title, description, category, origin, icon, version, screenshots=()):
    return {
        "id": app_id,
        "title": title,
        "description": description,
        "category": category,
        "origin": origin,
        "icon": icon,
        "version": version,
        "screenshots": list(screenshots),
    }


_NATIVE_APPS = [
    _app("nimbus.mines", "Buscaminas", "El clásico buscaminas con tema Nimbus.",
         "games", "Nativo", "games", "1.0"),
    _app("nimbus.notes", "Notas", "Notas rápidas sincronizadas con tu sesión.",
         "productivity", "Nativo", "notes", "1.2"),
    _app("nimbus.chat", "Charla", "Mensajería local de la sesión Nimbus.",
         "communication", "Nativo", "chat", "1.0"),
    _app("nimbus.paint", "Dibujo", "Lienzo simple para bocetos rápidos.",
         "creative", "Nativo", "paint", "1.1"),
    _app("nimbus.music", "Música", "Reproductor minimalista del sistema.",
         "media", "Nativo", "music", "1.0"),
    _app("nimbus.terminal", "Terminal", "Emulador de terminal del sistema.",
         "development", "Nativo", "terminal", "1.0"),
    _app("nimbus.calc", "Calculadora", "Calculadora del sistema.",
         "utilities", "Nativo", "calc", "1.0"),
]

_FLATHUB_APPS = [
    _app("org.supertuxkart.SuperTuxKart", "SuperTuxKart",
         "Juego de carreras de karts libre.", "games", "Flathub",
         "supertuxkart", "1.4", ["sk-shot1", "sk-shot2"]),
    _app("org.libreoffice.LibreOffice", "LibreOffice",
         "Suite ofimática completa.", "productivity", "Flathub",
         "libreoffice", "24.8", ["lo-shot1"]),
    _app("org.telegram.desktop", "Telegram",
         "Mensajería rápida y segura.", "communication", "Flathub",
         "telegram", "5.5", ["tg-shot1"]),
    _app("org.gimp.GIMP", "GIMP",
         "Editor de imágenes profesional.", "creative", "Flathub",
         "gimp", "2.10", ["gimp-shot1", "gimp-shot2"]),
    _app("com.spotify.Client", "Spotify",
         "Música en streaming.", "media", "Flathub",
         "spotify", "1.2", ["sp-shot1"]),
    _app("com.visualstudio.code", "Visual Studio Code",
         "Editor de código extensible.", "development", "Flathub",
         "vscode", "1.93", ["code-shot1", "code-shot2"]),
    _app("org.mozilla.firefox", "Firefox",
         "Navegador web libre.", "utilities", "Flathub",
         "firefox", "131.0", ["ff-shot1"]),
]

# Estado en memoria: las nativas vienen instaladas de fábrica; las de
# Flathub se instalan bajo demanda (simulado hasta el cableado real con
# libflatpak en M2, que vivirá detrás de esta misma API).
_installed_ids = {a["id"] for a in _NATIVE_APPS}

# Forzado de tests: None = autodetección, True/False = valor impuesto.
_flatpak_override = None


def set_flatpak_available(value):
    """Fija la disponibilidad de Flatpak (True/False) o la libera (None).

    Gancho para tests: permite ejercitar ambos caminos sin Flatpak real.
    """
    global _flatpak_override
    _flatpak_override = value


def flatpak_available():
    """True si hay backend Flatpak utilizable (binario + libflatpak)."""
    if _flatpak_override is not None:
        return bool(_flatpak_override)
    try:
        if shutil.which("flatpak") is None:
            return False
        import gi

        gi.require_version("Flatpak", "1.0")
        from gi.repository import Flatpak  # noqa: F401

        return True
    except Exception:
        return False


def flatpak_error():
    """Texto legible del estado de Flatpak; "" si está disponible."""
    if flatpak_available():
        return ""
    return FLATPAK_MISSING_MESSAGE


def _catalog():
    apps = list(_NATIVE_APPS)
    if flatpak_available():
        apps.extend(_FLATHUB_APPS)
    return apps


def _with_state(app):
    entry = dict(app)
    entry["screenshots"] = list(app["screenshots"])
    entry["installed"] = app["id"] in _installed_ids
    return entry


def list_apps(category=""):
    """Lista apps visibles; con categoría desconocida devuelve []."""
    try:
        apps = _catalog()
        if category:
            if category not in CATEGORIES:
                return []
            apps = [a for a in apps if a["category"] == category]
        return [_with_state(a) for a in apps]
    except Exception:
        return []


def search(query):
    """Filtra por título sin distinguir mayúsculas; "" devuelve todo."""
    try:
        needle = str(query or "").strip().lower()
        apps = _catalog()
        if not needle:
            return [_with_state(a) for a in apps]
        return [
            _with_state(a)
            for a in apps
            if needle in a["title"].lower() or needle in a["id"].lower()
        ]
    except Exception:
        return []


def get_app(app_id):
    """Ficha completa de una app; {} si no existe. Nunca lanza."""
    try:
        for app in _catalog():
            if app["id"] == app_id:
                return _with_state(app)
        return {}
    except Exception:
        return {}


def is_installed(app_id):
    """True si la app está instalada; False si no existe. Nunca lanza."""
    try:
        return app_id in _installed_ids
    except Exception:
        return False


def install(app_id):
    """Instala una app. Devuelve (ok, mensaje): el error es texto."""
    try:
        target = next((a for a in _catalog() if a["id"] == app_id), None)
        if target is None:
            # Sin Flatpak ni siquiera se ve en el catálogo: se busca también
            # en el catálogo completo para dar un mensaje preciso.
            known = next((a for a in _NATIVE_APPS + _FLATHUB_APPS if a["id"] == app_id), None)
            if known is not None and known["origin"] == "Flathub" and not flatpak_available():
                return False, FLATPAK_MISSING_MESSAGE
            return False, _NOT_FOUND_MESSAGE.format(app_id=app_id)
        if target["origin"] == "Flathub" and not flatpak_available():
            return False, FLATPAK_MISSING_MESSAGE
        _installed_ids.add(app_id)
        return True, ""
    except Exception as exc:
        return False, str(exc)


def uninstall(app_id):
    """Desinstala una app. Distingue "no instalada" de "error"."""
    try:
        known = next((a for a in _NATIVE_APPS + _FLATHUB_APPS if a["id"] == app_id), None)
        if known is None:
            return False, _NOT_FOUND_MESSAGE.format(app_id=app_id)
        if app_id not in _installed_ids:
            return False, _NOT_INSTALLED_MESSAGE.format(title=known["title"])
        _installed_ids.discard(app_id)
        return True, ""
    except Exception as exc:
        return False, str(exc)


def list_updates():
    """Lista actualizaciones pendientes. Siempre una lista, nunca lanza."""
    try:
        if not flatpak_available():
            return []
        updates = []
        for app in _FLATHUB_APPS:
            if app["id"] in _installed_ids:
                entry = _with_state(app)
                updates.append(entry)
        return updates
    except Exception:
        return []


def main(argv=None):
    """CLI JSON para el puente QML (`StoreBackend.qml`).

    Uso: store_backend.py --json <op> [args]
      list-apps [categoria] | search <q> | get <id> |
      install <id> | uninstall <id> | updates | flatpak

    Imprime el resultado por stdout como JSON y sale con 0; con uso
    incorrecto sale con 2. Nunca vuelca trazas (los errores viajan en el
    JSON o por stderr como texto). No cambia la API de modulo: los tests
    existentes siguen importando las funciones sin pasar por aqui.
    """
    import json
    import sys

    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) < 2 or args[0] != "--json":
        print(
            "Uso: store_backend.py --json "
            "<list-apps [categoria]|search <q>|get <id>|"
            "install <id>|uninstall <id>|updates|flatpak>",
            file=sys.stderr,
        )
        return 2
    op = args[1]
    rest = args[2:]
    try:
        if op == "list-apps":
            print(json.dumps(list_apps(rest[0] if rest else "")))
        elif op == "search":
            if not rest:
                print("falta la consulta de busqueda", file=sys.stderr)
                return 2
            print(json.dumps(search(rest[0])))
        elif op == "get":
            if not rest:
                print("falta el id de la aplicacion", file=sys.stderr)
                return 2
            print(json.dumps(get_app(rest[0])))
        elif op == "install":
            if not rest:
                print("falta el id de la aplicacion", file=sys.stderr)
                return 2
            ok, message = install(rest[0])
            print(json.dumps({"ok": ok, "message": message}))
        elif op == "uninstall":
            if not rest:
                print("falta el id de la aplicacion", file=sys.stderr)
                return 2
            ok, message = uninstall(rest[0])
            print(json.dumps({"ok": ok, "message": message}))
        elif op == "updates":
            print(json.dumps(list_updates()))
        elif op == "flatpak":
            print(
                json.dumps(
                    {"available": flatpak_available(), "error": flatpak_error()}
                )
            )
        else:
            print("operacion desconocida: %s" % op, file=sys.stderr)
            return 2
    except Exception as exc:
        print("store_backend: %s" % exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
