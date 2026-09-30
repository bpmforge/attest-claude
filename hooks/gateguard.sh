#!/bin/bash
# Opt-in (EXPERTS_GATEGUARD=1) fact-forcing gate: deny the FIRST edit/write of a file
# per session until the agent states concrete facts, then allow the retry.
# Hook type: PreToolUse (Write|Edit|MultiEdit). Adapted from affaan-m/ECC (MIT).
# Same as ECC: the retry is not checked for facts (forced pause + fact request), Write/Edit only
# (no Bash gate), 30-min memory. ECC's "+2.25 quality" is 2 self-run tests -- keep opt-in until
# the attest A/B (docs/work/GROUP_K_DESIGN.md) says otherwise.
# EXPERTS_GATEGUARD_LOG=<file>: append one JSONL row per deny (an A/B run where the gate never
# fired must be discarded).

[ "$EXPERTS_GATEGUARD" = "1" ] || exit 0
if ! command -v jq >/dev/null 2>&1; then
  echo "GATEGUARD: jq not found -- gate DISABLED (install jq)" >&2
  exit 0
fi
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

# Session key: session_id, else transcript path, else cwd -- never a shared constant.
raw=$(echo "$input" | jq -r '.session_id // .transcript_path // empty')
[ -z "$raw" ] && raw="cwd-$PWD"
session=$(printf '%s' "$raw" | shasum | cut -c1-16)

state="${TMPDIR:-/tmp}/attest-gateguard-$session"
ttl=1800
now=$(date +%s)
if [ -f "$state" ]; then
  mtime=$(stat -f %m "$state" 2>/dev/null || stat -c %Y "$state" 2>/dev/null || echo "$now")
  [ $((now - mtime)) -ge $ttl ] && rm -f "$state"
fi
grep -qxF "$file_path" "$state" 2>/dev/null && exit 0
echo "$file_path" >> "$state"

if [ -n "$EXPERTS_GATEGUARD_LOG" ]; then
  jq -cn --arg s "$session" --arg f "$file_path" --argjson t "$now" \
    '{ts:$t,event:"gate_denied",session:$s,file:$f}' >> "$EXPERTS_GATEGUARD_LOG"
fi

if [ -f "$file_path" ]; then
  echo "GATEGUARD: before editing $file_path, state these facts (gather with grep/read, then retry the same edit): 1. Every file that imports/requires it. 2. The public functions/classes this change affects. 3. If it reads/writes data files: field names and structure (redacted values). 4. The user's current instruction, quoted verbatim." >&2
else
  echo "GATEGUARD: before creating $file_path, state these facts (then retry the same write): 1. The file(s)/line(s) that will call it. 2. That no existing file already serves this purpose (show your search). 3. If it reads/writes data files: field names and structure (redacted values). 4. The user's current instruction, quoted verbatim." >&2
fi
exit 2
