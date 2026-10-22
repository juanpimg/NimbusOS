# Decisiones tomadas (y por qué)

<!-- La versión en inglés seguirá. -->

Registro de las **decisiones que se tomaron durante el desarrollo** y que no se
deducen del código. Cada una dice **qué** se decidió, **por qué** y **qué se
rompe si la decisión fue mala**.

Este documento existe porque el registro de trabajo (`ledger`) vive en
`.superpowers/`, que **no** se versiona: sin esto, las decisiones se perderían
al cambiar de máquina o al retomar el proyecto dentro de un mes.

## M0 — Fundaciones

- **El repo de paquetes se firma a mano, offline; la CI nunca firma.** Ruling:
  la clave privada no puede estar en una CI. Coste: la promoción
  `testing → stable` es manual (`tools/promote.sh`).
- **`SigLevel = PackageRequired DatabaseOptional`** en lugar de `Required`. Ruling:
  `Required` = `PackageRequired` + `PackageTrustedOnly`, y un keyring recién
  poblado no alcanza confianza *ultimate* (las firmas cruzadas de las claves
  maestras de Arch son SHA-1, que gpg 2.4+ rechaza) → **toda** firma salía
  como inválida. Coste: la DB no exige firma; los paquetes sí.
- **La clave actual es de bootstrap y hay que rotarla antes de publicar.** El
  procedimiento de 6 pasos está en `packages/README.md`. Coste: publicar sin
  rotarla publica una clave conocida.

## M1/M2 — Shell e instalador

- **El shell se monta con ventanas propias, no con `Loader`.** Ruling: un
  `Loader` de QML no instancia `PanelWindow`/`FloatingWindow` de forma fiable y
  **el fallo es silencioso** (el shell "arranca", la puerta de readiness dice
  que todo está bien y no se ve ninguna superficie). Coste: hay que instanciar
  a mano y perder la carga declarativa.
- **Las ventanas flotantes no declaran tamaño; su contenido no se ancla a
  ellas.** Ruling: si la ventana declara tamaño **y** el contenido se ancla,
  la circularidad se resuelve con **el tamaño de la pantalla** (una tarjeta de
  360 px se convertía en un cartel a pantalla completa). Coste: el centrado hay
  que hacerlo a mano.
- **Las superficies declaran su capa `layer-shell`** (fondo `Background`, barra
  y Dock `Top`, overlays `Overlay`). Sin capa, el fondo opaco del shell tapaba
  todo. Coste: hay que declararla en cada ventana.
- **`settings.conf` en YAML, no en INI.** Ruling: Calamares lo lee con
  `YAML::LoadFile`; en INI el instalador **no arrancaba**. Coste: ninguno.

## M3/M4 — Gameready, beta y la sesión live

- **La sesión live la arranca el greeter (SDDM con autologin), no un unit
  suelto.** Ruling: hace falta una **sesión de logind** de verdad (PAM) para
  que el compositor tenga el asiento; un `Type=idle` con `User=` no la da. Coste:
  el arranque depende del greeter, y sin display manager no hay sesión.
- **`LIBSEAT_BACKEND=noop` en la sesión live.** Ruling: libseat solo tiene
  backends `logind`/`seatd`/`noop`, y sin sesión de logind el backend `logind`
  aborta con `CBackend::create() failed!`. Con `noop`, wlroots abre el nodo DRM
  directamente. Coste: **no se puede cambiar de VT** ni pausar dispositivos
  (aceptable en una live de un solo compositor; el sistema instalado usará
  sesión de logind normal).
- **Los grupos del usuario live se declaran en `etc/sysusers.d/nimbus.conf`
  (tipo `m`), no editando `/etc/group`.** Ruling: `/etc/group` lo reescribe el
  scriptlet del paquete `shadow` y el paquete `filesystem` lo reemplaza en la
  transacción → la pertenencia a `video`/`render`/`input` se perdía y el
  compositor no podía abrir `/dev/dri/card0`. Coste: una unidad más.
- **La puerta de readiness es honesta.** Ruling: antes pillaba un proceso `qs`
  transitorio durante el init de EGL, justo antes de que muriese con
  `Failed to load configuration` → **daba verde con el escritorio roto**. Ahora
  el shell escribe su propio marcador y la puerta lo exige. Coste: una ISO con
  el shell caído no pasa el harness (que es lo correcto).
- **El tour de bienvenida se abre a petición, no al arrancar.** Ruling: en una
  live efímera se repetía en cada arranque y tapaba el escritorio. En un
  sistema instalado se sigue mostrando. Coste: el usuario nuevo no lo ve solo
  (mitigable: ofrecerlo en el menú de la Manzana).
- **El flag `--no-tour` por línea de comandos es inviable.** Ruling: `qs` usa un
  parser tipo clap → rechaza opciones desconocidas y aborta el arranque, y un
  `--` convierte el argumento en posicional. Se descartó el mecanismo. Coste:
  no hay forma de pasar argumentos a la app QML.
- **La ISO live es netinstall puro: no lleva `nimbus-gaming` ni `nimbus-energy`.**
  Ruling: dependen de Steam y Proton (pesados ✗) y la live solo necesita lo
  mínimo para arrancar. Coste: en la live no se puede tocar la energía.
- **El workflow de la ISO en GitHub es manual.** Ruling: el contenedor no
  permite montar `/proc` ni crear namespaces (comprobado por las dos vías:
  `--mount --pid` y `--user` → `Operation not permitted`). Un job que falla
  siempre por el entorno hace creer que la ISO está rota. Coste: la ISO deja
  de probarse en CI (ya no se probaba de verdad).
- **El tema del greeter tiene un solo dueño (`nimbus-installer`) y una sola
  fuente canónica (`installer/greeter/nimbus-greeter/`),** que además usa el
  API real de SDDM (`sddm.login`) y no señales inventadas. Ruling: los dos
  paquetes instalándolo hacían fallar la transacción con `conflicting files`,
  y la versión de `installer/greeter/` usaba un API que ningún daemon escucha.
  Coste: ninguno.
- **Las builds se serializan con un `flock`.** Ruling: la caché de pacman la
  comparten todas y dos builds a la vez se pisan → errores de firma que
  parecen de confianza pero son corrupción. Coste: dos builds no corren a la vez.

## Sobre este repositorio

- **Todo lo que se afirma aquí está verificado con un comando o una captura.**
  Lo que no se ha verificado en hardware real (GPU, batería, VRR, dual-boot
  con Windows) se dice explícitamente como pendiente.
- La memoria entre sesiones la da el plugin `opencode-mem` (ver
  [`CONTINUAR.md`](CONTINUAR.md) §5-bis): el plugin registra las trampas y las
  decisiones en una base local con vectores, para que una sesión nueva no
  vuelva a tropezar con ellas.
