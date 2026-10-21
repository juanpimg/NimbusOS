#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verifica que todos los ficheros fuente declaren su licencia SPDX."""
import argparse
import pathlib

SOURCE_SUFFIXES = {".py", ".sh", ".bats", ".qml", ".cpp", ".h", ".lua", ".js", ".yaml", ".yml"}

# Directorios que contienen artefactos de build, no codigo fuente. Recorrerlos
# haria fallar el check en cuanto un desarrollador deja un arbol de compilacion
# a medias (por ejemplo iso/work/ tras construir la ISO).
IGNORED_DIRS = {
    ".git",
    ".superpowers",
    "__pycache__",
    ".pytest_cache",
    "build",
    "out",
    "work",
    "node_modules",
    ".venv",
}

# `pkg/` y `src/` son los directorios de trabajo de makepkg, pero SOLO dentro
# de packages/: `shell/src/` es codigo fuente de verdad y tiene que comprobarse.
MAKEDIR_SCRATCH = {"pkg", "src"}


def is_ignored(path: pathlib.Path) -> bool:
    parts = path.parts
    if IGNORED_DIRS & set(parts):
        return True
    if "packages" in parts and MAKEDIR_SCRATCH & set(parts):
        return True
    return False


def collect_sources(root: pathlib.Path):
    sources = []
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in SOURCE_SUFFIXES:
            continue
        if is_ignored(path):
            continue
        sources.append(path)
    return sorted(sources)


def expected_spdx(path: pathlib.Path) -> str:
    if "third_party" in path.parts:
        return "MIT"
    return "GPL-3.0-or-later"


def main() -> int:
    parser = argparse.ArgumentParser(description="Comprueba cabeceras SPDX.")
    parser.add_argument("--root", default=".", help="Directorio raíz a analizar")
    args = parser.parse_args()
    root = pathlib.Path(args.root)
    offenders = []
    count = 0
    for path in collect_sources(root):
        count += 1
        expected = expected_spdx(path)
        try:
            head = path.read_bytes()[:600].decode("utf-8", errors="replace")
        except OSError:
            head = ""
        if f"SPDX-License-Identifier: {expected}" not in head:
            try:
                shown = path.relative_to(root)
            except ValueError:
                shown = path
            offenders.append(f"{shown}: falta SPDX {expected}")
    if offenders:
        for line in offenders:
            print(line)
        return 1
    print(f"SPDX OK: {count} ficheros")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
