#!/usr/bin/env bash
# Gate 2 (PreToolUse, matcher Bash): blocks deploys to prod/uat orgs and destructive commands.
# Claude Code sends the tool call as JSON on stdin. Exit 2 = block the tool and send stderr back to the agent.
set -euo pipefail

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
else
  cmd="$(printf '%s' "$input" | python3 -c 'import sys, json; print((json.load(sys.stdin).get("tool_input") or {}).get("command", ""))' 2>/dev/null || true)"
fi

# Nothing to inspect: let it through.
if [ -z "${cmd}" ]; then
  exit 0
fi

lc="$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')"

# A blocked call never reaches PostToolUse, so the audit hook would not see it. Log it here.
log_blocked() {
  local root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
  mkdir -p "${root}/.claude/logs" 2>/dev/null || return 0
  CMD="$cmd" REASON="$1" TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)" python3 -c '
import json, os
print(json.dumps({"timestamp": os.environ["TS"], "tool_name": "Bash", "blocked": True,
                  "reason": os.environ["REASON"], "summary": os.environ["CMD"]}))
' >> "${root}/.claude/logs/tool-calls.jsonl" 2>/dev/null || true
}

# 1) Destructive commands.
if printf '%s' "$lc" | grep -Eq 'sf[[:space:]]+org[[:space:]]+delete|git[[:space:]]+push[^|;&]*--force|rm[[:space:]]+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r)'; then
  log_blocked "destructive command"
  echo "BLOCKED by Gate 2: destructive commands (sf org delete, git push --force, rm -rf) are not allowed in this project. Ask a human to run it." >&2
  exit 2
fi

# 2) Deploy to a production or UAT org.
if printf '%s' "$lc" | grep -Eq '(^|[^a-z])sf[[:space:]]+(project[[:space:]]+)?deploy'; then
  # Alias passed with -o / --target-org (also --target-org=alias): block when it contains prod, production or uat.
  alias_value="$(printf '%s' "$lc" | grep -Eo '(-o|--target-org)[ =][^[:space:]]+' | head -n 1 | sed -E 's/^(-o|--target-org)[ =]//' || true)"
  if [ -n "${alias_value}" ] && printf '%s' "$alias_value" | grep -Eq 'prod|uat'; then
    log_blocked "deploy to production or UAT"
    echo "BLOCKED by Gate 2: deploying to a production or UAT org is not allowed in this project. Use --target-org lab." >&2
    exit 2
  fi
  # Any other standalone mention of prod, production or uat in the deploy command.
  if printf '%s' "$lc" | grep -Eq '(^|[^a-z0-9])(prod|production|uat)([^a-z0-9]|$)'; then
    log_blocked "deploy to production or UAT"
    echo "BLOCKED by Gate 2: deploying to a production or UAT org is not allowed in this project. Use --target-org lab." >&2
    exit 2
  fi
fi

exit 0
