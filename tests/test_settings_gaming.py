# SPDX-License-Identifier: GPL-3.0-or-later
"""Contrato de la pagina Ajustes -> Energia y juegos (M3 T6).

La pagina `SettingsGaming.qml` llama a los CLI reales (nimbus-energy,
nimbus-anonicy, upower, gamescope-vrr-check), aplica de verdad (pkexec en
los `set`) y muestra resultado o error traducido. Estas son las guardas
estaticas; el comportamiento con runners falsos vive en
`shell/tests/tst_settingsgaming.qml`.
"""

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
PAGE = ROOT / "shell" / "src" / "Nimbus" / "apps" / "Settings" / "SettingsGaming.qml"
SETTINGS = ROOT / "shell" / "src" / "Nimbus" / "apps" / "Settings" / "Settings.qml"
TRANSLATIONS = ROOT / "shell" / "src" / "Nimbus" / "Translations.qml"

# Claves propias de la pagina (las de energia reutilizan settings.power.*).
GAMING_KEYS = (
    "settings.section.gaming",
    "settings.gaming.title",
    "settings.gaming.ananicy",
    "settings.gaming.ananicy.enable",
    "settings.gaming.ananicy.disable",
    "settings.gaming.ananicy.enabled",
    "settings.gaming.ananicy.disabled",
    "settings.gaming.ananicy.unknown",
    "settings.gaming.ananicy.refresh",
    "settings.gaming.battery",
    "settings.gaming.battery.none",
    "settings.gaming.battery.refresh",
    "settings.gaming.battery.charging",
    "settings.gaming.battery.discharging",
    "settings.gaming.battery.full",
    "settings.gaming.vrr",
    "settings.gaming.vrr.supported",
    "settings.gaming.vrr.unsupported",
    "settings.gaming.vrr.refresh",
    "settings.gaming.chargeUnlimited",
)

LITERAL_RE = re.compile(r'translated\("([^"]+)"\)')
TABLE_RE = re.compile(r'"(es|en)": \{(.*?)\n        \}', re.S)


def _tables():
    text = TRANSLATIONS.read_text(encoding="utf-8")
    out = {}
    for lang, body in TABLE_RE.findall(text):
        out[lang] = set(re.findall(r'"([^"]+)"\s*:', body))
    assert set(out) == {"es", "en"}, "la tabla debe tener ES y EN"
    return out


def _page_text():
    assert PAGE.is_file(), "falta shell/.../Settings/SettingsGaming.qml"
    return PAGE.read_text(encoding="utf-8")


def test_gaming_keys_exist_in_both_locales():
    tables = _tables()
    for key in GAMING_KEYS:
        assert key in tables["es"], f"falta ES: {key}"
        assert key in tables["en"], f"falta EN: {key}"


def test_gaming_tables_stay_symmetric():
    tables = _tables()
    assert tables["es"] == tables["en"], (
        "tabla asimetrica: solo-es=%s solo-en=%s"
        % (sorted(tables["es"] - tables["en"]), sorted(tables["en"] - tables["es"]))
    )


def test_every_gaming_key_used_exists():
    text = _page_text()
    used = {k for k in LITERAL_RE.findall(text) if k.startswith("settings.")}
    assert used, "la pagina debe pedir textos por Config.translated()"
    tables = _tables()
    missing = sorted(k for k in used if k not in tables["es"] or k not in tables["en"])
    assert not missing, "claves sin ES+EN: %s" % missing


def test_page_is_a_pure_item_without_window_or_console():
    text = _page_text()
    head = "\n".join(text.splitlines()[:2])
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in head
    assert "FloatingWindow" not in text, "la pagina no instancia ventanas (testeable sin compositor)"
    assert "ApplicationWindow" not in text
    assert "Window {" not in text
    assert "console." not in text, "nada de console.*: el resultado se muestra traducido"


def test_page_drives_the_real_clis():
    text = _page_text()
    for cli in ("nimbus-energy", "nimbus-anonicy", "upower", "gamescope-vrr-check"):
        assert cli in text, f"la pagina debe invocar {cli}"
    for args in ('"profile", "set"', '"charge-limit", "set"', '"gpu", "set"',
                 '"enable"', '"disable"', '"status"'):
        assert args in text, f"la pagina debe pedir {args}"


def test_page_is_hooked_in_settings():
    text = SETTINGS.read_text(encoding="utf-8")
    assert "gaming" in text, "Settings.qml debe enganchar la seccion gaming"
    assert "SettingsGaming.qml" in text, "pageFor debe resolver la pagina gaming"
