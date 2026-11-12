"""Gate 3a: turn Salesforce Code Analyzer results into something a reviewer sees without opening the logs.

- One GitHub annotation per violation, on the exact file and line (shows in the PR "Files changed" tab).
- A Markdown table in the job summary.
- Exit 1 when any violation is at or above the severity threshold (1 = Critical ... 5 = Info).

Usage: python3 report-violations.py <code-analyzer-results.json> <max-severity-that-fails>
"""
import json
import os
import sys

results_file, threshold = sys.argv[1], int(sys.argv[2])
workspace = os.environ.get("GITHUB_WORKSPACE", os.getcwd())
names = {1: "Critical", 2: "High", 3: "Moderate", 4: "Low", 5: "Info"}

with open(results_file, encoding="utf-8") as f:
    violations = json.load(f).get("violations", [])

blocking = []
for v in violations:
    loc = v["locations"][v.get("primaryLocationIndex", 0)]
    path = os.path.relpath(loc.get("file", ""), workspace).replace(os.sep, "/")
    line = loc.get("startLine", 1)
    sev = int(v.get("severity", 5))
    msg = " ".join(str(v.get("message", "")).split())
    if sev > threshold:
        continue  # below the gate: stays in the log, does not clutter the pull request
    # GitHub workflow command: becomes an annotation on that line of the pull request.
    print(f"::error file={path},line={line},title={v['rule']} ({names.get(sev, sev)})::{msg}")
    blocking.append((names.get(sev, sev), v["rule"], path, line, msg))

if blocking:
    report = (f"## Gate 3a blocked this pull request: {len(blocking)} violation(s) at severity {threshold} or higher\n\n"
              "| Severity | Rule | File | Line | Message |\n|---|---|---|---|---|\n")
    for sev, rule, path, line, msg in blocking:
        report += f"| {sev} | {rule} | `{path}` | {line} | {msg.replace('|', '/')} |\n"
    report += "\nEach violation is also annotated on its line in the **Files changed** tab.\n"
else:
    report = f"## Gate 3a passed: no violation at severity {threshold} or higher\n"

# Job summary (Checks page) and a file the next step posts as a pull request comment.
for target in (os.environ.get("GITHUB_STEP_SUMMARY"), "gate3a-report.md"):
    if target:
        with open(target, "a", encoding="utf-8") as out:
            out.write(report)

print(f"Gate 3a: {len(blocking)} blocking violation(s), {len(violations)} in total.")
sys.exit(1 if blocking else 0)
