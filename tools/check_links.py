#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Comprueba que los enlaces y las rutas de la documentacion existen.

Por que existe: un README que apunta a un documento que no esta, o que
menciona una ruta que ya no existe, es documentacion rota. Es el fallo mas
barato de tener (y el mas comun cuando el repo se mueve rapido).

Comprueba:
  1. Los enlaces markdown relativos entre documentos apuntan a algo que existe.
  2. Las rutas que se citan en el codigo (``. `` dentro de ```` ``) existen,
     cuando parecen rutas del repo (empiezan por ``docs/``, ``iso/``, ``shell/``,
     ``packages/``, ``installer/``, ``tools/``, ``tests/`` o ``dots/``).

Uso:  python tools/check_links.py [--root .]
Sale con codigo 1 si algo no resuelve, con un mensaje por cada fallo.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

# Ficheros que se revisan: la documentacion y los ficheros con rutas citedas.
DOC_SUFFIXES = (".md",)
CODE_SUFFIXES = (".qml", ".py", ".sh", ".service", ".conf")

# Directorios del repo cuyas rutas tienen sentido citar.
REPO_DIRS = (
    "docs/", "iso/", "shell/", "packages/", "installer/", "tools/", "tests/",
    "dots/", ".github/",
)

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
# ``ruta/`` dentro de texto o de comentarios.
PATH_RE = re.compile(r"`([A-Za-z0-9_./-]+\.(?:md|qml|py|sh|service|conf|qmltypes|desktop|yaml|yml))`")


def _is_external(target: str) -> bool:
    return target.startswith(("http://", "https://", "mailto:", "#"))


def _resolve(base: pathlib.Path, target: str) -> pathlib.Path | None:
    """Resuelve un enlace relativo; None si es externo o no tiene sentido."""
    target = target.split("#", 1)[0]
    if not target or _is_external(target):
        return None
    return (base / target).resolve()


def check_links(root: pathlib.Path) -> list[str]:
    problems: list[str] = []
    skip_parts = {".git", "out", ".superpowers", "node_modules", "work"}
    docs = sorted(
        p for p in root.rglob("*")
        if p.is_file() and p.suffix in DOC_SUFFIXES and not (skip_parts & set(p.parts))
    )
    for doc in docs:
        text = doc.read_text(encoding="utf-8", errors="replace")
        for target in LINK_RE.findall(text):
            resolved = _resolve(doc.parent, target)
            if resolved is None:
                continue
            if not resolved.exists():
                rel = doc.relative_to(root)
                problems.append(f"{rel}: enlace roto -> {target}")
    return problems


def check_paths(root: pathlib.Path) -> list[str]:
    """Rutas citadas en el codigo que no existen."""
    problems: list[str] = []
    skip_parts = {".git", "out", ".superpowers", "node_modules", "work"}
    files = [
        p for p in root.rglob("*")
        if p.is_file()
        and p.suffix in CODE_SUFFIXES
        and not (skip_parts & set(p.parts))
    ]
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        for cited in PATH_RE.findall(text):
            if not cited.startswith(REPO_DIRS):
                continue
            if not (root / cited).exists():
                rel = path.relative_to(root)
                problems.append(f"{rel}: ruta citada que no existe -> {cited}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="raiz del repo")
    args = parser.parse_args()
    root = pathlib.Path(args.root).resolve()

    problems = check_links(root) + check_paths(root)
    # Los mismos problemas pueden repetirse en varios ficheros: unicos.
    unique = sorted(set(problems))
    for problem in unique:
        print(f"  {problem}", file=sys.stderr)
    if unique:
        print(f"{len(unique)} problema(s) de documentacion", file=sys.stderr)
        return 1
    print("Documentacion: todos los enlaces y rutas resuelven")
    return 0


if __name__ == "__main__":
    sys.exit(main())
