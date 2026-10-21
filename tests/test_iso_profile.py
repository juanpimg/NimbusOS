# SPDX-License-Identifier: GPL-3.0-or-later
"""Perfil de ISO de Nimbus en formato archiso 91 (mkarchiso)."""
import pathlib
import re

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
    assert (PROFILE / "airootfs" / "etc" / "systemd" / "system" / "nimbus-live.service").is_file()
    assert (PROFILE / "airootfs" / "etc" / "systemd" / "system" / "nimbus-live-ready.service").is_file()
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
    # Contrato con el harness: Requires= y el marcador hacia la consola.
    assert "Requires=nimbus-live.service" in text
    assert "NIMBUS_LIVE_READY" in text
    assert "/dev/console" in text
    # ... pero el marcador lo escribe el script solo con la sesion lista,
    # nunca un ExecStart del unit que dispararia con la sesion en bucle.
    starts = [line.strip() for line in text.splitlines() if line.strip().startswith("ExecStart=")]
    assert starts, "el unit debe ejecutar el script de readiness"
    assert all("NIMBUS_LIVE_READY" not in line for line in starts), starts
    assert any("nimbus-live-ready" in line and "echo" not in line for line in starts), starts


def test_live_session_is_managed_by_hyprland_for_user_nimbus():
    live = PROFILE / "airootfs" / "etc" / "systemd" / "system" / "nimbus-live.service"
    ready = PROFILE / "airootfs" / "etc" / "systemd" / "system" / "nimbus-live-ready.service"
    text = live.read_text(encoding="utf-8")
    assert "User=nimbus" in text
    starts = [line.strip() for line in text.splitlines() if line.strip().startswith("ExecStart=")]
    assert any(
        "/usr/bin/Hyprland" in line
        and "--config" in line
        and "/home/nimbus/.config/hypr/hyprland.lua" in line
        for line in starts
    ), starts
    # El shell lo arranca la config de Hyprland, no este unit directamente.
    assert all("nimbus-shell" not in line for line in starts), starts
    # El marcador no debe aparecer si la sesion no arranco: Requires= lo garantiza.
    assert "Requires=nimbus-live.service" in ready.read_text(encoding="utf-8")


def test_live_units_are_enabled_at_boot():
    # live cuelga de graphical (su After=graphical.target lo exige) y ready
    # de multi-user: si ready colgara tambien de graphical, systemd detecta
    # un ciclo de orden (live->graphical->ready->live) y lo salta sin marcador.
    wants = PROFILE / "airootfs" / "etc" / "systemd" / "system"
    assert (wants / "graphical.target.wants" / "nimbus-live.service").is_symlink()
    assert (wants / "multi-user.target.wants" / "nimbus-live-ready.service").is_symlink()


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
    assert 'PKGDEST="$REPO_DIR" makepkg' in text
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
