# Arquitectura NimbusOS

Cómo encajan las piezas. Lee `AGENTS.md` y
[`architecture/PRODUCT-MODEL.md`](architecture/PRODUCT-MODEL.md) primero.

## 1. De dónde sale la ISO

```
CachyOS-Live-ISO (pin UPSTREAM_COMMIT)
  + nimbus-overlay/                 (base: live, Calamares, systemd, theming)
  + nimbus-overlay-plasma/          (delta Plasma: SDDM, barra, tema, skel)
  + packages.nimbus-plasma.append   (sistema + Plasma; 127 paquetes)
  + packages.nimbus-plasma-aur.txt  (AUR del perfil)
  + NimbusShell/dotfiles            (skel generado por nimbus-skel-sync)
  + NimbusShell/scripts/build-components (9 GUI + KCM)
  + repo local [nimbus]             (AUR precompilados)
  → mkarchiso → out/nimbus-YYYY.MM.DD-x86_64.iso
```

El perfil se elige con `--profile plasma|legacy-hypr`. El build son 7 pasos:
`check_deps → pin SOURCE_DATE_EPOCH → setup_keys → get_upstream →
apply_overlay → build → verify`.

## 2. Frontera con NimbusShell

NimbusShell es la fuente de verdad del escritorio. NimbusOS **no** copia a mano:

| Pieza | Origen | Cómo entra |
|---|---|---|
| Dotfiles / skel | `NimbusShell/dotfiles/` | `nimbus-skel-sync --apply` |
| Paquetes Plasma | `NimbusShell/packages/plasma.list` | `packages.nimbus-plasma.append` |
| Tema Tahoe / SDDM | `NimbusShell/packages/themes/` | Overlay Plasma |
| Barra / apps / KCM | `NimbusShell/packages/`, `apps/`, `packages/kcm/` | `build-components --destdir` |
| Sistema / ISO / arranque | `NimbusOS/` | Solo aquí |

## 3. Sesión gráfica (Plasma)

```
SDDM (tema nimbus) → Plasma 6.8 Wayland
  ├─ nimbus-bar.service / autostart (barra superior)
  ├─ KWin + scripts nimbus-* + efecto nimbus-overview
  ├─ Dock Krema (preset kremarc-nimbus)
  └─ KCM Nimbus en System Settings
```

El perfil legacy mantiene `greetd → Hyprland → MacShell` congelado.

## 4. Primer arranque e instalado

- `nimbus-live-setup`: pamac/Flathub, AUR diferido, servicios. En Plasma
  mantiene `power-profiles-daemon`; en Hyprland enmascara PPD y usa
  auto-cpufreq.
- `nimbus-installed-setup`: Calamares `%post`; en Plasma no toca greetd (SDDM
  manda) y habilita PPD/thermald/bluetooth; en Hyprland regenera greetd.
- El perfil se marca en `/etc/nimbus/profile` (`plasma` o `legacy-hypr`).

## 5. Límites conocidos

- La ISO Plasma **no está validada en VM todavía** (F12).
- Calamares/boost y GRUB se mantienen del perfil base.
- El perfil Hyprland no recibe features nuevas; solo fixes críticos de rollback.
- Subir `UPSTREAM_COMMIT` o `NIMBUS_SHELL_COMMIT` exige revalidar la ISO.
