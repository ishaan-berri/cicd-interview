# CI/CD Engineering Interview Exercise

You're the new CI/CD owner. The pipeline is broken. Your job: get it all green.

## Setup

```bash
pip install pyyaml pytest
./run_ci.sh
```

## How it works

Run `./run_ci.sh` to see which jobs are passing and which are failing.

For failing jobs, read `logs/<job_name>.log` to understand what went wrong.

Fix the issue, re-run `./run_ci.sh`. Repeat until all green.

## Ground rules

- **Fix root causes, not symptoms.** Don't delete tests or comment out checks to get green.
- **Use `git revert` to undo bad commits**, not `git reset --hard`. We don't rewrite shared history.
- You can look things up — that's fine. The goal is to show your reasoning.

## Jobs

| Job | What it checks |
|-----|----------------|
| `lint` | Core modules have no syntax errors |
| `unit_tests` | All test files compile and run |
| `bedrock_tests` | Bedrock tests pass and are resilient to future deprecations |
| `regression_tests` | Core routing logic works correctly |
| `security_scan` | CI config doesn't expose secrets to untrusted fork PRs |

## Hints

Stuck? `hints/task<N>_hint.md` has a nudge. Try to avoid them — but they're there if you need them.
