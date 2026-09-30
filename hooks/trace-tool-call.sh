#!/bin/bash
# Opt-in (EXPERTS_TRACE_LOG=<file>) per-tool-call trace for rule-compliance grading (Group K4).
# Hook type: PostToolUse (matcher: *). Never blocks and never fails a tool call.
# Row: {ts,session,tool,file,cmd,out,tool_use_id,group}. `group` = the assistant message id that issued the call:
# calls issued in PARALLEL share it, so scripts/lib/trace-order.mjs treats their relative order as undefined
# (Claude Code hands hooks no ordering between parallel calls; the transcript does carry the message id).
# `out` keeps head+tail of the output (a test failure summary sits at the END of long output).
# Adapted for attest from affaan-m/ECC skill-comply (MIT).

[ -n "$EXPERTS_TRACE_LOG" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)

ts=$(perl -MTime::HiRes=time -e 'printf "%d", time*1000' 2>/dev/null || echo "$(date +%s)000")
tuid=$(printf '%s' "$input" | jq -r '.tool_use_id // empty')
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
group=""
if [ -n "$tuid" ] && [ -n "$tp" ] && [ -f "$tp" ]; then
  group=$(tail -n 400 "$tp" | jq -r --arg id "$tuid" \
    'select((.message.content? | type) == "array") | select(any(.message.content[]; .type == "tool_use" and .id == $id)) | .message.id // empty' 2>/dev/null | head -1)
fi

row=$(printf '%s' "$input" | jq -c --argjson ts "$ts" --arg group "$group" '
  def head_tail: if length > 200 then .[:100] + " ... " + .[-100:] else . end;
  { ts: $ts,
    session: (.session_id // null),
    tool: ((.tool_name // "") | ascii_downcase),
    file: (.tool_input.file_path // .tool_input.path // null),
    cmd: ((.tool_input.command // null) | if type == "string" then (if length > 600 then .[:300] + " ... " + .[-300:] else . end) else null end),
    out: ((.tool_response // "") | if type == "string" then . else ((.stdout // "") + (.stderr // "") + (.output // "") + (if (.content | type) == "string" then .content else "" end)) end | head_tail),
    tool_use_id: (.tool_use_id // null),
    group: (if $group == "" then null else $group end) }' 2>/dev/null) || exit 0
[ -n "$row" ] && printf '%s\n' "$row" >> "$EXPERTS_TRACE_LOG" 2>/dev/null
exit 0
