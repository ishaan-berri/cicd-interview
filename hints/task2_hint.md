# Hint: bedrock_tests

There are three parts to this fix. After each fix, re-run `./run_ci.sh` to see what's next.

**Part A — Quick fix**

The model ID in `tests/test_bedrock.py` references a deprecated model.
Update it to `anthropic.claude-v2`.

**Part B — Resilience**

After Part A passes, you'll see a new failure from `check_resilience.py`.
Read the error message — it explains what's expected and why.

The goal: if Bedrock deprecates a model again tomorrow, you should only need to
change one line in `.circleci/config.yml`. No test files should need updating.

**Part C — Wire it up**

After Part B, there's one more thing: the variable you're using in tests needs
to be defined in `.circleci/config.yml` for CI to know what value to use.
