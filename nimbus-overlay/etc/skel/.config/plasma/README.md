# dotfiles — configs Plasma (perfil activo)

Dotfiles canónicos del perfil Plasma. Fuente de verdad que se genera hacia
NimbusOS en una sola dirección (NimbusShell → NimbusOS).

- `dotfiles/.config/plasma/`: configs base Plasma (`plasmarc`,
  `plasmashellrc`, `kwinrc`, `kdeglobals`, `kglobalshortcutsrc`, `krunnerrc`,
  `kscreenlockerrc`, `plasma-org.kde.plasma.desktop-appletsrc`,
  `plasmanotifyrc` — F3-T09: banner arriba-derecha, 5s, DND).
- **KWin lee `~/.config/kwinrc`, no `plasma/kwinrc`:** `dotfiles/.config/kwinrc`
  es la copia efectiva (idéntica, verificada con `cmp` por
  `tests/bar/test_kwinrc.sh` y `scripts/ci.sh`). Toda edición de política KWin
  se hace en `plasma/kwinrc` y se duplica en `.config/kwinrc`; el instalador de
  NimbusOS copia el canónico al efectivo si falta y fija Klassy en ambos.
  (`kwinrulesrc` vive en la raíz de `dotfiles/.config`: KWin lo lee ahí.)
- **Convención:** identificadores `org.nimbus.*` para plasmoids, efectos KWin
  y KCM propios.
- **Qué va:** solo configs del perfil Plasma. **Qué no:** nada del
  compositor/shell anterior (criterio F1-T04: cero menciones al perfil
  legacy en este árbol); el perfil anterior vive congelado bajo
  `legacy/` (ver su README).
