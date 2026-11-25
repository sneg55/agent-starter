#!/usr/bin/env python3
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

LOCKFILE_NAMES = {
    "package-lock.json", "npm-shrinkwrap.json", "pnpm-lock.yaml", "yarn.lock", "bun.lock",
    "uv.lock", "poetry.lock", "Pipfile.lock", "pdm.lock", "pylock.toml",
    "Cargo.lock", "go.mod", "Gemfile.lock", "composer.lock", "pubspec.lock",
    "gradle.lockfile", "mix.lock", "packages.lock.json",
}
REQUIREMENTS_RE = re.compile(r"^requirements[\w.-]*\.txt$")
CACHE_DIR = Path.home() / ".claude" / "cache" / "dep-vuln"
IGNORE_FILE = Path.home() / ".claude" / "state" / "dep-vuln-ignore.json"
SCAN_TIMEOUT_S = 75
MAX_CONTEXT_LINES = 20

TRIGGERS = [
    ("commit", re.compile(r"(^|[\s;&|(])git(\s+-C\s+\S+)?\s+commit\b")),
    ("mr", re.compile(r"(^|[\s;&|(])gh\s+pr\s+create\b")),
    ("mr", re.compile(r"(^|[\s;&|(])glab\s+mr\s+create\b")),
    ("mr", re.compile(r"merge_request\.create")),
]


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=False, capture_output=True, text=True, timeout=15)


def repo_root(start):
    out = git(start, "rev-parse", "--show-toplevel")
    return Path(out.stdout.strip()) if out.returncode == 0 and out.stdout.strip() else None


def tracked_lockfiles(root):
    out = git(root, "ls-files", "-z")
    if out.returncode != 0:
        return []
    paths = []
    for rel in out.stdout.split("\0"):
        name = os.path.basename(rel)
        if name in LOCKFILE_NAMES or REQUIREMENTS_RE.match(name):
            full = root / rel
            if full.is_file():
                paths.append(full)
    return sorted(paths)


def load_ignores(root):
    try:
        data = json.loads(IGNORE_FILE.read_text())
    except (OSError, ValueError):
        return set()
    ids = set(data.get("ids", []))
    ids.update(data.get("repos", {}).get(str(root), []))
    return ids


def fixed_versions(vuln, name, ecosystem):
    found = []
    for affected in vuln.get("affected", []):
        pkg = affected.get("package", {})
        if pkg.get("name") != name or pkg.get("ecosystem") != ecosystem:
            continue
        for rng in affected.get("ranges", []):
            for event in rng.get("events", []):
                if "fixed" in event and event["fixed"] not in found:
                    found.append(event["fixed"])
    return found


def run_osv(lockfiles):
    cmd = ["osv-scanner", "scan", "source", "--format", "json"]
    for path in lockfiles:
        cmd += ["-L", str(path)]
    proc = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=SCAN_TIMEOUT_S)
    if proc.returncode not in (0, 1):
        raise RuntimeError((proc.stderr or proc.stdout).strip().splitlines()[-1:] or ["osv-scanner failed"])
    return json.loads(proc.stdout) if proc.stdout.strip() else {"results": []}


def collect(root, report, ignores):
    merged = {}
    for result in report.get("results", []):
        source = os.path.relpath(result.get("source", {}).get("path", ""), root)
        for pkg_entry in result.get("packages", []):
            pkg = pkg_entry.get("package", {})
            vulns = {v["id"]: v for v in pkg_entry.get("vulnerabilities", [])}
            for group in pkg_entry.get("groups", []):
                ids = group.get("ids", [])
                aliases = set(group.get("aliases", [])) | set(ids)
                if aliases & ignores:
                    continue
                primary = next((i for i in ids if i.startswith("GHSA-")), ids[0] if ids else "?")
                vuln = vulns.get(primary) or next((vulns[i] for i in ids if i in vulns), {})
                key = (pkg.get("ecosystem"), pkg.get("name"), pkg.get("version"), primary)
                entry = merged.setdefault(key, {
                    "ecosystem": pkg.get("ecosystem"),
                    "name": pkg.get("name"),
                    "version": pkg.get("version"),
                    "id": primary,
                    "aliases": sorted(aliases - {primary}),
                    "summary": vuln.get("summary", ""),
                    "severity": vuln.get("database_specific", {}).get("severity", ""),
                    "cvss": group.get("max_severity", ""),
                    "fixed": fixed_versions(vuln, pkg.get("name"), pkg.get("ecosystem")),
                    "sources": [],
                })
                if source not in entry["sources"]:
                    entry["sources"].append(source)
    return sorted(merged.values(), key=lambda f: (not f["fixed"], SEVERITY_RANK.get(f["severity"].upper(), 4), f["name"]))


def scan(root, use_cache):
    lockfiles = tracked_lockfiles(root)
    if not lockfiles:
        return lockfiles, None, []
    digest = hashlib.sha256(str(root).encode())
    digest.update(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d").encode())
    for path in lockfiles:
        digest.update(str(path).encode())
        digest.update(path.read_bytes())
    state_key = digest.hexdigest()[:24]
    cache_file = CACHE_DIR / f"{state_key}.json"
    if use_cache and cache_file.is_file():
        findings = json.loads(cache_file.read_text())
    else:
        findings = collect(root, run_osv(lockfiles), set())
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        cache_file.write_text(json.dumps(findings))
    ignores = load_ignores(root)
    kept = [f for f in findings if not ({f["id"], *f["aliases"]} & ignores)]
    return lockfiles, state_key, kept


SEVERITY_RANK = {"CRITICAL": 0, "HIGH": 1, "MODERATE": 2, "MEDIUM": 2, "LOW": 3}


def version_key(version):
    parts = []
    for chunk in re.split(r"[.+-]", version or ""):
        m = re.match(r"\d+", chunk)
        if not m:
            break
        parts.append(int(m.group()))
    return tuple(parts)


def minimal_fix(f):
    current = version_key(f["version"])
    above = [v for v in f["fixed"] if version_key(v) > current]
    return min(above, key=version_key) if above else None


def format_line(f):
    fix = f"fix {', '.join(f['fixed'])}" if f["fixed"] else "no fix yet"
    sev = f["severity"] or (f"cvss {f['cvss']}" if f["cvss"] else "unrated")
    return f"- [{sev}] {f['ecosystem']} {f['name']}@{f['version']} {f['id']}: {fix} ({', '.join(f['sources'])})"


def package_rollup(findings):
    groups = {}
    for f in findings:
        groups.setdefault((f["ecosystem"], f["name"], f["version"]), []).append(f)
    rows = []
    for (eco, name, version), items in groups.items():
        worst = min(items, key=lambda f: SEVERITY_RANK.get(f["severity"].upper(), 4))["severity"] or "unrated"
        fixes = [minimal_fix(f) for f in items]
        unfixed = sum(1 for v in fixes if v is None)
        target = max((v for v in fixes if v), key=version_key, default=None)
        sources = sorted({s for f in items for s in f["sources"]})
        clears = f"clears at {target}" if target else "no fix yet"
        if target and unfixed:
            clears += f" ({unfixed} still unfixed)"
        major = target and version_key(target)[:1] != version_key(version)[:1]
        rows.append((SEVERITY_RANK.get(worst.upper(), 4), name, (
            f"- [{worst}] {eco} {name}@{version}: {len(items)} advisories, {clears}"
            f"{' MAJOR BUMP' if major else ''} ({', '.join(sources)})"
        )))
    return [line for _, _, line in sorted(rows)]


def target_dir(command, cwd):
    m = re.search(r"git\s+-C\s+(\"[^\"]+\"|'[^']+'|\S+)", command)
    if not m:
        m = re.match(r"\s*cd\s+(\"[^\"]+\"|'[^']+'|\S+)\s*(&&|;)", command)
    if m:
        path = os.path.expanduser(m.group(1).strip("\"'"))
        return Path(path if os.path.isabs(path) else os.path.join(cwd, path))
    return Path(cwd)


def first_time(session, marker):
    seen_file = CACHE_DIR / f"seen-{session}"
    seen = set(seen_file.read_text().split()) if seen_file.is_file() else set()
    if marker in seen:
        return False
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    seen_file.write_text("\n".join(seen | {marker}))
    return True


def hook_main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    command = payload.get("tool_input", {}).get("command", "")
    kind = next((k for k, rx in TRIGGERS if rx.search(command)), None)
    if not kind:
        return 0
    root = repo_root(target_dir(command, payload.get("cwd") or os.getcwd()))
    if not root:
        return 0
    session = payload.get("session_id", "none")
    if not shutil.which("osv-scanner"):
        if first_time(session, "missing-osv-scanner"):
            print(json.dumps({"systemMessage": "dep-vuln: osv-scanner not installed, skipped (https://google.github.io/osv-scanner/installation/)"}))
        return 0
    try:
        _, state_key, findings = scan(root, use_cache=True)
    except (RuntimeError, subprocess.TimeoutExpired, ValueError, OSError) as exc:
        if first_time(session, "scan-error:" + hashlib.sha256(str(root).encode()).hexdigest()[:12]):
            print(json.dumps({"systemMessage": f"dep-vuln: scan skipped in {root.name}: {exc}"}))
        return 0
    if not state_key or not findings:
        return 0
    if not first_time(session, f"{state_key}:{kind}"):
        return 0
    fixable = [f for f in findings if minimal_fix(f)]
    rollup = package_rollup(findings)
    lines = rollup[:MAX_CONTEXT_LINES]
    if len(rollup) > MAX_CONTEXT_LINES:
        lines.append(f"- ... {len(rollup) - MAX_CONTEXT_LINES} more packages (run {Path(__file__)} --repo {root})")
    gate = "commit" if kind == "commit" else "merge request"
    context = (
        f"dep-vuln check at {gate} time in {root}: {len(findings)} open advisories, {len(fixable)} with a fixed version.\n"
        + "\n".join(lines)
        + "\nThe command was not blocked. Tell the user in one line and ask whether to fix them now with the "
        "dep-vuln-update skill. Do not start fixing without a yes."
    )
    print(json.dumps({
        "systemMessage": f"dep-vuln: {len(findings)} advisories ({len(fixable)} fixable) in {root.name}",
        "hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": context},
    }))
    return 0


def cli_main(args):
    root = repo_root(Path(args.repo).expanduser())
    if not root:
        print(f"not a git repo: {args.repo}", file=sys.stderr)
        return 2
    lockfiles, _, findings = scan(root, use_cache=not args.no_cache)
    if args.json:
        print(json.dumps({"root": str(root), "lockfiles": [os.path.relpath(p, root) for p in lockfiles], "findings": findings}, indent=1))
    elif args.detail:
        for f in findings:
            print(format_line(f))
    else:
        print(f"{root}: {len(lockfiles)} tracked lockfiles, {len(findings)} open advisories")
        for line in package_rollup(findings):
            print(line)
    return 1 if any(minimal_fix(f) for f in findings) else 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hook", action="store_true")
    parser.add_argument("--repo", default=".")
    parser.add_argument("--no-cache", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--detail", action="store_true")
    args = parser.parse_args()
    return hook_main() if args.hook else cli_main(args)


if __name__ == "__main__":
    sys.exit(main())
