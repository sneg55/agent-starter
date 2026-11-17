import os
import re
import subprocess
import sys
from collections import Counter, namedtuple

CODE_EXTS = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".mts", ".cts", ".py")
DOC_EXTS = (".md", ".mdx")
REFERENCE_EXTS = CODE_EXTS + DOC_EXTS + (".json", ".yaml", ".yml", ".toml", ".html", ".vue", ".svelte")
MAX_BYTES = 2_000_000

TEST_DIR_SEGMENTS = {
    "test", "tests", "__tests__", "__mocks__", "__fixtures__", "e2e", "fixtures", "testing", "spec", "specs",
}
TEST_NAME = re.compile(
    r"(\.(test|spec)\.([cm]?[jt]sx?|py)$)|(^test_.*\.py$)|(_test\.py$)|(^conftest\.py$)|([.-]test-helpers?\.)"
)

STARTER_TEMPLATE_BASENAMES = {
    "env.ts",
    "env.py",
    "errorIds.ts",
    "error_ids.py",
    "truncate-for-context.ts",
    "truncate_for_context.py",
}
STARTER_PATTERNS_FILE = ".claude/rules/starter-patterns.md"

FRAMEWORK_EXPORT_NAMES = {
    "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS",
    "metadata", "generateMetadata", "generateStaticParams", "generateViewport", "viewport",
    "dynamic", "dynamicParams", "revalidate", "runtime", "preferredRegion", "maxDuration",
    "config", "middleware", "proxy", "main", "setup", "teardown",
}

TS_DECLARED_EXPORT = re.compile(
    r"^export\s+(?:default\s+)?(?:declare\s+)?(?:async\s+)?(?:abstract\s+)?"
    r"(?:function\*?|const\s+enum|enum|const|let|var|class)\s+([A-Za-z_$][\w$]*)",
    re.MULTILINE,
)
TS_EXPORT_LIST = re.compile(r"^export\s*\{([^}]*)\}(?!\s*from\b)", re.MULTILINE)
PY_TOP_LEVEL = re.compile(r"^(?:async\s+def|def|class)\s+([A-Za-z]\w*)", re.MULTILINE)
IDENTIFIER = re.compile(r"[A-Za-z_$][\w$]*")
PATH_TOKEN = re.compile(r"[\w./-]+")

Export = namedtuple("Export", "name local own_mentions_when_unused")
Row = namedtuple("Row", "status test_refs path name flag")


def list_files(root):
    out = subprocess.run(
        ["git", "-C", root, "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        capture_output=True,
        check=True,
    ).stdout.decode("utf-8", "replace")
    return sorted({p for p in out.split("\0") if p and p.endswith(REFERENCE_EXTS)})


def is_test_path(path):
    parts = path.split("/")
    return any(seg in TEST_DIR_SEGMENTS for seg in parts[:-1]) or bool(TEST_NAME.search(parts[-1]))


def read(root, path):
    try:
        with open(os.path.join(root, path), encoding="utf-8", errors="ignore") as fh:
            text = fh.read(MAX_BYTES + 1)
    except OSError:
        return ""
    return "" if len(text) > MAX_BYTES else text


def exports_of(path, text):
    if path.endswith(".py"):
        found = [Export(m.group(1), m.group(1), 1) for m in PY_TOP_LEVEL.finditer(text)]
    else:
        found = [Export(m.group(1), m.group(1), 1) for m in TS_DECLARED_EXPORT.finditer(text)]
        for block in TS_EXPORT_LIST.finditer(text):
            for item in block.group(1).split(","):
                words = item.replace("type ", " ").split()
                if not words:
                    continue
                local, name = words[0], words[-1]
                found.append(Export(name, local, 2))
    return [e for e in found if not e.name.startswith("_") and e.name not in FRAMEWORK_EXPORT_NAMES]


def classify(root):
    files = list_files(root)
    is_test = {p: is_test_path(p) for p in files}
    is_prod_ref = {p: not is_test[p] and not p.endswith(DOC_EXTS) for p in files}
    files_by_token = {}
    candidates = []
    starter_paths = set()
    for path in files:
        text = read(root, path)
        if path == STARTER_PATTERNS_FILE:
            starter_paths = set(PATH_TOKEN.findall(text))
        counts = Counter(IDENTIFIER.findall(text))
        for token in counts:
            files_by_token.setdefault(token, []).append(path)
        if path.endswith(CODE_EXTS) and not is_test[path]:
            exports = exports_of(path, text)
            if exports:
                candidates.append((path, exports, counts))

    rows = []
    for path, exports, counts in candidates:
        for export in exports:
            others = [p for p in files_by_token.get(export.name, []) if p != path]
            if any(is_prod_ref[p] for p in others):
                continue
            test_refs = sum(1 for p in others if is_test[p])
            used_in_file = counts[export.local] >= export.own_mentions_when_unused + 1
            if test_refs and used_in_file:
                status = "USED-IN-FILE"
            elif test_refs:
                status = "TEST-ONLY"
            elif not used_in_file:
                status = "UNREFERENCED"
            else:
                continue
            scaffold = os.path.basename(path) in STARTER_TEMPLATE_BASENAMES or path in starter_paths
            rows.append(Row(status, test_refs, path, export.name, "scaffold" if scaffold else "-"))
    return sorted(rows, key=lambda r: (r.status, r.path, r.name))


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
    for row in classify(root):
        print("\t".join(str(field) for field in row))


if __name__ == "__main__":
    main()
