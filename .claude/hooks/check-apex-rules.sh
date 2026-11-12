#!/usr/bin/env bash
# Gate 2 (PostToolUse, matcher Edit|Write): reviews every edited .cls file against the rules in CLAUDE.md.
# Heuristic checks with grep. Exit 2 sends the findings back to the agent so it fixes them before moving on.
# Escape hatch for deliberate exceptions: a comment containing `gates:allow-system-mode:` plus the reason.
set -euo pipefail

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
else
  file="$(printf '%s' "$input" | python3 -c 'import sys, json; print((json.load(sys.stdin).get("tool_input") or {}).get("file_path", ""))' 2>/dev/null || true)"
fi

case "${file}" in
  *.cls) ;;
  *) exit 0 ;;
esac

if [ ! -f "${file}" ]; then
  exit 0
fi

problems=()
has_marker=0
if grep -q 'gates:allow-system-mode' "${file}"; then
  has_marker=1
fi

# Rule 1: SOQL without USER_MODE anywhere in the file.
flat="$(tr '\n' ' ' < "${file}")"
if printf '%s' "$flat" | grep -Eiq '\[[[:space:]]*select' && ! grep -q 'USER_MODE' "${file}" && [ "${has_marker}" -eq 0 ]; then
  problems+=("SOQL without WITH USER_MODE (rule 1)")
fi

# Rule 2: DML statements without 'as user', and Database.<op> calls without AccessLevel.USER_MODE.
if [ "${has_marker}" -eq 0 ]; then
  if grep -Ei '^[[:space:]]*(insert|update|delete|upsert|undelete)[[:space:]]+' "${file}" | grep -Eviq '[[:space:]]as[[:space:]]+user' ; then
    problems+=("DML statement without 'as user' (rule 2)")
  fi
  if grep -Ei 'Database\.(insert|update|delete|upsert|undelete)[[:space:]]*\(' "${file}" | grep -vq 'AccessLevel\.USER_MODE'; then
    problems+=("Database DML without AccessLevel.USER_MODE (rule 2)")
  fi
fi

# Rule 3: class without 'with sharing'.
if grep -Eiq '(^|[[:space:]])class[[:space:]]+[A-Za-z_]' "${file}" && ! grep -Eiq '(^|[^a-z])with[[:space:]]+sharing' "${file}" && [ "${has_marker}" -eq 0 ]; then
  problems+=("class without 'with sharing' (rule 3)")
fi

# Rule 6: test class without any assert.
if grep -Eiq '@IsTest' "${file}" && ! grep -Eq 'Assert\.|System\.assert' "${file}"; then
  problems+=("test without Assert.* or System.assert* (rule 6)")
fi

if [ "${#problems[@]}" -gt 0 ]; then
  {
    echo "Gate 2 found problems in ${file}:"
    for p in "${problems[@]}"; do
      echo " - ${p}"
    done
    echo "Fix before continuing. Rules in CLAUDE.md."
  } >&2
  exit 2
fi

exit 0
