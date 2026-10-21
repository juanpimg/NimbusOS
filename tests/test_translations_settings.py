# SPDX-License-Identifier: GPL-3.0-or-later
"""Guarda de Ajustes: ninguna pantalla muestra una clave literal.

Las 11 paginas de `shell/src/Nimbus/apps/Settings/**` piden sus textos por
`Config.translated("settings...")`. Sin entrada en la tabla de
`shell/src/Nimbus/Translations.qml`, `lookup()` devuelve la clave tal cual
y el usuario lee `settings.power.title` en pantalla.

Este test recorre el codigo de Ajustes (literales `translated()`,
prefijos dinamicos `"settings.x." + ...` y claves construidas en
`SettingsData.qml`) y falla si alguna clave no existe en ES ni en EN.
Tambien ata la simetria total de la tabla (es == en).
"""

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
SETTINGS_DIR = ROOT / "shell" / "src" / "Nimbus" / "apps" / "Settings"
TRANSLATIONS = ROOT / "shell" / "src" / "Nimbus" / "Translations.qml"
SETTINGS_DATA = SETTINGS_DIR / "SettingsData.qml"
SERVICES = ROOT / "shell" / "src" / "Nimbus" / "Services.qml"

LITERAL_RE = re.compile(r'translated\("([^"]+)"\)')
PREFIX_RE = re.compile(r'"(settings\.[A-Za-z0-9_.]*\.)"\s*\+')
TABLE_RE = re.compile(r'"(es|en)": \{(.*?)\n        \}', re.S)


def _tables():
    text = TRANSLATIONS.read_text(encoding="utf-8")
    out = {}
    for lang, body in TABLE_RE.findall(text):
        out[lang] = set(re.findall(r'"([^"]+)"\s*:', body))
    assert set(out) == {"es", "en"}, "la tabla debe tener ES y EN"
    return out


def _settings_sources():
    return sorted(SETTINGS_DIR.glob("*.qml")) + [SETTINGS_DATA]


def _section_ids():
    """IDs del sidebar, leidos del propio `sectionOrder()` (no hardcode)."""
    text = SETTINGS_DATA.read_text(encoding="utf-8")
    match = re.search(r"function sectionOrder\(\) \{\s*return \[(.*?)\]", text, re.S)
    assert match, "SettingsData.qml debe definir sectionOrder()"
    return re.findall(r'"([a-z]+)"', match.group(1))


def _accent_keys():
    """Nombres de `accentPresets()`: llegan a `translated(modelData.name)`."""
    text = SETTINGS_DATA.read_text(encoding="utf-8")
    keys = re.findall(r'"name": "(settings\.accent\.[a-z]+)"', text)
    assert keys, "SettingsData.qml debe definir accentPresets() con claves settings.accent.*"
    return keys


def _service_default(prop):
    """Valor por defecto de `Services.<prop>` (lo que el codigo puede pedir hoy)."""
    text = SERVICES.read_text(encoding="utf-8")
    match = re.search(r"property string %s: \"([a-z]+)\"" % prop, text)
    assert match, "Services.qml debe declarar %s" % prop
    return match.group(1)


def _service_states_list(name):
    """Dominio declarado en Services.qml (`networkStates`, `bluetoothStates`).

    Las claves traducidas deben cubrir TODO el dominio, no solo el valor
    por defecto: el probe puede fijar cualquier valor del dominio.
    """
    text = SERVICES.read_text(encoding="utf-8")
    match = re.search(r"readonly property var %s:\s*\[(.*?)\]" % name, text, re.S)
    assert match, "Services.qml debe declarar el dominio %s" % name
    values = re.findall(r'"([a-z]+)"', match.group(1))
    assert values, "el dominio %s esta vacio" % name
    return values


def _required_keys():
    required = set()
    for path in _settings_sources():
        text = path.read_text(encoding="utf-8")
        for key in LITERAL_RE.findall(text):
            if key.startswith("settings."):
                required.add(key)
        for prefix in PREFIX_RE.findall(text):
            if prefix == "settings.section.":
                required.update("settings.section." + sid for sid in _section_ids())
            elif prefix == "settings.appearance.mode.":
                required.update(
                    "settings.appearance.mode." + mode for mode in ("light", "dark", "auto")
                )
            elif prefix == "settings.network.state.":
                required.update(prefix + value for value in _service_states_list("networkStates"))
            elif prefix == "settings.bluetooth.state.":
                required.update(prefix + value for value in _service_states_list("bluetoothStates"))
            else:  # pragma: no cover - un prefijo nuevo debe registrarse aqui
                raise AssertionError(
                    "prefijo dinamico sin dominio conocido: %s (en %s)" % (prefix, path.name)
                )
    required.update(_accent_keys())
    # Los literales con prefijo sin sufijo nunca resuelven solos, no son claves.
    required = {key for key in required if not key.endswith(".")}
    return required


def test_translation_tables_are_symmetric():
    tables = _tables()
    assert tables["es"] == tables["en"], (
        "tabla asimetrica: solo-es=%s solo-en=%s"
        % (sorted(tables["es"] - tables["en"]), sorted(tables["en"] - tables["es"]))
    )


def test_every_settings_key_used_exists_in_both_locales():
    tables = _tables()
    missing = sorted(
        key
        for key in _required_keys()
        if key not in tables["es"] or key not in tables["en"]
    )
    assert not missing, (
        "%d claves settings.* usadas por Ajustes sin entrada ES+EN: %s"
        % (len(missing), missing)
    )
