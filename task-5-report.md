# Task 5 — Reporte de build ISO (NimbusOS)

## Fix packages.x86_64 (2026-10-23)

**Root cause:** mkarchiso fallaba con `Packages file
'work/upstream/archiso/packages.x86_64' does not exist` + `syslinux missing`.
El perfil upstream solo trae `packages_desktop.x86_64`; su
`util-iso.sh prepare_profile desktop` hace
`cp archiso/packages_desktop.x86_64 archiso/packages.x86_64` antes de
buildear. `build_iso.sh apply_overlay` concatenaba el append a
`packages_desktop.x86_64` pero nunca generaba `packages.x86_64` → lista
vacía → syslinux missing.

**Fix mínimo en `build_iso.sh` apply_overlay (tras file_permissions, antes de build):**
- `cp packages_desktop.x86_64 packages.x86_64` (sobreescribir) + check
  `[ -f packages.x86_64 ]` + `grep -q '^syslinux$'`.
- Idempotencia ante re-run: si `packages_desktop.x86_64` ya contiene el
  marcador Nimbus (`# --- Task`), restaurar desde git
  (`checkout -- archiso/packages_desktop.x86_64`) antes de concatenar.
  (El orden normal ya es limpio: `get_upstream` hace `reset --hard
  $UPSTREAM_COMMIT` antes de apply; la guarda cubre re-runs sin get_upstream.)
- `sed` de `iso_name` solo si aún dice `cachyos`; inyección
  `file_permissions` solo si `macshell` ausente (el `assert` de python
  fallaba en re-run).
- Sin tocar overlay ni paquetes.

**Verificación:** `bash -n build_iso.sh` OK,
`./build_iso.sh --check-only` PASS,
`bash scripts/verify-build.sh` → PASS=71 FAIL=0.
`verify-build.sh` ahora exige el `cp` y el check `syslinux`.
