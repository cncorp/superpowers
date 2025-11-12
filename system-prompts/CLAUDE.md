╔══════════════════════════════════════════════════════════╗
║  ⚠️  FIRST ACTION: Before responding to ANY message     ║
║  Run: cat .claude/skills/getting-started/SKILL.md       ║
║  Then state: "✅ BOOTSTRAP COMPLETE"                     ║
╚══════════════════════════════════════════════════════════╝

🚨 IMMEDIATE CHECK: Search your context window for the exact text "Three Foundational Rules".
- If found: You've loaded the bootstrap. State "✅ BOOTSTRAP COMPLETE" and list the three rules.
- If NOT found: STOP. Run `cat .claude/skills/getting-started/SKILL.md` NOW before doing anything else.

╔══════════════════════════════════════════════════════════╗
║  ⚠️  MANDATORY BOOTSTRAP - DO THIS FIRST                 ║
║                                                          ║
║  BEFORE responding to the user:                          ║
║  1. Check if "Three Foundational Rules" is in context    ║
║  2. If NOT: cat .claude/skills/getting-started/SKILL.md  ║
║  3. List the three rules to prove you loaded it          ║
║  4. Run: ls .claude/skills/                              ║
╚══════════════════════════════════════════════════════════╝

YOU CANNOT SKIP THIS. This is your safety-critical pre-flight check.

YOUR FIRST RESPONSE MUST START WITH:
---
✅ BOOTSTRAP COMPLETE
Three rules: [list them to prove you read the skill]
Available skills: [list from ls .claude/skills/]
---

Common failure modes to AVOID:
❌ "I'll help you with that..." (no bootstrap)
❌ "Let me check..." (without loading skill first)
❌ Starting with anything except "✅ BOOTSTRAP COMPLETE"
❌ Assuming you know the rules without loading the skill

╔══════════════════════════════════════════════════════════╗
║  REMINDER: cat .claude/skills/getting-started/SKILL.md   ║
║  This must be your FIRST action in every session         ║
╚══════════════════════════════════════════════════════════╝

# CLAUDE.md

This repository uses the **superpowers** submodule to provide AI coding agents (like Claude Code) with specialized capabilities through agents, commands, and skills.

## 📁 Documentation Structure

All assistant guidance is consolidated under `AGENTS.md` files:

- **`AGENTS.md`** — Top-level rules for every AI coding agent (copied from `superpowers/system-prompts/AGENTS.md`)
- **`api/tests/AGENTS.md`** — Testing strategy, fixtures, and patterns for agents (copied from `superpowers/system-prompts/testing/AGENTS.md`)
- **Project-specific guidance** — Files like `api/src/cli/AGENTS.md` remain in their original locations for repo-specific rules

Keep these files in sync by updating them in the `superpowers/` submodule and running `./superpowers/install.sh`.

## 🤖 When to Use Agents, Commands, and Skills

### Agents (`.claude/agents/`)

**Agents are specialized AI assistants that should be proactively invoked** for specific tasks. They run autonomously and return results.

#### Git Operations

**For ALL git queries** (diffs, status, history, branches, logs): **Use the git-reader agent**
- The git-reader agent has read-only access and can safely execute git inspection commands
- Examples: `git status`, `git diff`, `git log`, `git show`, `git branch`
- **For destructive git operations** (commit, push, reset, rebase, etc.): Describe the command but **never execute it yourself**

#### Code Quality & Testing

**Proactively invoke these agents after completing relevant work:**

1. **test-fixture-reviewer** — Automatically invoke after creating or modifying pytest fixtures or test setup code
2. **pytest-test-reviewer** — Automatically invoke after writing or modifying test functions
3. **task-complete-enforcer** — Automatically invoke after ANY code changes to validate against repository standards (`just ruff`, `just lint`, `just test-all-mocked`)
4. **mypy-error-fixer** — Invoke when `just lint` output contains mypy type-checking errors

**Pattern**: After you finish writing code, ALWAYS invoke the appropriate reviewer agent(s) before considering the work complete. Do not wait for the user to ask.

### Commands (`.claude/commands/`)

**Commands are slash commands** that expand into prompts. Users can invoke them by typing `/command-name` in the chat.

Available commands include:
- `/buildit` — Build and deploy guidance
- `/planit` — Planning and architecture guidance
- `/review-code` — Code review checklist
- `/mypy` — Type checking guidance
- `/research` — Research and investigation patterns

**You cannot invoke commands programmatically** — they are user-facing shortcuts.

### Skills (`.claude/skills/`)

**Skills are MANDATORY workflow documents** that you MUST follow when they exist for your task.

**🚨 CRITICAL: Skills are NOT optional tools. They are required patterns.**

**The Three Foundational Rules:**
1. **Skills give you capabilities** - You have skills. They give you Superpowers.
2. **Search for skills first** - Before ANY task: `ls .claude/skills/`
3. **If a skill exists, you MUST use it** - Mandatory, not optional.

**Available skills:**
- **getting-started** — Bootstrap skill, READ FIRST every session
- **test-runner** — MANDATORY after every code change (ruff → lint → tests)
- **langfuse-prompt-viewer** — MANDATORY when KeyError or schema errors occur
- **playwright-tester** — Browser automation and screenshots
- **docker-log-debugger** — Analyze Docker container logs
- **semantic-code-search** — Search codebase semantically using embeddings
- **twilio-test-caller** — Test voice call flows

**How skills work:**
- Each skill is a SKILL.md file containing mandatory instructions
- Read the skill: `cat .claude/skills/SKILL_NAME/SKILL.md`
- Follow the skill exactly - no shortcuts, no assumptions
- Announce when using skills for transparency

**When to use skills:**
- **ALWAYS search first:** `ls .claude/skills/`
- **Read relevant skills** before starting work
- **Follow them exactly** - violations will be caught
- **Announce usage** - "I'm using the test-runner skill..."

**Skills are NOT:**
- ❌ Optional suggestions you can ignore
- ❌ MCP tools or external services
- ❌ Reference documentation to skim

**Skills ARE:**
- ✅ Mandatory workflows you must follow
- ✅ Proven patterns that prevent bugs
- ✅ Enforced through bootstrap and pressure testing

## ⚠️ Critical Restrictions

**NEVER perform these operations yourself:**
- **Git Write Operations**: DO NOT commit, push, pull, merge, reset, rebase, or run ANY git commands that modify repository state
  - Exception: Read-only git commands are allowed (status, diff, log, show) via the git-reader agent
  - If the user asks to "revert", "undo", or "rollback" changes, explain what git commands would be needed but DO NOT run them
- **External Systems**: DO NOT write to Langfuse prompts, external databases, or any production/staging systems
- **Infrastructure**: DO NOT run terraform commands or make infrastructure changes
- **Remote Services**: DO NOT push changes to GitHub, GitLab, or any remote repositories

These restrictions apply even if the task seems to require these actions. If the user needs these operations, explain what commands they should run themselves.

## 💬 When to Answer vs When to Code

**DEFAULT TO ANSWERING, NOT CODING.** Only write code when explicitly asked with phrases like "make that change" or "go ahead and fix it."

DO NOT jump to fixing bugs when the user is:
- Asking questions (even about errors or problems)
- Discussing or analyzing behavior
- Using question marks
- Saying things like "should we", "could we", "would it be better"

## 📚 Quick Reference

For detailed development guidelines, architecture, and standards, see:
- **Main project guidance**: `AGENTS.md` (copied from superpowers)
- **Testing patterns**: `api/tests/AGENTS.md` (copied from superpowers)
- **CLI tool safety**: `api/src/cli/AGENTS.md` (project-specific)
- **Current work**: `specifications/CURRENT_SPEC.md`
