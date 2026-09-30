#!/bin/bash
# Opt-in (EXPERTS_GATEGUARD=1) fact-forcing gate: deny the FIRST edit/write of a file
# per session until the agent states concrete facts, then allow the retry.
# Hook type: PreToolUse (Write|Edit|MultiEdit). Adapted from affaan-m/ECC (MIT).
# ECC's "+2.25 quality" claim is 2 self-run tests -- keep opt-in until attest evals confirm.

[ "$EXPERTS_GATEGUARD" = "1" ] || exit 0
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
session=$(echo "$input" | jq -r '.session_id // "_"')
[ -z "$file_path" ] && exit 0

state="${TMPDIR:-/tmp}/attest-gateguard-$session"
key="$file_path"
grep -qxF "$key" "$state" 2>/dev/null && exit 0
echo "$key" >> "$state"

if [ -f "$file_path" ]; then
  echo "GATEGUARD: before editing $file_path, state these facts (gather with grep/read, then retry the same edit): 1. Every file that imports/requires it. 2. The public functions/classes this change affects. 3. If it reads/writes data files: field names and structure (redacted values). 4. The user's current instruction, quoted verbatim." >&2
else
  echo "GATEGUARD: before creating $file_path, state these facts (then retry the same write): 1. The file(s)/line(s) that will call it. 2. That no existing file already serves this purpose (show your search). 3. The user's current instruction, quoted verbatim." >&2
fi
exit 2
