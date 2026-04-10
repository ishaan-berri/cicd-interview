#!/bin/bash
# Creates the git commit history for the CI/CD interview exercise.
# Run ONCE from the repo root. Do not run again — it will fail (repo already exists).
#
# Usage: bash build_history.sh

set -e

if [ -d ".git" ]; then
    echo "ERROR: .git already exists. build_history.sh should only be run once."
    exit 1
fi

GIT_AUTHOR_NAME="Ishaan Jaffer"
GIT_AUTHOR_EMAIL="ishaan@berri.ai"
GIT_COMMITTER_NAME="Ishaan Jaffer"
GIT_COMMITTER_EMAIL="ishaan@berri.ai"
export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

commit() {
    local msg=$1
    local date=$2
    GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" git commit -m "$msg"
}

git init
git checkout -b main

# ── Commit 1: Initial project structure ──────────────────────────────────────
# Include all the exercise infrastructure + auth module (no source bugs yet)

git add \
    README.md \
    requirements.txt \
    run_ci.sh \
    check_resilience.py \
    check_security.py \
    hints/ \
    auth.py \
    tests/__init__.py \
    tests/test_auth.py

commit "Initial commit: project structure and auth module" "2024-01-15T09:00:00"

# ── Commit 2: Add router — GOOD state (max_retries=3) ────────────────────────

# Write the GOOD version of router.py (not the broken current one)
cat > router.py << 'HEREDOC'
"""
Router for load balancing and fallback routing across model providers.
"""
from typing import List, Optional


class RouterConfig:
    def __init__(self, max_retries: int = 3, fallback_models: Optional[List[str]] = None):
        self.max_retries = max_retries
        self.fallback_models = fallback_models or []


class Router:
    """Routes requests to the best available model with automatic fallback."""

    def __init__(self, config: Optional[RouterConfig] = None):
        self.config = config or RouterConfig()

    @property
    def max_retries(self) -> int:
        return self.config.max_retries

    def route(self, model: str, prompt: str) -> dict:
        """Route a request, retrying up to max_retries times on failure."""
        last_error = None
        for attempt in range(self.max_retries):
            try:
                return self._call_model(model, prompt)
            except Exception as e:
                last_error = e
                if attempt < self.max_retries - 1:
                    model = self._get_fallback(model)
        raise RuntimeError(f"All {self.max_retries} attempts failed: {last_error}")

    def _call_model(self, model: str, prompt: str) -> dict:
        return {"model": model, "response": f"Mock response for: {prompt}"}

    def _get_fallback(self, model: str) -> str:
        if self.config.fallback_models:
            return self.config.fallback_models[0]
        return model
HEREDOC

git add router.py tests/test_router.py
commit "feat: add router with fallback logic (max_retries=3)" "2024-01-16T10:30:00"

# ── Commit 3: Add Bedrock tests (deprecated model) ───────────────────────────
git add tests/test_bedrock.py
commit "feat: add Bedrock model integration tests" "2024-01-18T14:00:00"

# ── Commit 4: Add CI config — SECURE version first ───────────────────────────
# Write a SECURE version of config.yml (no pypi-publish on pr_tests)

mkdir -p .circleci
cat > .circleci/config.yml << 'HEREDOC'
version: 2.1

# CONTEXT DEFINITIONS (configured in CircleCI UI):
#
#   pypi-publish — contains PYPI_TOKEN used to publish releases to PyPI

workflows:
  version: 2
  build-and-test:
    jobs:
      - lint
      - unit_tests
      - bedrock_tests
      - regression_tests
      - pr_tests
      - publish:
          requires:
            - pr_tests
          context:
            - pypi-publish
          filters:
            branches:
              only: main

jobs:
  lint:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Install and run linter
          command: pip install ruff && ruff check .

  unit_tests:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Install dependencies
          command: pip install -r requirements.txt
      - run:
          name: Run unit tests
          command: pytest tests/ -v --tb=short

  bedrock_tests:
    docker:
      - image: cimg/python:3.11
    environment:
      AWS_REGION: us-east-1
    steps:
      - checkout
      - run:
          name: Run Bedrock integration tests
          command: pytest tests/test_bedrock.py -v

  regression_tests:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Run regression tests
          command: pytest tests/test_router.py -v

  pr_tests:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Run PR validation tests
          command: pytest tests/ -v --ignore=tests/test_bedrock.py

  publish:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Build package
          command: pip install build && python -m build
      - run:
          name: Publish to PyPI
          command: pip install twine && twine upload dist/* --non-interactive
HEREDOC

git add .circleci/config.yml
commit "ci: add CircleCI pipeline configuration" "2024-01-19T11:00:00"

# ── Commit 5: THE BAD COMMIT — change max_retries to 1 ───────────────────────

python3 -c "
content = open('router.py').read()
content = content.replace('max_retries: int = 3', 'max_retries: int = 1')
open('router.py', 'w').write(content)
"

git add router.py
commit "refactor: router config cleanup" "2024-01-20T16:45:00"

# ── Commit 6: Update CI config — introduce security issue ────────────────────

cat > .circleci/config.yml << 'HEREDOC'
version: 2.1

# CONTEXT DEFINITIONS (configured in CircleCI UI):
#
#   pypi-publish — contains PYPI_TOKEN used to publish releases to PyPI
#
# SECURITY NOTE: Any job that references the 'pypi-publish' context will have
# access to PYPI_TOKEN at runtime. Be careful about which jobs have this context,
# especially jobs that run on pull_request events from forks.

workflows:
  version: 2
  build-and-test:
    jobs:
      - lint
      - unit_tests
      - bedrock_tests
      - regression_tests
      - pr_tests:
          context:
            - pypi-publish
      - publish:
          requires:
            - pr_tests
          context:
            - pypi-publish

jobs:
  lint:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Install and run linter
          command: pip install ruff && ruff check .

  unit_tests:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Install dependencies
          command: pip install -r requirements.txt
      - run:
          name: Run unit tests
          command: pytest tests/ -v --tb=short

  bedrock_tests:
    docker:
      - image: cimg/python:3.11
    environment:
      AWS_REGION: us-east-1
      # TODO: add BEDROCK_MODEL_ID here once tests are updated to use env vars
    steps:
      - checkout
      - run:
          name: Run Bedrock integration tests
          command: pytest tests/test_bedrock.py -v

  regression_tests:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Run regression tests
          command: pytest tests/test_router.py -v

  pr_tests:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Run PR validation tests
          command: pytest tests/ -v --ignore=tests/test_bedrock.py

  publish:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Build package
          command: pip install build && python -m build
      - run:
          name: Publish to PyPI
          command: pip install twine && twine upload dist/* --non-interactive
HEREDOC

git add .circleci/config.yml
commit "ci: add publishing workflow and PR validation" "2024-01-21T10:00:00"

# ── Commit 7: Add unit tests — with syntax error ──────────────────────────────
git add tests/test_syntax_error.py
commit "test: add additional unit test coverage" "2024-01-22T09:30:00"

# ── Commit 8: Update dependencies ────────────────────────────────────────────
echo "pytest>=7.0
pyyaml>=6.0
" > requirements.txt

git add requirements.txt
commit "chore: update dependencies" "2024-01-23T08:00:00"

echo ""
echo "Git history created. Run: git log --oneline"
echo ""
git log --oneline
