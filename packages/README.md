# Modelo de pins: canales `testing` y `stable`

El repositorio `nimbus` sigue un modelo híbrido: la base rueda con CachyOS
y el stack de escritorio se pinea y se promueve a mano.

## Qué rueda y qué se pinea

Rolling (siguen a CachyOS/Arch sin congelar):

- `core`, `extra`
- `cachyos`, `cachyos-v3`, `cachyos-v4`

Pineado (solo entra lo que se promueve a `stable`):

- `nimbus`: `hyprland`, `quickshell`, `qt6-*`, `nimbus-shell`,
  `nimbus-dots`, temas, configs y reempaquetados de AUR.

Consecuencia: una rotura de Hyprland o Quickshell upstream llega primero a
`testing` y nunca al usuario hasta que alguien la ha probado.

Ejemplo de `pacman.conf` en un usuario de `stable`:

```ini
[nimbus]
SigLevel = Required DatabaseOptional
Server = https://github.com/juanpimg/NimbusOS/releases/download/stable/$arch
```

Los testers de beta cambian la URL a `testing` para optar al canal
de pruebas.

## Flujo `testing` → `stable`

1. La CI compila los PKGBUILDs de `packages/` y publica los
   `*.pkg.tar.zst` en `testing` **sin firmar**. La clave maestra nunca
   vive en un runner de CI.
2. Alguien arranca la ISO en QEMU, prueba el escritorio y decide
   promocionar.
3. La promoción es un acto manual con la clave offline:

```bash
tools/promote.sh \
  --from /srv/repo/testing \
  --to /srv/repo/stable \
  --gpgdir /run/media/offline/gnupg \
  --key 0DB3E603DB1FDD884F9CB903A872CF40DB22D699
```

4. Los usuarios de `stable` reciben el stack nuevo en la siguiente
   sincronización (`pacman -Syu`).

## Contrato de `promote.sh`

```bash
tools/promote.sh --from <dir> --to <dir> --gpgdir <dir> --key <fpr>
```

- Copia los `*.pkg.tar.zst` y `*.pkg.tar.gz` de `--from` a `--to`
  **solo si** no existe ya allí un paquete con el mismo
  `nombre-versión` (todo antes del sufijo `-<arquitectura>.pkg.tar.*`).
  Si alguno colisiona, imprime
  `el paquete <nombre-versión> ya existe en el destino` y sale con 1
  **sin copiar nada** (promoción atómica: o todo o nada).
- Firma cada paquete copiado con la clave offline
  (`gpg --detach-sign`), para que `verify_repo.sh` pueda comprobarlo.
- Regenera la DB con `repo-add` desde los paquetes presentes en `--to`
  (reconstrucción completa en un temporal dentro de `--to`, que solo se
  mueve a su sitio si `repo-add` funciona; si falla, la DB anterior queda
  intacta) y firma la DB resultante con
  `tools/sign_repo.sh --repo <to> --gpgdir <gpgdir> --key <fpr>`.
- Si `--from` está vacío, no hay nada que promover: el destino se deja
  intacto, no se crea ni se toca ninguna base de datos, se imprime
  `nada que promover: --from no contiene paquetes; no se creó ninguna base de datos`
  y se sale con 0.
- Requiere `repo-add` en el PATH; si falta, imprime
  `repo-add no encontrado: instala el paquete repo` y sale con 1.

## Contrato de `verify_repo.sh`

```bash
tools/verify_repo.sh --repo <dir> --gpgdir <dir>
```

- Verifica la DB: `gpg --verify <repo>/nimbus.db.sig <repo>/nimbus.db`.
- Verifica cada paquete: `gpg --verify <paquete>.sig <paquete>`.
  Un paquete sin fichero `.sig` contiguo cuenta como fallo.
- Acumula fallos; si hay alguno, imprime la lista y sale con 1.
  Si todo cuadra, imprime `repo verificado: N paquetes` y sale con 0.

Ejemplo:

```bash
tools/verify_repo.sh --repo /srv/repo/stable --gpgdir /run/media/offline/gnupg
# repo verificado: 4 paquetes
```

## Rotación de clave

1. Generar la clave nueva en una máquina offline:
   `tools/genkeyring.sh --outdir /tmp/nuevo --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"`.
2. Firmar todo el repo actual con la clave nueva: re-ejecutar
   `promote.sh` con `--gpgdir` del disco nuevo (los paquetes ya
   presentes se re-firman y la DB se regenera y se firma de nuevo).
3. Publicar el nuevo keyring (`nimbus.gpg`, `nimbus-trusted`,
   `nimbus-revoked`) como release firmado.
4. Añadir la clave nueva al keyring de los usuarios: publicar
   `nimbus-keyring` con ambas claves en `nimbus-trusted` y hacer que
   `stable` lo sirva antes de retirar la antigua.
5. Revocar la clave antigua: añadir su revocación a `nimbus-revoked`
   y publicar el `nimbus-keyring` final solo con la nueva.
6. Actualizar `packages/nimbus-keyring/` en este repo (PKGBUILD,
   `.install` y ficheros de `usr/share/pacman/keyrings/`) y etiquetar
   el commit para que la ISO siguiente embeba el keyring nuevo.

## Custodia de la clave offline

**La clave offline se guarda cifrada en dos sitios y el procedimiento
de recuperación está escrito aquí.**

- Copia 1: USB cifrado (LUKS) guardado fuera de la máquina de firma,
  con la subclave de firma y el certificado de revocación pregenerado.
- Copia 2: segundo soporte cifrado en una ubicación física distinta,
  con el mismo contenido y la passphrase en sobre sellado.
- Recuperación: arrancar una live sin red, abrir el soporte con
  `cryptsetup open`, importar con
  `gpg --homedir <gpgdir> --import <respaldo>.asc`, comprobar el
  fingerprint con `gpg --list-keys --with-colons` y re-firmar el repo
  con `promote.sh` como en el flujo normal. Si un soporte se pierde,
  rotar la clave siguiendo los 6 pasos de arriba antes de seguir
  firmando.
