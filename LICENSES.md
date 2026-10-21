# Licencias

Nimbus es software libre bajo la GNU General Public License v3.0 o posterior.
El texto completo está en [`LICENSE`](LICENSE).

## Componentes

| Componente | Licencia | Ruta | Notas |
|------------|----------|------|-------|
| MacShell | MIT | `third_party/macshell/` | Código vendorizado de MacShell, con su licencia original MIT y su cabecera SPDX `MIT`. |
| Componentes propios de Nimbus | GPL-3.0-or-later | Resto del repositorio | Todo el código propio (shell, instalador, tienda, herramientas, tests) se distribuye bajo `GPL-3.0-or-later`. |

Cada fichero fuente declara su licencia en una cabecera `SPDX-License-Identifier`
verificada por `tools/check_spdx.py`: `MIT` bajo `third_party/` y
`GPL-3.0-or-later` en el resto.

## Marcas y assets

Los nombres, logotipos y demás assets visuales de Apple están excluidos de este
repositorio por marca registrada. Nimbus no incluye ni distribuye ningún asset
propietario de Apple; la estética estilo macOS es una implementación original.
