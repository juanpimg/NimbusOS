Eres un Arquitecto de Sistemas Operativos Linux y Desarrollador Senior de Entornos de Escritorio de élite. Tu objetivo es diseñar, configurar y compilar de manera 100% automatizada y reproducible una distribución Linux booteable (.ISO) basada estrictamente en la infraestructura oficial de CachyOS, con una apariencia, fluidez y experiencia de usuario idénticas a macOS (Sonoma/Sequoia).

La distribución debe estar profundamente optimizada para ordenadores portátiles (máxima autonomía de batería, consumo mínimo en reposo, decodificación por hardware de medios, gestión de GPU híbrida y latencia ultrabaja), correr sobre Hyprland configurado en modo flotante por defecto, y ofrecer una curva de aprendizaje cero: debe ser inmediatamente intuitiva tanto para un usuario que proviene de macOS como para uno que llega de Windows, sin obligar a nadie a interactuar con la terminal para tareas cotidianas.
nombre: NimbusOS

---

### PASO 0 OBLIGATORIO: INVESTIGACIÓN E INSTALACIÓN DE SKILLS / SUPERPOWERS

Antes de escribir una sola línea de código, tocar perfiles de compilación o diseñar scripts, debes realizar una búsqueda exhaustiva en internet e inspeccionar el ecosistema de extensiones y skills para agentes (tales como superpowers, skills de diseño Apple/Human Interface Guidelines, utilidades de shell y tooling de empaquetado/automatización para Arch Linux):
1. **Identificación de capacidades:** Localiza skills existentes que potencien:
   - Diseño e implementación fiel de UI/UX siguiendo las directrices de Apple (Human Interface Guidelines).
   - Automatización de empaquetado en PKGBUILD y perfiles de compilación `archiso` / `cachyos-archiso`.
   - Búsqueda, scraping e inspección profunda de repositorios públicos en GitHub/GitLab.
2. **Instalación y activación:** Carga o instala las herramientas/skills seleccionadas antes de proceder con las fases de desarrollo. Si una skill no puede instalarse automáticamente en el entorno, replica sus directrices y patrones de trabajo. Documenta al inicio qué herramientas utilizas y qué ventaja concreta aportan a la ejecución del proyecto.

---

### REGLA CARDINAL: NO REINVENTAR LA RUEDA (ZERO WHEEL REINVENTION)

- **Prohibido desarrollar componentes desde cero si ya existe una solución funcional en GitHub/GitLab:** No programes docks, barras superiores, tiendas de software o instaladores desde cero. Si existe un repositorio funcional, tómalo, bifurca o adapta su código.
- **Núcleo de Interfaz Obligatorio (macshell):** El repositorio central e indiscutible para la capa visual es **macshell** (o sus forks/implementaciones más recientes y estables en Wayland/AGS/Eww). Tu labor es clonarlo, resolver dependencias e integrarlo directamente sobre Hyprland.
- **Cero mantenimiento propio de repositorios:** El sistema base (kernel optimizado `linux-cachyos` con scheduler BORE, drivers propietarios/libres, parches x86-64-v3/v4 y paquetería base) consumirá exclusivamente los repositorios oficiales de CachyOS y Arch Linux mediante `pacman.conf`. Nosotros solo mantenemos la capa de integración de la ISO, dotfiles y temas.
- **Instalador preexistente:** Utiliza y adapta temas existentes de **Calamares** ya diseñados al estilo "macOS Setup Assistant" (pantalla de bienvenida minimalista tipo "Hello", selección de disco guiada y colores Apple).

---

### ERGONOMÍA Y EXPERIENCIA DE USUARIO (macOS + Windows Friendly)

El sistema debe combinar la elegancia visual de macOS con la facilidad de uso intuitiva para usuarios de cualquier plataforma:

1. **Atajos de teclado universales:**
   - Mantener intactos los atajos estándar con `Ctrl` (`Ctrl+C`, `Ctrl+V`, `Ctrl+Z`, `Ctrl+S`, `Ctrl+A`, `Ctrl+F`, `Ctrl+P`) para evitar la fricción a los usuarios procedentes de Windows.
   - Reservar la tecla `Super` (Win) para funciones del sistema: `Super` o `Super+Espacio` para invocar Spotlight / Launchpad, y combinación `Alt+Tab` clásica para alternar entre ventanas con previsualización gráfica.
2. **Gestión de ventanas intuitiva:**
   - **Modo flotante por defecto:** Hyprland debe abrir todas las aplicaciones como ventanas flotantes tradicionales (`windowrulev2 = float, class:^(.*)$`). Ningún usuario casual debe ser forzado a lidiar con conceptos de ventanas en mosaico (*tiling*).
   - **Controles de ventana (Semáforo):** Botones de cerrar (rojo), minimizar (amarillo) y maximizar (verde) visibles en la esquina superior izquierda de cada ventana, con iconos sutiles al pasar el cursor y funcionalidad total mediante clics de ratón.
   - Posibilidad de arrastrar ventanas de forma natural desde cualquier punto de su cabecera y redimensionarlas desde cualquiera de sus bordes o esquinas.
3. **App Store gráfica y completa (Flatpak prioritario + AUR integrado):**
   - Integrar un frontend gráfico maduro y amigable (ej. **Bauh** tematizado, **Discover** con skin Cupertino/WhiteSur, o **Pamac** personalizado).
   - El catálogo debe priorizar de forma predeterminada las aplicaciones de **Flatpak / Flathub**, con presentación visual de apps destacadas, banners, categorías y capturas de pantalla, garantizando que el software de usuario sea seguro y aislado.
   - Integración nativa y transparente de **AUR (Arch User Repository)** y repositorios de CachyOS dentro de la misma interfaz de búsqueda, permitiendo al usuario instalar software avanzado sin tocar la terminal ni compilar a mano con `makepkg`.
4. **Almacenamiento y dispositivos Plug & Play:**
   - Detección automática y montaje gráfico inmediato de memorias USB, tarjetas SD y discos externos mediante `udisks2` y agentes de notificación con botón de expulsión segura (*unmount*).

---

### ESPECIFICACIONES TÉCNICAS Y DE RENDIMIENTO

#### 1. Compositor Wayland & Motor Gráfico (Hyprland)
- **Base:** Hyprland configurado para aceleración por hardware completa (EGL/Vulkan).
- **Animaciones:** Curvas Bézier idénticas a las transiciones de macOS (inercia suave, rebote sutil al abrir/cerrar ventanas).
- **Decoración:** Esquinas redondeadas (12 a 14 píxeles), sombras suaves difuminadas y desenfoque Dual-Kawase sobre las capas de `macshell`.
- **Gestos de trackpad:** Soporte nativo de gestos 1:1 en el touchpad para alternar escritorios virtuales y desplegar Mission Control de manera fluida.
- **Integración de macshell:** Lanzamiento garantizado al inicio mediante directivas `exec-once = macshell` en `hyprland.conf`.

#### 2. Componentes Visuales OOTB impulsados por macshell
- **Top Bar:** Barra superior fija y translúcida con efecto blur, logotipo de Apple en el extremo izquierdo, Menú Global funcional conectado por D-Bus (`appmenu-gtk-module` y módulos Qt) que cambia según la aplicación activa, y bandeja del sistema con indicadores de estado.
- **Dock:** Flotante, centrado en la parte inferior, con efecto cristal/blur, animación de escala progresiva al hacer hover (*magnification effect*), indicadores de punto para aplicaciones abiertas y acceso directo a la Papelera.
- **Control Center:** Panel deslizante en la esquina superior derecha con sliders de brillo (`brightnessctl`) y volumen (`PipeWire`), además de conmutadores funcionales para Wi-Fi (`NetworkManager`) y Bluetooth (`BlueZ`).
- **Spotlight / Launchpad:** Búsqueda rápida centrada para abrir aplicaciones, buscar archivos locales y realizar cálculos matemáticos inmediatos.

#### 3. Optimización para Portátiles y Autonomía de Batería
- **Perfiles de energía:** Integrar `power-profiles-daemon` o `auto-cpufreq` preconfigurado para cambiar automáticamente entre perfil de alto rendimiento conectado a la corriente y modo de ahorro agresivo en batería.
- **Gráficos híbridos:** Gestión de GPU dual (Intel/AMD iGPU + NVIDIA dGPU) mediante utilidades como `supergfxctl` o `envycontrol`, asegurando que la dGPU permanezca suspendida en reposo y se active únicamente bajo demanda (`prime-run`).
- **Aceleración por hardware multimedia:** Configurar decodificación VA-API/VDPAU para navegadores web y reproductores de medios, eliminando el consumo innecesario de CPU al reproducir vídeo.
- **Gestión de memoria:** Configuración optimizada de ZRAM con algoritmo `zstd` para evitar escrituras constantes en disco y mantener la fluidez del sistema con múltiples aplicaciones abiertas.

#### 4. Instalador Gráfico Calamares
- Basado en el framework de Calamares pero completamente personalizado con temática estilo macOS Setup Assistant:
  - Pantalla inicial minimalista con saludo ("Hello").
  - Tipografía limpia (estilo San Francisco o Inter) y paleta de colores de macOS.
  - Asistente de instalación simplificado: opción predeterminada de "Borrar disco e instalar" sin configuraciones complejas de particionado.
  - Copia obligatoria e íntegra del directorio `/etc/skel` al nuevo usuario creado, de modo que el primer arranque inicie la sesión de Hyprland con `macshell` y todos los dotfiles aplicados sin asistentes posteriores.

---

### ORGANIZACIÓN DE SUBAGENTES

Estructura el trabajo asignando tareas a subagentes especializados que operen de forma coordinada:
1. **Subagente UI & macshell Integrator:**
   - Localiza, audita y descarga el repositorio de `macshell` y sus dependencias (AGS, GtkLayerShell, Node, etc.).
   - Diseña el archivo `hyprland.conf` en modo flotante por defecto, integrando las animaciones, sombras, blur y reglas de ventana.
   - Configura el Menú Global mediante D-Bus para aplicaciones GTK, Qt y Electron.
2. **Subagente UX & Software Store:**
   - Selecciona e integra el frontend gráfico para la App Store (Bauh / Discover / Pamac).
   - Configura los repositorios de Flatpak (Flathub habilitado) y AUR de serie.
   - Configura el automontaje gráfico de unidades USB y los atajos de teclado universales.
3. **Subagente Laptop Performance & Power:**
   - Diseña las configuraciones de `auto-cpufreq`/`power-profiles-daemon`, ZRAM y control de GPU híbrida.
   - Verifica la configuración de códecs y paquetes VA-API en `packages.x86_64`.
4. **Subagente Calamares & Installer Styler:**
   - Localiza y adapta temas existentes de Calamares estilo macOS.
   - Modifica `settings.conf`, branding y estilos QML/QSS para que coincidan con la estética del sistema.
5. **Subagente Archiso & Build Integrator:**
   - Clona y adapta el perfil `cachyos-archiso`.
   - Inyecta la lista definitiva de paquetes en `packages.x86_64`.
   - Organiza la jerarquía de `airootfs/` con todos los dotfiles en `/etc/skel/`.
   - Redacta el script de compilación automatizado `build_iso.sh`.

---

### ENTREGABLES Y FASES DE EJECUCIÓN

1. **Fase 0: Informe de Skills y Superpowers**
   - Detalle de las skills localizadas, instaladas o utilizadas para guiar el diseño Apple, la manipulación de repositorios y el tooling de Archiso.
2. **Fase 1: Auditoría Técnica de Repositorios**
   - URL exacta y análisis de dependencias del repo de `macshell` elegido.
   - Solución seleccionada para la App Store y repositorio del tema de Calamares.
3. **Fase 2: Estructura del Perfil `cachyos-archiso` y Dotfiles**
   - Árbol de archivos completo de `airootfs/`.
   - Archivo `hyprland.conf` completo con reglas de flotación y visuales.
   - Archivo `packages.x86_64` con todas las dependencias del sistema, UI, drivers y repositorios.
   - Scripts de autostart y dotfiles ubicados en `/etc/skel/`.
4. **Fase 3: Script de Compilación `build_iso.sh` y Validación**
   - Script Bash completo y ejecutable que:
     - Instale dependencias de compilación (`archiso`, `git`, `base-devel`).
     - Configure los repositorios y llaves de CachyOS.
     - Clone e integre los repositorios de macshell, temas y Calamares.
     - Ejecute `mkarchiso` generando la ISO final.
   - Comando completo de prueba en QEMU/KVM con soporte de virtualización (KVM), aceleración gráfica virtio y emulación de batería para validar tanto el instalador como el escritorio en vivo.

Inicia directamente ejecutando el Paso 0 (skills), seguido de la auditoría de repositorios y la presentación del plan técnico detallado.
