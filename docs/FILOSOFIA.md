# Filosofía del proyecto

Reglas de colaboración que todo contribuidor (humano o IA) debe seguir. Lo técnico vinculante está en `AGENTS.md`; esto es el **porqué**.

## 1. Upstream primero, siempre

Si algo ya existe en GitHub (dock, barra, tienda, instalador, tema), **se reutiliza, no se reprograma**. Bifurcar o reescribir solo si upstream está muerto, es incompatible por diseño, o tras intentarlo de buena fe. El coste de mantener un fork lo paga el proyecto para siempre.

## 2. MacShell: colaborar, no opacar

MacShell es la capa visual y la citamos con repo, rama y commit (`iso.manifest`). Su código vendoreado viaja **prístino**: cualquier parche se marca como `NimbusOS Ruling` con fecha y motivo, se mantiene mínimo, y **toda mejora reutilizable se propone aguas arriba** (issue/PR con enlace). Nuestro valor no es otro shell, es llevar esa experiencia a **todo el SO** + instalador fácil.

## 3. El usuario nunca toca la terminal

Cero fricción para quien viene de macOS o Windows: atajos `Ctrl` intactos, todo arrastrable y redimensionable con ratón, tienda gráfica, montaje USB automático, instalador guiado. Si una feature exige terminal, la feature está incompleta.

## 4. Evidencia antes que afirmaciones

Nada está "hecho" sin su verificación vista pasar: suite en verde, `hyprland --verify-config` limpio, captura de QEMU si toca píxeles. Los informes de agente se verifican contra el diff, no se creen.

## 5. Español primero

El proyecto se documenta en español (propietario y audiencia). El inglés llega después. Código, identificadores y commits en inglés.

## 6. Sin afiliación, siempre visible

CachyOS, Apple/Mac/macOS y MacShell son proyectos y marcas de terceros. Se les cita y agradece, nunca se sugiere respaldo. El aviso vive en el README y en `LICENSE`.
