# SPDX-License-Identifier: GPL-3.0-or-later
"""Empaquetado del instalador de Nimbus (`nimbus-installer`).

El paquete convierte la ISO en distribución instalable: depende de
`cachyos-calamares-next` y lleva los 6 módulos propios de Nimbus, el
tema SDDM del greeter, la config SDDM con autologin y las herramientas
que los módulos invocan por ruta relativa. Todo se comprueba en
estático sobre el PKGBUILD (sin root ni Calamares instalado).
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
PKGDIR = ROOT / "packages" / "nimbus-installer"
PKGBUILD = PKGDIR / "PKGBUILD"
PROFILE_PKGS = ROOT / "iso" / "profiles" / "nimbus" / "packages.x86_64"

MODULES = [
    "nimbus-dualboot",
    "nimbus-appearance",
    "nimbus-software",
    "nimbus-bootloader",
    "nimbus-postinstall",
    "nimbus-verify",
]

CALAMARES_LIB = "/usr/lib/calamares/modules"
CALAMARES_ETC = "/etc/calamares/modules"


def _pkgbuild():
    assert PKGBUILD.is_file(), (
        "falta packages/nimbus-installer/PKGBUILD: el instalador no se empaqueta"
    )
    return PKGBUILD.read_text(encoding="utf-8")


def test_pkgbuild_exists_and_has_spdx():
    text = _pkgbuild()
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in text.splitlines()[0]


def test_pkgbuild_metadata_follows_monorepo_style():
    text = _pkgbuild()
    assert "pkgname=nimbus-installer" in text
    assert "arch=('any')" in text
    # Monorepo: sin descargas, los ficheros se leen del árbol local.
    assert "source=()" in text
    assert "cachyos-calamares-next" in text  # el instalador, como dependencia


def test_pkgbuild_depends_on_sddm_for_greeter_and_autologin():
    text = _pkgbuild()
    depends = [line for line in text.splitlines() if line.startswith("depends=")]
    assert depends, "el PKGBUILD debe declarar depends"
    blob = "\n".join(depends)
    assert "sddm" in blob


def test_pkgbuild_installs_all_six_modules():
    text = _pkgbuild()
    for module in MODULES:
        assert f"{CALAMARES_LIB}/{module}/{module}.py" in text, (
            f"el paquete no instala el código de {module} en {CALAMARES_LIB}"
        )
        assert f"{CALAMARES_ETC}/{module}.conf" in text, (
            f"el paquete no instala la config de {module} en {CALAMARES_ETC}"
        )
        assert f"{CALAMARES_LIB}/{module}/module.desc" in text, (
            f"el paquete no instala module.desc de {module}: "
            "Calamares no descubre módulos sin descriptor"
        )


def test_module_sources_exist_in_tree():
    missing = []
    for module in MODULES:
        for name in (f"{module}.py", f"{module}.conf"):
            path = ROOT / "installer" / "calamares" / "modules" / module / name
            if not path.is_file():
                missing.append(str(path.relative_to(ROOT)))
    assert missing == [], f"fuentes ausentes en el árbol: {missing}"


def test_pkgbuild_installs_greeter_theme_where_sddm_looks():
    text = _pkgbuild()
    assert "/usr/share/sddm/themes/nimbus/" in text, (
        "el tema debe instalarse en /usr/share/sddm/themes/nimbus/ "
        "(ThemeDir de SDDM; Current=nimbus lo exige)"
    )


def test_greeter_sources_exist_in_tree():
    theme = ROOT / "installer" / "greeter" / "nimbus-greeter"
    missing = [
        name for name in ("Main.qml", "metadata.desktop", "theme.conf",
                          "background.svg")
        if not (theme / name).is_file()
    ]
    assert missing == [], f"ficheros del tema ausentes: {missing}"


def test_pkgbuild_installs_sddm_config_with_theme_and_autologin():
    text = _pkgbuild()
    assert "/etc/sddm.conf.d/nimbus.conf" in text
    conf = PKGDIR / "files" / "sddm-nimbus.conf"
    assert conf.is_file(), (
        "falta packages/nimbus-installer/files/sddm-nimbus.conf "
        "(fuente de /etc/sddm.conf.d/nimbus.conf)"
    )
    body = conf.read_text(encoding="utf-8")
    assert "Current=nimbus" in body
    assert "User=nimbus" in body
    assert "Session=" in body and "hyprland" in body


def test_postinstall_stays_wired_to_calamares_paths():
    text = _pkgbuild()
    # El módulo calcula TOOL_PATH como parents[2]/tools/nimbus-postinstall
    # desde /usr/lib/calamares/modules/nimbus-postinstall/: sin ese path
    # el job falla (no hay fallback). El paquete debe proveerlo.
    assert "/usr/lib/calamares/tools/nimbus-postinstall" in text, (
        "el paquete no cablea TOOL_PATH de nimbus-postinstall "
        "(/usr/lib/calamares/tools/nimbus-postinstall)"
    )
    # nimbus-dualboot usa parents[3]/tools/nimbus-partitionsafe.
    assert "tools/nimbus-partitionsafe" in text, (
        "el paquete no cablea PARTITIONSAFE_BIN de nimbus-dualboot"
    )
    # Los 6 módulos importan parents[2]/nimbus_i18n.py.
    assert "/usr/lib/calamares/nimbus_i18n.py" in text
    # Las herramientas también viven como CLI en /usr/bin.
    assert "/usr/bin/nimbus-postinstall" in text
    assert "/usr/bin/nimbus-partitionsafe" in text
    # Y la secuencia del flujo trae el paso de post-instalación.
    settings = ROOT / "installer" / "calamares" / "settings.conf"
    assert "nimbus-postinstall" in settings.read_text(encoding="utf-8")


def test_iso_lists_nimbus_installer():
    """La ISO live debe llevar el instalador (lo añade la otra pista).

    Si falla: añade exactamente esta línea a
    iso/profiles/nimbus/packages.x86_64 (una por línea, orden
    alfabético junto al resto de paquetes nimbus):

        nimbus-installer
    """
    wanted = "nimbus-installer"
    lines = [
        line.strip() for line in PROFILE_PKGS.read_text(
            encoding="utf-8").splitlines()
    ]
    assert wanted in lines, (
        f"la ISO live no lleva el instalador: `{wanted}` no está en "
        "iso/profiles/nimbus/packages.x86_64. "
        "Añade exactamente esta línea al fichero: `nimbus-installer`"
    )
