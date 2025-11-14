---
name: test-runner
description: MANDATORY skill for running tests and lint after EVERY code change. If you modify code, you MUST use this skill to verify it works.
allowed-tools:
  - Bash
  - BashOutput
  - Grep
---

# Test Runner - MANDATORY WORKFLOW

╔══════════════════════════════════════════════════════════════════════════╗
║  🚨 BANNED PHRASE: "All tests pass"                                     ║
║                                                                          ║
║  You CANNOT say "all tests pass" unless you:                            ║
║  1. Run `.claude/skills/test-runner/scripts/run_tests_parallel.sh`     ║
║  2. Check ALL log files (mocked + e2e-live + smoke)                     ║
║  3. Verify ZERO failures across all suites                              ║
║                                                                          ║
║  `just test-all-mocked` = "quick tests pass" (NOT "all tests pass")    ║
╚══════════════════════════════════════════════════════════════════════════╝

## 🔥 CRITICAL: This Skill Is Not Optional

**After EVERY code change, you MUST follow this workflow.**

No exceptions. No shortcuts. No "it's a small change" excuses.

## ⚠️ FUNDAMENTAL HYGIENE: Only Commit Code That Passes Tests

**CRITICAL WORKFLOW PRINCIPLE:**

We only commit code that passes tests. This means:

**If tests fail after your changes → YOUR changes broke them (until proven otherwise)**

### The Stash/Pop Verification Protocol

**NEVER claim test failures are "unrelated" or "pre-existing" without proof.**

**To verify a failure is truly unrelated:**
```bash
# 1. Remove your changes temporarily
git stash

# 2. Run the failing test suite
just test-all-mocked         # Or whichever suite failed

# 3. Observe the result:
# - If tests PASS → YOUR changes broke them (fix your code)
# - If tests FAIL → pre-existing issue (rare on main/merge base)

# 4. Restore your changes
git stash pop
```

**Why This Matters:**
- Tests on `main` branch ALWAYS pass (CI enforces this)
- Tests at your merge base ALWAYS pass (they passed to get into main)
- Therefore: test failures after your changes = your changes broke them
- The stash/pop protocol is the ONLY way to prove otherwise

**DO NOT:**
- ❌ Assume failures are unrelated
- ❌ Say "that test was already broken"
- ❌ Claim "it's just a flaky test" without verification
- ❌ Skip investigation because "it's not my area"

**ALWAYS:**
- ✅ Stash changes first
- ✅ Verify tests pass without your changes
- ✅ Only then claim pre-existing issue (if true)
- ✅ Otherwise: fix your code

## ⚠️ Always Use `just` Commands

**Direct `pytest` is removed from blocklist** - but ALWAYS prefer `just` commands which handle Docker, migrations, and environment setup.

Pass pytest args in quotes: `just test-unit "path/to/test.py::test_name -vv"`

## MANDATORY WORKFLOW: Every Code Change

**After making ANY code change:**

### Step 0: ALWAYS Run Ruff First (Code Formatting)
```bash
cd api && just ruff
```

**YOU MUST:**
- ✅ Run this command and see the output
- ✅ Verify it passes or auto-fixes issues
- ✅ If failures occur: Fix them IMMEDIATELY before continuing
- ✅ This checks code style and formatting

**NEVER skip ruff** - it catches formatting issues before they become lint failures.

### Step 1: ALWAYS Run Lint (Type Checking)
```bash
cd api && just lint
```

**YOU MUST:**
- ✅ Run this command and see the output
- ✅ Verify output shows "All checks passed!" or similar success message
- ✅ If failures occur: Fix them IMMEDIATELY before continuing
- ✅ NEVER skip this step, even for "tiny" changes

**NEVER say "linting passed" unless you:**
- Actually ran the command
- Saw the actual output
- Confirmed it shows success

### Step 2: ALWAYS Run Quick Tests (Development Cycle)
```bash
cd api && just test-all-mocked
```

**⚠️ CRITICAL: This is NOT all tests! This is for rapid development iteration.**

**YOU MUST:**
- ✅ Run this command and see the output
- ✅ Verify output shows "X passed in Y.Ys" or similar success message
- ✅ If failures occur: Fix them IMMEDIATELY before continuing
- ✅ Read the actual test output - don't assume

**This runs ONLY:**
- Unit tests (SQLite + FakeRedis)
- Integration tests (SQLite + FakeRedis)
- E2E mocked tests (PostgreSQL + Redis + mock APIs)

**This DOES NOT run:**
- ❌ E2E live tests (real OpenAI/Langfuse APIs)
- ❌ Smoke tests (full Docker stack)

**Takes ~20 seconds. Use for rapid iteration.**

### Step 3: ALWAYS Run ALL Tests Before Saying "All Tests Pass"
```bash
.claude/skills/test-runner/scripts/run_tests_parallel.sh
```

**🚨 CRITICAL: You can NEVER say "all tests pass" or "tests are passing" without running THIS command.**

**This command runs EVERYTHING:**
- ✅ All mocked tests (unit + integration + e2e_mocked)
- ✅ E2E live tests (real OpenAI/Langfuse APIs)
- ✅ Smoke tests (full Docker stack)

**After running, CHECK THE RESULTS:**
```bash
# Check for any failures
grep -E "failed|ERROR|FAILED" api/tmp/test-logs/test-mocked_*.log
grep -E "failed|ERROR|FAILED" api/tmp/test-logs/test-e2e-live_*.log
grep -E "failed|ERROR|FAILED" api/tmp/test-logs/test-smoke_*.log

# View summary
for log in api/tmp/test-logs/test-*_*.log; do
  echo "=== $(basename $log) ==="
  grep -E "passed|failed" "$log" | tail -1
done
```

**Takes ~5 minutes. MANDATORY before saying "all tests pass".**

## Primary Commands (Reference)

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

## 🚨 VIOLATIONS: What NOT To Do

**These are VIOLATIONS of this skill:**

❌ **CRITICAL: Claiming test failures are "unrelated" to your changes**
- WRONG: "The smoke test failure is unrelated to our changes"
- WRONG: "That test was already failing"
- WRONG: "This failure is just a flaky test"
- RIGHT: **Stash your changes, run tests, verify they pass WITHOUT your changes**

**FUNDAMENTAL RULE: Tests ALWAYS pass on main/merge base. If a test fails after your changes, YOUR changes broke it.**

**To verify a failure is truly unrelated:**
```bash
git stash                    # Remove your changes
just test-all-mocked         # Or whichever suite is failing
# If tests PASS → your changes broke them
# If tests FAIL → pre-existing issue (rare!)
git stash pop                # Restore your changes
```

**NEVER assume. ALWAYS verify with stash/pop.**

❌ **CRITICAL: Saying "all tests pass" without running the full suite**
- WRONG: "I ran `just test-all-mocked`, all tests pass"
- WRONG: "Tests are passing" (after only running mocked tests)
- WRONG: "All tests pass" (without running the parallel script)
- RIGHT: *Runs `.claude/skills/test-runner/scripts/run_tests_parallel.sh`* → *Checks all logs* → "All tests pass"

**The phrase "all tests" requires THE FULL SUITE.**
- `just test-all-mocked` = "quick tests pass" or "mocked tests pass"
- Parallel script = "all tests pass"

❌ **Skipping ruff formatting**
- WRONG: "Lint passed, so formatting is fine"
- RIGHT: *Runs `just ruff` FIRST, before lint*

❌ **Saying "tests passed" without running them**
- WRONG: "I fixed the bug, tests should pass"
- RIGHT: *Runs `just test-all-mocked` and shows output*

❌ **Skipping linting "because it's a small change"**
- WRONG: "It's just 3 lines, lint isn't needed"
- RIGHT: *Runs `just lint` ALWAYS, regardless of change size*

❌ **Assuming tests pass without verification**
- WRONG: "The change is simple, tests will pass"
- RIGHT: *Runs tests and confirms actual output shows success*

❌ **Not reading the actual test output**
- WRONG: "Command completed, so tests passed"
- RIGHT: *Reads output, sees "15 passed in 18.2s"*

❌ **Batching multiple changes before testing**
- WRONG: *Makes 5 changes, then tests once*
- RIGHT: *Make change → test → make change → test*

## ⚡ When to Use This Skill

**ALWAYS. Use this skill:**
- After EVERY code modification
- After ANY file edit
- After fixing ANY bug
- After adding ANY feature
- After refactoring ANYTHING

**The only acceptable time to skip this skill:**
- Never. There is no acceptable time.

## Development Workflow

### Simple Changes (Quick Iteration)
1. Make change
2. Run `just ruff` (formatting)
3. Run `just lint` (type checking)
4. Run `just test-all-mocked` (quick tests)
5. **DONE for iteration** (but cannot say "all tests pass" yet)

### Before Marking Task Complete
1. Run `.claude/skills/test-runner/scripts/run_tests_parallel.sh`
2. Check all logs for failures
3. **ONLY NOW** can you say "all tests pass"

### Complex Changes (Multiple Files/Features)
1. Make a logical change
2. **Stage it:** `git add <files>`
3. Run `just ruff`
4. Run `just lint`
5. Run `just test-all-mocked`
6. Repeat steps 1-5 for each logical chunk
7. **At the end, MANDATORY:** Run `.claude/skills/test-runner/scripts/run_tests_parallel.sh`
8. Check all logs
9. **ONLY NOW** can you say "all tests pass"

This workflow ensures you catch issues early and don't accumulate breaking changes.

**Remember:**
- **Quick iteration:** ruff → lint → test-all-mocked (Steps 0-2)
- **Task complete:** Run parallel script, check logs (Step 3)
- **Never say "all tests pass" without Step 3**

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

- **ALWAYS:** Run `just ruff` → `just lint` → `just test-all-mocked` after every code change
- User asks to run tests
- Validating code changes
- After modifying code
- Debugging test failures

**Every change (Steps 0-2):**
- Run `just ruff` (formatting)
- Run `just lint` (type checking)
- Run `just test-all-mocked` (quick tests)

**Before saying "all tests pass" (Step 3):**
- Run `.claude/skills/test-runner/scripts/run_tests_parallel.sh`
- Check all logs for failures
- Verify ALL suites passed

**Terminology:**
- "Quick tests pass" = `just test-all-mocked` passed
- "Mocked tests pass" = `just test-all-mocked` passed
- "All tests pass" = parallel script passed (ONLY after running it)

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
# 🔥 Step 0: ALWAYS run ruff first (formatting)
cd api && just ruff

# 🔥 Step 1: ALWAYS run lint (type checking)
cd api && just lint

# 🔥 Step 2: ALWAYS run quick tests (development)
cd api && just test-all-mocked
# ^ This is NOT "all tests" - only say "quick tests pass" or "mocked tests pass"

# 🔥 Step 3: Run ALL tests before saying "all tests pass" (MANDATORY before task complete)
.claude/skills/test-runner/scripts/run_tests_parallel.sh

# Check results (MUST do this before saying "all tests pass")
grep -E "failed|ERROR|FAILED" api/tmp/test-logs/test-mocked_*.log
grep -E "failed|ERROR|FAILED" api/tmp/test-logs/test-e2e-live_*.log
grep -E "failed|ERROR|FAILED" api/tmp/test-logs/test-smoke_*.log

# View summary
for log in api/tmp/test-logs/test-*_*.log; do
  echo "=== $(basename $log) ==="
  grep -E "passed|failed" "$log" | tail -1
done

# Monitor parallel tests while running
tail -f api/tmp/test-logs/test-*.log

# 🚨 REMEMBER:
# - Steps 0-2 = quick iteration (DO NOT say "all tests pass")
# - Step 3 = full validation (ONLY NOW can say "all tests pass")
```
