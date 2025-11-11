#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing/Updating Superpowers...${NC}\n"

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPERPOWERS_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Superpowers directory: $SUPERPOWERS_DIR"
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
    echo "  Updating existing .claude directory from superpowers..."
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
    echo "  Updating existing AGENTS.md from superpowers..."
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
    echo "  Updating existing testing AGENTS.md from superpowers..."
    cp "$SOURCE_TESTING_AGENTS" "$TESTING_AGENTS"
    echo -e "${GREEN}  ✓ Updated testing AGENTS.md${NC}"
else
    cp "$SOURCE_TESTING_AGENTS" "$TESTING_AGENTS"
    echo -e "${GREEN}  ✓ Created testing AGENTS.md${NC}"
fi

# 3. Copy pre-commit scripts
# Note: We copy instead of symlink because Claude Code doesn't reliably respect symlinks
echo -e "\n${YELLOW}Step 3: Copying pre-commit scripts...${NC}"
PRE_COMMIT_DIR="$PROJECT_ROOT/.pre-commit-scripts"
SOURCE_PRE_COMMIT="$SUPERPOWERS_DIR/pre-commit-scripts"

if [ -L "$PRE_COMMIT_DIR" ]; then
    echo "  ! Removing old .pre-commit-scripts symlink (switching to copy for reliability)"
    rm "$PRE_COMMIT_DIR"
    cp -r "$SOURCE_PRE_COMMIT" "$PRE_COMMIT_DIR"
    echo -e "${GREEN}  ✓ Converted .pre-commit-scripts from symlink to copy${NC}"
elif [ -d "$PRE_COMMIT_DIR" ]; then
    echo "  Updating existing .pre-commit-scripts directory from superpowers..."
    rsync -a --update "$SOURCE_PRE_COMMIT/" "$PRE_COMMIT_DIR/"
    echo -e "${GREEN}  ✓ Updated .pre-commit-scripts directory${NC}"
else
    cp -r "$SOURCE_PRE_COMMIT" "$PRE_COMMIT_DIR"
    echo -e "${GREEN}  ✓ Created .pre-commit-scripts directory${NC}"
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

# 5. Setup superpowers environment configuration
echo -e "\n${YELLOW}Step 5: Setting up superpowers environment configuration...${NC}"

SUPERPOWERS_ENV="$SUPERPOWERS_DIR/.env"
SUPERPOWERS_ENV_EXAMPLE="$SUPERPOWERS_DIR/.env.example"

if [ -f "$SUPERPOWERS_ENV" ]; then
    echo -e "${GREEN}  ✓ .env file already exists - skipping API key setup${NC}"

    # Check if the existing .env has a valid-looking OPENAI_API_KEY
    if grep -q "^OPENAI_API_KEY=sk-" "$SUPERPOWERS_ENV"; then
        echo "  ✓ OPENAI_API_KEY configured"
    else
        echo -e "${YELLOW}  ! OPENAI_API_KEY not configured in $SUPERPOWERS_ENV${NC}"
        echo "    Edit superpowers/.env to add your key if needed"
    fi
else
    # Check if OpenAI API key is in environment or parent project
    PARENT_API_KEY=""
    if [ -f "$PROJECT_ROOT/api/.env" ]; then
        PARENT_API_KEY=$(grep "^OPENAI_API_KEY=" "$PROJECT_ROOT/api/.env" | head -1 | cut -d'=' -f2 | tr -d ' ')
    fi

    if [ -n "$OPENAI_API_KEY" ]; then
        echo "  Using OPENAI_API_KEY from environment"
        cp "$SUPERPOWERS_ENV_EXAMPLE" "$SUPERPOWERS_ENV"
        sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$OPENAI_API_KEY|" "$SUPERPOWERS_ENV"
        echo -e "${GREEN}  ✓ Created .env with API key from environment${NC}"
    elif [ -n "$PARENT_API_KEY" ]; then
        echo "  Found OPENAI_API_KEY in parent project (api/.env)"
        read -p "  Use this key for superpowers? [Y/n]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            cp "$SUPERPOWERS_ENV_EXAMPLE" "$SUPERPOWERS_ENV"
            sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$PARENT_API_KEY|" "$SUPERPOWERS_ENV"
            echo -e "${GREEN}  ✓ Created .env with API key from parent project${NC}"
        else
            cp "$SUPERPOWERS_ENV_EXAMPLE" "$SUPERPOWERS_ENV"
            echo -e "${YELLOW}  ! Created .env template - edit it to add your OpenAI API key${NC}"
        fi
    else
        read -p "  Enter OpenAI API key (or press Enter to skip): " API_KEY
        if [ -n "$API_KEY" ]; then
            cp "$SUPERPOWERS_ENV_EXAMPLE" "$SUPERPOWERS_ENV"
            sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$API_KEY|" "$SUPERPOWERS_ENV"
            echo -e "${GREEN}  ✓ Created .env with provided API key${NC}"
        else
            cp "$SUPERPOWERS_ENV_EXAMPLE" "$SUPERPOWERS_ENV"
            echo -e "${YELLOW}  ! Created .env template - edit it to add your OpenAI API key${NC}"
        fi
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
        echo "    cd superpowers && docker-compose up -d"
    else
        # Check if containers are already running
        if docker ps | grep -q superpowers-semantic-search-cli; then
            echo -e "${GREEN}  ✓ Semantic code search containers already running${NC}"
        else
            # Check if OpenAI API key is configured
            if [ ! -f "$SUPERPOWERS_ENV" ] || ! grep -q "^OPENAI_API_KEY=sk-" "$SUPERPOWERS_ENV"; then
                echo -e "${YELLOW}  ! OPENAI_API_KEY not configured in $SUPERPOWERS_ENV${NC}"
                echo "    Edit superpowers/.env to add your key, then run:"
                echo "    cd superpowers && docker-compose up -d"
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
                            if docker exec superpowers-semantic-search-cli psql postgresql://codesearch:codesearch@semantic-search-db:5432/codesearch -c "SELECT 1" &> /dev/null; then
                                break
                            fi
                            sleep 1
                        done

                        # Index the project root
                        echo "    Indexing codebase (this may take a minute)..."
                        docker exec superpowers-semantic-search-cli code-search index /project --clear 2>&1 | tail -5

                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}    ✓ Indexed codebase${NC}"

                            # Show stats
                            echo ""
                            docker exec superpowers-semantic-search-cli code-search stats
                        else
                            echo -e "${RED}    ✗ Failed to index codebase${NC}"
                            echo "    Try manually: docker exec superpowers-semantic-search-cli code-search index /project --clear"
                        fi
                    else
                        echo -e "${RED}    ✗ Failed to start semantic code search containers${NC}"
                    fi

                    cd "$PROJECT_ROOT"
                else
                    echo "  Skipped semantic code search startup"
                    echo "  To start later: cd superpowers && docker-compose up -d"
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
    echo "  Updating existing CLAUDE.md from superpowers..."
    cp "$SOURCE_CLAUDE_MD" "$CLAUDE_MD"
    echo -e "${GREEN}  ✓ Updated CLAUDE.md${NC}"
else
    cp "$SOURCE_CLAUDE_MD" "$CLAUDE_MD"
    echo -e "${GREEN}  ✓ Created CLAUDE.md${NC}"
fi

echo -e "\n${GREEN}✓ Installation complete!${NC}"
echo ""
echo "Superpowers setup (all files copied from superpowers/):"
echo "  - $PROJECT_ROOT/.claude (copied from superpowers/dot-claude)"
echo "  - $PROJECT_ROOT/.pre-commit-scripts (copied from superpowers/pre-commit-scripts)"
echo "  - $PROJECT_ROOT/CLAUDE.md (copied from superpowers/system-prompts/CLAUDE.md)"
echo "  - $PROJECT_ROOT/AGENTS.md (copied from superpowers/system-prompts/AGENTS.md)"
echo "  - $PROJECT_ROOT/api/tests/AGENTS.md (copied from superpowers/system-prompts/testing/AGENTS.md)"
echo ""

# Check if .env was created
if [ -f "$SUPERPOWERS_ENV" ]; then
    echo -e "${GREEN}Environment configuration:${NC}"
    echo "  - superpowers/.env (edit this file to configure API keys)"
    echo ""
fi

# Check if semantic code search was set up
if docker ps | grep -q superpowers-semantic-search-cli; then
    echo -e "${GREEN}Semantic code search is ready!${NC}"
    echo "  Usage: docker exec superpowers-semantic-search-cli code-search find \"your search query\""
    echo "  Stats: docker exec superpowers-semantic-search-cli code-search stats"
    echo "  Reindex: docker exec superpowers-semantic-search-cli code-search index /project --clear"
    echo ""
fi

echo "To update from superpowers (CLAUDE.md/AGENTS.md/.claude/.pre-commit-scripts): re-run ./superpowers/install.sh"
echo "To edit patterns: modify files in superpowers/system-prompts/ then re-run install.sh to sync"
echo "To manage superpowers services: cd superpowers && docker-compose up -d"
