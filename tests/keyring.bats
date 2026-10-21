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

@test "la clave pública exportada verifica, sin la clave privada" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/out/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  printf 'contenido\n' > "$TESTDIR/datos.txt"
  gpg --homedir "$TESTDIR/out/gnupg" --batch --yes --detach-sign --local-user "$FPR" "$TESTDIR/datos.txt"

  # Un keyring limpio que solo tiene la clave pública, tal y como verá el usuario.
  mkdir -p "$TESTDIR/verifyhome"
  chmod 700 "$TESTDIR/verifyhome"
  gpg --homedir "$TESTDIR/verifyhome" --quiet --import "$TESTDIR/out/nimbus.gpg"
  run gpg --homedir "$TESTDIR/verifyhome" --verify "$TESTDIR/datos.txt.sig" "$TESTDIR/datos.txt"
  [ "$status" -eq 0 ]
}

@test "nimbus.gpg es importable con gpg --import, como exige pacman-key --populate" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  # pacman-key --populate hace exactamente esto: gpg --import <nimbus.gpg>.
  # Si el artefacto es un keybox en vez de una exportacion armored, falla aqui.
  mkdir -p "$TESTDIR/importhome"
  chmod 700 "$TESTDIR/importhome"
  run gpg --homedir "$TESTDIR/importhome" --quiet --import "$TESTDIR/out/nimbus.gpg"
  [ "$status" -eq 0 ]
  # Y la clave importada debe ser la de Nimbus.
  run gpg --homedir "$TESTDIR/importhome" --list-keys --with-colons
  [[ "$output" == *"nimbus@example.org"* ]]
}

@test "el ownertrust y el populate estan bien formados" {
  bash "$REPO_ROOT/tools/genkeyring.sh" --outdir "$TESTDIR/out" --uid "Nimbus Signing <nimbus@example.org>" --email "nimbus@example.org"
  FPR="$(gpg --homedir "$TESTDIR/out/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  # El ownertrust debe referenciar la clave con nivel 6 (ultimate). Sin esto,
  # pacman-key importa la clave pero no le da confianza y toda firma del repo
  # falla con "signature from unknown trust".
  grep -q ":6:" "$TESTDIR/out/nimbus-keyring/nimbus-trusted"
  grep -q "$FPR" "$TESTDIR/out/nimbus-keyring/nimbus-trusted"
  # Y el .install debe ejecutar el populate, que es lo que aplica el ownertrust.
  grep -q "pacman-key --populate nimbus" "$TESTDIR/out/nimbus-keyring/nimbus-keyring.install"
  # La copia versionada, que es la que se instala en el sistema, debe llevar
  # las tres rutas y el mismo post_install con el populate.
  grep -q "usr/share/pacman/keyrings/nimbus.gpg" "$REPO_ROOT/packages/nimbus-keyring/nimbus-keyring.install"
  grep -q "usr/share/pacman/keyrings/nimbus-trusted" "$REPO_ROOT/packages/nimbus-keyring/nimbus-keyring.install"
  grep -q "usr/share/pacman/keyrings/nimbus-revoked" "$REPO_ROOT/packages/nimbus-keyring/nimbus-keyring.install"
  grep -q "pacman-key --populate nimbus" "$REPO_ROOT/packages/nimbus-keyring/nimbus-keyring.install"
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
