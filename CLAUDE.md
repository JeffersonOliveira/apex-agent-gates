# Project rules for any Apex code (read this in every session)

## Mandatory
1. Every SOQL query uses WITH USER_MODE, or Database.queryWithBinds(..., AccessLevel.USER_MODE).
2. Every DML uses `as user` or Database.<op>(records, AccessLevel.USER_MODE). SYSTEM_MODE only with a written justification in a comment starting with `// gates:allow-system-mode:`.
3. Every class declares `with sharing` unless the justification comment above is present.
4. No SOQL, DML or callout inside a loop. Design for 200 records per transaction.
5. Credentials only in Named Credentials. Never in code or metadata.
6. Every test proves behavior with asserts. Coverage is not a goal.
7. Code that reads or writes sensitive data has a test with System.runAs on a restricted persona (see TestPersonas).
8. Before saying you are done: run `sf code-analyzer run` and the tests on the lab org, and report the results.

## Never
- Deploy to any org whose alias contains prod, production or uat.
- Run `sf org delete`, `git push --force`, `rm -rf` or any destructive command.
- Store or print real customer data.

## How to work here
- One branch per task. Commit with a message that names the task (T1..T6).
- The lab org alias is `lab`. Use `--target-org lab`.
