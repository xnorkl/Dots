#!/usr/bin/env bash
# hx-hook-lib.sh — dual-schema adapter for the hx shell-gating hooks.
# Sourced by a hook script; parses the JSON a harness pipes on stdin and
# provides a deny helper that answers in that harness's dialect:
#
#   Claude Code  PreToolUse            {tool_input:{command}, cwd}
#                deny: exit 2, message on stderr
#   Cursor       beforeShellExecution  {command, workspace_roots:[...]}
#                deny: exit 0, {"permission":"deny","agent_message":...} on stdout
#
#   hx_hook_parse            sets HX_HARNESS / HX_CMD / HX_DIR; rc 1 on no input
#   hx_hook_deny "message"   blocks the action, feeding message to the agent
#
# Fail-open by design: no input, unparseable JSON, or missing jq/python3 -> the
# caller sees rc 1 / empty vars and should allow. Gates that must fail closed
# express that via the harness config (Cursor failClosed), not here.
#
# Cursor + failClosed subtlety: a failClosed hook that exits 0 with EMPTY stdout
# is treated by Cursor as "returned no output" = failure = block. So for Cursor
# every clean (rc 0) exit must emit an explicit {"permission":"allow"}. An EXIT
# trap armed by hx_hook_parse does this, so the scripts' many bare `exit 0` allow
# paths need no changes. Claude Code allow stays silent (empty stdout, exit 0).

_HX_DECIDED=0

# EXIT trap: for Cursor, turn any clean exit that hasn't already emitted a
# decision into an explicit allow, so a failClosed hook never blocks on empty
# output. Must not change the exit code, so it never calls exit.
_hx_hook_finish() {
    local rc=$?
    if [ "${HX_HARNESS:-}" = "cursor" ] && [ "$rc" = 0 ] && [ "${_HX_DECIDED:-0}" = 0 ]; then
        printf '{"permission":"allow"}\n'
    fi
}

hx_hook_parse() {
    HX_HARNESS="" HX_CMD="" HX_DIR=""
    local input
    input=$(cat 2>/dev/null || true)
    [ -z "$input" ] && return 1

    if command -v jq >/dev/null 2>&1; then
        # jq's // falls through only on null/false, NOT "". Cursor sends cwd:"" ,
        # so select non-empty explicitly or HX_DIR becomes "" and callers misresolve.
        HX_HARNESS=$(printf '%s' "$input" | jq -r \
            'if has("tool_input") then "claude" elif has("command") then "cursor" else "" end' 2>/dev/null)
        HX_CMD=$(printf '%s' "$input" | jq -r \
            '[.tool_input.command, .command] | map(select(. != null and . != "")) | first // empty' 2>/dev/null)
        HX_DIR=$(printf '%s' "$input" | jq -r \
            '[.cwd, .workspace_roots[0]] | map(select(. != null and . != "")) | first // empty' 2>/dev/null)
    elif command -v python3 >/dev/null 2>&1; then
        eval "$(printf '%s' "$input" | python3 -c '
import json, shlex, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
harness = "claude" if "tool_input" in d else "cursor" if "command" in d else ""
cmd = d.get("tool_input", {}).get("command") or d.get("command") or ""
roots = d.get("workspace_roots") or [""]
wd = d.get("cwd") or roots[0] or ""
print(f"HX_HARNESS={shlex.quote(harness)} HX_CMD={shlex.quote(cmd)} HX_DIR={shlex.quote(wd)}")
' 2>/dev/null)"
    else
        echo "hx-hook-lib: neither jq nor python3 available -- gate skipped" >&2
        return 1
    fi
    [ -n "$HX_CMD" ] || return 1
    trap _hx_hook_finish EXIT
    return 0
}

hx_hook_deny() {
    local msg="$1"
    _HX_DECIDED=1
    if [ "${HX_HARNESS:-}" = "cursor" ]; then
        if command -v jq >/dev/null 2>&1; then
            jq -n --arg m "$msg" '{permission: "deny", agent_message: $m}'
        else
            python3 -c 'import json,sys; print(json.dumps({"permission": "deny", "agent_message": sys.argv[1]}))' "$msg"
        fi
        exit 0
    fi
    printf '%s\n' "$msg" >&2
    exit 2
}
