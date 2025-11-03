# Superpowers

Reusable Claude Code agents, commands, skills, and patterns for your projects.

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

## Usage

Once installed:

1. **Agents**: Available automatically in Claude Code (e.g., mypy-error-fixer, pytest-test-reviewer)
2. **Commands**: Use slash commands like `/buildit`, `/planit`, `/review-code`
3. **Skills**: Invoke skills like `docker-log-debugger`, `langfuse-prompt-viewer`, `playwright-tester`
4. **Patterns**: Referenced automatically via symlinked AGENTS.md files
5. **Pre-commit Scripts**: LLM anti-pattern detection runs during linting

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
