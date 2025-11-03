#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Superpowers...${NC}\n"

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPERPOWERS_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Superpowers directory: $SUPERPOWERS_DIR"
echo "Project root directory: $PROJECT_ROOT"
echo ""

# 1. Link .claude directory to project root (Claude Code expects it there)
echo -e "${YELLOW}Step 1: Linking .claude directory...${NC}"
CLAUDE_LINK="$PROJECT_ROOT/.claude"

if [ -L "$CLAUDE_LINK" ]; then
    echo "  ✓ .claude symlink already exists"
elif [ -d "$CLAUDE_LINK" ]; then
    echo -e "${RED}  ✗ .claude exists as a directory (not a symlink)${NC}"
    echo "    Move it first: mv $CLAUDE_LINK ${CLAUDE_LINK}.backup"
    exit 1
else
    ln -s "$SUPERPOWERS_DIR/dot-claude" "$CLAUDE_LINK"
    echo -e "${GREEN}  ✓ Created .claude symlink${NC}"
fi

# 2. Link AGENTS.md files
echo -e "\n${YELLOW}Step 2: Linking AGENTS.md files...${NC}"

# Root AGENTS.md
ROOT_AGENTS="$PROJECT_ROOT/AGENTS.md"
if [ -L "$ROOT_AGENTS" ]; then
    echo "  ✓ Root AGENTS.md symlink already exists"
elif [ -f "$ROOT_AGENTS" ]; then
    echo "  ! Backing up existing $ROOT_AGENTS to ${ROOT_AGENTS}.backup"
    mv "$ROOT_AGENTS" "${ROOT_AGENTS}.backup"
    ln -s "$SUPERPOWERS_DIR/system-prompts/AGENTS.md" "$ROOT_AGENTS"
    echo -e "${GREEN}  ✓ Created root AGENTS.md symlink${NC}"
else
    ln -s "$SUPERPOWERS_DIR/system-prompts/AGENTS.md" "$ROOT_AGENTS"
    echo -e "${GREEN}  ✓ Created root AGENTS.md symlink${NC}"
fi

# Testing AGENTS.md
TESTING_AGENTS="$PROJECT_ROOT/api/tests/AGENTS.md"
if [ -L "$TESTING_AGENTS" ]; then
    echo "  ✓ Testing AGENTS.md symlink already exists"
elif [ -f "$TESTING_AGENTS" ]; then
    echo "  ! Backing up existing $TESTING_AGENTS to ${TESTING_AGENTS}.backup"
    mv "$TESTING_AGENTS" "${TESTING_AGENTS}.backup"
    ln -s "$SUPERPOWERS_DIR/system-prompts/testing/AGENTS.md" "$TESTING_AGENTS"
    echo -e "${GREEN}  ✓ Created testing AGENTS.md symlink${NC}"
else
    ln -s "$SUPERPOWERS_DIR/system-prompts/testing/AGENTS.md" "$TESTING_AGENTS"
    echo -e "${GREEN}  ✓ Created testing AGENTS.md symlink${NC}"
fi

# 3. Link pre-commit scripts
echo -e "\n${YELLOW}Step 3: Linking pre-commit scripts...${NC}"
PRE_COMMIT_LINK="$PROJECT_ROOT/.pre-commit-scripts"

if [ -L "$PRE_COMMIT_LINK" ]; then
    echo "  ✓ .pre-commit-scripts symlink already exists"
elif [ -d "$PRE_COMMIT_LINK" ]; then
    echo -e "${RED}  ✗ .pre-commit-scripts exists as a directory (not a symlink)${NC}"
    echo "    Move it first: mv $PRE_COMMIT_LINK ${PRE_COMMIT_LINK}.backup"
    exit 1
else
    ln -s "$SUPERPOWERS_DIR/pre-commit-scripts" "$PRE_COMMIT_LINK"
    echo -e "${GREEN}  ✓ Created .pre-commit-scripts symlink${NC}"
fi

# 4. Install Node dependencies for skills
echo -e "\n${YELLOW}Step 4: Installing Node dependencies for skills...${NC}"

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo -e "${YELLOW}  ! npm not found - skipping skill dependency installation${NC}"
    echo "    Skills requiring Node.js will need manual 'npm install' in their directories"
else
    # Find all package.json files in skills directories
    SKILL_DIRS=$(find "$SUPERPOWERS_DIR/dot-claude/skills" -name "package.json" -exec dirname {} \;)

    if [ -z "$SKILL_DIRS" ]; then
        echo "  ✓ No Node.js skills require installation"
    else
        for SKILL_DIR in $SKILL_DIRS; do
            SKILL_NAME=$(basename "$SKILL_DIR")
            echo "  Installing dependencies for skill: $SKILL_NAME"

            # Install dependencies quietly
            (cd "$SKILL_DIR" && npm install --silent) && \
                echo -e "${GREEN}    ✓ Installed $SKILL_NAME dependencies${NC}" || \
                echo -e "${RED}    ✗ Failed to install $SKILL_NAME dependencies${NC}"
        done
    fi
fi

# 5. Update CLAUDE.md to point to the new structure
echo -e "\n${YELLOW}Step 5: Updating CLAUDE.md redirect...${NC}"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"

cat > "$CLAUDE_MD" << 'CLAUDEMD'
# CLAUDE.md

This repository now consolidates all assistant guidance under `AGENTS.md` files managed by the superpowers submodule. Use the list below to jump to the right doc:

- `AGENTS.md` — top-level rules for every AI coding agent (symlinked from superpowers/system-prompts/AGENTS.md)
- `api/tests/AGENTS.md` — testing strategy, fixtures, and patterns for agents (symlinked from superpowers/system-prompts/testing/AGENTS.md)

Keep these files in sync by updating them in the `superpowers/` submodule.

# Command Restrictions

- Never run any `git` commands yourself. If you need repository state (diffs, status, history), describe the command and ask the user to execute it and share the output.

# When to Answer vs When to Code

**DEFAULT TO ANSWERING, NOT CODING.** Only write code when explicitly asked with phrases like "make that change" or "go ahead and fix it."

DO NOT jump to fixing bugs when the user is:
- Asking questions (even about errors or problems)
- Discussing or analyzing behavior
- Using question marks
- Saying things like "should we", "could we", "would it be better"
CLAUDEMD

echo -e "${GREEN}  ✓ Updated CLAUDE.md${NC}"

echo -e "\n${GREEN}✓ Installation complete!${NC}"
echo ""
echo "The following symlinks have been created:"
echo "  - $PROJECT_ROOT/.claude -> $SUPERPOWERS_DIR/dot-claude"
echo "  - $PROJECT_ROOT/.pre-commit-scripts -> $SUPERPOWERS_DIR/pre-commit-scripts"
echo "  - $PROJECT_ROOT/AGENTS.md -> $SUPERPOWERS_DIR/system-prompts/AGENTS.md"
echo "  - $PROJECT_ROOT/api/tests/AGENTS.md -> $SUPERPOWERS_DIR/system-prompts/testing/AGENTS.md"
echo ""
echo "To update patterns, edit files in superpowers/ and they will automatically reflect in your project."
