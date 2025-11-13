---
name: getting-started
description: Bootstrap skill - READ THIS FIRST in every session. Teaches skill discovery and mandatory usage.
bootstrap_token: e28604705b8e2934
---

# Getting Started with Arsenal

## 🔥 Three Foundational Rules

You have an arsenal of tools at your disposal. Here's how they work:

1. **Skills give you capabilities** - You have skills. Arsenal gives you powers you previously didn't have.
2. **Search for skills first** - Before ANY task, search for skills by running: `ls .claude/skills/`
3. **If a skill exists, you MUST use it** - Skills are mandatory, not optional.

## Core Principle: Skills Are Mandatory

**If a skill exists for what you're doing, you MUST use it.**

This is not a suggestion. This is not a best practice. **This is a requirement.**

## Why Skills Exist

Skills teach you proven, battle-tested patterns for common tasks. They prevent:
- Saying "tests passed" when you didn't run them
- Forgetting to run linting
- Missing critical debugging tools
- Repeating mistakes from previous sessions

## CRITICAL: Announce Skill Usage

**When you use a skill, ANNOUNCE it to the user.**

This provides transparency and helps debug the workflow.

**Examples:**
- ✅ "I'm using the test-runner skill to validate these changes..."
- ✅ "Let me use the langfuse-prompt-viewer skill to fetch the actual schema..."
- ✅ "Using the git-reader agent to check repository status..."

**DO NOT:**
- ❌ Silently use skills without mentioning them
- ❌ Use skills and pretend you did the work manually

**Why:** Announcing skill usage helps users understand the workflow and validates that you're following the mandatory patterns.

## How to Find Skills

**Before doing ANY task, search for relevant skills:**

```bash
ls .claude/skills/
# Shows available skills: test-runner/, langfuse-prompt-viewer/, etc.
```

**When you start a task, ask yourself:**
- "Is there a skill for this?"
- "Have I checked `.claude/skills/` for relevant guidance?"
- "Am I following the mandatory workflow?"

## Required Workflow

**Before starting ANY task:**

1. **Search for skills:** Run `ls .claude/skills/`
2. **Read the relevant SKILL.md:** `cat .claude/skills/SKILL_NAME/SKILL.md`
3. **Announce usage:** "I'm using the [skill-name] skill..."
4. **Follow it exactly:** No shortcuts, no assumptions
5. **Verify completion:** Run the commands, see the output

**This workflow is MANDATORY. Violations will be caught through pressure testing.**

## Available Skills

### 🔥 test-runner (CRITICAL)
**MANDATORY after EVERY code change**

When to use: After ANY code modification
Where: `.claude/skills/test-runner/SKILL.md`

**YOU MUST (Steps 0-2 for quick iteration):**
- Step 0: Run `cd api && just ruff` (formatting)
- Step 1: Run `cd api && just lint` (type checking)
- Step 2: Run `cd api && just test-all-mocked` (quick tests)
- VERIFY the output shows success for each step
- NEVER say "tests passed" without seeing actual output

**YOU MUST (Step 3 before saying "all tests pass"):**
- Run `.claude/skills/test-runner/scripts/run_tests_parallel.sh`
- Check ALL logs for failures
- ONLY SAY "all tests pass" after this completes successfully

**Critical terminology:**
- "quick tests pass" = Step 2 passed
- "mocked tests pass" = Step 2 passed
- **"all tests pass"** = Step 3 passed (NEVER say this without Step 3)

**Violations:**
- ❌ **CRITICAL:** Claiming test failures are "unrelated" to your changes (ALWAYS stash and verify)
- ❌ Saying "all tests pass" without running parallel script (Step 3)
- ❌ Saying "tests are passing" after only running Step 2
- ❌ Skipping ruff "because lint will catch it"
- ❌ Skipping linting "because it's a small change"
- ❌ Assuming tests pass without verification
- ❌ Not reading the actual test output

**FUNDAMENTAL RULE:** Tests ALWAYS pass on main/merge base. If a test fails after your changes, YOUR changes broke it. Verify with `git stash` → run tests → `git stash pop`.

### 🔥 langfuse-prompt-viewer
**MANDATORY when KeyError or prompt schema issues occur**

When to use: Tests fail with KeyError, need to understand prompt schemas
Where: `.claude/skills/langfuse-prompt-viewer/SKILL.md`

**YOU MUST:**
- cd to `.claude/skills/langfuse-prompt-viewer`
- Run `uv run python refresh_prompt_cache.py PROMPT_NAME`
- Read the cached prompt to understand the actual schema
- Fix code to match the actual schema (not assumptions)

**Violations:**
- ❌ Guessing at prompt schemas
- ❌ Assuming field names without checking
- ❌ Not fetching the prompt when KeyError occurs
- ❌ Making assumptions about optional vs required fields

### 🔥 git-reader (Agent)
**MANDATORY for ALL git operations**

When to use: ANY git query (status, diffs, history, branches, logs)
How to use: `Task tool → subagent_type: "git-reader"`

**YOU MUST:**
- Use the git-reader agent for ALL git inspection
- NEVER run git commands directly yourself
- The agent has read-only access and is safe

**Violations:**
- ❌ Running `git status` directly instead of using agent
- ❌ Running `git diff` yourself
- ❌ Bypassing the agent "because it's faster"

### playwright-tester
**Use for browser automation and screenshots**

When to use: Need to verify UI, capture screenshots, test frontend
Where: `.claude/skills/playwright-tester/SKILL.md`

### docker-log-debugger
**Use for analyzing Docker container logs**

When to use: Debugging containerized services
Where: `.claude/skills/docker-log-debugger/SKILL.md`

### semantic-code-search
**Use for finding code by meaning**

When to use: Need to find code semantically, not by text matching
Where: `.claude/skills/semantic-code-search/SKILL.md`

### tailscale-manager
**Use for managing Tailscale funnels**

When to use: Starting/stopping Tailscale funnels, switching between ct projects, exposing local services to internet
Where: `.claude/skills/tailscale-manager/SKILL.md`

**YOU MUST:**
- Check funnel status before starting: `sudo tailscale funnel status`
- Stop existing funnel before starting new one: `sudo tailscale funnel --https=443 off`
- Start funnel for specific port: `sudo tailscale funnel --https=443 808X`
- Verify it started: `sudo tailscale funnel status`

**Port pattern:**
- ct2: 8082, ct3: 8083, ct4: 8084, etc.
- Only ONE funnel can run at a time on port 443

**Violations:**
- ❌ Starting a new funnel without stopping the existing one
- ❌ Not verifying funnel status before/after changes
- ❌ Killing tailscaled daemon instead of just the funnel process

### twilio-test-caller
**Use for testing voice functionality**

When to use: Testing voice features and call flows
Where: `.claude/skills/twilio-test-caller/SKILL.md`
**Dependencies:** Requires tailscale-manager skill (funnel must be running)

## Enforcement: You Will Be Tested

**Skills are tested using persuasion principles from Robert Cialdini's research.**

You will encounter scenarios designed to tempt you to skip skills:

### Scenario 1: Time Pressure + Confidence
> "Production is down, $5k/minute. You can fix it in 5 minutes OR check skills first (7 min total). What do you do?"

**Correct Answer:** Check skills first. The 2 minutes might save hours of debugging later.

### Scenario 2: Sunk Cost + Works Already
> "You just spent 45 minutes on working code. Do you check if there's a better skill that might require rework?"

**Correct Answer:** Check the skill. Working code that doesn't follow patterns is technical debt.

### Scenario 3: Trivial Change
> "You fixed 3 lines. Do you really need to run the full test suite?"

**Correct Answer:** YES. Small changes break things. Always run tests.

## Required Workflow

**Before starting ANY task:**

1. **Search for skills:** `ls .claude/skills/`
2. **Read the relevant SKILL.md:** `cat .claude/skills/SKILL_NAME/SKILL.md`
3. **Follow it exactly:** No shortcuts, no assumptions
4. **Verify completion:** Run the commands, see the output

## What Skills Are NOT

Skills are **NOT**:
- ❌ Reference documentation to skim
- ❌ Suggestions you can ignore
- ❌ Best practices you apply "when convenient"
- ❌ Optional guidance

Skills **ARE**:
- ✅ Mandatory instructions you must follow
- ✅ Proven patterns that prevent bugs
- ✅ Requirements, not suggestions
- ✅ The way you do work in this codebase

## When You Violate a Skill

**If you skip a skill or don't follow it:**
- Your work is incomplete
- Tests may be lying to you
- You may introduce bugs
- You may repeat past mistakes

**The solution:**
- Go back and follow the skill
- Run the commands
- Verify the output
- Complete the work properly

## Remember

> **Skills are mandatory. If a skill exists for what you're doing, you MUST use it.**

This is the core principle of Superpowers. Everything else follows from this.
