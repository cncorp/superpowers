---
name: test-runner
description: Run tests and lint. ALWAYS - just lint. FREQUENT - just test-all-mocked (~20s). COMPLEX changes - stage, lint, test each chunk, then run parallel script at end.
allowed-tools:
  - Bash
  - BashOutput
  - Grep
---

# Test Runner

Run pytest tests using project's test commands.

## ⚠️ Always Use `just` Commands

**`pytest` is blocked** - use `just` commands which handle Docker, migrations, and environment setup.

Pass pytest args in quotes: `just test-unit "path/to/test.py::test_name -vv"`

## Primary Commands

### Frequent: Mocked Tests (~20s)
```bash
cd api && just test-all-mocked
```
Runs unit + integration + e2e_mocked in parallel. No real APIs. Use frequently during development.

### Exhaustive: All Suites in Parallel (~5 mins)
```bash
.claude/skills/test-runner/scripts/run_tests_parallel.sh
```
Runs ALL suites in background (mocked, e2e-live, smoke). Logs to `api/tmp/test-logs/`.

**Check results after completion:**
```bash
# Check for failures
grep -E "failed|ERROR|FAILED" api/tmp/test-logs/test-mocked_*.log | tail -20
grep -E "failed|ERROR|FAILED" api/tmp/test-logs/test-e2e-live_*.log | tail -20
grep -E "failed|ERROR|FAILED" api/tmp/test-logs/test-smoke_*.log | tail -20

# Summary
for log in api/tmp/test-logs/test-*_*.log; do
  echo "=== $(basename $log) ==="
  grep -E "passed|failed" "$log" | tail -1
done
```

## CRITICAL: Always Run Lint

**Every change MUST pass linting:**
```bash
cd api && just lint
```

Run this before considering any change complete. Linting failures = incomplete work.

## Development Workflow

### Simple Changes
1. Make change
2. Run `just lint`
3. Run `just test-all-mocked`
4. Done

### Complex Changes (Multiple Files/Features)
1. Make a logical change
2. **Stage it:** `git add <files>`
3. Run `just lint`
4. Run `just test-all-mocked`
5. Repeat steps 1-4 for each logical chunk
6. **At the end:** Run `.claude/skills/test-runner/scripts/run_tests_parallel.sh`

This workflow ensures you catch issues early and don't accumulate breaking changes.

## Individual Test Suites

```bash
# Unit tests (SQLite, FakeRedis) - fastest, run most frequently
cd api && just test-unit

# Integration tests (SQLite, FakeRedis)
cd api && just test-integration

# E2E mocked (PostgreSQL, Redis, mock APIs)
cd api && just test-e2e

# E2E live (real OpenAI/Langfuse)
cd api && just test-e2e-live

# Smoke tests (full stack with Docker)
cd api && just test-smoke
```

## Running Specific Tests

```bash
# Specific test: just test-unit "path/to/test.py::test_name -vv"
# Keyword filter: just test-unit "-k test_message"
# With markers: just test-e2e "-m 'not slow'"
```

## When to Use

- **ALWAYS:** Run `just lint` after every code change
- User asks to run tests
- Validating code changes
- After modifying code
- Debugging test failures

**Every change:** Run `just lint` (non-negotiable)
**Frequent development:** Run `just test-all-mocked`
**Complex changes:** Stage chunks, lint + test each, then run parallel script
**After all changes complete:** Run `.claude/skills/test-runner/scripts/run_tests_parallel.sh`

## Interpreting Results

**Success:** `====== X passed in Y.Ys ======`
**Failure:** `FAILED tests/path/test.py::test_name - AssertionError`

## Troubleshooting

```bash
# Smoke test failures - check Docker logs
docker compose logs --since 15m | grep -iE -B 10 -A 10 "error|fail|exception"

# Kill hung tests
pkill -f pytest

# Docker not running (smoke tests)
docker compose up -d
```

## Quick Reference

```bash
# 🔥 ALWAYS run lint (every change)
cd api && just lint

# 🔥 Frequent development
cd api && just test-all-mocked

# 🔥 Complex changes workflow
# 1. Make change → 2. Stage → 3. Lint → 4. Test → 5. Repeat
git add <files>
cd api && just lint
cd api && just test-all-mocked

# 🔥 After all complex changes complete
.claude/skills/test-runner/scripts/run_tests_parallel.sh
grep -E "failed|ERROR" api/tmp/test-logs/*.log

# Monitor parallel tests
tail -f api/tmp/test-logs/test-*.log
```
