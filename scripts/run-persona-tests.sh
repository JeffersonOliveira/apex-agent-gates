#!/usr/bin/env bash
# Runs the two lab test classes that prove behavior (T1/T3 persona test and T2 volume test) on the lab org.
# Usage: scripts/run-persona-tests.sh   (uses the default org; set one with: sf config set target-org lab)
set -euo pipefail

sf apex run test --tests CaseNoteSummaryServiceSafe_Test --tests OpportunityLineTotals_Test --result-format human --code-coverage --wait 10
