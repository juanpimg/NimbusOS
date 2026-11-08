# Ramas, versiones y pines

- `main`: ISO **estable** (hoy Hyprland) hasta validar la ISO Plasma.
- `plasma-migration`: línea nueva Plasma + NimbusShell. No se mergea hasta F12
  (VM/ISO real, rendimiento, instalación, soak).
- `plasma-skel-sync`: port aditivo del skel, base de `plasma-migration`.

## Pin entre repos

`iso.manifest` registra:

```
NIMBUS_SHELL_COMMIT=<sha de NimbusShell>
NIMBUS_SHELL_TAG=<tag opcional>
```

El build Plasma sincroniza desde ese commit, no desde el `HEAD` móvil. Subir el
pin exige revalidar la ISO.

## Regla de merge

1. NimbusShell CI verde + evidencia.
2. `./build_iso.sh --check-only --profile plasma` verde.
3. ISO real en VM: instalación + primer arranque + matriz F12.
4. Solo entonces `plasma-migration → main` y tag de NimbusOS.
