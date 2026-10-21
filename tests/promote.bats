#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  TESTDIR="$(mktemp -d)"
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/key" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/key/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  mkdir -p "$TESTDIR/testing" "$TESTDIR/stable"
}

teardown() {
  rm -rf "$TESTDIR"
}

_make_pkg() {
  local name="$1" ver="$2"
  local dir="$TESTDIR/build/$name-$ver"
  rm -rf "$dir"; mkdir -p "$dir"
  # Un paquete pacman válido necesita .PKGINFO y .MTREE; repo-add rechaza
  # cualquier otra cosa, así que aquí se construyen a mano (sin makepkg, que
  # se niega a correr como root y rompería el CI en contenedores).
  printf 'pkgname = %s\npkgver = %s\npkgrel = 1\npkgdesc = paquete de prueba\nurl = https://example.org\nbuilddate = 1700000000\npackager = Test <test@example.org>\nsize = 1\narch = x86_64\nlicense = GPL-3.0-or-later\n' "$name" "$ver" > "$dir/.PKGINFO"
  printf 'contenido\n' > "$dir/dato"
  ( cd "$dir" && bsdtar -cf - --format=mtree .PKGINFO dato | gzip -c > "$dir/.MTREE" )
  ( cd "$dir" && bsdtar -czf "$TESTDIR/testing/${name}-${ver}-x86_64.pkg.tar.gz" .PKGINFO .MTREE dato )
}

@test "promote copia paquetes y produce una DB firmada" {
  _make_pkg nimbus-shell 0.1.0
  run bash "$REPO_ROOT/tools/promote.sh" --from "$TESTDIR/testing" --to "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg" --key "$FPR"
  [ "$status" -eq 0 ]
  [ -f "$TESTDIR/stable/nimbus-shell-0.1.0-x86_64.pkg.tar.gz" ]
  [ -f "$TESTDIR/stable/nimbus.db" ]
  [ -f "$TESTDIR/stable/nimbus.db.sig" ]
}

@test "promote se niega a sobrescribir la misma versión" {
  _make_pkg nimbus-shell 0.1.0
  bash "$REPO_ROOT/tools/promote.sh" --from "$TESTDIR/testing" --to "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg" --key "$FPR"
  run bash "$REPO_ROOT/tools/promote.sh" --from "$TESTDIR/testing" --to "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg" --key "$FPR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ya existe"* ]]
}

@test "promote con testing vacío deja stable intacto pero firmado" {
  run bash "$REPO_ROOT/tools/promote.sh" --from "$TESTDIR/testing" --to "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg" --key "$FPR"
  [ "$status" -eq 0 ]
  [ -f "$TESTDIR/stable/nimbus.db.sig" ]
  [ -z "$(ls -A "$TESTDIR/stable" | grep pkg.tar || true)" ]
}

@test "verify_repo detecta un paquete manipulado" {
  _make_pkg nimbus-shell 0.1.0
  bash "$REPO_ROOT/tools/promote.sh" --from "$TESTDIR/testing" --to "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg" --key "$FPR"
  run bash "$REPO_ROOT/tools/verify_repo.sh" --repo "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg"
  [ "$status" -eq 0 ]
  printf 'manipulado\n' >> "$TESTDIR/stable/nimbus-shell-0.1.0-x86_64.pkg.tar.gz"
  run bash "$REPO_ROOT/tools/verify_repo.sh" --repo "$TESTDIR/stable" --gpgdir "$TESTDIR/key/gnupg"
  [ "$status" -eq 1 ]
}
