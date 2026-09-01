#!/usr/bin/env python3
import re

HASH = ("#",)
SLASH = ("//",)
LINE_COMMENT_PREFIXES = {
    ".py": HASH,
    ".pyi": HASH,
    ".sh": HASH,
    ".bash": HASH,
    ".zsh": HASH,
    ".yaml": HASH,
    ".yml": HASH,
    ".toml": HASH,
    ".ini": HASH,
    ".cfg": HASH,
    ".conf": HASH,
    ".tf": HASH,
    ".hcl": HASH,
    ".rb": HASH,
    ".js": SLASH,
    ".jsx": SLASH,
    ".mjs": SLASH,
    ".cjs": SLASH,
    ".ts": SLASH,
    ".tsx": SLASH,
    ".go": SLASH,
    ".rs": SLASH,
    ".java": SLASH,
    ".kt": SLASH,
    ".c": SLASH,
    ".h": SLASH,
    ".cc": SLASH,
    ".cpp": SLASH,
    ".swift": SLASH,
    ".scss": SLASH,
    ".less": SLASH,
    ".css": (),
    ".sql": ("--",),
    ".lua": ("--",),
}
BLOCK_COMMENT_EXTENSIONS = {
    ".js",
    ".jsx",
    ".mjs",
    ".cjs",
    ".ts",
    ".tsx",
    ".go",
    ".rs",
    ".java",
    ".kt",
    ".c",
    ".h",
    ".cc",
    ".cpp",
    ".swift",
    ".css",
    ".scss",
    ".less",
    ".sql",
}
BLOCK_COMMENT_PREFIXES = ("/*", "*/", "*", "{/*")
FILENAME_PREFIXES = {
    "Dockerfile": HASH,
    "Makefile": HASH,
    "Justfile": HASH,
    ".gitignore": (),
    ".dockerignore": (),
}
DOCSTRING_OPENERS = ('"""', "'''", 'r"""', "r'''", 'f"""', "f'''")
TOOLCHAIN_DIRECTIVE = re.compile(
    r"""^\#!
    |noqa
    |type:\s*ignore
    |pragma
    |fmt:\s*(on|off|skip)
    |isort:
    |ruff:
    |mypy:
    |eslint-disable
    |eslint-enable
    |eslint-env
    |globals?\s
    |@ts-(expect-error|ignore|nocheck)
    |@jsxImportSource
    |prettier-ignore
    |stylelint-
    |biome-ignore
    |istanbul\signore
    |c8\signore
    |v8\signore
    |coverage:
    |SPDX-
    |@license
    |@preserve
    |webpackChunkName
    |@vitest-environment
    |vite-ignore
    |silent-ok
    |shellcheck\s+disable
    |yamllint
    |terraform:
    |language=
    |sourceMappingURL""",
    re.VERBOSE | re.IGNORECASE,
)
