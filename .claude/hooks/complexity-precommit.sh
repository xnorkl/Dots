#!/usr/bin/env bash
# Pre-commit cognitive complexity gate: hard-blocks git commits when staged
# Python files have cognitive complexity >= 16.
# Dual-harness via hx-hook-lib.sh: Claude Code PreToolUse (settings.json also
# pre-filters with if: Bash(git commit*)) and Cursor beforeShellExecution.
# The commit match and repo resolution happen here because Cursor user hooks
# run from ~/.cursor, not the project, and pass no command filter.
set -uo pipefail

COGNITIVE_MAX=15  # complexipy exits 1 if any function exceeds this

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hx-hook-lib.sh"

hx_hook_parse || exit 0

# Strip quoted strings so a commit message mentioning "git commit" can't match.
SCRUBBED=$(printf '%s' "$HX_CMD" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
printf '%s' "$SCRUBBED" \
    | grep -qE '(^|[;&|[:space:]])git[[:space:]]([^|;&]*[[:space:]])?commit([[:space:]]|$)' \
    || exit 0

DIR="${HX_DIR:-$PWD}"
# Honour git -C <path> so commits targeting another repo are checked there.
if [[ "$SCRUBBED" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
    C_PATH="${BASH_REMATCH[1]}"
    [[ "$C_PATH" = /* ]] || C_PATH="$DIR/$C_PATH"
    [ -d "$C_PATH" ] && DIR="$C_PATH"
fi
ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0

STAGED_PY=$(git diff --name-only --cached -- '*.py' 2>/dev/null || true)
[ -z "$STAGED_PY" ] && exit 0

if ! command -v complexipy &>/dev/null; then
    echo "WARNING: complexipy not installed — skipping cognitive complexity check." >&2
    echo "  pip install complexipy" >&2
    exit 0
fi

FILES=()
while IFS= read -r f; do
    [ -f "$f" ] && FILES+=("$f")
done <<< "$STAGED_PY"
[ "${#FILES[@]}" -eq 0 ] && exit 0

echo "Checking cognitive complexity of ${#FILES[@]} staged Python file(s)..." >&2

if ! OUT=$(complexipy "${FILES[@]}" --max-complexity-allowed "$COGNITIVE_MAX" --failed --color no 2>&1); then
    hx_hook_deny "COMMIT BLOCKED: Cognitive complexity violations found in staged files.

$OUT

Run /complexity to identify and refactor violations, then retry the commit."
fi

echo "OK — cognitive complexity within threshold." >&2
exit 0
