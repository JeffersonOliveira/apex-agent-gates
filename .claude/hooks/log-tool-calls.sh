#!/usr/bin/env bash
# Gate 2 (PostToolUse, any tool): audit trail. Appends one JSON line per tool call to .claude/logs/tool-calls.jsonl.
# Never blocks: always exits 0.
set -euo pipefail
trap 'exit 0' ERR

input="$(cat)"
root="${CLAUDE_PROJECT_DIR:-.}"
mkdir -p "${root}/.claude/logs"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if command -v jq >/dev/null 2>&1; then
  printf '%s' "$input" | jq -c --arg ts "$ts" \
    '{timestamp: $ts, tool_name: (.tool_name // "unknown"), summary: (.tool_input.command // .tool_input.file_path // "")}' \
    >> "${root}/.claude/logs/tool-calls.jsonl"
else
  printf '%s' "$input" | TS="$ts" python3 -c '
import json, os, sys
d = json.load(sys.stdin)
ti = d.get("tool_input") or {}
print(json.dumps({"timestamp": os.environ["TS"], "tool_name": d.get("tool_name", "unknown"), "summary": ti.get("command") or ti.get("file_path") or ""}))
' >> "${root}/.claude/logs/tool-calls.jsonl"
fi

exit 0
