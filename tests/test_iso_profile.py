# SPDX-License-Identifier: GPL-3.0-or-later
"""Perfil de ISO de Nimbus en formato archiso 91 (mkarchiso)."""
import os
import pathlib
import re
import stat
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROFILE = ROOT / "iso" / "profiles" / "nimbus"

REQUIRED_FILES = [
    "profiledef.sh",
    "packages.x86_64",
    "pacman.conf",
]

REQUIRED_PACKAGES = [
    "linux-cachyos",
    "hyprland",
    "quickshell",
    "nimbus-shell",
    "nimbus-dots",
    "sddm",
    "swaybg",
    "systemd",
    "xdg-desktop-portal-hyprland",
    "mkinitcpio-archiso",
    "syslinux",
]


def _packages():
    text = (PROFILE / "packages.x86_64").read_text(encoding="utf-8")
    return {line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")}


def _nimbus_server():
    """URL file:// de la seccion [nimbus] del pacman.conf del perfil."""
    text = (PROFILE / "pacman.conf").read_text(encoding="utf-8")
    section = text.split("[nimbus]")[1]
    match = re.search(r"^Server\s*=\s*(\S+)", section, re.MULTILINE)
    assert match is not None
    return match.group(1)


def test_required_profile_files_exist():
    missing = [name for name in REQUIRED_FILES if not (PROFILE / name).is_file()]
    assert missing == []
    assert (PROFILE / "airootfs").is_dir()


def test_old_format_files_are_gone():
    gone = ["airoot.sh", "customize.sh", "file-contexts.sh"]
    remaining = [name for name in gone if (PROFILE / name).exists()]
    assert remaining == []
    assert not (PROFILE / "overlay").exists()


def test_profile_lists_required_packages():
    packages = _packages()
    missing = [p for p in REQUIRED_PACKAGES if p not in packages]
    assert missing == []


def test_profiledef_declares_nimbus_metadata():
    text = (PROFILE / "profiledef.sh").read_text(encoding="utf-8")
    assert 'iso_name="nimbus"' in text
    assert 'install_dir="nimbus"' in text
    assert 'pacman_conf="pacman.conf"' in text
    assert 'airootfs_image_type="squashfs"' in text
    assert '["/etc/shadow"]="0:0:400"' in text


def test_airootfs_contains_nimbus_os_release():
    text = (PROFILE / "airootfs" / "etc" / "os-release").read_text(encoding="utf-8")
    assert "ID=nimbus" in text
    assert "ID_LIKE=arch cachyos" in text
    assert 'PRETTY_NAME="Nimbus Linux"' in text


def test_airootfs_contains_live_units_and_keyring():
    assert (PROFILE / "airootfs" / "etc" / "systemd" / "system" / "nimbus-live-ready.service").is_file()
    assert (PROFILE / "airootfs" / "etc" / "sddm.conf.d" / "nimbus.conf").is_file()
    assert (
        PROFILE / "airootfs" / "usr" / "share" / "wayland-sessions" / "nimbus.desktop"
    ).is_file()
    assert (PROFILE / "airootfs" / "usr" / "lib" / "nimbus" / "nimbus-session").is_file()
    assert (PROFILE / "airootfs" / "usr" / "share" / "pacman" / "keyrings" / "nimbus.gpg").is_file()
    assert (PROFILE / "airootfs" / "usr" / "share" / "pacman" / "keyrings" / "nimbus-trusted").is_file()


def test_airootfs_defines_live_user():
    passwd = (PROFILE / "airootfs" / "etc" / "passwd").read_text(encoding="utf-8")
    assert "nimbus:x:1000:1000:" in passwd
    assert "/home/nimbus" in passwd
    shadow = (PROFILE / "airootfs" / "etc" / "shadow").read_text(encoding="utf-8")
    assert re.search(r"^nimbus:\$[^:]+:", shadow, re.MULTILINE) is not None


def test_live_ready_marker_is_written_by_the_readiness_script():
    unit = PROFILE / "airootfs" / "etc" / "systemd" / "system" / "nimbus-live-ready.service"
    text = unit.read_text(encoding="utf-8")
    # Contrato con el harness: la puerta espera al display manager y escribe
    # el marcador hacia la consola.
    assert "display-manager.service" in text
    assert "NIMBUS_LIVE_READY" in text
    assert "/dev/console" in text
    # ... pero el marcador lo escribe el script solo con la sesion lista,
    # nunca un ExecStart del unit que dispararia con la sesion en bucle.
    starts = [line.strip() for line in text.splitlines() if line.strip().startswith("ExecStart=")]
    assert starts, "el unit debe ejecutar el script de readiness"
    assert all("NIMBUS_LIVE_READY" not in line for line in starts), starts
    assert any("nimbus-live-ready" in line and "echo" not in line for line in starts), starts


def test_live_session_is_launched_by_sddm_for_user_nimbus():
    # La sesion live la arranca SDDM (autologin), no un unit propio: dos
    # lanzadores del compositor competirian entre si. El shell lo arranca
    # la config de Hyprland (hyprland.lua -> nimbus-start) via hyprland.start.
    desktop = PROFILE / "airootfs" / "usr" / "share" / "wayland-sessions" / "nimbus.desktop"
    session = PROFILE / "airootfs" / "usr" / "lib" / "nimbus" / "nimbus-session"
    text = session.read_text(encoding="utf-8")
    assert "User=nimbus" in (PROFILE / "airootfs" / "etc" / "sddm.conf.d" / "nimbus.conf").read_text(
        encoding="utf-8"
    )
    assert "/usr/bin/start-hyprland" in text
    assert "--config" in text
    assert ".config/hypr/hyprland.lua" in text
    # El shell lo arranca la config de Hyprland, no la sesion directamente.
    assert "nimbus-shell" not in desktop.read_text(encoding="utf-8")
    assert "nimbus-shell" not in text
    # El marcador no debe aparecer si la sesion no arranco: la puerta espera
    # al display manager.
    ready = PROFILE / "airootfs" / "etc" / "systemd" / "system" / "nimbus-live-ready.service"
    assert "display-manager.service" in ready.read_text(encoding="utf-8")


def test_live_units_are_enabled_at_boot():
    # El display manager y la puerta de readiness cuelgan de
    # graphical.target, y no de multi-user.
    #
    # La regla que aplica (systemd.target(5)): "Target units will automatically
    # complement all configured dependencies of type Wants= or Requires= with
    # dependencies of type After=". O sea, un target espera a todo lo que
    # quiere o requiere. Con la puerta esperando al display-manager y ambos
    # bajo graphical.target, la cadena es lineal
    # (display-manager -> ready -> graphical) y no hay espera circular.
    #
    # Ademas el [Install] de ready coincide con el directorio donde vive
    # su symlink, de modo que un `systemctl enable` es idempotente. SDDM se
    # habilita con el alias display-manager.service, como hace Arch.
    system = PROFILE / "airootfs" / "etc" / "systemd" / "system"
    assert (system / "display-manager.service").is_symlink()
    wants = system / "graphical.target.wants"
    assert (wants / "nimbus-live-ready.service").is_symlink()
    assert not (wants / "nimbus-live.service").exists()
    assert not (system / "multi-user.target.wants" / "nimbus-live-ready.service").exists()


def test_live_ready_unit_install_section_matches_where_its_symlink_lives():
    unit = PROFILE / "airootfs" / "etc" / "systemd" / "system" / "nimbus-live-ready.service"
    text = unit.read_text(encoding="utf-8")
    # El [Install] tiene que decir graphical.target: si dijera otra cosa, un
    # `systemctl enable` pondria un symlink extra y reintroduciria el ciclo.
    installs = [line.strip() for line in text.splitlines() if line.strip().startswith("WantedBy=")]
    assert installs == ["WantedBy=graphical.target"], installs


def test_live_user_can_open_the_drm_device():
    # Sin los grupos video/render/input el usuario live no puede abrir
    # /dev/dri/card0 (crw-rw---- root:video) y el compositor aborta con
    # "CBackend::create() failed!". Verificado en la sesion live.
    #
    # Se declara con sysusers.d y NO editando /etc/group: ese fichero lo
    # escribe el scriptlet del paquete shadow (groupadd) y el paquete
    # filesystem lo reemplaza durante la transaccion, asi que a mano no es
    # fiable. El tipo "m" de sysusers.d anade el miembro al grupo.
    sysusers = PROFILE / "airootfs" / "etc" / "sysusers.d" / "nimbus.conf"
    assert sysusers.is_file()
    lines = [line.strip() for line in sysusers.read_text(encoding="utf-8").splitlines()]
    members = {line for line in lines if line.startswith("m ")}
    assert {"m nimbus video", "m nimbus render", "m nimbus input"} <= members, members
    # Y el usuario live existe con su home y su shell.
    group = (PROFILE / "airootfs" / "etc" / "group").read_text(encoding="utf-8")
    assert re.search(r"^nimbus:x:1000:", group, re.MULTILINE) is not None


def test_live_session_runs_inside_a_logind_session():
    # Con SDDM hay login (PAM) y sesion de logind, asi que el backend
    # logind de libseat funciona: el apaño noop de la etapa sin greeter
    # ya no hace falta y no debe aparecer en ningun fichero del airootfs.
    for path in (PROFILE / "airootfs").rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        assert "LIBSEAT_BACKEND" not in text, f"{path} fija backend de libseat a mano"


def test_boot_configs_point_at_cachyos_kernel():
    syslinux = (PROFILE / "syslinux" / "syslinux-linux.cfg").read_text(encoding="utf-8")
    assert "vmlinuz-linux-cachyos" in syslinux
    assert "initramfs-linux-cachyos.img" in syslinux
    grub = (PROFILE / "grub" / "grub.cfg").read_text(encoding="utf-8")
    assert "vmlinuz-linux-cachyos" in grub
    assert "initramfs-linux-cachyos.img" in grub


def test_iso_is_smaller_than_3gb_budget():
    budget = 3 * 1024 * 1024 * 1024
    iso_dir = ROOT / "iso"
    for iso in iso_dir.glob("*.iso"):
        assert iso.stat().st_size < budget, f"{iso.name} excede el presupuesto de 3 GB"


BUILD_SH = ROOT / "iso" / "build.sh"


def test_build_uses_pkgdest_and_not_packagelist():
    text = BUILD_SH.read_text(encoding="utf-8")
    # La intencion es que makepkg CONSTRUYA el paquete en el repo local, no
    # que solo liste las rutas que se producirian. Se comprueba por separado
    # para no atar el test a como este maquetada la invocacion.
    assert 'PKGDEST="$REPO_DIR"' in text
    assert "makepkg" in text
    assert "--packagelist" not in text


def test_build_indexes_repo_with_valid_db_extension():
    text = BUILD_SH.read_text(encoding="utf-8")
    assert "repo-add" in text
    assert "nimbus.db.tar.gz" in text


def test_build_fails_loudly_when_no_package_was_built():
    text = BUILD_SH.read_text(encoding="utf-8")
    assert 'compgen -G "$REPO_DIR/*.pkg.tar.*"' in text
    assert "no se ha construido ningun paquete" in text
    assert "build-*.log" in text


def test_build_checks_required_binaries():
    text = BUILD_SH.read_text(encoding="utf-8")
    assert "command -v mkarchiso" in text
    assert "command -v mksquashfs" in text
    assert "command -v makepkg" in text
    assert "command -v repo-add" in text


def test_build_invokes_mkarchiso_and_not_the_old_cli():
    text = BUILD_SH.read_text(encoding="utf-8")
    assert 'mkarchiso -m iso -o "$OUTDIR" -w "$WORK" "$WORK/profile"' in text
    assert re.search(r"(?<!mk)archiso -p", text) is None


def test_local_repo_is_a_flag_without_argument():
    text = BUILD_SH.read_text(encoding="utf-8")
    assert "--local-repo) LOCAL_REPO=1; shift ;;" in text
    assert "--local-repo) LOCAL_REPO=\"$2\"" not in text
    assert 'if [ "$LOCAL_REPO" -eq 1 ]' in text


def test_local_repo_url_matches_profile_pacman_conf():
    text = BUILD_SH.read_text(encoding="utf-8")
    match = re.search(r'NIMBUS_REPO_MOUNT="([^"]+)"', text)
    assert match is not None
    assert _nimbus_server() == f"file://{match.group(1)}"


def test_bootstrap_repo_is_unsigned_with_a_visible_todo():
    text = (PROFILE / "pacman.conf").read_text(encoding="utf-8")
    section = text.split("[nimbus]")[1].split("[")[0]
    assert "SigLevel = Optional" in section
    assert "TODO(bootstrap)" in section


def _repo_servers(text, repo):
    """Lista de `Server =` de la seccion [repo] de un pacman.conf."""
    section = text.split(f"[{repo}]")[1].split("[")[0]
    return re.findall(r"^Server\s*=\s*(\S+)", section, re.MULTILINE)


def test_live_and_build_pacman_confs_share_the_same_mirrors():
    build = (PROFILE / "pacman.conf").read_text(encoding="utf-8")
    live = (PROFILE / "airootfs" / "etc" / "pacman.conf").read_text(encoding="utf-8")
    for repo in ("cachyos", "core", "extra"):
        assert _repo_servers(build, repo), repo
        assert _repo_servers(build, repo) == _repo_servers(live, repo), repo
    # Sin directivas Include: ambas usan espejos explicitos verificados.
    assert re.search(r"(?m)^\s*Include\s*=", build) is None
    assert re.search(r"(?m)^\s*Include\s*=", live) is None


def test_parallel_downloads_is_capped_in_both_pacman_confs():
    for name in ("pacman.conf", "airootfs/etc/pacman.conf"):
        text = (PROFILE / name).read_text(encoding="utf-8")
        assert re.search(r"^ParallelDownloads\s*=\s*3\s*$", text, re.MULTILINE) is not None, name


def test_airootfs_mirrorlists_repeat_the_same_mirrors():
    mirrorlist = (PROFILE / "airootfs" / "etc" / "pacman.d" / "mirrorlist").read_text(encoding="utf-8")
    cachyos = (PROFILE / "airootfs" / "etc" / "pacman.d" / "cachyos-mirrorlist").read_text(encoding="utf-8")
    live = (PROFILE / "airootfs" / "etc" / "pacman.conf").read_text(encoding="utf-8")
    for repo in ("core", "extra"):
        for server in _repo_servers(live, repo):
            assert server in mirrorlist, (repo, server)
    for server in _repo_servers(live, "cachyos"):
        assert server in cachyos, server


def test_hyprland_config_is_installed_in_live_user_home():
    staged = PROFILE / "airootfs" / "home" / "nimbus" / ".config" / "hypr" / "hyprland.lua"
    source = ROOT / "dots" / "hypr" / "hyprland.lua"
    assert staged.is_file()
    assert staged.read_text(encoding="utf-8") == source.read_text(encoding="utf-8")
    # El build refresca la copia desde dots/ para que no se desincronice.
    build = BUILD_SH.read_text(encoding="utf-8")
    assert "dots/hypr/hyprland.lua" in build
    assert "airootfs/home/nimbus/.config/hypr/hyprland.lua" in build


def test_airootfs_has_localtime_symlink_so_firstboot_does_not_block():
    """Sin /etc/localtime, systemd-firstboot pide la zona horaria por consola
    y el arranque se queda esperando entrada: el marcador nunca sale."""
    link = PROFILE / "airootfs" / "etc" / "localtime"
    assert link.is_symlink(), "falta el symlink de /etc/localtime"
    assert link.resolve().name == "UTC"


# --- Pista ISO (T1-T4): sesion live estilo macOS y estable. ---

BACKGROUNDS = ROOT / "dots" / "backgrounds"
WALLPAPER_NAMES = ("Nimbus.png", "Nimbus-Light.png")


def test_nimbus_wallpaper_sources_exist_and_are_documented():
    assert (BACKGROUNDS / "generate.sh").is_file()
    for name in WALLPAPER_NAMES:
        assert (BACKGROUNDS / name).is_file(), f"falta el fondo {name}"
    readme = BACKGROUNDS / "README.md"
    assert readme.is_file()
    text = readme.read_text(encoding="utf-8")
    assert "SPDX-License-Identifier" in text
    assert "Nimbus.png" in text and "Nimbus-Light.png" in text


def test_nimbus_wallpaper_generator_is_deterministic_and_safe():
    script = BACKGROUNDS / "generate.sh"
    text = script.read_text(encoding="utf-8")
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in text
    assert "set -euo pipefail" in text
    assert "eval" not in text
    assert "convert" in text
    for name in WALLPAPER_NAMES:
        assert name in text, f"generate.sh no genera {name}"


def test_nimbus_dots_package_installs_the_backgrounds():
    text = (ROOT / "packages" / "nimbus-dots" / "PKGBUILD").read_text(encoding="utf-8")
    assert "usr/share/nimbus/backgrounds" in text
    for name in WALLPAPER_NAMES:
        assert name in text, f"nimbus-dots no instala {name}"


def test_live_user_wallpapers_match_the_nimbus_sources():
    staged = PROFILE / "airootfs" / "home" / "nimbus" / "Pictures" / "Wallpapers"
    for name in WALLPAPER_NAMES:
        candidate = staged / name
        assert candidate.is_file(), f"el shell lista ~/Pictures/Wallpapers: falta {name}"
        assert candidate.read_bytes() == (BACKGROUNDS / name).read_bytes(), (
            f"{name} desincronizado con dots/backgrounds"
        )


def test_wallpaper_files_are_png_and_non_trivial():
    for name in WALLPAPER_NAMES:
        data = (BACKGROUNDS / name).read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{name} no es un PNG valido"
        assert len(data) > 50_000, f"{name} sospechosamente pequeno: {len(data)} bytes"


def test_profile_includes_a_wallpaper_layer_client():
    assert "swaybg" in _packages()


def test_greeter_session_uses_start_hyprland_with_the_nimbus_config():
    desktop = PROFILE / "airootfs" / "usr" / "share" / "wayland-sessions" / "nimbus.desktop"
    assert desktop.is_file()
    text = desktop.read_text(encoding="utf-8")
    assert re.search(r"(?m)^Exec=/usr/lib/nimbus/nimbus-session\s*$", text), text
    session = PROFILE / "airootfs" / "usr" / "lib" / "nimbus" / "nimbus-session"
    assert session.is_file()
    script = session.read_text(encoding="utf-8")
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in script
    assert "set -euo pipefail" in script
    assert "/usr/bin/start-hyprland" in script
    assert "--config" in script
    assert "hyprland.lua" in script
    # Nuestra config, no la de Hyprland por defecto.
    assert "HWALLPAPER" not in script and "/usr/share/hypr/hyprland" not in script


def test_no_session_launcher_bypasses_start_hyprland():
    offenders = []
    for path in (PROFILE / "airootfs").rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        if path.suffix in (".png", ".gpg", ".revoked", "-trusted"):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for line in text.splitlines():
            stripped = line.strip()
            if stripped.startswith("ExecStart=") and "/usr/bin/Hyprland" in line:
                offenders.append(f"{path}:{stripped}")
    assert offenders == [], f"lanzadores directos de Hyprland sin wrapper: {offenders}"


def test_sddm_is_configured_with_nimbus_theme_and_autologin():
    conf = PROFILE / "airootfs" / "etc" / "sddm.conf.d" / "nimbus.conf"
    assert conf.is_file()
    text = conf.read_text(encoding="utf-8")
    assert re.search(r"(?m)^Current\s*=\s*nimbus\s*$", text), text
    assert re.search(r"(?m)^User\s*=\s*nimbus\s*$", text), text
    assert re.search(r"(?m)^Session\s*=\s*nimbus(\.desktop)?\s*$", text), text


def test_sddm_theme_is_packaged_from_versioned_sources():
    pkgbuild = (ROOT / "packages" / "nimbus-shell" / "PKGBUILD").read_text(encoding="utf-8")
    assert "usr/share/sddm/themes/nimbus" in pkgbuild
    assert "dots/sddm/nimbus" in pkgbuild
    theme = ROOT / "dots" / "sddm" / "nimbus"
    for name in ("Main.qml", "metadata.desktop", "theme.conf"):
        assert (theme / name).is_file(), f"falta el tema SDDM propio: {name}"
    main = (theme / "Main.qml").read_text(encoding="utf-8")
    assert "SPDX-License-Identifier: GPL-3.0-or-later" in main
    assert "sddm.login" in main, "el tema debe autenticar con el API real de SDDM"
    assert "sessionModel" in main and "userModel" in main
    assert re.search(r"^\s*Item\s*\{", main, re.M)
    for forbidden in ("Quickshell", "PanelWindow", "ShellRoot"):
        assert forbidden not in main


def test_display_manager_is_enabled_and_live_unit_is_gone():
    system = PROFILE / "airootfs" / "etc" / "systemd" / "system"
    assert not (system / "nimbus-live.service").exists()
    assert not (system / "graphical.target.wants" / "nimbus-live.service").exists()
    link = system / "display-manager.service"
    assert link.is_symlink(), "SDDM debe habilitarse como display-manager"
    assert link.readlink().as_posix() == "/usr/lib/systemd/system/sddm.service"
    wants = system / "graphical.target.wants"
    assert (wants / "nimbus-live-ready.service").is_symlink()
    assert not (wants / "nimbus-live.service").exists()


def test_live_ready_waits_for_the_display_manager_not_the_removed_unit():
    unit = PROFILE / "airootfs" / "etc" / "systemd" / "system" / "nimbus-live-ready.service"
    text = unit.read_text(encoding="utf-8")
    assert "nimbus-live.service" not in text
    assert "display-manager.service" in text
    # El marcador lo sigue escribiendo el script, nunca un ExecStart.
    starts = [line.strip() for line in text.splitlines() if line.strip().startswith("ExecStart=")]
    assert starts
    assert all("NIMBUS_LIVE_READY" not in line for line in starts), starts


def test_live_session_does_not_need_the_noop_libseat_backend():
    for path in (PROFILE / "airootfs").rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        assert "LIBSEAT_BACKEND=noop" not in text, (
            f"{path} aun usa noop: con SDDM hay sesion de logind"
        )


def test_live_network_and_dns_are_wired():
    system = PROFILE / "airootfs" / "etc" / "systemd" / "system"
    multi = system / "multi-user.target.wants"
    assert (multi / "NetworkManager.service").is_symlink()
    assert (multi / "systemd-resolved.service").is_symlink()
    alias = system / "dbus-org.freedesktop.resolve1.service"
    assert alias.is_symlink()
    assert alias.readlink().as_posix() == "/usr/lib/systemd/system/systemd-resolved.service"
    link = PROFILE / "airootfs" / "etc" / "resolv.conf"
    assert link.is_symlink(), "/etc/resolv.conf debe apuntar al stub de resolved"
    assert link.readlink().as_posix() == "/run/systemd/resolve/stub-resolv.conf"


def test_live_locale_defaults_to_spanish_shell_on_c_utf8_system():
    locale_conf = (PROFILE / "airootfs" / "etc" / "locale.conf").read_text(encoding="utf-8")
    assert re.search(r"(?m)^LANG=C\.UTF-8\s*$", locale_conf)
    defaults = (ROOT / "dots" / "nimbus" / "defaults.conf").read_text(encoding="utf-8")
    assert re.search(r"(?m)^locale\s*=\s*es\s*$", defaults)
    config = (ROOT / "shell" / "src" / "Nimbus" / "Config.qml").read_text(encoding="utf-8")
    assert re.search(r'property\s+string\s+locale\s*:\s*"es"', config)
    assert "setLocale" in config


def test_live_units_never_restart_in_a_loop():
    ready = PROFILE / "airootfs" / "etc" / "systemd" / "system" / "nimbus-live-ready.service"
    text = ready.read_text(encoding="utf-8")
    assert "Restart=" not in text, "un oneshot con Restart entraria en bucle tras Timeout"


def test_live_pacman_conf_has_no_broken_nimbus_repo():
    # La seccion [nimbus] del build apunta a un file:// que solo existe en
    # el host durante pacstrap. En la live rompia `pacman -Sy` entero: fuera.
    live = (PROFILE / "airootfs" / "etc" / "pacman.conf").read_text(encoding="utf-8")
    assert re.search(r"(?m)^\[nimbus\]\s*$", live) is None, "el repo de bootstrap no existe en la live"
    assert "bootmnt" not in live
    # El perfil de build si lo necesita para instalar nimbus-shell/dots.
    build = (PROFILE / "pacman.conf").read_text(encoding="utf-8")
    assert "[nimbus]" in build


def test_pacman_keyring_is_initialized_at_boot():
    # Sin esto, /etc/pacman.d/gnupg no existe en la live y pacman no puede
    # ni comprobar firmas ("Public keyring not found"). Patron de releng.
    system = PROFILE / "airootfs" / "etc" / "systemd" / "system"
    mount = system / "etc-pacman.d-gnupg.mount"
    assert mount.is_file()
    assert "Where=/etc/pacman.d/gnupg" in mount.read_text(encoding="utf-8")
    init = system / "pacman-init.service"
    assert init.is_file()
    text = init.read_text(encoding="utf-8")
    assert "pacman-key --init" in text
    assert "pacman-key --populate" in text
    assert (system / "multi-user.target.wants" / "pacman-init.service").is_symlink()


GATE = PROFILE / "airootfs" / "usr" / "lib" / "nimbus" / "nimbus-live-ready"


def _stub_bin(path, body):
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def _run_gate(tmp_path, pgrep_body, hyprctl_body, timeout="6"):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    out = tmp_path / "console.log"
    _stub_bin(bin_dir / "pgrep", pgrep_body)
    _stub_bin(bin_dir / "hyprctl", hyprctl_body)
    env = dict(
        os.environ,
        PATH=f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
        NIMBUS_LIVE_READY_TIMEOUT=timeout,
        NIMBUS_LIVE_READY_POLL="1",
        NIMBUS_LIVE_READY_STABLE_FOR="2",
        NIMBUS_LIVE_READY_OUT=str(out),
    )
    proc = subprocess.run(
        ["bash", str(GATE)], capture_output=True, text=True, env=env, timeout=60
    )
    return proc, out


def test_honest_gate_flaky_shell_never_writes_ready(tmp_path):
    """Un shell que muere al cargar (pid distinto en cada poll) no escribe
    NIMBUS_LIVE_READY: el gate espera en vano y senala TIMEOUT."""
    state = tmp_path / "calls"
    state.write_text("0", encoding="utf-8")
    pgrep = f"""#!/usr/bin/env bash
n=$(cat {state})
echo $((n + 1)) > {state}
if [ "$n" -lt 3 ]; then echo "100$n"; exit 0; fi
exit 1
"""
    hyprctl = """#!/usr/bin/env bash
echo '{"instances": [{"id": "x"}]}'
"""
    proc, out = _run_gate(tmp_path, pgrep, hyprctl)
    assert proc.returncode != 0
    text = out.read_text(encoding="utf-8")
    assert "NIMBUS_LIVE_READY" not in text.split("NIMBUS_LIVE_TIMEOUT")[0]
    assert "NIMBUS_LIVE_TIMEOUT" in text


def test_honest_gate_stable_shell_writes_ready(tmp_path):
    """Compositor que responde + mismo pid del shell tras la ventana de
    estabilidad => marcador honesto."""
    pgrep = """#!/usr/bin/env bash
echo 4242
exit 0
"""
    hyprctl = """#!/usr/bin/env bash
echo '{"instances": [{"id": "x"}]}'
"""
    proc, out = _run_gate(tmp_path, pgrep, hyprctl)
    assert proc.returncode == 0, proc.stderr
    assert out.read_text(encoding="utf-8").strip().splitlines()[-1] == "NIMBUS_LIVE_READY"
