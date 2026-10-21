#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
  TESTDIR="$(mktemp -d)"
  export GNUPGHOME="$TESTDIR/gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "genkeyring exporta una clave y el paquete del keyring" {
  run bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  [ "$status" -eq 0 ]
  [ -f "$TESTDIR/out/nimbus.gpg" ]
  [ -f "$TESTDIR/out/nimbus-keyring/nimbus.gpg" ]
  [ -f "$TESTDIR/out/nimbus-keyring/nimbus-trusted" ]
  [ -f "$TESTDIR/out/nimbus-keyring/nimbus-revoked" ]
  [ -f "$TESTDIR/out/nimbus-keyring/nimbus-keyring.install" ]
  [[ "$output" =~ ^[0-9A-F]{40}$ ]]
}

@test "genkeyring se niega a sobrescribir un keyring existente" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  run bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  [ "$status" -eq 1 ]
  [[ "$output" == *"existe"* ]]
}

@test "la clave exportada verifica su propia firma" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/out/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  printf 'contenido\n' > "$TESTDIR/datos.txt"
  gpg --homedir "$TESTDIR/out/gnupg" --batch --yes --detach-sign --local-user "$FPR" "$TESTDIR/datos.txt"
  run gpg --homedir "$TESTDIR/out/gnupg" --verify "$TESTDIR/datos.txt.sig" "$TESTDIR/datos.txt"
  [ "$status" -eq 0 ]
}

@test "el keybox exportado verifica con la clave pública, sin la clave privada" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/out/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  printf 'contenido\n' > "$TESTDIR/datos.txt"
  gpg --homedir "$TESTDIR/out/gnupg" --batch --yes --detach-sign --local-user "$FPR" "$TESTDIR/datos.txt"

  # Un keyring limpio que solo tiene la clave pública, tal y como verá el usuario.
  mkdir -p "$TESTDIR/verifyhome"
  chmod 700 "$TESTDIR/verifyhome"
  run gpg --homedir "$TESTDIR/verifyhome" --no-default-keyring --keyring "$TESTDIR/out/nimbus.gpg" --verify "$TESTDIR/datos.txt.sig" "$TESTDIR/datos.txt"
  [ "$status" -eq 0 ]
}

@test "sign_repo firma la base de datos y se niega a firmar dos veces" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/out/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  mkdir -p "$TESTDIR/repo"
  printf '%%FILENAME%%\n' > "$TESTDIR/repo/nimbus.db"
  run bash "$REPO_ROOT/tools/sign_repo.sh" --repo "$TESTDIR/repo" --gpgdir "$TESTDIR/out/gnupg" --key "$FPR"
  [ "$status" -eq 0 ]
  [ -f "$TESTDIR/repo/nimbus.db.sig" ]
  run bash "$REPO_ROOT/tools/sign_repo.sh" --repo "$TESTDIR/repo" --gpgdir "$TESTDIR/out/gnupg" --key "$FPR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ya firmado"* ]]
}
