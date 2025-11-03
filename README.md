# Superpowers

Reusable Claude Code agents, commands, skills, and patterns for your projects.

## Quick Start

1. **Copy environment template**:
   ```bash
   cp .env.example .env
   # Edit .env and add your OPENAI_API_KEY
   ```

2. **Start all skill containers** (optional, for Docker-based skills):
   ```bash
   docker-compose up -d
   ```

3. **Verify skills are running**:
   ```bash
   docker ps | grep superpowers
   ```

## Environment Setup

Skills that require API keys (like semantic-code-search) use a shared `.env` file at the superpowers root:

```bash
# Copy template
cp .env.example .env

# Add your API keys
echo "OPENAI_API_KEY=sk-proj-your-key" >> .env
```

Alternatively, export from your shell environment:
```bash
export OPENAI_API_KEY=$(grep OPENAI_API_KEY ../api/.env | cut -d '=' -f2)
docker-compose up -d
```

## Structure

```
superpowers/
├── dot-claude/           # Claude Code configurations
│   ├── agents/          # Custom agents (mypy-error-fixer, pytest-test-reviewer, etc.)
│   ├── commands/        # Slash commands (/buildit, /planit, /review-code, etc.)
│   ├── skills/          # Skills (docker-log-debugger, langfuse-prompt-viewer, etc.)
│   └── settings.local.json
├── pre-commit-scripts/  # Pre-commit hooks and linting scripts
│   └── check_llm_nits.py # LLM anti-pattern detection
├── system-prompts/      # Project-specific patterns
│   ├── AGENTS.md       # Root-level agent guidance
│   └── testing/        # Testing-specific patterns
│       └── AGENTS.md
├── install.sh          # Installation script
├── uninstall.sh        # Uninstallation script
└── README.md           # This file
```

## Installation

### As a Git Submodule

From your project root:

```bash
# Add as submodule
git submodule add git@github.com:cncorp/superpowers.git superpowers

# Initialize and update
git submodule update --init --recursive
```

### Linking to Your Project

After adding as a submodule, create symlinks to enable the agents/commands/skills:

```bash
# From your project root directory
./superpowers/install.sh
```

This will:
- Link `.claude/` configurations to your project root (symlinks `dot-claude/` → `.claude/`)
- Link `.pre-commit-scripts/` for code quality checks (symlinks `pre-commit-scripts/` → `.pre-commit-scripts/`)
- Create symlinks for AGENTS.md files in appropriate locations
- Install Node.js dependencies for skills that require them (playwright-tester, etc.)
- Preserve existing project-specific customizations

### Prerequisites

For skills requiring Node.js (like playwright-tester):
- Node.js and npm must be installed
- The install script will automatically run `npm install` for these skills
- If npm is not available, you can manually install dependencies later:
  ```bash
  cd superpowers/dot-claude/skills/playwright-tester
  npm install
  ```

## What You Get

### 🤖 Specialized Agents (Auto-invoked)
Claude Code automatically uses these agents when appropriate:

- **`pytest-test-reviewer`** - Reviews test code for quality, parametrization, and best practices
- **`test-fixture-reviewer`** - Refactors test fixtures to follow patterns
- **`mypy-error-fixer`** - Automatically fixes type errors
- **`task-complete-enforcer`** - Ensures tasks meet Definition of Done before marking complete

### 📋 Slash Commands
Invoke with `/command-name` in Claude Code:

**Planning & Implementation:**
- `/planit` - Create detailed implementation plans
- `/buildit` - Implement the next stage in your plan
- `/plan-tdd` - Create TDD-based implementation plans
- `/implement-tdd` - Implement using Test-Driven Development

**Code Quality:**
- `/review-code` - Review code changes for quality and patterns
- `/prreview` - Review pull requests comprehensively
- `/mypy` - Run and fix mypy type errors

**Research & Exploration:**
- `/research` - Research codebase features or topics
- `/wdyt` - "What do you think?" - get opinions on implementation approaches

**Quick Actions:**
- `/cyw` - "Code your way" - implement with minimal guidance
- `/yjd` - "You just do" - quick implementation without discussion
- `/prime` - Prime context for a task

**Project Management:**
- `/create-linear-ticket` - Create Linear tickets from tasks
- `/linear-agent` - Work with Linear issues

### 🎯 Skills (Specialized Tools)

**Semantic Code Search:**
```bash
# Start the skill
cd superpowers && docker-compose up -d

# Find code by meaning, not text
docker exec superpowers-semantic-search-cli python /app/src/cli.py find "authentication logic"
docker exec superpowers-semantic-search-cli python /app/src/cli.py find "send message to user"
```

**Langfuse Prompt Viewer:**
- View and debug Langfuse prompts and traces
- Understand prompt schemas when KeyError occurs
- Analyze AI model behavior in production

**Other Skills:**
- **`playwright-tester`** - Browser automation testing
- **`docker-log-debugger`** - Debug container logs
- **`test-runner`** - Run and manage test suites
- **`twilio-test-caller`** - Test Twilio voice integrations

### 📚 System Prompts
Automatically loaded guidance for AI agents:
- **`AGENTS.md`** - Root-level coding patterns, anti-patterns, and quality standards
- **`api/tests/AGENTS.md`** - Testing patterns, fixture guidelines, and test types

### 🔍 Pre-commit Scripts
Automatic code quality checks:
- **`check_llm_nits.py`** - Detects LLM anti-patterns (broad exceptions, late imports, single-use functions)

## Updating

To pull latest changes from superpowers:

```bash
cd superpowers
git pull origin main
cd ..
git add superpowers
git commit -m "Update superpowers submodule"
```

After updating, re-run the install script if new skills were added:
```bash
./superpowers/install.sh
```

## Contributing

When updating patterns or configurations:

1. Make changes in `superpowers/` directory
2. Test in your project (changes reflect via symlinks)
3. Commit and push to superpowers repo
4. Update submodule reference in your project

## Skills with Node.js Dependencies

The following skills require Node.js and npm:
- **playwright-tester**: Browser automation skill using Playwright

These will be automatically set up during installation if npm is available.

## License

[Your License Here]
