#!/bin/bash
# Mock CI Runner
# Usage: ./run_ci.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

mkdir -p logs

# ─── Job definitions ──────────────────────────────────────────────────────────

job_lint() {
    if ! python3 -m mypy router.py auth.py --ignore-missing-imports 2>&1; then
        return 1
    fi
    echo "mypy: no type errors found."
}

job_unit_tests() {
    python3 -m py_compile tests/test_syntax_error.py 2>&1 || {
        echo "SyntaxError: tests/test_syntax_error.py has a syntax error."
        echo ""
        echo "  File \"tests/test_syntax_error.py\""
        echo "  SyntaxError: expected ':' after function definition"
        echo ""
        echo "Run: python3 -m py_compile tests/test_syntax_error.py"
        echo "to see the exact line."
        return 1
    }
    echo "All unit tests compiled and passed."
}

job_bedrock_tests() {
    if grep -qE '"bedrock/anthropic\.claude-v1"' tests/test_bedrock.py 2>/dev/null; then
        echo "ValidationException: The model ID 'anthropic.claude-v1' has been deprecated."
        echo "AWS Bedrock no longer serves responses for this model."
        echo ""
        echo "  tests/test_bedrock.py:"
        echo "    BEDROCK_MODEL = \"bedrock/anthropic.claude-v1\""
        echo "                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
        echo "                    Deprecated since 2025-01-01 (see models.json)"
        echo ""
        python3 - << 'PYEOF'
import json
with open("models.json") as f:
    data = json.load(f)
deprecated = [m for m in data["models"] if m.get("deprecated")]
active     = [m for m in data["models"] if not m.get("deprecated")]
print("  From models.json — deprecated models:")
for m in deprecated:
    print(f"    ✗  {m['model_id']:<45}  deprecated {m['deprecation_date']}  →  use {m['replacement']}")
print()
print("  Available replacements (not deprecated):")
for m in active[:5]:
    print(f"    ✓  {m['model_id']:<45}  ${m['input_cost_per_1k_tokens']}/1k in  ${m['output_cost_per_1k_tokens']}/1k out  (until {m['deprecation_date']})")
if len(active) > 5:
    print(f"       ... and {len(active)-5} more — see models.json for full list")
PYEOF
        echo ""
        echo "Fix: update BEDROCK_MODEL to a non-deprecated model ID and re-run."
        return 1
    fi

    echo "Bedrock tests passed."
}

job_regression_tests() {
    # Check max_retries is 3 in router.py
    if ! grep -qE "max_retries.*:.*int.*=.*3|max_retries=3" router.py 2>/dev/null; then
        echo "FAILED tests/test_router.py::test_default_max_retries"
        echo ""
        echo "  AssertionError: expected 3 fallback attempts, got 1"
        echo "  at tests/test_router.py, test_default_max_retries"
        echo ""
        echo "A recent commit changed the default max_retries value in router.py."
        echo ""
        echo "Suggested approach:"
        echo "  1. git log --oneline          # review commit history"
        echo "  2. git bisect start"
        echo "  3. git bisect bad             # current HEAD is broken"
        echo "  4. git bisect good <sha>      # pick a known-good earlier commit"
        echo "  5. git bisect reset           # once you've found the bad commit"
        echo "  6. git revert <bad-commit-sha>"
        return 1
    fi

    # Enforce that a revert commit exists — no direct edits without traceability
    if ! git log --oneline 2>/dev/null | grep -qi "revert"; then
        echo "FAIL: router.py looks correct, but no revert commit found."
        echo ""
        echo "Please use 'git revert <sha>' to undo the bad commit properly."
        echo "Directly editing the file without a revert commit means the bad"
        echo "commit still exists in history — anyone can re-introduce it."
        return 1
    fi

    echo "Regression tests passed."
}

job_security_scan() {
    python3 check_security.py .circleci/config.yml 2>&1
}

job_docker_lint() {
    if grep -qE "^FROM python:3\.[0-8]" Dockerfile 2>/dev/null; then
        local tag
        tag=$(grep -E "^FROM python:" Dockerfile | head -1 | sed 's/FROM python://' | awk '{print $1}')
        echo "FAIL: Dockerfile uses python:${tag}"
        echo ""
        echo "  Dockerfile:"
        echo "    FROM python:${tag}"
        echo ""
        echo "  Python 3.8 reached end-of-life on 2024-10-07."
        echo "  EOL images no longer receive security patches."
        echo ""
        echo "  Docs: https://devguide.python.org/versions/"
        return 1
    fi
    echo "Docker base image OK."
}

job_dependency_audit() {
    if grep -qE "requests==2\.(18|19|20|21|22|23|24|25|26|27|28|29|30)\." requirements.txt 2>/dev/null || \
       grep -qE "requests==2\.18\.0" requirements.txt 2>/dev/null; then
        local ver
        ver=$(grep "requests==" requirements.txt | tr -d ' ')
        echo "FAIL: vulnerable dependency detected"
        echo ""
        echo "  requirements.txt:"
        echo "    ${ver}"
        echo ""
        echo "  CVE-2023-32681: requests<2.31.0 leaks the Proxy-Authorization header"
        echo "  to the destination server when following a redirect to a different host."
        echo ""
        echo "  Docs: https://github.com/advisories/GHSA-j8r2-6x86-q33q"
        return 1
    fi
    echo "No known vulnerabilities found."
}

# ─── Runner ───────────────────────────────────────────────────────────────────

run_job() {
    local name=$1
    local func="job_${name}"

    printf "  %-22s" "$name"

    local output
    local exit_code
    output=$($func 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf "${GREEN}✓ pass${NC}\n"
        PASS_COUNT=$((PASS_COUNT + 1))
        rm -f "logs/${name}.log"
    else
        printf "${RED}✗ fail${NC}  → logs/${name}.log\n"
        printf '%s\n' "$output" > "logs/${name}.log"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ─── Header ───────────────────────────────────────────────────────────────────

COMMIT_COUNT=$(git log --oneline 2>/dev/null | wc -l | tr -d ' ')
BRANCH=$(git branch --show-current 2>/dev/null || echo "HEAD")

echo ""
echo -e "${BOLD}  CI Pipeline${NC}  ${DIM}(${COMMIT_COUNT} commits · ${BRANCH})${NC}"
echo "  ──────────────────────────────────────"

run_job lint
run_job unit_tests
run_job bedrock_tests
run_job security_scan
run_job docker_lint
run_job dependency_audit
run_job regression_tests

echo "  ──────────────────────────────────────"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}All ${PASS_COUNT} jobs passing.${NC} Pipeline is green."
elif [ "$PASS_COUNT" -eq 0 ]; then
    echo -e "  ${RED}${BOLD}${FAIL_COUNT} jobs failing.${NC}  Fix one, then re-run ./run_ci.sh"
else
    echo -e "  ${GREEN}${PASS_COUNT} passing${NC} · ${RED}${FAIL_COUNT} failing${NC}  — re-run ./run_ci.sh after each fix"
fi

echo ""
