# CLAUDE.md

This repository uses the **superpowers** submodule to provide AI coding agents (like Claude Code) with specialized capabilities through agents, commands, and skills.

## 📁 Documentation Structure

All assistant guidance is consolidated under `AGENTS.md` files:

- **`AGENTS.md`** — Top-level rules for every AI coding agent (symlinked from `superpowers/system-prompts/AGENTS.md`)
- **`api/tests/AGENTS.md`** — Testing strategy, fixtures, and patterns for agents (symlinked from `superpowers/system-prompts/testing/AGENTS.md`)
- **Project-specific guidance** — Files like `api/src/cli/AGENTS.md` remain in their original locations for repo-specific rules

Keep these files in sync by updating them in the `superpowers/` submodule.

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

**Skills are tools** that extend your capabilities with specialized functionality.

Available skills:
- **langfuse-prompt-viewer** — View and inspect Langfuse prompts
- **playwright-tester** — Run browser-based E2E tests
- **docker-log-debugger** — Analyze Docker container logs
- **test-runner** — Execute test suites with specific configurations
- **twilio-test-caller** — Test voice call flows
- **semantic-code-search** — Search codebase semantically using embeddings

**When to use skills:**
- Use them just like any other tool available to you
- Skills are invoked through MCP (Model Context Protocol)
- Check `.claude/skills/*/skill.json` for available skill tools and their parameters

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
- **Main project guidance**: `AGENTS.md` (symlinked from superpowers)
- **Testing patterns**: `api/tests/AGENTS.md` (symlinked from superpowers)
- **CLI tool safety**: `api/src/cli/AGENTS.md` (project-specific)
- **Current work**: `specifications/CURRENT_SPEC.md`
