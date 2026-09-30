#!/usr/bin/env bash
# Behavioural tests for the Group K hooks (config-protection, gateguard, trace-tool-call).
# These hooks were previously only checked by hand. Run: bash tests/hooks/test-hooks.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
H="$ROOT/hooks"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"          # gateguard state must not touch the real tmp
PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); }
bad(){ FAILN=$((FAILN+1)); echo "FAIL: $1"; }
expect(){ [ "$2" = "$3" ] && ok || bad "$1 (got $2, want $3)"; }
rc(){ "$@" >/dev/null 2>&1; echo $?; }

# ---------------- config-protection
mkdir -p "$T/p/node_modules/x" "$T/p/test/fixtures" "$T/p/src"
echo '{}' > "$T/p/tsconfig.json"; echo '{}' > "$T/p/node_modules/x/tsconfig.json"; echo x > "$T/p/test/fixtures/.eslintrc"
echo x > "$T/p/src/a.ts"; ln -s "$T/p/tsconfig.json" "$T/p/link.json"; echo '{}' > "$T/p/RUFF.TOML"
cp_(){ printf '{"tool_input":{"file_path":"%s"}}' "$1" | bash "$H/config-protection.sh" >/dev/null 2>&1; echo $?; }
expect "config: existing tsconfig blocked" "$(cp_ "$T/p/tsconfig.json")" 2
expect "config: new config file allowed" "$(cp_ "$T/p/new/tsconfig.json")" 0
expect "config: ordinary source allowed" "$(cp_ "$T/p/src/a.ts")" 0
expect "config: vendored node_modules config allowed" "$(cp_ "$T/p/node_modules/x/tsconfig.json")" 0
expect "config: fixture-dir config allowed" "$(cp_ "$T/p/test/fixtures/.eslintrc")" 0
expect "config: symlink alias to tsconfig blocked" "$(cp_ "$T/p/link.json")" 2
expect "config: uppercase basename blocked" "$(cp_ "$T/p/RUFF.TOML")" 2
expect "config: bypass env allows" "$(printf '{"tool_input":{"file_path":"%s"}}' "$T/p/tsconfig.json" | EXPERTS_ALLOW_CONFIG_EDIT=1 bash "$H/config-protection.sh" >/dev/null 2>&1; echo $?)" 0
expect "config: garbage stdin does not crash (exit 0)" "$(echo 'not json' | bash "$H/config-protection.sh" >/dev/null 2>&1; echo $?)" 0

# ---------------- gateguard
echo x > "$T/p/g.ts"
gg(){ printf '%s' "$1" | EXPERTS_GATEGUARD="${2:-1}" EXPERTS_GATEGUARD_LOG="${3:-}" bash "$H/gateguard.sh" >/dev/null 2>&1; echo $?; }
S1="{\"session_id\":\"A\",\"tool_input\":{\"file_path\":\"$T/p/g.ts\"}}"
S2="{\"session_id\":\"B\",\"tool_input\":{\"file_path\":\"$T/p/g.ts\"}}"
NS="{\"tool_input\":{\"file_path\":\"$T/p/g.ts\"}}"
expect "gateguard: off by default" "$(printf '%s' "$S1" | bash "$H/gateguard.sh" >/dev/null 2>&1; echo $?)" 0
expect "gateguard: first edit denied" "$(gg "$S1")" 2
expect "gateguard: retry allowed" "$(gg "$S1")" 0
expect "gateguard: another session re-gates" "$(gg "$S2")" 2
expect "gateguard: no session id still gates once" "$(gg "$NS")" 2
expect "gateguard: no session id retry allowed" "$(gg "$NS")" 0
NL="{\"session_id\":\"C\",\"tool_input\":{\"file_path\":\"a\"}}"; NL2="{\"session_id\":\"C\",\"tool_input\":{\"file_path\":\"a\\nzzz\"}}"
gg "$NL" >/dev/null
expect "gateguard: a path with a newline cannot ride on its first line (was a bypass)" "$(gg "$NL2")" 2
LOG="$T/gate.jsonl"; gg "{\"session_id\":\"D\",\"tool_input\":{\"file_path\":\"x\"}}" 1 "$LOG" >/dev/null
expect "gateguard: deny is logged as JSONL" "$(jq -r .event "$LOG" 2>/dev/null)" gate_denied
expect "gateguard: unwritable log path still denies (exit 2)" "$(gg "{\"session_id\":\"E\",\"tool_input\":{\"file_path\":\"y\"}}" 1 /nonexistent/dir/log)" 2
sid=$(printf '%s' F | shasum | cut -c1-16); f="$TMPDIR/attest-gateguard-$sid"
gg "{\"session_id\":\"F\",\"tool_input\":{\"file_path\":\"z\"}}" >/dev/null; touch -t 202001010000 "$f"
expect "gateguard: memory expires after the TTL (re-gates)" "$(gg "{\"session_id\":\"F\",\"tool_input\":{\"file_path\":\"z\"}}")" 2

# ---------------- trace-tool-call
TL="$T/trace.jsonl"
tr_(){ printf '%s' "$1" | EXPERTS_TRACE_LOG="${2-$TL}" bash "$H/trace-tool-call.sh" >/dev/null 2>&1; echo $?; }
TR="$T/transcript.jsonl"
cat > "$TR" <<'JSONL'
{"type":"assistant","message":{"id":"msg_par","content":[{"type":"tool_use","id":"tu_1","name":"Write","input":{}}]}}
{"type":"assistant","message":{"id":"msg_par","content":[{"type":"tool_use","id":"tu_2","name":"Write","input":{}}]}}
{"type":"assistant","message":{"id":"msg_solo","content":[{"type":"tool_use","id":"tu_3","name":"Bash","input":{}}]}}
JSONL
LONG=$(head -c 900 /dev/zero | tr '\0' 'x')
expect "trace: off when EXPERTS_TRACE_LOG is unset" "$(printf '{}' | bash "$H/trace-tool-call.sh" >/dev/null 2>&1; echo $?)" 0
tr_ "{\"session_id\":\"s\",\"tool_name\":\"Write\",\"tool_use_id\":\"tu_1\",\"transcript_path\":\"$TR\",\"tool_input\":{\"file_path\":\"src/a.py\"},\"tool_response\":\"ok\"}" >/dev/null
tr_ "{\"session_id\":\"s\",\"tool_name\":\"Write\",\"tool_use_id\":\"tu_2\",\"transcript_path\":\"$TR\",\"tool_input\":{\"file_path\":\"tests/t.py\"},\"tool_response\":\"ok\"}" >/dev/null
tr_ "{\"session_id\":\"s\",\"tool_name\":\"Bash\",\"tool_use_id\":\"tu_3\",\"transcript_path\":\"$TR\",\"tool_input\":{\"command\":\"pytest\"},\"tool_response\":{\"stdout\":\"$LONG FAILED 1\",\"stderr\":\"\"}}" >/dev/null
expect "trace: one row per call" "$(wc -l < "$TL" | tr -d ' ')" 3
expect "trace: tool name lower-cased, file captured" "$(sed -n 1p "$TL" | jq -r '[.tool,.file]|join(" ")')" "write src/a.py"
expect "trace: parallel calls (same assistant message) share a group" "$(jq -r .group "$TL" | sed -n 1p)" "$(jq -r .group "$TL" | sed -n 2p)"
expect "trace: the group is the assistant message id" "$(sed -n 1p "$TL" | jq -r .group)" msg_par
expect "trace: a separate message gets a different group" "$(sed -n 3p "$TL" | jq -r .group)" msg_solo
expect "trace: long output keeps the TAIL (failure summary), not just the head" "$(sed -n 3p "$TL" | jq -r '.out | test("FAILED 1$")')" true
LONGC=$(head -c 2000 /dev/zero | tr '\0' 'y')
tr_ "{\"session_id\":\"s\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$LONGC cat /answer/key --final\"},\"tool_response\":\"\"}" >/dev/null
expect "trace: a long command keeps its TAIL (a path/flag at the end must stay visible)" "$(tail -1 "$TL" | jq -r '.cmd | test("--final$")')" true
expect "trace: a long command stays bounded" "$(tail -1 "$TL" | jq -r '.cmd | length <= 605')" true
expect "trace: output is bounded" "$(sed -n 3p "$TL" | jq -r '.out | length <= 210')" true
expect "trace: object tool_response (Bash) is flattened to text" "$(sed -n 3p "$TL" | jq -r '.out|type')" string
expect "trace: garbage stdin never fails the tool call" "$(echo 'not json' | EXPERTS_TRACE_LOG="$TL" bash "$H/trace-tool-call.sh" >/dev/null 2>&1; echo $?)" 0
expect "trace: garbage stdin adds no row" "$(wc -l < "$TL" | tr -d ' ')" 4
expect "trace: unwritable log path never fails the tool call" "$(tr_ '{"tool_name":"Bash","tool_input":{"command":"ls"}}' /nonexistent/dir/t.jsonl)" 0
expect "trace: missing transcript still records (group null)" "$(tr_ '{"session_id":"s","tool_name":"Bash","tool_use_id":"nope","transcript_path":"/none","tool_input":{"command":"ls"},"tool_response":""}' >/dev/null; tail -1 "$TL" | jq -r '.group')" null

echo "hooks: $PASS passed, $FAILN failed"
[ "$FAILN" -eq 0 ]
