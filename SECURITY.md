# Política de seguridad

> **Note for English-speaking contributors:** this security policy is written in Spanish first. An English version will follow.

## Cómo reportar una vulnerabilidad

El proyecto **no tiene dirección de correo de seguridad** (no hay ninguna publicada en el
árbol y no se inventa una aquí). El canal para reportes es el propio GitHub:

1. Ve a la pestaña **Security** del repositorio (`https://github.com/juanpimg/NimbusOS/security`)
   y usa **Report a vulnerability** (aviso privado, `GitHub Security Advisories`).
2. Si ese canal no está disponible, abre un issue normal **sin detalles explotables** (describe el
   componente afectado y cómo contactarte) y pide una vía privada.

No publiques exploits ni datos sensibles en issues públicos, discusiones ni pull requests.

## Alcance

- Cadena de firma y keyring (`tools/genkeyring.sh`, `tools/sign_repo.sh`, `tools/promote.sh`,
  `tools/verify_repo.sh`, `packages/nimbus-keyring/`).
- Instalador Calamares ejecutado como root (`installer/calamares/`, `installer/tools/`).
- Agente de autenticación del shell (`shell/src/Nimbus/PolkitAgent.qml`).
- Superficies del shell que ejecutan acciones del sistema (`shell/src/`).

## Plazo

Nimbus lo mantiene una sola persona. El compromiso es honesto y modesto:

- **Acuse de recepción: 7 días naturales** desde el aviso privado.
- **Corrección o plan público: 30 días naturales** para vulnerabilidades confirmadas en el alcance.
- Si un plazo no se puede cumplir, se dice en el propio aviso, no se deja en silencio.

## Versiones soportadas

Solo la rama `main` recibe correcciones de seguridad. No hay releases versionadas todavía
(ver [CHANGELOG.md](CHANGELOG.md)): cuando las haya, se listarán aquí las soportadas.
