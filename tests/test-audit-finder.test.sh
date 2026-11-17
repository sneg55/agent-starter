#!/bin/bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/lib/assert.sh"
FINDER="$ROOT/skills/test-audit/scripts/find-test-only-exports.py"

REPO=$(mktemp -d)
trap 'rm -rf "$REPO"' EXIT
mkdir -p "$REPO/src/lib" "$REPO/src/utils" "$REPO/src/app/api" "$REPO/pkg" "$REPO/tests" "$REPO/.claude/rules"

cat > "$REPO/src/lib/math.ts" <<'EOF'
export function add(a: number, b: number) { return a + b; }
export function legacySum(xs: number[]) { return xs.reduce(add, 0); }
export const helper = (x: number) => x * 2;
export const doubled = (x: number) => helper(x);
EOF
cat > "$REPO/src/app.ts" <<'EOF'
import { add, doubled } from "./lib/math";
console.log(add(1, 2), doubled(3));
EOF
cat > "$REPO/src/lib/math.test.ts" <<'EOF'
import { add, helper, legacySum } from "./math";
test("sum", () => expect(legacySum([1, 2])).toBe(add(1, 2)));
test("helper", () => expect(helper(2)).toBe(4));
EOF
cat > "$REPO/src/utils/truncate-for-context.ts" <<'EOF'
export function truncateForContext(s: string) { return s.slice(0, 10); }
EOF
cat > "$REPO/.claude/rules/starter-patterns.md" <<'EOF'
Use truncateForContext from src/utils/truncate-for-context.ts.
EOF
cat > "$REPO/src/app/api/route.ts" <<'EOF'
export async function GET() { return new Response("ok"); }
EOF
cat > "$REPO/pkg/core.py" <<'EOF'
def used_fn():
    return 1


def only_tested():
    return 2


def _private():
    return 3
EOF
cat > "$REPO/pkg/main.py" <<'EOF'
from pkg.core import used_fn

print(used_fn())
EOF
cat > "$REPO/tests/test_core.py" <<'EOF'
from pkg.core import only_tested


def test_only():
    assert only_tested() == 2
EOF

cat > "$REPO/src/lib/kinds.ts" <<'EOF'
export const enum Dir { Up, Down }
EOF
cat > "$REPO/src/lib/listed.ts" <<'EOF'
function hidden() { return 1; }
export { hidden };
export { add } from "./math";
export default function defaultOnly() { return 2; }
function shared() { return 5; }
export { shared };
export const viaShared = () => shared();
EOF
cat > "$REPO/src/consumer.ts" <<'EOF'
import { viaShared } from "./lib/listed";
console.log(viaShared());
EOF
cat > "$REPO/src/lib/extra.test.ts" <<'EOF'
import defaultOnly, { hidden, shared } from "./listed";
import { Dir } from "./kinds";
test("extra", () => expect(hidden() + defaultOnly() + shared() + Dir.Up).toBe(8));
EOF
mkdir -p "$REPO/spec"
cat > "$REPO/pkg/extra.py" <<'EOF'
def spec_only():
    return 4
EOF
cat > "$REPO/spec/extra_check.py" <<'EOF'
from pkg.extra import spec_only

assert spec_only() == 4
EOF

git -C "$REPO" init -q && git -C "$REPO" add -A

got=$(python3 -I "$FINDER" "$REPO"); rc=$?
want=$(printf '%s\t%s\t%s\t%s\t%s\n' \
  TEST-ONLY 1 pkg/core.py only_tested - \
  TEST-ONLY 1 pkg/extra.py spec_only - \
  TEST-ONLY 1 src/lib/kinds.ts Dir - \
  TEST-ONLY 1 src/lib/listed.ts defaultOnly - \
  TEST-ONLY 1 src/lib/listed.ts hidden - \
  TEST-ONLY 1 src/lib/math.ts legacySum - \
  UNREFERENCED 0 src/utils/truncate-for-context.ts truncateForContext scaffold \
  USED-IN-FILE 1 src/lib/listed.ts shared - \
  USED-IN-FILE 1 src/lib/math.ts helper -)
assert_eq 0 "$rc" "finder exits 0"
assert_eq "$want" "$got" "finder classifies test-only, unreferenced scaffold, and used-in-file exports"

EMPTY=$(mktemp -d)
git -C "$EMPTY" init -q
got=$(python3 -I "$FINDER" "$EMPTY"); rc=$?
rm -rf "$EMPTY"
assert_eq 0 "$rc" "empty repo exits 0"
assert_eq "" "$got" "empty repo prints nothing"

exit $ASSERT_FAILED
