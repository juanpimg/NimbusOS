# Nimbus — Documento de diseño

**Fecha:** 2026-10-21
**Estado:** Borrador para revisión del constructor
**Autor:** jp (fundador) con el asistente de diseño

---

## 1. Intención

Nimbus es una distribución Linux para personas que nunca abrirán una terminal y que llegan
desde macOS o Windows. La promesa es una sola:

> **Enciendes, instalas, y estás usando el ordenador. Nunca escribes un comando.**

Hoy, "usar Linux" significa "investigar el gestor de paquetes, elegir entre Flatpak, AUR o
repos, descubrir que tu vídeo no reproduce, y pelearte con los drivers de la GPU". Nimbus
elimina ese trabajo: un instalador que parece un asistente de macOS, un escritorio escrito
desde cero que se siente como Tahoe, un "gameready" de un clic y actualizaciones que nunca
dejan el sistema roto.

La tesis de diseño es que **la estética y la/usabilidad no son dos cosas**. En Linux el
problema real del novato no es que el escritorio sea feo: es que no entiende el modelo mental.
macOS y Windows esconden el modelo mental detrás de un lenguaje visual coherente —
"Dock", "Spotlight", "Control Center", "Barra de menú superior". Si el escritorio de Nimbus
*se parece* a macOS, la persona que viene de macOS **ya sabe usarlo**. La estética no es
decoración: es el mapa mental.

De ahí sale la regla que gobierna todo el proyecto:

> **Todo debe parecer nativo. Nada de parches copiados de otros sitios.**

Eso significa que el shell de escritorio, la tienda, el instalador, el greeter y los avisos
son **código propio de Nimbus**, escritos contra un único sistema de diseño, no un montón de
temas de terceros pegados con cinta.

## 2. Objetivos, no-objetivos y anti-objetivos

### Objetivos

| # | Objetivo |
|---|-----------|
| G1 | Cero terminal para el 100 % de las tareas comunes (instalar apps, configurar GPU, batería, red, actualizaciones, impresión) |
| G2 | Un único escritorio coherente, con un solo lenguaje visual, escrito por nosotros |
| G3 | "Gameready" decidible en el instalador: Steam, Proton, gamescope con VRR/HDR, Heroic/Lutris/Bottles listos para jugar |
| G4 | Portátil primero: perfiles de energía, umbrales de batería, gráficos híbridos, suspensión fiable |
| G5 | Una distro que una comunidad pueda mantener: repo propio firmado, rolling, snapshots Btrfs y rollback de un clic |
| G6 | Pública desde el día 1: repos abiertos, issues abiertas, decisiones documentadas |
| G7 | Nimbus Store propia: instalar software debe ser tan natural como en la App Store |

### No-objetivos

- **No** es un retheme de KDE/Plasma.
- **No** es un fork de Mainstream OS ni de MacShell. Aprendemos de ellos; no heredamos su código
  ni su deuda técnica.
- **No** es un SteamOS competidor. Nos diferenciamos en la estética y el approche novato.
- **No** pretende soportar todo el hardware del mundo en v1. Cubre AMD mainstream, Intel
  integrada y Arc, NVIDIA (con y sin dGPU), y portátiles híbridos. Fuera de alcance: hardware
  exótico, ARM64, servers.
- **No** tiene telemetría. Es un proyecto comunitario; los datos no se teletransportan.
- **No** es una distribución de escritorio "configurable por expertos". La configuración
  avanzada existe, pero está detrás de la experiencia por defecto.

### Anti-objetivos — qué harían fracasar Nimbus aunque "funcione"

- **A1.** El usuario tiene que abrir una terminal para una tarea normal.
- **A2.** El escritorio parece "Linux con un fondo de pantalla de macOS" — o peor, un collage
  de cuatro proyectos ajenos pegados. Un solo lenguaje visual, un solo sistema de tokens.
- **A3.** Una actualización de Hyprland, Quickshell o Mesa rompe el escritorio y el usuario no
  tiene forma de volver atrás.
- **A4.** Instalar Nimbus tarda más de 10 minutos.
- **A5.** Es un proyecto de una sola persona que muere en tres meses. (Mitigado por G6.)

## 3. Decisiones ya tomadas

Estas decisiones las tomó el fundador durante la fase de discovery y no se reabren sin una
reunión explícita:

| Decisión | Valor | Razón |
|----------|-------|--------|
| Base | **CachyOS** | Repos con x86-64-v3/v4 + LTO/PGO/BOLT, kernel propio con sched-ext/LAVD/BORE, `chwd` para autodetección de hardware, zram, ananicy-cpp, firejail, Calamares ya mantenido |
| Escritorio | **Hyprland + shell propio en Quickshell (QML)**, construido sobre código vendorizado de MacShell (MIT) y reimplementando patrones de Mainstream OS / end-4 | Único camino a Liquid Glass real y a un modelo de interacción Apple completo. "Propio" significa **código nuestro y vendorizado**, no código escrito desde un folio en blanco |
| Sesiones | **Solo Hyprland + nuestro shell** | Una sola experiencia, coherente y mantenible |
| Distribución de apps | **Híbrida** — Flatpak (Flathub) para escritorio, nativo/AUR para juegos y drivers | Sensación de App Store sin perder rendimiento en gaming |
| Tienda | **Nimbus Store, propia en Quickshell** | Coherencia con el resto; nada de "app de Linux pegada en el escritorio" |
| Selección de apps | **En el instalador**, al estilo OEM | El primer arranque llega con todo listo, no con un formulario |
| Actualizaciones | **Rolling + snapshots Btrfs + rollback de un clic** | La red de seguridad que la base Arch no trae |
| Primer arranque | **Tour guiado de 2 minutos**, nada más | Todo lo demás ya viene hecho desde el instalador |
| Gameready | **Toggle en el instalador**; el contenido lo define este documento | Decisión delegada al fundador |
| Idiomas | **ES + EN de fábrica**, infraestructura gettext lista para traducción por comunidad | |
| Nombre | **Nimbus** | Sin conflictos con otras distros; evoca la capa translúcida |
| Tienda | **Nimbus Store** | |
| Horizonte | **Beta pública primero, v1.0 después** | Feedback real antes de prometer |
| Mantenimiento | **Comunidad desde el día 1** | Repos públicos, issues abiertas, decisiones documentadas |
| Nombre del proyecto | **Nimbus** (directorio de trabajo: `Linux-MacOS`) | |
| Modelo de release | **Híbrido**: base rolling de CachyOS + stack de escritorio **pineado y promovido por CI** | La base se mueve sola; el escritorio se congela hasta que la CI lo aprueba. Evita el rotura-de-Hyprland-a-todos-y-a-las-3am (anti-objetivo A3) |
| Secure Boot | **Requisito de v1.0**, no bloqueante para las betas | La mayoría de portátiles con Windows vienen con Secure Boot activo. Se diseña desde M0 pero se entrega antes de v1.0 |
| Modo de instalación | **Netinstall puro**, ISO < 3 GB | Se instala rápido y la ISO se baja rápido. Requiere red en el momento de instalar |
| Arranque dual | **Sí, con GRUB y salvaguardas** | Es el escenario más común de un portátil con Windows; no se puede dejar fuera |
| Repo y firma | **GitHub** (Actions artifacts + Releases + CDN) con **firma GPG offline manual** | La clave maestra nunca vive en un runner de CI. La CI compila y prueba; la promoción a stable es un acto manual |
| Agente de polkit | **Propio, dentro de nuestro shell** | Sin KDE ni GNOME instalados no hay agente de polkit. Escribirlo en Quickshell es coherente con G2 y evita una ventana de estilo ajena |
| Hibernación / TPM2 | **Fuera de v1** | `s2idle` cubre el caso de uso real del portátil. Hibernar sobre Btrfs con swapfile exige offset, hooks de initramfs y una política de sueño completamente distinta |
| corte de hardware | §4.13 | Con una sola máquina de prueba, la lista cerrada define qué exige el programa beta |

### Relleno de decisiones tomadas por esta sesión (no las tomó el fundador explícitamente)

Estas son **mis** llamadas, marcadas como tales. Si alguna no cuadra, es el sitio más barato de
corregir el diseño:

- **D1. Iconos:** empaquetamos **WhiteSur** (GPL-3.0) como base de la cobertura de apps, con
  atribución visible. Recrear un set de iconos propio son años de trabajo y no es donde está
  el valor de Nimbus. Se documenta en los créditos y en `LICENSES.md`. *Rationale:* el
  anti-objetivo A2 habla de coherencia del escritorio, no deKgdraw authorship de cada PNG.
- **D2. Tipografía:** **Inter** (SIL OFL) como sustituto de SF Pro. SF Pro es propietario y no
  se puede redistribuir.
- **D3. Logo:** diseño propio, geometría abstracta de nube/cristal. Nada de assets de Apple
  (prohibido por marca registrada). El shell **no** dibuja el logo de Apple.
- **D4. Greeter:** **SDDM** con tema propio de Nimbus (CachyOS ya usa SDDM en instalaciones
  Plasma). Alternativa descartada: greetd.
- **D5. Gestor de energía:** `power-profiles-daemon` + `auto-cpufreq` (que ya trae CachyOS).
  **No** usamos TLP: es invasivo, entra en conflicto con power-profiles y ya está en
  mantenimiento ligero.
- **D6. Graphs:** Btrfs es el sistema de archivos por defecto y **el único con rollback
  completo**. En ext4/xfs el sistema funciona igual pero sin snapshots: en su lugar se instala
  un kernel LTS como red de seguridad.
- **D7. AUR:** los paquetes de AUR que necessitamos se reempaquetan y compilan en nuestro repo
  `nimbus`, firmados con GPG. **El usuario final nunca necesita yay/paru ni AUR.**
- **D8. Arquitectura:** solo x86-64 en v1. aarch64 queda fuera.
- **D9. Scope del shell en v1:** barra de menú global, dock, Spotlight, Centro de Control,
  notificaciones, switcher, capturas, pantalla de bloqueo, selector de fondos, Ajustes del
  sistema, Nimbus Store, tour. Los widgets de escritorio (clima, reloj) son **post-v1**:
  es la parte más frágil del shell y la de menor valor para un novato.
- **D10. Steam:** **nativo** desde nuestro repo (no Flatpak) — mismo criterio que SteamOS,
  mejor rendimiento y mejor integración con Proton/gamescope. El Flatpak de Steam se ofrece
  como alternativa en la tienda.
- **D11. Agente de polkit:** propio, escrito en Quickshell dentro de nuestro shell. Al no
  estar KDE ni GNOME instalados, `polkit-gnome` sería una ventana ajena al diseño.(password
  con estilo Nimbus, misma glass.)
- **D12. Modelo de privilegios:** el usuario creado en el instalador pertenece a `wheel` y
  usa `sudo` con **timeout de 5 minutos** y least-privilege por defecto; el login de root está
  deshabilitado. Se prefiere siempre polkit (Store, actualizaciones, energía, red) antes que
  `sudo`, para que el usuario interactúe con un diálogo, no con una terminal.
- **D13. Swap y cifrado:** `zram-generator` (ya en CachyOS) es el único swap. **Sin swapfile y
  sin hibernación en v1.** LUKS2 **solo con passphrase**, sin TPM2/`systemd-cryptenroll`: un
  TPM reseteado por el fabricante dejaría el disco inaccesible, y ese riesgo no compensa en
  v1. Reconsiderado en v2.
- **D14. Licencia del shell: GPL-3.0**, obligatoriamente, porque vendorizamos código GPL-3.0
  de Mainstream OS / end-4 y porque el resto de la distro (Calamares, archiso) ya lo es. Es
  además la licencia correcta para un proyecto comunitario: cualquiera puede auditar y
  reutilizar Nimbus. El código MIT de MacShell es compatible sin problema.

### Procedencia del código: qué tomamos de dónde

Reutilizar código es una decisión de ingeniería, no un accidente. La regla de Nimbus:

> **Tomamos prestada la implementación. Nunca la identidad.**

**Permitido, con atribución:**
- **MacShell (MIT)** — el shader de refracción de cristal, la estructura de módulos QML, el
  patrón del lock screen, la lógica del Spotlight. Se **vendoriza**: el código vive en
  nuestro repo, con el historial de licencias intacto. **No es una dependencia en runtime**
  — si el GitHub de MacShell desaparece mañana, Nimbus sigue funcionando igual.
- **Mainstream OS (GPL-3.0)** — los *patrones* (snapshot antes de cada actualización,
  verificación post-instalación, sesión de juegos, repo con firma offline). El código se
  **reimplementa** salvo que la reimplementación no aporte nada, y entonces se documenta el
  origen.
- **end-4/dots-hyprland (GPL-3.0)** — configuración de Hyprland, estructura de la config
  Lua, integraciones de IPC.
- **WhiteSur (GPL-3.0)** — iconos.

**Prohibido:**
- Instalar el shell de otro proyecto tal cual y llamarlo Nimbus.
- Que Nimbus dependa en runtime de un repositorio externo para funcionar.
- Que un componente visible no use nuestros tokens de diseño. **Si algo no pasa por el
  sistema de tokens, no entra.** Esto es lo que garantiza que no parezca un collage.

**Regla operativa:** todo componente visible que no sea nuestro se **reimplementa o se adapta
hasta que pase por nuestros tokens**. Si al final se parece a su original, se admite — pero
entonces ya es código nuestro, y el original queda como referencia histórica en el commit
message.

**El bug que se hereda y hay que arreglar.** Tomar la captura de ventanas en vivo de MacShell
significa heredar su crash conocido: `wl_display: invalid object` cuando muchas ventanas
abren y cierran — que es exactamente lo que pasa cuando arranca un juego. **No se reproduce:
se corrige de raíz antes de la beta**, porque el stack de juegos depende de ello. Es el
precio de heredar código: también se heredan sus defectos, y hay que pagarlos.

#### Licencias y compatibilidad

El shell de Nimbus es **GPL-3.0**. Compatibilidad verificada antes de vendorizar nada:

| Origen | Licencia | ¿Compatible con GPL-3.0? |
|--------|----------|--------------------------|
| MacShell | MIT | Sí — MIT es permisiva y compatible |
| Mainstream OS, end-4/dots-hyprland, WhiteSur | GPL-3.0 | Sí — el derivado debe ser GPL-3.0 |
| Inter | SIL OFL 1.1 | Sí |
| Calamares, archiso | GPL-3.0 | Sí — ya son forks |

Todo el código vendorizado conserva sus cabeceras de licencia, aparece en `LICENSES.md` y en
los créditos de Ajustes → Acerca de. Los assets de Apple (logo, SF Pro, capturas) quedan
excluidos por marca registrada.

### Requisitos de Secure Boot

Objetivo de v1.0 (no bloqueante para las betas):

- Arranque con **systemd-boot + UKI** firmado por una clave de Nimbus, encadenada a un
  **shim firmado por Microsoft** (el shim de Microsoft valida el UKI de cualquier distro).
- Gestión con **`sbctl`** (firmar, enrolar claves, revocar).
- La ISO se arranca con el shim de Microsoft para que el usuario no tenga que desactivar
  Secure Boot antes de instalar.
- **Limitación honesta:** el shim de Microsoft deja de ser válido cuando Microsoft lo revoca
  (algo que ya ha pasado). Por eso la clave de Nimbus debe estar **revocable y rotable** por
  nuestra parte sin depender de Microsoft. Se documenta en el wiki.
- La ISO de las betas se firma con MOK provisional hasta que el shim esté listo.

## 4. Arquitectura

### 4.1 Capas

```
┌──────────────────────────────────────────────────────────────────────┐
│  Nimbus Shell (QML/Quickshell)  ·  Nimbus Store  ·  Ajustes  ·  Tour  │  ← nuestro código
├──────────────────────────────────────────────────────────────────────┤
│  Hyprland (compositor)  ·  SDDM (greeter)  ·  Calamares (instalador) │  ← config. nuestra sobre base mantenida
├──────────────────────────────────────────────────────────────────────┤
│  Repo nimbus (GPG)  ·  repo cachyos  ·  repo cachyos-v3/v4  ·  Flathub │  ← paquetes
├──────────────────────────────────────────────────────────────────────┤
│  kernel linux-cachyos  ·  Mesa  ·  drivers  ·  systemd  ·  PipeWire │  ← base CachyOS
└──────────────────────────────────────────────────────────────────────┘
```

### 4.2 Base: CachyOS

Lo que heredamos sin tocar nada:

- `linux-cachyos` y variantes de scheduler (sched-ext/LAVD/BORE/BMQ). LAVD es el mejor
  performer para gaming y es el que activaremos por defecto en el perfil "gameready".
- Repos `cachyos-v3` y `cachyos-v4` (x86-64 optimizados) + `cachyos-v4-zen4`.
- `chwd` (autodetección de hardware y drivers), `ananicy-cpp` (prioridades de procesos),
  `zram-generator`, `firejail`.
- `cachyos-calamares-next`: Calamares fork con módulos de bootloader, `mhwd`/`chwd` para
  drivers, y `netinstall.yaml` con perfiles de desktop ya definidos.

Lo que **no** heredamos: los perfiles de desktop de CachyOS (Hyprland+Noctalia, Plasma,
GNOME, etc.). Los sustituimos por un único perfil: `nimbus`.

#### Modelo de pins (híbrido)

Este es el mecanismo que sostiene el anti-objetivo A3. La base se mueve sola; el escritorio,
no.

| Capa | ¿De dónde viene? | ¿Se congela? |
|------|------------------|----------------|
| `linux-cachyos` y variantes | repo cachyos | No — rolling |
| Mesa, drivers, systemd, firmware | repo cachyos | No — rolling |
| `hyprland`, `quickshell`, `qt6-*` | **repo nimbus** | **Sí** |
| `nimbus-shell`, `nimbus-store`, tema, configs | **repo nimbus** | **Sí** |
| Paquetes reempaquetados de AUR (D7) | **repo nimbus** | **Sí** |

Cómo funciona:

1. `nimbus/packages` construye Hyprland, Quickshell y el shell contra las versiones actuales
   de la base. La CI compila, lintea y arranca la ISO en QEMU.
2. Una **rama `testing`** en el repo nimbus recibe esos binarios en cuanto pasan los tests.
3. La promoción a `stable` es un **acto manual y deliberado**: alguien (el fundador o un
   mantenedor con acceso a la clave offline) prueba la ISO y mueve las versiones.
4. Los usuarios reciben `stable`. Los testers de beta pueden opt-in a `testing` con una línea
   en `pacman.conf`.

Consecuencia: una rotura de Hyprland o Quickshell upstream **no llega al usuario** hasta que
la CI y una persona la han visto. Ese es el diseño, no un accidente.

El coste es real y hay que decirlo: mantenemos un desfase con upstream que alguien tiene que
gestionar (rebasear sobre `testing`, resolver conflictos, probar la promoción). Por eso el
stack de escritorio se mantiene lo más pequeño posible: menos piezas = menos desfase.

### 4.3 Escritorio: Hyprland + shell propio

El shell de Nimbus es **código nuestro, no código ajeno instalado**. Nace de tomar la
implementación de referencia (MacShell, MIT) y convertirla en un producto con su propia
identidad: nuestros tokens, nuestros componentes, nuestro nombre, nuestro ciclo de
lanzamiento. Ver §3 "Procedencia del código".

El criterio de calidad no es "qué porcentaje es nuevo" sino **"¿se siente como un producto
único?"**. Si un usuario ve Nimbus y no puede decir de qué proyecto salió cada parte, hemos
acertado.

#### 4.3.1 Por qué Hyprland

Es la única base que permite un shell estilo macOS real: compositor Wayland con control
fino de capas, blur por región, animación de entrada/salida de superficies, workspaces y
extensiones. KDE/Plasma puede *disfrazarse* de macOS; Hyprland puede *ser* el sustrato de
macOS.

Configuramos Hyprland en **modo flotante por defecto** con comportamiento de ventanas tipo
macOS (sin tiling forzado), snapping suave, atajos de Apple (⌘Tab, ⌘Espacio, ⌘W, ⌘Q,
⌘C/⌘V, ⌘1-9, ⌘Ctrl+F) y "cero" incongruencias. Esto es clave para G1: el usuario nunca
sabe que debajo hay un compositor de mosaico.

**Riesgo aceptado:** Hyprland es joven y sus APIs cambian. Mitigaciones en §6.

#### 4.3.2 Nimbus Shell — alcance de v1

Un solo proceso Quickshell, con módulos(QML) separados:

| Módulo | Función |
|--------|---------|
| `TopBar` | Menú de aplicación global (vía DBus `GlobalMenu`), items de estado (red, volumen, batería, bluetooth, DND), reloj, acceso a Spotlight y Centro de Control |
| `Dock` | Magnificación al hover, indicadores de apps en ejecución, badges, menús contextuales, auto-ocultar, favoritos, carpeta "basura" |
| `Spotlight` | Apps, archivos (indexados), acciones del sistema, calculadora, historial de portapapeles, emojis |
| `ControlCenter` | WiFi, Bluetooth, audio (salida/entrada/volumen), brillo, tema claro/oscuro/auto, color de acento, perfil de energía, disposición de pantallas, modo avión, suspender/bloquear/cerrar sesión/apagar/reiniciar |
| `Notifications` | Toasts de cristal apilados, agrupación por app, acciones, DND, historial |
| `Switcher` | Cmd+Tab / Alt+Tab estilo macOS con miniaturas |
| `Screenshot` | Región, ventana, pantalla completa; copiar o guardar; previsualización |
| `QuickLook` | Barra espaciadora: previsualiza archivo sin abrirlo |
| `Wallpaper` | Selector de fondos incluidos + carpeta del usuario, pares claro/oscuro |
| `LockScreen` | Reloj, controles multimedia, acceso rápido, autenticación PAM |
| `ThemeEngine` | Tokens de diseño: color, radio, espaciado, tipografía, material de cristal |
| `SystemTray` | Iconos del sistema (XEmbed + StatusNotifier) |
| `Overlay` | Ajustes del sistema, Nimbus Store, Tour, diálogo de actualización |

**Nimbus Store** (app separada, mismo proceso o proceso propio): browse por categorías,
ficha con icono/capturas/descripción/origen (Flathub o nativo), instalar/desinstalar,
pestaña de actualizaciones, búsqueda.

**Ajustes del sistema** (app nativa): Apariencia, Pantallas, Teclado, Red, Bluetooth, Sonido,
Energía, Usuarios, Software y actualizaciones, Acerca de Nimbus.

**Tour**: secuencia de 2 minutos, 7-9 pasos, sobre una sesión real (no un vídeo), en el
idioma del sistema. Se salta con Esc y nunca se repite.

#### 4.3.3 Fundamentos compartidos

- **Tokens de diseño** en un único QML singleton. Todo el shell (incluida la Store, los
  Ajustes y el Tour) lee de ahí. Cambiar el acento o el modo claro/oscuro cambia todo el
  sistema de una vez. **Este es el mecanismo que garantiza G2.**
- **Cristal:** shader de refracción propio (GLSL, compilado con `qsb`), parametrizado por los
  tokens. Las superficies de cristal (barra, dock, menús, notificaciones, spotlight) usan el
  mismo material.
- **Iconos:** WhiteSur (D1), más iconos propios para Nimbus (logo, ajustes, store).
- **Tipografía:** Inter (D2).
- **Icono de app:** SVG, con fallback a PNG.

### 4.4 Instalador

Calamares (fork de `cachyos-calamares-next`), con módulos propios. Flujo de 11 pasos:

1. **Bienvenida** — idioma del instalador, teclado.
2. **Ubicación** — país, zona horaria, formato de fecha/hora.
3. **Particionado** — cuatro opciones:
   - **Borrar disco** (todo el disco, limpio).
   - **Instalar junto a Windows** — redimensiona la partición NTFS, reutiliza o crea la EFI
     compartida, instala **GRUB** (no systemd-boot: en multiboot, systemd-boot es frágil) y
     **salvaguardas**: copia de la tabla de particiones antes de tocar nada, aviso explícito
     de que hay que desactivar Fast Boot de Windows antes de instalar, y verificación
     post-instalación de que ambos sistemas arrancan (§4.4, paso 11).
   - **Usar disco completo** (conserva las particiones de datos).
   - **Manual** (avanzado,montar a mano).

   **Btrfs por defecto** con subvolúmenes y `@snapshots` (rollback, D6). Ofrecemos ext4 y xfs
   con la advertencia explícita de que no hay rollback.
4. **Cifrado** — LUKS2 opcional, con frase de paso o autogenerada (se muestra una vez).
5. **Usuario** — nombre, usuario, contraseña, nombre del equipo.
6. **Apariencia** *(nuestro)* — claro/oscuro/auto, **color de acento** (12 presets),
  fondo de pantalla con vista previa. Todo aplicado en el primer arranque.
7. **Software** *(nuestro)* — perfiles de selección múltiple:
   - `Base` (obligatorio): shell, gestor de archivos, navegador, visor PDF, multimedia, terminal.
   - `Gaming` — §4.6.
   - `Creativo` — GIMP, Krita, Inkscape, Kdenlive, Blender, OBS.
   - `Desarrollo` — VS Code, Git, Python, Node, Docker/Podman.
   - `Comunicación` — Discord, Telegram, Signal, WhatsApp (Flatpak).
   - `Oficina` — LibreOffice, ONLYOFFICE.
8. **Hardware** — detección automática vía `chwd` (GPU, wifi, bluetooth, impresión, códecs).
   El instalador **muestra qué va a instalar** antes de hacerlo, y permite forzar variante
   NVIDIA (open/propietaria) en sistemas híbridos.
9. **Arranque** — **GRUB** en el caso de arranque dual (obligatorio por multiboot) y
   `systemd-boot` en el caso de disco único (preferido: encaja con las UKIs y con
   `snapper-sync`). Integración con snapshots: el menú de arranque ofrece las entradas de
   rollback (§4.9). En la beta, Secure Boot se resuelve con MOCK provisional; el shim firmado
   llega para v1.0.
10. **Progreso** — con registro técnico descargable.
11. **Resumen y verificación** — lista de comprobaciones post-instalación (GPU, audio, red,
    webcam, suspensión, accelerometer si existe, espacio, arranque, **arranque dual si
    aplica**). Resultado: "Todo correcto" o una lista clara de lo que revisar.

**Sesión live:** la ISO arranca en Hyprland + nuestro shell, con el instalador visible en el
dock. **El usuario ve el futuro escritorio antes de instalar nada.** Es el momento de venta más
importante del producto.

**Instalación con red (netinstall puro).** La ISO pesa menos de 3 GB y **no lleva los
paquetes dentro**: se descargan durante la instalación. Consecuencias y mitigaciones:

- El instalador comprueba la conexión **antes** de empezar y lo dice con claridad.
- La **sesión live tiene red propia** (NetworkManager + `iwd`), así que el usuario puede
  conectar el wifi *antes* de instalar y tener internet durante la instalación. Este es el
  camino natural y lo documentamos en el primer paso.
- `linux-firmware` completo se descarga en `netinstall.yaml`; los firmware proprietary
  (Realtek, Broadcom) vienen en el paquete `linux-firmware` de Arch, así que **el wifi
  funciona en la live session**.
- Si el usuario no puede conectarse nunca, el instalador ofrece **instalar sin red con un
  subconjunto mínimo** (kernel, shell base, sin drivers de GPU dedicados) y continuar después.
  Es un caso de último recurso, con aviso claro.

**Post-instalación** (script, no módulo): installer nuestro repo y keyring, activar
`snapper`-style snapshots, configurar `nvidia-prime` en modo on-demand para híbridos,
habilitar `power-profiles-daemon`, configurar Bluetooth, tema del greeter, `nimbus-update`
timer, y `/etc/issue` + `/etc/os-release` con la marca Nimbus.

### 4.5 Primer arranque

- Greeter SDDM con tema Nimbus (fondo con degradado, reloj, lista de usuarios con avatar).
- El tour de 2 minutos es lo **único** que se le pide al usuario. Todo lo demás ya está
  configurado por el instalador.
- Si el usuario eligió un tema claro/oscuro y acento en el paso 6, se aplican al entrar.

### 4.6 Gameready — contenido del perfil

Este es el contenido del toggle "Gameready" del instalador (el fundador delegó la decisión):

**Base de juego**
- `steam` nativo desde nuestro repo (D10)
- `proton-cachyos` (el fork de Proton que mantiene CachyOS: FSR4, d7vk, parches de
  anti-cheat, correcciones de 1 % low) y `proton-ge` como alternativa; `protonup-qt` para
  gestionar versiones.
- `gamescope` (con los parches de CachyOS para VRR y HDR), `gamemode`
- `mangohud` + `vkbasalt` + `lib32-vulkan` + `vkd3d-proton`
- `lutris`, `bottles`, `heroic` (Epic/GOG/Amazon)
- `protontricks` (helper no-GUI para tweaks de Proton)

**Sesión de juegos**
- Entrada propia en SDDM: **"Nimbus Gaming"** → arranca `gamescope` con Steam Big Picture
  como sesión. Sin barra de tareas, sin notificaciones, sin fondo de escritorio.
- Activación de VRR: requiere kernel con soporte de VRR (`linux-cachyos` lo trae) y variable
  de entorno `WLR_VRR_ERROR_CAP`/parámetros de gamescope.

**Rendimiento**
- Perfil de energía "Rendimiento" aplicado al entrar en la sesión de juegos.
- Preset de MangoHud (FPS, temps, RAM, GPU power).
- Desactivación de animaciones del shell durante la sesión de juegos.

**Post-instalación**
- `steam` con `STEAM_COMPAT_DATA_PATH` y rutas ya configuradas.
- Verificación: el instalador comprueba que la GPU aparece y ofrece un test de Vulkan
  (`vulkaninfo`) al final.

### 4.7 Portátiles y energía

- `power-profiles-daemon` con perfiles: **Economía / Balanceado / Rendimiento** (D5).
- `auto-cpufreq` (de CachyOS) para governors y Energy Performance Preference.
- **Umbbrales de carga de batería:** amdgpu (`amdgpu_charge_limit`), NVIDIA
  (`nvidia-smi -pl`), Intel (`thinkpad_acpi`/fwupd). Interfaz en Ajustes → Energía.
- **Gráficos híbridos:** `nvidia-prime` en modo **on-demand** por defecto (la dGPU se activa
  solo al demanded por una app o al lanzar un juego); opción "always" en Ajustes → Energía.
- **Suspensión:** `s2idle` por defecto (moderno, seguro en portátiles modernos), con opción
  "deep sleep" (suspend a RAM) para TravelMate/ThinkPad. `hypridle` bloquea antes de dormir.
- `zram-generator` (swap comprimido en RAM) + zswap.
- `ananicy-cpp` con reglas para que las apps de escritorio no roben CPU al juego.

### 4.8 Nimbus Store

**Backend:**
- Flatpak vía `libflatpak`, con el remoto **Flathub** preconfigurado y verificado.
- Paquetes nativos vía `PackageKit` (D-Bus), para lo que no esté en Flathub.
- Los juegos y drivers **no** están en la Store: se gestionan desde Nimbus Store → sección
  "Juegos" que abre la sesión de juegos o el gestor nativo, siguiendo la misma lógica.

**UI (nuestra, en el mismo lenguaje visual):**
- Sidebar con categorías: Juegos, Productividad, Comunicación, Creativo, Multimedia,
  Desarrollo, Utilidades.
- Grid con iconos, nombre, y etiqueta de origen (Flathub / Nativo).
- Ficha de app: icono grande, capturas, descripción completa, origen, botón instalar /
  desinstalar, permisos.
- Búsqueda unificada (apps + acciones del sistema).
- Pestaña **Actualizaciones**: lista de actualizaciones de Flatpak y nativas, un botón
  "Actualizar todo" que es el único botón que el usuario tiene que pulsar.

**Detalle de la implementación:** la instalación de paquetes nativos necesita privilegios. Se
usa `packagekitd` con el agente de polkit estándar ( KDE polkit agent o `polkit-gnome`), de
modo que el usuario ve una contraseña, no una terminal.

### 4.9 Actualizaciones y rollback

**`nimbus-update`**, nuestra GUI de actualizaciones (integrada en Ajustes → Software y
actualizaciones, con acceso desde el menú del reloj):

- Muestra el estado: "Todo actualizado" / "3 actualizaciones disponibles".
- Botón: **Actualizar todo**. Hace: `pacman -Syu` + actualización de flatpaks, con snapshot
  previo automático.
- Historial de actualizaciones con fecha y paquetes tocados.
- Opción de **actualizaciones automáticas** (timer de systemd, por defecto activado con
  ventana de mantenimiento configurable, p. ej. "no reiniciar entre 9:00 y 18:00").

**Rollback (D6):**
- Snapshot Btrfs automático antes de cada transacción que toque paquetes del sistema.
- El cargador muestra entradas extra: `Nimbus (última versión conocida buena)` y
  `Nimbus (modo seguro)`. En disco único, `systemd-boot` con `snapper-sync`; en arranque dual,
  GRUB con un submenú de snapshots generado por el mismo mecanismo.
- **Un clic → arranca la versión anterior.** Es la red de seguridad que convierte "rolling" en
  "rolling con red".
- En ext4/xfs no hay snapshots: se instala `linux-cachyos-lts` y el rollback manual es
  "arrancar con el kernel LTS". El instalador lo dice claramente.

**Qué se actualiza y cuándo.** El usuario en `stable` recibe:

- **Base rolling** (kernel, Mesa, systemd, drivers) en cuanto CachyOS la publica.
- **Stack de escritorio** (Hyprland, Quickshell, shell, tema) **solo cuando se promueve a
  `stable`**, que es un acto manual (§4.2). El ritmo real de esto es de días o semanas, no de
  horas, y esa es la decisión de diseño.

El resultado práctico: Nimbus recibe los beneficios del rolling de Arch/CachyOS (drivers
nuevos, kernels, juegos) sin la inestabilidad crónica de un compositor y un toolkit de shell
moviéndose al mismo tiempo.

### 4.10 Repos e infraestructura

Repos públicos desde el día 1 (G6):

| Repo | Contenido |
|------|-----------|
| `nimbus/nimbus-shell` | El shell QML/Quickshell, Nimbus Store, Ajustes, Tour, tokens de diseño |
| `nimbus/dots` | Configuración de Hyprland + defaults del sistema |
| `nimbus/packages` | PKGBUILDs de nuestro repo, incluidos los reempaquetados de AUR (D7) |
| `nimbus/archiso` | Constructor de la ISO (fork de `archlinux/archiso`) |
| `nimbus/calamares` | Fork de `cachyos-calamares` con nuestros módulos |
| `nimbus/docs` | Documentación y sitio web |
| `nimbus/.github` | Workflows de CI (build de ISO, build de paquetes, tests) |

- **Repo `nimbus`:** firmado con GPG, con keyring propio (`nimbus-keyring`).
- **Alojo y firma:** el repo se sirve desde **GitHub** — Actions artifacts para `testing`,
  GitHub Releases + CDN para `stable`. La **clave GPG maestra vive en una máquina offline**
  (nunca en un runner de CI, nunca en un repositorio). El flujo es:
  1. La CI compila y **no** firma. Publica artefactos en `testing`.
  2. Alguien con acceso al disco offline verifica, firma los paquetes y los **promociona** a
     `stable` junto con la DB firmada (`nimbus.db`).
  3. La clave offline se puede **rotar**; el keyring de los usuarios se actualiza con el
     paquete `nimbus-keyring` del propio repo.
  - El keyring inicial va **embebido en la ISO** para que `pacman` pueda verificar desde el
    primer arranque.
- **CI:** GitHub Actions. Construye la ISO en cada push a `main`, compila los paquetes del
  repo, y ejecuta tests: lint QML, validación de la configuración de Calamares, test de
  arranque de la ISO.
- **Compilación:** los paquetes de nuestro repo se compilan con las mismas optimizaciones de
  CachyOS (v3/v4 + LTO) reutilizando su infraestructura, para que no perdemos rendimiento.
- **Espejos:** inicialmente GitHub. La lista de espejos (`nimbus-mirrorlist`) está en el
  keyring para que añadir espejos sea trivial más adelante.

### 4.11 Estrategia de pruebas

**Restricción real:** solo hay **una** máquina de prueba — Intel i7-12700H + Iris Xe +
RTX 4060 Max-Q (híbrido), 16 GB, NVMe 1 TB. `/dev/kvm` disponible. No hay GPU AMD ni Arc.

Esto define la estrategia:

| Nivel | Entorno | Qué cubre |
|-------|---------|-----------|
| **Unitario / CI** | GitHub Actions | Lint QML, tests de los tokens y del motor de tema, validación de `settings.conf` de Calamares, validación de PKGBUILDs, build de la ISO |
| **Integración** | **QEMU/KVM en local** (y en CI) | Arranque de la ISO → instalador completo → instalación → primer arranque → tour → instalar desde la Store → actualizar → **rollback**. Con render por software (llvmpipe) o virtio |
| **Real** | El portátil del fundador | Solo lo que la VM no puede simular: driver NVIDIA, GPU híbrida, suspensión, batería, gamescope/VRR, Steam. **Siempre en un disco externo USB, nunca sobre la instalación CachyOS actual** |
| **Comunidad** | Programa beta | La matriz de hardware que no tenemos: AMD, Intel Arc, multi-GPU, GPUs viejas, ultraportátiles. Es el mecanismo principal de cobertura |

**Regla dura:** el desarrollo de Nimbus **nunca** se hace sobre la instalación CachyOS actual
del fundador. Todo el trabajo diario ocurre en el repo; las pruebas de integración, en VM; las
de hardware, en USB externo.

### 4.12 Legal y marca

- **Prohibido** usar assets de Apple: logo, tipografías propietarias (SF Pro), capturas de
  pantalla de macOS, "Finder", "Spotlight", "Mac OS X" en los nombres de nuestros
  componentes.
- **Permitido y usado:** Reactive Design (KDE) para el concepto de menú global, nombres
  genéricos (buscador, panel de control, bandeja),GPL themes (WhiteSur) con atribución.
- Cada componente lleva su licencia en `LICENSES.md` y los créditos en el Ajustes → Acerca de.
- Nombre, logo y marca visual propios de Nimbus.
- Sin telemetría en el binario. Si en el futuro se añade algo, es opt-in explícito.

### 4.13 Hardware soportado en v1

Con una sola máquina de prueba (Intel i7-12700H + Iris Xe + RTX 4060 Max-Q), esta lista
**cerrada** es obligatoria: define qué verifica la VM, qué exige el programa beta y qué
ramas de `chwd` tenemos que probar.

| Componente | Soportado en v1 | Notas |
|------------|------------------|-------|
| **CPU** | x86-64 con SSE4.2 como mínimo; soporta v3 (AVX2) y v4 (AVX-512) | `x86-64-v3` es el objetivo de compilación por defecto; v4 es opt-in por CPU |
| **AMD GPU** | GCN 3 (Volcano, Polaris) en adelante, con RADV | Polaris+ tiene soporte de VRR y FSR |
| **Intel iGPU** | Gen8 (Broadwell/Apollo Lake) en adelante, con Mesa | Gen8+ es el mínimo razonable para Mesa estable |
| **Intel Arc** | A-series y H-series (Alchemist) | Requiere `intel-media-driver` + `vulkan-intel` con `anvil` |
| **NVIDIA** | Turing (RTX 20xx / GTX 16xx) en adelante con **módulos abiertos** (`nvidia-open`) | Pascal/Maxwell/Volta con el driver propietario, soportado pero **no optimizado ni probado por el programa beta** |
| **Híbridos** | dGPU NVIDIA + iGPU Intel/AMD, con `nvidia-prime` en modo **on-demand** | Es el caso por defecto del portátil del fundador |
| **WiFi** | `iwlwifi` (Intel), Realtek `rtw88`/`rtl8xx`, Broadcom `b43`/`brcmfmac` | Los proprietary de Realtek (`rtl8821ce` etc.) se ofrecen vía AUR reempaquetado |
| **Bluetooth** | BlueZ con firmware de la distro | |
| **Audio** | PipeWire + WirePlumber, `sof-firmware` para Intel HDA | |
| **Codecs** | `libavcodec` completo vía `ffmpeg` (incluye H.264/AAC) | Sin problemas legales |
| **Impresoras** | CUPS + `ipp-usb` | Sin drivers proprietary de fabricante en v1 |
| **Portátiles** | Soporte de tapa, suspensión `s2idle`, escalado de brillo, `thinkpad_acpi` | |
| **Fuera de alcance** | ARM64, GPUs de datacenter, estaciones de trabajo DRM-free, handheld Steam Deck | |

**Implicación operativa:** cada línea de esta tabla es una entrada del programa beta. Lo que
no se puede probar en VM tiene que estar cubierto por un tester con ese hardware. La lista es
deliberadamente corta: **es preferible soportar bien 8 combinaciones que 40 a medias.**

## 5. Hitos

| Hito | Contenido | Criterio de salida |
|------|-----------|-------------------|
| **M0 — Cimientos** | Repos, CI, anillo de keyring, modelo de pins (`testing`/`stable`) con firma offline manual, ISO netinstall mínima con Hyprland | La ISO arranca en VM e instala un Hyprland pelado; el ciclo build→test→promocionar a `stable` funciona de extremo a extremo |
| **M1 — Shell v0** | Tokens de diseño, TopBar, Dock, notificaciones, Centro de Control, agente de polkit propio | El shell se ve y se siente coherente; tour manual en VM |
| **M2 — Instalador** | Todos los módulos de §4.4, arranque dual con GRUB, post-instalación, verificación | Instalación completa automatizada en VM, del ISO al escritorio; y el dual-boot con Windows probado en un disco de prueba |
| **M3 — Tienda y greeter** | Nimbus Store, Ajustes del sistema, tema de SDDM, tour | Un usuario puede instalar una app sin tocar nada más que un botón |
| **M4 — Gameready y energía** | Perfil Gaming completo, sesión Nimbus Gaming, gestión de energía, híbrido | Juego real funcionando en el portátil del fundador |
| **M5 — Beta pública** | Docs, sitio, proceso de issues, programa beta, primer release | 50+ testers activos, issues triadas, cobertura de la matriz §4.13 |
| **M6 — v1.0** | Estabilidad, accesibilidad, i18n completa ES/EN, **Secure Boot con shim firmado**, sistema de actualizaciones maduro | Un desconocido instala Nimbus y no necesita leer nada |

Cada hito debe dejar el sistema **usable**, no un esqueleto. La beta de M5 es un sistema real
que se usa a diario, con los fallos conocidos publicados.

El trabajo de Secure Boot (shim, UKI, `sbctl`, clave revocable) se **diseña en M0** —porque
toca el bootloader y la construcción de la ISO— pero **se entrega en M6**. Antes de eso, las
betas usan MOCK provisional.

## 6. Riesgos

| Riesgo | Impacto | Mitigación |
|--------|---------|------------|
| Hyprland cambia APIs y rompe el shell | Alto | **Modelo de pins (§4.2)**: la rotura llega a `testing` primero, no a `stable`. Además: solo APIs estables de Quickshell, capa de abstracción propia sobre IPC, CI que compila el shell en cada push, snapshots + rollback |
| Quickshell/Qt6 actualiza y rompe el shell | Alto | Igual que arriba. El desfase con upstream se asume explícitamente como coste |
| El desfase de pins se acumula y nadie lo mantiene | Alto | Mantener el stack de escritorio **lo más pequeño posible** (D9). Si el desfase supera ~2 versiones, se prioriza rebasear sobre reducir funcionalidad |
| Secure Boot no llega a tiempo para v1.0 | Medio | El diseño se hace en M0; si se retrasa, v1.0 se publica sin Secure Boot con aviso explícito, no se sacrifica nada más |
| Un driver NVIDIA en Wayland rompe algo | Medio | Camino de configuración por hardware documentado y probado por la comunidad; `nvidia-prime` preconfigurado; fallback a Nouveau documentado |
| VRR/gamescope no funciona en todo | Medio | Se documenta por GPU; el modo sin gamescope es el fallback |
| El proyecto muere por falta de mantenedores | Alto | Beta pública desde el día 1, issues abiertas, docs, G6. **Este es el riesgo #1.** Mitigación: el proyecto se divide en repos pequeños con deuda de mantenimiento baja, y el shell tiene el menor número posible de piezas |
| Alcance excesivo (el shell es enorme) | Alto | D9 recorta los widgets de escritorio; el shell v1 son 12 módulos, no 30 |
| La ISO crece demasiado | Bajo | Netinstall puro: la ISO es < 3 GB independientemente de los perfiles de apps |
| La clave de firma offline se pierde | Alto | Copias offline cifradas + documento de recuperación en el wiki + **al menos dos personas** con acceso a la clave. Si se pierde, se publica una clave nueva y se rota el keyring |
| Netinstall deja fuera a quien no tiene wifi | Medio | La live session tiene red propia para configurar el wifi antes de instalar; y hay un modo de instalación mínima sin red como último recurso (§4.4) |
| El dual-boot rompe el arranque de Windows | Alto | Salvaguardas: copia de la tabla de particiones, aviso de Fast Boot, verificación post-instalación de ambos arranques, y en v1 el dual-boot se marca como "beta" en el instalador |

## 7. Lo que queda por decidir (o por decidir el constructor)

Estas decisiones son de implementación y las puede tomar el constructor con el criterio
establecido aquí. Se listan para que ninguna se tome por accidente:

1. **Arquitectura interna del shell:** cómo se estructuran los módulos QML, el bus de
   eventos interno y la configuración por usuario (`~/.config/nimbus/`).
2. **Versionado del esquema de configuración:** cómo se invalida una configuración vieja tras
   una actualización del shell, y qué pasa si el usuario tiene customizaciones.
3. **Estrategia de assets:** empaquetado en el paquete del shell vs. temas del usuario.
4. **El shader de cristal:** parámetros, degradación de rendimiento y fallback a blur simple
   en GPUs débiles.
5. **Escalado de fracciones:** fractional scaling en Hyprland con XWayland, que es un
   dolor de cabeza conocido.
6. **Estructura del repo `nimbus`:** nombres de paquetes (`nimbus-shell`, `nimbus-store`, …),
   metapaquetes y perfiles.
7. **Política de snapshots:** exactamente qué se snapshottea y cada cuánto. Constraint del
   fundador: **debe existir un rollback de un clic** (§4.9). Queda abierto si se usa
   `snapper` con limpieza automática o un mecanismo propio sobre subvolúmenes de Btrfs.
8. **Qué se hace con Flatpak en modo `gameready`:** Flatpak y Steam nativo no conviven bien.
   Decidir si la sesión de juegos desactiva Flatpak o si se acepta el solapamiento.
9. **Estructura del keyring y rotación:** formato del `nimbus-keyring`, cómo se anuncia una
   clave nueva a los usuarios instalados y el procedimiento de revocación.
10. **Estrategia de la CI de la ISO:** qué se prueba automáticamente en cada build (arranque
    en QEMU, lint QML, validación de Calamares) y qué se prueba a mano en la promoción a
    `stable`.
11. **Estrategia de datos del Tour:** qué pasos exactos, y cómo se localiza (los .desktop de
    los pasos deben existir en ES y EN desde el primer día).
12. **Modelo de los "atajos de teclado" entre sesiones:** qué atajos se capturan a nivel
    Hyprland y cuáles a nivel shell, y cómo se documenta el mapa completo para el usuario
    (objetivo: un `⌘`-style sheet en Ajustes → Teclado).

## 8. Referencia: de dónde sale cada pieza

No copiamos proyectos: **aprendemos de ellos y declaramos la deuda**. Esto es lo que Nimbus
toma de cada uno y en qué condiciones.

- **Mainstream OS** (Arch + Hyprland + Quickshell): resolvió la maquinaria — repo firmado,
  ISO firmada, snapshots antes de cada actualización, rollback en el menú de arranque,
  verificación post-instalación de 19 comprobaciones, modo consola de juegos.
  **Tomamos los patrones, reimplementamos el código.** No su marca ni sus nombres de paquete.
- **MacShell** (MIT): demostró que un shell Quickshell con refracción real puede parecer
  Tahoe. **Vendorizamos su implementación** — el shader de cristal, la estructura de módulos,
  el lock screen, el Spotlight — integrada en nuestros tokens.
  **No lo forked como dependencia**: el código vive en nuestro repo y si su GitHub muere,
  Nimbus no se entera. **Sus límites también son nuestros**: heredamos el crash de
  `wl_display` con muchas ventanas y está en nuestra lista de bugs a corregir antes de la beta.
- **CachyOS**: motor, kernel, repos optimizados, `chwd`, Calamares, Proton parcheado, y sus claves de firma en los que confiamos para el Secure Boot.
- **Omarchy**: prueba de que "Arch + Hyprland + cero terminal" es un mercado real. Nos
  inspira su posición de "todo preinstalado"; su estética no es la nuestra.
- **SteamOS / Zorin / elementary**: los patrones de "instalador que se siente como un
  producto" y "actualizaciones con red de seguridad".
- **WhiteSur** (GPL-3.0): iconos, con atribución.

Lo que **no** tomamos de ninguno: el nombre del logo de Apple, SF Pro, capturas de macOS, ni
los nombres "Finder"/"Spotlight" para nuestros componentes.

## 9. Definición de terminado (v1.0)

Una persona que nunca ha usado Linux, en un portátil con gráficos híbridos, puede:

1. Descargar la ISO, arrancar en modo live, **ver el escritorio y jugar con él** en 2 minutos.
2. Instalarlo con un instalador de 11 pasos en menos de 10 minutos, eligiendo "gameready" si
   quiere.
3. Arrancar, ver el greeter, entrar al escritorio, hacer el tour de 2 minutos.
4. Instalar una aplicación desde Nimbus Store con un clic.
5. Jugar un juego de Steam con Proton-GE y gamescope a VRR, sin tocar una sola configuración.
6. Cerrar la tapa, abrirla, seguir trabajando. La batería no se ha descargado.
7. Recibir una actualización, que se aplica sola, y si algo va mal, volver atrás con un clic.
8. No haber escrito un comando en ningún momento de todo el proceso.
9. Con **Secure Boot activado**, sin haber desactivado nada en la BIOS.

Ese es el estándar. Todo lo demás es secundario.
