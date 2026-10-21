# Fondos de Nimbus

<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

Aurora abstracta original del proyecto, en la paleta macOS del tema
(claro `#F5F5F7`, oscuro `#1C1C1E`, acentos azul `#0A84FF`,
violeta `#5E5CE6`, turquesa `#30B0C7` / `#64D2FF`). No contiene assets de
Apple ni de terceros: todo se dibuja con `generate.sh` (ImageMagick).

## Ficheros

| Fichero           | Variante | Uso                                    |
|-------------------|----------|----------------------------------------|
| `Nimbus.png`      | oscura   | Fondo por defecto de la sesión live    |
| `Nimbus-Light.png`| clara    | Variante clara del mismo fondo         |

El sufijo `-Light` sigue la convención del selector del shell
(`shell/src/Nimbus/modules/Wallpaper.qml`, `groupPairs`): `Nimbus.png` y
`Nimbus-Light.png` forman UN par claro/oscuro, no dos fondos sueltos.

## Regenerar

```bash
dots/backgrounds/generate.sh
```

Requiere `convert` (ImageMagick). La generación es determinista a nivel de
byte (sin azar, sin metadatos de fecha gracias a `-strip`): regenerar
produce los mismos SHA256, así que los PNG se versionan sin miedo.

## Instalación

- El paquete `nimbus-dots` los instala en `/usr/share/nimbus/backgrounds/`.
- La ISO live copia este par en `~/Pictures/Wallpapers` del usuario
  `nimbus`, que es la carpeta que el selector del shell ya lista.
- La sesión live muestra `Nimbus.png` vía `swaybg` (ver `dots/nimbus/nimbus-start`).
