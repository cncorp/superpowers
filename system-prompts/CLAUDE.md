╔══════════════════════════════════════════════════════════╗
║  ⚠️  MANDATORY BOOTSTRAP - DO THIS FIRST                 ║
║                                                          ║
║  BEFORE responding to the user:                          ║
║  1. Search context for: "bootstrap_token: e2860470..."   ║
║  2. If NOT FOUND: cat .claude/skills/getting-started/SKILL.md ║
║  3. Verify you have the FULL 16-character token          ║
║  4. Run: ls .claude/skills/                              ║
║                                                          ║
║  YOU CANNOT SKIP THIS. This is your pre-flight check.    ║
╚══════════════════════════════════════════════════════════╝

EVERY SINGLE RESPONSE MUST START WITH THE BOOTSTRAP TOKEN:
---
🔐 e2860470********
---

On your FIRST response only, also include this bootstrap summary:
---
✅ BOOTSTRAP COMPLETE
Bootstrap token verified: e2860470******** (16 chars from SKILL.md)
Three foundational rules: [list them]
Available skills: [list from ls .claude/skills/]
---

🚨 CRITICAL: NEVER respond without the bootstrap token at the very start.
🚨 EVERY message you send must begin with: 🔐 e2860470******** (actual full token from SKILL.md)
🚨 You MUST read .claude/skills/getting-started/SKILL.md to get the complete 16-character token
🚨 The token is NOT "e2860470********" - that's partial. Get the full token from SKILL.md.

Common failure modes to AVOID:
❌ Responding without the bootstrap token header
❌ "I'll help you with that..." (no bootstrap token at start)
❌ "Let me check..." (no bootstrap token at start)
❌ Starting without the full 16-character bootstrap token from SKILL.md
❌ Finding "Three Foundational Rules" in CLAUDE.md (wrong - need the token from SKILL.md)
❌ Using partial token "e2860470..." without reading SKILL.md for full token
❌ Putting the token anywhere except the very first line of your response
❌ Using "e2860470********" as the token instead of reading SKILL.md for the complete token

# CLAUDE.md

This repository uses the **arsenal** submodule to provide AI coding agents (like Claude Code) with specialized capabilities through agents, commands, and skills.

## 📁 Documentation Structure

All assistant guidance is consolidated under `AGENTS.md` files:

- **`AGENTS.md`** — Top-level rules for every AI coding agent (copied from `arsenal/system-prompts/AGENTS.md`)
- **`api/tests/AGENTS.md`** — Testing strategy, fixtures, and patterns for agents (copied from `arsenal/system-prompts/testing/AGENTS.md`)
- **Project-specific guidance** — Files like `api/src/cli/AGENTS.md` remain in their original locations for repo-specific rules

Keep these files in sync by updating them in the `arsenal/` submodule and running `./arsenal/install.sh`.

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

**🚨 CRITICAL FOR TEST WRITING:**
- **BEFORE writing tests** → Use test-writer skill (MANDATORY - analyzes code type, dependencies, contract)
- **AFTER writing tests** → Invoke pytest-test-reviewer agent (validates patterns)
- **YOU CANNOT WRITE TESTS WITHOUT test-writer SKILL** - No exceptions, no shortcuts, every test, every time

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
1. **Skills give you capabilities** - You have skills. Arsenal gives you powers you previously didn't have.
2. **Search for skills first** - Before ANY task: `ls .claude/skills/`
3. **If a skill exists, you MUST use it** - Mandatory, not optional.

**Available skills:**
- **getting-started** — Bootstrap skill, READ FIRST every session
- **test-writer** — 🚨 MANDATORY before writing ANY test code (YOU CANNOT WRITE TESTS WITHOUT THIS SKILL)
- **test-runner** — MANDATORY after every code change (ruff → lint → tests)
- **langfuse-prompt-and-trace-debugger** — MANDATORY when KeyError or schema errors occur. Views prompts and debugs traces from Langfuse servers (staging or production)
- **update-langfuse-staging-server-prompt** — Push prompt updates to Langfuse STAGING SERVER ONLY (langfuse.staging.cncorp.io). Does NOT sync to production server
- **sql-reader** — Query production PostgreSQL database with read-only credentials (investigation, debugging)
- **playwright-tester** — Browser automation and screenshots
- **docker-log-debugger** — Analyze Docker container logs
- **semantic-code-search** — Search codebase semantically using embeddings
- **twilio-test-caller** — Test voice call flows

**IMPORTANT: Langfuse Server Architecture**
We have TWO completely separate Langfuse servers:
1. **Staging Langfuse Server** (`langfuse.staging.cncorp.io`) - For development/testing
2. **Production Langfuse Server** (`langfuse.prod.cncorp.io`) - For real users

Both servers have prompts tagged with "production" label, but they mean different things:
- Staging server "production" label = default prompts for staging tests (NOT user-facing)
- Production server "production" label = actual live prompts shown to users

There is NO automated sync between these servers. Changes must be manually propagated.

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
- **Main project guidance**: `AGENTS.md` (copied from arsenal)
- **Testing patterns**: `api/tests/AGENTS.md` (copied from arsenal)
- **CLI tool safety**: `api/src/cli/AGENTS.md` (project-specific)
- **Current work**: `specifications/CURRENT_SPEC.md`
