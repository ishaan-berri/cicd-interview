# Hint: security_scan

Read `logs/security_scan.log` — it explains both issues clearly.

The core problem: two jobs both have the `pypi-publish` context in
`.circleci/config.yml`, but only one of them actually needs `PYPI_TOKEN`.

Key questions to answer:
1. Which job needs to publish to PyPI? (only that one should have the context)
2. Should the publish job run on every branch, or only on `main`?

Once you've reasoned through those two questions, the fix in `.circleci/config.yml`
should be clear. Look at how `context` and `filters` are structured under each
job in the `workflows` section.
