#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Promueve paquetes de testing a stable: copia atómica, indexa y firma.
set -euo pipefail

FROM=""
TO=""
GPGDIR=""
KEY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --from)
      FROM="${2:-}"
      shift 2
      ;;
    --to)
      TO="${2:-}"
      shift 2
      ;;
    --gpgdir)
      GPGDIR="${2:-}"
      shift 2
      ;;
    --key)
      KEY="${2:-}"
      shift 2
      ;;
    *)
      echo "promote: opción desconocida: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$FROM" ] || [ -z "$TO" ] || [ -z "$GPGDIR" ] || [ -z "$KEY" ]; then
  echo "promote: se requieren --from, --to, --gpgdir y --key" >&2
  exit 1
fi

if [ ! -d "$FROM" ]; then
  echo "promote: no existe --from: $FROM" >&2
  exit 1
fi

mkdir -p "$TO"

if ! command -v repo-add >/dev/null 2>&1; then
  echo "repo-add no encontrado: instala el paquete repo" >&2
  exit 1
fi

list_pkgs() {
  # Imprime un paquete por línea, excluyendo las firmas .sig.
  local dir="$1"
  shopt -s nullglob
  local all=( "$dir"/*.pkg.tar.* )
  shopt -u nullglob
  local f
  for f in "${all[@]}"; do
    [[ "$f" == *.sig ]] && continue
    printf '%s\n' "$f"
  done
}

mapfile -t src_pkgs < <(list_pkgs "$FROM")

# Sin nada que promover, la DB del destino no se toca: no se borra la
# existente ni se crea una nueva. No es un error, así que se sale con 0.
if [ ${#src_pkgs[@]} -eq 0 ]; then
  echo "nada que promover: --from no contiene paquetes; no se creó ninguna base de datos"
  exit 0
fi

mapfile -t to_pkgs < <(list_pkgs "$TO")

# Comprobación atómica: ninguna colisión antes de copiar nada.
for src in "${src_pkgs[@]}"; do
  base="$(basename "$src")"
  tmp="${base%.pkg.tar.*}"
  namever="${tmp%-*}"
  for dst in "${to_pkgs[@]}"; do
    dbase="$(basename "$dst")"
    if [[ "$dbase" == "$namever"-*.pkg.tar.* ]]; then
      echo "el paquete $namever ya existe en el destino" >&2
      exit 1
    fi
  done
done

# Copia atómica: primero a un temporal dentro del destino y solo al final
# se mueve a su sitio, para que un fallo de `cp` no deje copias parciales
# que luego se auto-colisionarían en un reintento.
stage="$(mktemp -d "$TO/.stage.XXXXXX")"
copy_failed=0
for src in "${src_pkgs[@]}"; do
  if ! cp -- "$src" "$stage/"; then
    copy_failed=1
    break
  fi
done
if [ "$copy_failed" -ne 0 ]; then
  rm -rf "$stage"
  echo "promote: fallo al copiar los paquetes" >&2
  exit 1
fi
shopt -s nullglob
staged=( "$stage"/*.pkg.tar.* )
shopt -u nullglob
for f in "${staged[@]}"; do
  mv -- "$f" "$TO/"
done
rmdir "$stage"

# Firma los paquetes del destino con la clave offline. La CI compila sin
# firmar; la firma ocurre aquí, en el acto manual de promoción.
mapfile -t signed_pkgs < <(list_pkgs "$TO")
for pkg in "${signed_pkgs[@]}"; do
  if [ ! -f "$pkg.sig" ]; then
    gpg --homedir "$GPGDIR" --batch --yes --local-user "$KEY" --detach-sign "$pkg"
  fi
done

# Regenera la DB desde cero en un temporal (repo-add incremental falla si se
# le pasan paquetes ya indexados) y la mueve a su sitio solo cuando repo-add
# ha funcionado; si falla, la DB buena anterior sigue intacta.
mapfile -t pkgs < <(list_pkgs "$TO")
tmpwork="$(mktemp -d "$TO/.promote.XXXXXX")"
if ! repo-add "$tmpwork/nimbus.db.tar.gz" "${pkgs[@]}"; then
  rm -rf "$tmpwork"
  # Reversión: los paquetes recién copiados no quedan huérfanos sin DB.
  for src in "${src_pkgs[@]}"; do
    b="$(basename "$src")"
    rm -f "$TO/$b" "$TO/$b.sig"
  done
  echo "promote: repo-add falló; la base de datos anterior queda intacta" >&2
  exit 1
fi
mv -- "$tmpwork/nimbus.db.tar.gz" "$TO/nimbus.db.tar.gz"
if [ -f "$tmpwork/nimbus.files.tar.gz" ]; then
  mv -- "$tmpwork/nimbus.files.tar.gz" "$TO/nimbus.files.tar.gz"
  ln -sfn nimbus.files.tar.gz "$TO/nimbus.files"
fi
ln -sfn nimbus.db.tar.gz "$TO/nimbus.db"
rm -rf "$tmpwork"

# Limpieza de firmas y restos obsoletos en un único bloque: se hace solo
# cuando la DB nueva ya está en su sitio, para no dejar firmas huérfanas
# de la DB anterior ni bases firmadas obsoletas.
rm -f "$TO"/nimbus.db.sig "$TO"/nimbus.db.tar.gz.sig
rm -f "$TO"/nimbus.files.sig "$TO"/nimbus.files.tar.gz.sig
rm -f "$TO"/*.old

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/sign_repo.sh" --repo "$TO" --gpgdir "$GPGDIR" --key "$KEY"
