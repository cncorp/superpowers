#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing/Updating Arsenal...${NC}\n"

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPERPOWERS_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Arsenal directory: $SUPERPOWERS_DIR"
echo "Project root directory: $PROJECT_ROOT"
echo ""

# 1. Copy .claude directory to project root (Claude Code expects it there)
# Note: We copy instead of symlink because Claude Code doesn't reliably respect symlinked directories
echo -e "${YELLOW}Step 1: Setting up .claude directory...${NC}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
SOURCE_CLAUDE="$SUPERPOWERS_DIR/dot-claude"

if [ -L "$CLAUDE_DIR" ]; then
    echo "  ! Removing old .claude symlink (switching to copy for reliability)"
    rm "$CLAUDE_DIR"
    cp -r "$SOURCE_CLAUDE" "$CLAUDE_DIR"
    echo -e "${GREEN}  ✓ Converted .claude from symlink to copy${NC}"
elif [ -d "$CLAUDE_DIR" ]; then
    echo "  Updating existing .claude directory from arsenal..."
    # Use rsync to sync, preserving newer files in destination if any
    rsync -a --update "$SOURCE_CLAUDE/" "$CLAUDE_DIR/"
    echo -e "${GREEN}  ✓ Updated .claude directory${NC}"
else
    cp -r "$SOURCE_CLAUDE" "$CLAUDE_DIR"
    echo -e "${GREEN}  ✓ Created .claude directory${NC}"
fi

# 2. Copy AGENTS.md files
# Note: We copy instead of symlink because Claude Code doesn't reliably respect symlinks
echo -e "\n${YELLOW}Step 2: Copying AGENTS.md files...${NC}"

# Root AGENTS.md
ROOT_AGENTS="$PROJECT_ROOT/AGENTS.md"
SOURCE_ROOT_AGENTS="$SUPERPOWERS_DIR/system-prompts/AGENTS.md"
if [ -L "$ROOT_AGENTS" ]; then
    echo "  ! Removing old AGENTS.md symlink (switching to copy for reliability)"
    rm "$ROOT_AGENTS"
    cp "$SOURCE_ROOT_AGENTS" "$ROOT_AGENTS"
    echo -e "${GREEN}  ✓ Converted root AGENTS.md from symlink to copy${NC}"
elif [ -f "$ROOT_AGENTS" ]; then
    # Backup existing file if it differs from source
    if ! cmp -s "$ROOT_AGENTS" "$SOURCE_ROOT_AGENTS"; then
        BACKUP_FILE="$ROOT_AGENTS.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$ROOT_AGENTS" "$BACKUP_FILE"
        echo -e "${YELLOW}  ! Created backup: $BACKUP_FILE${NC}"
    fi
    echo "  Updating existing AGENTS.md from arsenal..."
    cp "$SOURCE_ROOT_AGENTS" "$ROOT_AGENTS"
    echo -e "${GREEN}  ✓ Updated root AGENTS.md${NC}"
else
    cp "$SOURCE_ROOT_AGENTS" "$ROOT_AGENTS"
    echo -e "${GREEN}  ✓ Created root AGENTS.md${NC}"
fi

# Testing AGENTS.md
TESTING_AGENTS="$PROJECT_ROOT/api/tests/AGENTS.md"
SOURCE_TESTING_AGENTS="$SUPERPOWERS_DIR/system-prompts/testing/AGENTS.md"
if [ -L "$TESTING_AGENTS" ]; then
    echo "  ! Removing old testing AGENTS.md symlink (switching to copy for reliability)"
    rm "$TESTING_AGENTS"
    cp "$SOURCE_TESTING_AGENTS" "$TESTING_AGENTS"
    echo -e "${GREEN}  ✓ Converted testing AGENTS.md from symlink to copy${NC}"
elif [ -f "$TESTING_AGENTS" ]; then
    # Backup existing file if it differs from source
    if ! cmp -s "$TESTING_AGENTS" "$SOURCE_TESTING_AGENTS"; then
        BACKUP_FILE="$TESTING_AGENTS.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$TESTING_AGENTS" "$BACKUP_FILE"
        echo -e "${YELLOW}  ! Created backup: $BACKUP_FILE${NC}"
    fi
    echo "  Updating existing testing AGENTS.md from arsenal..."
    cp "$SOURCE_TESTING_AGENTS" "$TESTING_AGENTS"
    echo -e "${GREEN}  ✓ Updated testing AGENTS.md${NC}"
else
    cp "$SOURCE_TESTING_AGENTS" "$TESTING_AGENTS"
    echo -e "${GREEN}  ✓ Created testing AGENTS.md${NC}"
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

            # Check if node_modules already exists and is not empty
            if [ -d "$SKILL_DIR/node_modules" ] && [ "$(ls -A "$SKILL_DIR/node_modules" 2>/dev/null)" ]; then
                echo -e "${GREEN}  ✓ $SKILL_NAME dependencies already installed${NC}"
            else
                echo "  Installing dependencies for skill: $SKILL_NAME"
                # Install dependencies quietly
                (cd "$SKILL_DIR" && npm install --silent) && \
                    echo -e "${GREEN}    ✓ Installed $SKILL_NAME dependencies${NC}" || \
                    echo -e "${RED}    ✗ Failed to install $SKILL_NAME dependencies${NC}"
            fi
        done
    fi
fi

# 5. Setup arsenal environment configuration
echo -e "\n${YELLOW}Step 5: Setting up arsenal environment configuration...${NC}"

SUPERPOWERS_ENV="$SUPERPOWERS_DIR/.env"
SUPERPOWERS_ENV_EXAMPLE="$SUPERPOWERS_DIR/.env.example"

if [ -f "$SUPERPOWERS_ENV" ]; then
    echo -e "${GREEN}  ✓ .env file already exists${NC}"

    # Check for keys in parent project (.env or api/.env)
    PARENT_API_KEY=""
    PARENT_LANGFUSE_PUBLIC_KEY=""
    PARENT_LANGFUSE_SECRET_KEY=""
    PARENT_LANGFUSE_HOST=""

    # Check api/.env first, then .env
    for parent_env in "$PROJECT_ROOT/api/.env" "$PROJECT_ROOT/.env"; do
        if [ -f "$parent_env" ]; then
            if [ -z "$PARENT_API_KEY" ]; then
                PARENT_API_KEY=$(grep "^OPENAI_API_KEY=" "$parent_env" | head -1 | cut -d'=' -f2 | tr -d ' ')
            fi
            if [ -z "$PARENT_LANGFUSE_PUBLIC_KEY" ]; then
                PARENT_LANGFUSE_PUBLIC_KEY=$(grep "^LANGFUSE_PUBLIC_KEY=" "$parent_env" | head -1 | cut -d'=' -f2 | tr -d ' ')
            fi
            if [ -z "$PARENT_LANGFUSE_SECRET_KEY" ]; then
                PARENT_LANGFUSE_SECRET_KEY=$(grep "^LANGFUSE_SECRET_KEY=" "$parent_env" | head -1 | cut -d'=' -f2 | tr -d ' ')
            fi
            if [ -z "$PARENT_LANGFUSE_HOST" ]; then
                PARENT_LANGFUSE_HOST=$(grep "^LANGFUSE_HOST=" "$parent_env" | head -1 | cut -d'=' -f2 | tr -d ' ')
            fi
        fi
    done

    # Check and offer to update OPENAI_API_KEY
    if grep -q "^OPENAI_API_KEY=sk-" "$SUPERPOWERS_ENV"; then
        echo "  ✓ OPENAI_API_KEY configured"
    else
        if [ -n "$PARENT_API_KEY" ]; then
            echo -e "${YELLOW}  ! OPENAI_API_KEY not configured${NC}"
            read -p "  Copy OPENAI_API_KEY from parent project? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$PARENT_API_KEY|" "$SUPERPOWERS_ENV"
                echo -e "${GREEN}    ✓ Copied OPENAI_API_KEY${NC}"
            fi
        else
            echo -e "${YELLOW}  ! OPENAI_API_KEY not configured - edit arsenal/.env to add it${NC}"
        fi
    fi

    # Check and offer to update LANGFUSE keys
    if grep -q "^LANGFUSE_PUBLIC_KEY=pk-lf-" "$SUPERPOWERS_ENV"; then
        echo "  ✓ LANGFUSE keys configured"
    else
        if [ -n "$PARENT_LANGFUSE_PUBLIC_KEY" ] && [ -n "$PARENT_LANGFUSE_SECRET_KEY" ]; then
            echo -e "${YELLOW}  ! LANGFUSE keys not configured${NC}"
            read -p "  Copy LANGFUSE keys from parent project? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sed -i "s|LANGFUSE_PUBLIC_KEY=.*|LANGFUSE_PUBLIC_KEY=$PARENT_LANGFUSE_PUBLIC_KEY|" "$SUPERPOWERS_ENV"
                sed -i "s|LANGFUSE_SECRET_KEY=.*|LANGFUSE_SECRET_KEY=$PARENT_LANGFUSE_SECRET_KEY|" "$SUPERPOWERS_ENV"
                if [ -n "$PARENT_LANGFUSE_HOST" ]; then
                    sed -i "s|LANGFUSE_HOST=.*|LANGFUSE_HOST=$PARENT_LANGFUSE_HOST|" "$SUPERPOWERS_ENV"
                fi
                echo -e "${GREEN}    ✓ Copied LANGFUSE keys${NC}"
            fi
        else
            echo -e "${YELLOW}  ! LANGFUSE keys not configured - edit arsenal/.env to add them if needed${NC}"
        fi
    fi
else
    echo "  Creating .env file from template..."
    cp "$SUPERPOWERS_ENV_EXAMPLE" "$SUPERPOWERS_ENV"
    echo -e "${GREEN}  ✓ Created .env file${NC}"

    # Check for keys in parent project (.env or api/.env)
    PARENT_API_KEY=""
    PARENT_LANGFUSE_PUBLIC_KEY=""
    PARENT_LANGFUSE_SECRET_KEY=""
    PARENT_LANGFUSE_HOST=""

    # Check api/.env first, then .env
    for parent_env in "$PROJECT_ROOT/api/.env" "$PROJECT_ROOT/.env"; do
        if [ -f "$parent_env" ]; then
            if [ -z "$PARENT_API_KEY" ]; then
                PARENT_API_KEY=$(grep "^OPENAI_API_KEY=" "$parent_env" | head -1 | cut -d'=' -f2 | tr -d ' ')
            fi
            if [ -z "$PARENT_LANGFUSE_PUBLIC_KEY" ]; then
                PARENT_LANGFUSE_PUBLIC_KEY=$(grep "^LANGFUSE_PUBLIC_KEY=" "$parent_env" | head -1 | cut -d'=' -f2 | tr -d ' ')
            fi
            if [ -z "$PARENT_LANGFUSE_SECRET_KEY" ]; then
                PARENT_LANGFUSE_SECRET_KEY=$(grep "^LANGFUSE_SECRET_KEY=" "$parent_env" | head -1 | cut -d'=' -f2 | tr -d ' ')
            fi
            if [ -z "$PARENT_LANGFUSE_HOST" ]; then
                PARENT_LANGFUSE_HOST=$(grep "^LANGFUSE_HOST=" "$parent_env" | head -1 | cut -d'=' -f2 | tr -d ' ')
            fi
        fi
    done

    # Offer to configure OpenAI API key
    if [ -n "$OPENAI_API_KEY" ]; then
        echo "  Using OPENAI_API_KEY from environment"
        sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$OPENAI_API_KEY|" "$SUPERPOWERS_ENV"
        echo -e "${GREEN}  ✓ Set OPENAI_API_KEY${NC}"
    elif [ -n "$PARENT_API_KEY" ]; then
        read -p "  Copy OPENAI_API_KEY from parent project? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$PARENT_API_KEY|" "$SUPERPOWERS_ENV"
            echo -e "${GREEN}  ✓ Copied OPENAI_API_KEY${NC}"
        else
            echo -e "${YELLOW}  ! OPENAI_API_KEY not set - edit arsenal/.env to add it${NC}"
        fi
    else
        echo -e "${YELLOW}  ! OPENAI_API_KEY not found - edit arsenal/.env to add it${NC}"
    fi

    # Offer to configure Langfuse keys
    if [ -n "$PARENT_LANGFUSE_PUBLIC_KEY" ] && [ -n "$PARENT_LANGFUSE_SECRET_KEY" ]; then
        read -p "  Copy LANGFUSE keys from parent project? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sed -i "s|LANGFUSE_PUBLIC_KEY=.*|LANGFUSE_PUBLIC_KEY=$PARENT_LANGFUSE_PUBLIC_KEY|" "$SUPERPOWERS_ENV"
            sed -i "s|LANGFUSE_SECRET_KEY=.*|LANGFUSE_SECRET_KEY=$PARENT_LANGFUSE_SECRET_KEY|" "$SUPERPOWERS_ENV"
            if [ -n "$PARENT_LANGFUSE_HOST" ]; then
                sed -i "s|LANGFUSE_HOST=.*|LANGFUSE_HOST=$PARENT_LANGFUSE_HOST|" "$SUPERPOWERS_ENV"
            fi
            echo -e "${GREEN}  ✓ Copied LANGFUSE keys${NC}"
        else
            echo -e "${YELLOW}  ! LANGFUSE keys not set - edit arsenal/.env to add them if needed${NC}"
        fi
    else
        echo -e "${YELLOW}  ! LANGFUSE keys not found - edit arsenal/.env to add them if needed${NC}"
    fi
fi

# 6. Setup semantic code search skill
echo -e "\n${YELLOW}Step 6: Setting up semantic code search skill...${NC}"

CODE_SEARCH_DIR="$SUPERPOWERS_DIR/dot-claude/skills/semantic-code-search"
if [ -d "$CODE_SEARCH_DIR" ]; then
    echo "  Found semantic-code-search skill"

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}  ! Docker not found - skipping semantic code search setup${NC}"
        echo "    To use semantic code search later, install Docker and run:"
        echo "    cd arsenal && docker-compose up -d"
    else
        # Check if containers are already running
        if docker ps | grep -q arsenal-semantic-search-cli; then
            echo -e "${GREEN}  ✓ Semantic code search containers already running${NC}"
        else
            # Check if OpenAI API key is configured
            if [ ! -f "$SUPERPOWERS_ENV" ] || ! grep -q "^OPENAI_API_KEY=sk-" "$SUPERPOWERS_ENV"; then
                echo -e "${YELLOW}  ! OPENAI_API_KEY not configured in $SUPERPOWERS_ENV${NC}"
                echo "    Edit arsenal/.env to add your key, then run:"
                echo "    cd arsenal && docker-compose up -d"
            else
                read -p "  Start semantic code search containers? [y/N]: " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo "  Starting semantic code search containers..."
                    cd "$SUPERPOWERS_DIR"

                    # Start containers
                    docker-compose up -d --build 2>&1 | grep -v "Pulling" | grep -v "Waiting"

                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}    ✓ Started semantic code search containers${NC}"

                        # Wait for postgres to be healthy
                        echo "    Waiting for database to be ready..."
                        for i in {1..30}; do
                            if docker exec arsenal-semantic-search-cli psql postgresql://codesearch:codesearch@semantic-search-db:5432/codesearch -c "SELECT 1" &> /dev/null; then
                                break
                            fi
                            sleep 1
                        done

                        # Index the project root
                        echo "    Indexing codebase (this may take a minute)..."
                        docker exec arsenal-semantic-search-cli code-search index /project --clear 2>&1 | tail -5

                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}    ✓ Indexed codebase${NC}"

                            # Show stats
                            echo ""
                            docker exec arsenal-semantic-search-cli code-search stats
                        else
                            echo -e "${RED}    ✗ Failed to index codebase${NC}"
                            echo "    Try manually: docker exec arsenal-semantic-search-cli code-search index /project --clear"
                        fi
                    else
                        echo -e "${RED}    ✗ Failed to start semantic code search containers${NC}"
                    fi

                    cd "$PROJECT_ROOT"
                else
                    echo "  Skipped semantic code search startup"
                    echo "  To start later: cd arsenal && docker-compose up -d"
                fi
            fi
        fi
    fi
else
    echo -e "${YELLOW}  ! Semantic code search skill not found - skipping${NC}"
fi

# 7. Copy CLAUDE.md
# Note: We copy instead of symlink because Claude Code doesn't reliably respect symlinks
echo -e "\n${YELLOW}Step 7: Copying CLAUDE.md...${NC}"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
SOURCE_CLAUDE_MD="$SUPERPOWERS_DIR/system-prompts/CLAUDE.md"

if [ -L "$CLAUDE_MD" ]; then
    echo "  ! Removing old CLAUDE.md symlink (switching to copy for reliability)"
    rm "$CLAUDE_MD"
    cp "$SOURCE_CLAUDE_MD" "$CLAUDE_MD"
    echo -e "${GREEN}  ✓ Converted CLAUDE.md from symlink to copy${NC}"
elif [ -f "$CLAUDE_MD" ]; then
    # Backup existing file if it differs from source
    if ! cmp -s "$CLAUDE_MD" "$SOURCE_CLAUDE_MD"; then
        BACKUP_FILE="$CLAUDE_MD.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$CLAUDE_MD" "$BACKUP_FILE"
        echo -e "${YELLOW}  ! Created backup: $BACKUP_FILE${NC}"
    fi
    echo "  Updating existing CLAUDE.md from arsenal..."
    cp "$SOURCE_CLAUDE_MD" "$CLAUDE_MD"
    echo -e "${GREEN}  ✓ Updated CLAUDE.md${NC}"
else
    cp "$SOURCE_CLAUDE_MD" "$CLAUDE_MD"
    echo -e "${GREEN}  ✓ Created CLAUDE.md${NC}"
fi

# 8. Setup SessionStart hook for getting-started skill
echo -e "\n${YELLOW}Step 8: Setting up SessionStart hook...${NC}"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SOURCE_HOOK="$SUPERPOWERS_DIR/hooks/session_start.py"
SETTINGS_JSON="$CLAUDE_DIR/settings.json"

# Create hooks directory if it doesn't exist
if [ ! -d "$HOOKS_DIR" ]; then
    mkdir -p "$HOOKS_DIR"
    echo -e "${GREEN}  ✓ Created hooks directory${NC}"
fi

# Copy session_start.py hook
if [ -f "$SOURCE_HOOK" ]; then
    cp "$SOURCE_HOOK" "$HOOKS_DIR/session_start.py"
    chmod +x "$HOOKS_DIR/session_start.py"
    echo -e "${GREEN}  ✓ Installed session_start.py hook${NC}"
else
    echo -e "${YELLOW}  ! Source hook not found at $SOURCE_HOOK${NC}"
    echo "    Creating default hook inline..."
    cat > "$HOOKS_DIR/session_start.py" << 'HOOK_EOF'
#!/usr/bin/env python3
"""
SessionStart hook that injects the getting-started skill into every session.

This ensures agents have the skill content in their context from the start,
making compliance mechanical rather than relying on LLM choice.
"""
import os
import sys

def main():
    skill_path = "./.claude/skills/getting-started/SKILL.md"

    if os.path.exists(skill_path):
        with open(skill_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
            line_count = len(lines)
            content = "".join(lines)

            print("╔══════════════════════════════════════════════════════════╗")
            print("║   📋 SESSION BOOTSTRAP: getting-started skill loaded     ║")
            print(f"║   File size: {line_count} lines                                   ║")
            print("╚══════════════════════════════════════════════════════════╝")
            print()
            print(content)
            print()
            print(f"--- End of getting-started skill ({line_count} lines) ---")
            print()
    else:
        print("⚠️  WARNING: getting-started skill not found at:", skill_path)
        print("Expected location: ./.claude/skills/getting-started/SKILL.md")
        print("The agent will not have skill context loaded.")
        sys.exit(1)

if __name__ == "__main__":
    main()
HOOK_EOF
    chmod +x "$HOOKS_DIR/session_start.py"
    echo -e "${GREEN}  ✓ Created default session_start.py hook${NC}"
fi

# Setup settings.json with hook configuration and permissions
if [ -f "$SETTINGS_JSON" ]; then
    # Check if SessionStart hook is already configured
    if grep -q '"SessionStart"' "$SETTINGS_JSON"; then
        echo "  ✓ settings.json already has SessionStart hook configured"
    else
        echo -e "${YELLOW}  ! settings.json exists but missing SessionStart hook${NC}"
        echo "    You may need to manually add the hook configuration"
    fi
else
    # Create settings.json with hook configuration and permissions
    cat > "$SETTINGS_JSON" << 'SETTINGS_EOF'
{
  "comment": "Modern Claude Code permissions format using permissions.deny with Bash(command:*) syntax per official docs. Blocks dangerous bash commands, git modification, and sudo access.",
  "permissions": {
    "deny": [
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git pull:*)",
      "Bash(git merge:*)",
      "Bash(git reset:*)",
      "Bash(git rebase:*)",
      "Bash(git stash pop:*)",
      "Bash(git cherry-pick:*)",
      "Bash(git apply:*)",
      "Bash(rm:*)",
      "Bash(rm -rf:*)",
      "Bash(sudo:*)"
    ],
    "allowGitWrite": false
  },
  "bashCommandApprovals": {
    "requireApprovalPatterns": []
  },
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "python3 .claude/hooks/session_start.py"
      }
    ]
  }
}
SETTINGS_EOF
    echo -e "${GREEN}  ✓ Created settings.json with SessionStart hook and permissions${NC}"
fi

echo -e "\n${GREEN}✓ Installation complete!${NC}"
echo ""
echo "Arsenal setup:"
echo "  - $PROJECT_ROOT/.claude (copied from arsenal/dot-claude)"
echo "  - $PROJECT_ROOT/.claude/hooks/session_start.py (SessionStart hook)"
echo "  - $PROJECT_ROOT/.claude/settings.json (hook configuration)"
echo "  - $PROJECT_ROOT/.pre-commit-scripts -> $SUPERPOWERS_DIR/pre-commit-scripts (symlink)"
echo "  - $PROJECT_ROOT/CLAUDE.md (copied from arsenal/system-prompts/CLAUDE.md)"
echo "  - $PROJECT_ROOT/AGENTS.md (copied from arsenal/system-prompts/AGENTS.md)"
echo "  - $PROJECT_ROOT/api/tests/AGENTS.md (copied from arsenal/system-prompts/testing/AGENTS.md)"
echo ""

# Check if .env was created
if [ -f "$SUPERPOWERS_ENV" ]; then
    echo -e "${GREEN}Environment configuration:${NC}"
    echo "  - arsenal/.env (edit this file to configure API keys)"
    echo ""
fi

# Check if semantic code search was set up
if docker ps | grep -q arsenal-semantic-search-cli; then
    echo -e "${GREEN}Semantic code search is ready!${NC}"
    echo "  Usage: docker exec arsenal-semantic-search-cli code-search find \"your search query\""
    echo "  Stats: docker exec arsenal-semantic-search-cli code-search stats"
    echo "  Reindex: docker exec arsenal-semantic-search-cli code-search index /project --clear"
    echo ""
fi

echo "To update from arsenal (CLAUDE.md/AGENTS.md/.claude/.pre-commit-scripts): re-run ./arsenal/install.sh"
echo "To edit patterns: modify files in arsenal/system-prompts/ then re-run install.sh to sync"
echo "To manage arsenal services: cd arsenal && docker-compose up -d"
