# sddm-nimbus — tema SDDM propio (F2-T02)

Login macOS-centrado para SDDM (QML, Qt6): fondo Sequoia NPS, reloj,
selector de usuario (`userModel`), contraseña, selector de
sesión (`sessionModel`), teclado/idioma, apagar/reiniciar. Glass y
tokens de `packages/themes/nimbus-tokens` (`NimbusTokens.qml` copiado
md5-idéntico; acento `#0A84FF`).

## Instalación

ISO (F2-T06): el tema se instala en `/usr/share/sddm/themes/nimbus/` y
`10-nimbus.conf` activa `[Theme] Current=nimbus`. Manual:

```bash
sudo cp -r packages/themes/sddm-nimbus /usr/share/sddm/themes/nimbus
sudo cp dotfiles/.config/sddm/sddm.conf.d/10-nimbus.conf /etc/sddm.conf.d/
sudo systemctl enable sddm.service
```

## Dependencias

`sddm>=0.21.0`, `layer-shell-qt` (solo si greeter Wayland), fuente
Inter, `Background.jpg` (Sequoia NPS, `assets/sequoia-light.jpg`).

## Atribución

Arte 100% propio NPS (R-APPLE: sin logos, tipografías, wallpapers ni
sonidos de Apple). Sin código de terceros: no requiere atribución.

## Límites

- Greeter X11 por defecto (el greeter Wayland de SDDM sigue
  experimental, ArchWiki 2026-10). Sesión de usuario siempre Wayland.
- `qmllint` falla sin `SddmComponents` instalado (esperado en host sin
  SDDM); la sintaxis se valida con `qmlformat` (ver `evidence/F2-T02.md`).
- Preview real: `sddm-greeter-qt6 --test-mode --theme ...` (requiere SDDM;
  diferido a VM F2-T08). El stub `preview/` solo valida layout.
- Autologin vacío por defecto; solo VM de pruebas (ver `10-nimbus.conf`).
