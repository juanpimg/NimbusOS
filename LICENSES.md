# Licencias

> **Note for English-speaking contributors:** this licenses page is written in Spanish first. An English version will follow.

Nimbus es software libre bajo la GNU General Public License v3.0 o posterior.
El texto completo está en [`LICENSE`](LICENSE).

## Código distribuido

| Componente | Licencia | Ruta | Notas |
|------------|----------|------|-------|
| Componentes propios de Nimbus | GPL-3.0-or-later | Resto del repositorio | Todo el código propio (shell, instalador, tienda, herramientas, tests) se distribuye bajo `GPL-3.0-or-later`. |
| Código de terceros | — | `third_party/` | **Hoy no se distribuye código de terceros: el directorio `third_party/` no existe en el árbol** (verificado con `test -e third_party`). Si algún día se vendoriza código externo, se inventariará aquí con su licencia original. |

Cada fichero fuente declara su licencia en una cabecera `SPDX-License-Identifier`
verificada por `tools/check_spdx.py`: `GPL-3.0-or-later` en todo el árbol, y `MIT` bajo
`third_party/` si ese directorio llega a existir.

## Créditos de proyectos ascendentes (no vendorizados)

El panel Ajustes → Acerca de (`shell/src/Nimbus/apps/Settings/SettingsData.qml`, función
`credits()`) nombra estos proyectos. Son atribución e inspiración, **no código distribuido**
en este repositorio:

| Proyecto | Licencia | Relación con Nimbus |
|----------|----------|---------------------|
| MacShell | MIT | Inspiración del diseño del shell; no se distribuye su código. |
| WhiteSur | GPL-3.0-or-later | Tema de referencia para la estética; no se distribuyen sus assets. |
| Quickshell | GPL-3.0-or-later | Framework sobre el que se construye el shell (dependencia, no vendorizado). |

## Marcas y assets

Los nombres, logotipos y demás assets visuales de Apple están excluidos de este
repositorio por marca registrada. Nimbus no incluye ni distribuye ningún asset
propietario de Apple; la estética estilo macOS es una implementación original.

## Material de terceros incluido en el repositorio

Esta lista es **exhaustiva**: si algo de terceros se distribuye aquí, esta abajo.
(El proyecto solo distribuye codigo propio y este material; los fondos y los
iconos los genera el repo.)

| Que | De donde | Licencia | Donde vive |
|---|---|---|---|
| `security-audit` (skill de auditoria de seguridad) | [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) | MIT (Cloudflare, Inc.) | `.opencode/skills/security-audit/` (incluye su `LICENSE`) |
