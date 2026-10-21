<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

## Qué cambia y por qué

<!-- Una o dos frases. Enlaza el issue si lo hay. -->

## Cómo se probó

<!-- Pega la salida de los tres comandos (o los que apliquen; justifica los que no): -->

```text
python -m pytest tests -v
# ...

PATH="$HOME/.local/bin:$PATH" bats tests/*.bats
# ...

QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/shell/src" /usr/lib/qt6/bin/qmltestrunner -input shell/tests
# ...
```

## Lista de comprobación

- [ ] Tests en verde (los tres suites, o justificado arriba).
- [ ] Cabecera SPDX en cada fichero nuevo (`python tools/check_spdx.py --root .` en verde).
- [ ] Toda cadena visible al usuario existe en español e inglés.
- [ ] Sin assets ni marcas de Apple.
- [ ] Si toca el aspecto: capturas del antes y el después (nadie ha visto aún el escritorio en
  una sesión real; no se promete ninguna captura que no exista).
- [ ] Mensaje del commit en inglés, estilo convencional.
