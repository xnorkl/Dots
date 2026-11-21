#!/usr/bin/env bash
# Trunk guard: blocks git actions that would land changes directly on the
# default branch of any repo (trunk-based development guardrail).
# Dual-harness via hx-hook-lib.sh: Claude Code PreToolUse (Bash matcher) and
# Cursor beforeShellExecution both feed it; the lib answers each in its own
# deny dialect.
#
# Blocks, when HEAD is the default branch: git commit / merge / revert /
# cherry-pick / am. Blocks any git push whose destination is the default
# branch, from any branch (including HEAD:main refspecs, :main deletes,
# --all / --mirror).
#
# Escape hatches (only when writing to trunk is genuinely intended):
#   HX_ALLOW_TRUNK=1 git ...           one-off, visible in the command
#   <repo>/.harness/allow-trunk        per-repo opt-out (local-only marker)
set -uo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hx-hook-lib.sh"

hx_hook_parse || exit 0
CMD="$HX_CMD"
CWD="$HX_DIR"

case "$CMD" in *git*) : ;; *) exit 0 ;; esac
case "$CMD" in *HX_ALLOW_TRUNK=1*) exit 0 ;; esac

# Strip quoted strings so commit messages etc. cannot trigger the matchers.
SCRUBBED=$(printf '%s' "$CMD" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

DIR="${CWD:-$PWD}"
# Honour git -C <path> so commands targeting another repo are checked there.
if [[ "$SCRUBBED" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
    C_PATH="${BASH_REMATCH[1]}"
    [[ "$C_PATH" = /* ]] || C_PATH="$DIR/$C_PATH"
    [ -d "$C_PATH" ] && DIR="$C_PATH"
fi

ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -e "$ROOT/.harness/allow-trunk" ] && exit 0

# Detached HEAD (rebase states, CI, worktree plumbing): allow.
CUR=$(git -C "$DIR" symbolic-ref --quiet --short HEAD 2>/dev/null) || exit 0

DEF=$(git -C "$DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)
DEF="${DEF#origin/}"
if [ -z "$DEF" ]; then
    for b in main master trunk; do
        if git -C "$DIR" show-ref --verify --quiet "refs/heads/$b"; then
            DEF="$b"
            break
        fi
    done
fi
[ -z "$DEF" ] && exit 0

deny() {
    hx_hook_deny "$1

Escape hatches (only when writing to trunk is genuinely intended):
  - one-off:        HX_ALLOW_TRUNK=1 git ...
  - per-repo:       touch $ROOT/.harness/allow-trunk"
}

GITSEG='(^|[;&|[:space:]])git[[:space:]]([^|;&]*[[:space:]])?'

if [ "$CUR" = "$DEF" ] && printf '%s' "$SCRUBBED" | grep -qE "${GITSEG}(commit|merge|revert|cherry-pick|am)([[:space:]]|\$)"; then
    deny "BLOCKED by trunk-guard: HEAD is '$DEF' (the default branch).
Trunk-based development requires working on a branch. Your changes are safe --
uncommitted work carries over when you create one:
  git switch -c <type>/<short-slug>
then retry this command."
fi

if printf '%s' "$SCRUBBED" | grep -qE "${GITSEG}push([[:space:]]|\$)"; then
    PUSH_SEG=$(printf '%s' "$SCRUBBED" | grep -oE "${GITSEG}push[^|;&]*" | head -1)
    AFTER=$(printf '%s' "$PUSH_SEG" | sed -E 's/.*push//')

    PUSH_MSG="BLOCKED by trunk-guard: this push writes to '$DEF' (the default branch).
Direct pushes to trunk are not allowed -- push your branch and open a pull
request instead (/hx-pr)."

    TOK=()
    read -ra TOK <<< "$AFTER" || true
    REMOTE=""
    REFSPECS=()
    for t in ${TOK[@]+"${TOK[@]}"}; do
        case "$t" in
            --all|--mirror) deny "$PUSH_MSG" ;;
            -*) continue ;;
            *)
                if [ -z "$REMOTE" ]; then REMOTE="$t"; else REFSPECS+=("$t"); fi
                ;;
        esac
    done

    if [ ${#REFSPECS[@]} -eq 0 ]; then
        # Bare push (or remote only): pushes the current branch.
        [ "$CUR" = "$DEF" ] && deny "$PUSH_MSG"
    else
        for r in ${REFSPECS[@]+"${REFSPECS[@]}"}; do
            DST="${r##*:}"      # after last colon; the token itself if no colon
            DST="${DST#+}"      # strip force marker
            if [ "$DST" = "$DEF" ] || [ "$DST" = "refs/heads/$DEF" ]; then
                deny "$PUSH_MSG"
            fi
            if [ "$DST" = "HEAD" ] && [ "$CUR" = "$DEF" ]; then
                deny "$PUSH_MSG"
            fi
        done
    fi
fi

exit 0
