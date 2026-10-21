#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Genera los fondos propios de Nimbus (par claro/oscuro, 1920x1080).
#
# Arte original del proyecto: aurora abstracta en la paleta macOS del tema
# (claro #F5F5F7, oscuro #1C1C1E, acentos azul/violeta/turquesa). Nada de
# assets de Apple ni de terceros: todo se dibuja con ImageMagick.
#
# Determinista: solo usa operaciones sin azar (degradados, dibujo, blur,
# composicion). Generar dos veces produce los mismos bytes; los PNG
# versionados en este directorio son la referencia.
#
# Uso: dots/backgrounds/generate.sh
# Requiere: convert (ImageMagick).
set -euo pipefail

OUT="$(cd "$(dirname "$0")" && pwd)"
W=1920
H=1080

command -v convert >/dev/null || {
    echo "generate.sh: falta ImageMagick (convert)" >&2
    exit 1
}

TMP="$(mktemp -d -t nimbus-bg-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# Una mancha suave: elipse de COLOR sobre lienzo transparente del tamano
# final, desenfocada. Al dibujar directamente a 1920x1080 no hay -extent ni
# recortes: es imposible que quede una arista visible. El desenfoque derrama
# ~3*sigma mas alla de la elipse; las coordenadas dejan margen de sobra
# para que el alfa llegue a 0 antes del borde del lienzo.
blob() {
    local dest="$1" rgb="$2" alpha="$3" cx="$4" cy="$5" rx="$6" ry="$7" blur="$8"
    convert -size "${W}x${H}" xc:none \
        -fill "rgba(${rgb},${alpha})" \
        -draw "ellipse ${cx},${cy} ${rx},${ry} 0,360" \
        -blur "0x${blur}" "$dest"
}

# Velo diagonal claro: banda blanca rotada y muy desenfocada.
streak() {
    local dest="$1" opacity="$2" width="$3" angle="$4"
    convert -size "2400x${width}" "xc:rgba(255,255,255,${opacity})" \
        -blur 0x60 -background none -rotate "$angle" \
        -gravity center -extent "${W}x${H}" +repage "$dest"
}

# Vinetado: oscurece los bordes para dar profundidad.
vignette() {
    local dest="$1" strength="$2"
    convert -size "${W}x${H}" \
        "radial-gradient:rgba(0,0,0,0)-rgba(0,0,0,${strength})" \
        "$dest"
}

# Fondo oscuro: base #1C1C1E con aurora azul/violeta/turquesa.
blob "$TMP/d1.miff" '10,132,255' '0.90' 1450 300 480 300 80
blob "$TMP/d2.miff" '10,132,255' '0.60' 1650 560 300 200 60
blob "$TMP/d3.miff" '94,92,230' '0.85' 480 680 520 320 90
blob "$TMP/d4.miff" '48,176,199' '0.50' 1050 780 320 180 70
streak "$TMP/ds.miff" '0.10' '200' '-24'
vignette "$TMP/dv.miff" '0.32'
convert -size "${W}x${H}" xc:'#1C1C1E' \
    "$TMP/d1.miff" -composite \
    "$TMP/d2.miff" -composite \
    "$TMP/d3.miff" -composite \
    "$TMP/d4.miff" -composite \
    "$TMP/ds.miff" -composite \
    "$TMP/dv.miff" -composite \
    -strip -depth 8 "$OUT/Nimbus.png"

# Fondo claro: base #F5F5F7 con aurora pastel de los mismos acentos.
blob "$TMP/l1.miff" '10,132,255' '0.55' 1450 300 480 300 80
blob "$TMP/l2.miff" '10,132,255' '0.40' 1650 560 300 200 60
blob "$TMP/l3.miff" '94,92,230' '0.50' 480 680 520 320 90
blob "$TMP/l4.miff" '100,210,255' '0.60' 1050 780 320 180 70
streak "$TMP/ls.miff" '0.35' '220' '-24'
vignette "$TMP/lv.miff" '0.12'
convert -size "${W}x${H}" xc:'#F5F5F7' \
    "$TMP/l1.miff" -composite \
    "$TMP/l2.miff" -composite \
    "$TMP/l3.miff" -composite \
    "$TMP/l4.miff" -composite \
    "$TMP/ls.miff" -composite \
    "$TMP/lv.miff" -composite \
    -strip -depth 8 "$OUT/Nimbus-Light.png"

echo "fondos generados en $OUT"
