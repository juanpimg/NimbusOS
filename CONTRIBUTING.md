# Contribuir a Nimbus

Gracias por querer contribuir a Nimbus. Este proyecto está en M0 (cimientos):
las reglas básicas importan más que las features.

## Licencias

- Todo el código propio se publica bajo `GPL-3.0-or-later`.
- Cada fichero fuente debe llevar su cabecera `SPDX-License-Identifier`
  en los primeros 600 bytes (`MIT` bajo `third_party/`,
  `GPL-3.0-or-later` en el resto).
- Antes de abrir un PR, ejecuta `python tools/check_spdx.py --root .`.
- No incluyas assets, nombres ni logotipos de Apple: están excluidos por
  marca registrada.

## Cómo contribuir

1. Abre o elige un issue y comenta tu intención antes de programar.
2. Trabaja en una rama `feature/<nombre-corto>` desde la rama principal.
3. Sigue el estilo del repo (`.editorconfig`: espacios, UTF-8, LF,
   salto de línea final).
4. Añade o actualiza los tests de tu cambio (`pytest`, `bats`,
   `qmltestrunner` según el área).
5. Verifica en local: `python -m pytest tests -v` y los linters que toque
   (`yamllint`, `actionlint`, `shellcheck`).
6. Abre el PR con una descripción clara: qué cambia, por qué y cómo se probó.

## Código de conducta

Toda participación está sujeta al [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
Mantén un trato respetuoso y profesional en issues, PRs y discusiones.
