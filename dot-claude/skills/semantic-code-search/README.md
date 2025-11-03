# Semantic Code Search Skill

A Claude Code skill that provides semantic code search using vector embeddings. Find functions, classes, and code by **meaning** rather than exact text matching.

## Overview

This skill uses:
- **PostgreSQL with pgvector** for vector similarity search
- **OpenAI embeddings** (text-embedding-3-small) for semantic understanding
- **Python AST parsing** for accurate code extraction
- **Docker containers** for isolated, portable deployment

## Installation

### Automatic (via superpowers install.sh)

When you run `./superpowers/install.sh` in your project, you'll be prompted to set up semantic-code-search:

```bash
./superpowers/install.sh
# Follow prompts, enter OpenAI API key when asked
```

### Manual Setup

```bash
cd .claude/skills/semantic-code-search

# Set OpenAI API key
export OPENAI_API_KEY="your-key-here"

# Start containers
docker-compose up -d --build

# Wait for database to be ready (about 10 seconds)
sleep 10

# Index your codebase
docker exec code-search-cli code-search index /workspace --clear

# Verify setup
docker exec code-search-cli code-search stats
```

## Usage

### Search for Code
```bash
# Find authentication code
docker exec code-search-cli code-search find "user authentication login verification"

# Find webhook handlers
docker exec code-search-cli code-search find "handle incoming webhook messages"

# Find database operations
docker exec code-search-cli code-search find "save data to PostgreSQL database"

# More results (default is 5)
docker exec code-search-cli code-search find "async processing" --limit 10
```

### View Statistics
```bash
docker exec code-search-cli code-search stats
```

### Re-index After Code Changes
```bash
docker exec code-search-cli code-search index /workspace --clear
```

## How Claude Code Uses This

When installed, Claude Code can automatically use this skill when:
- You ask "Where is the code that handles X?"
- You ask "How do we implement Y?"
- Traditional grep searches aren't finding what you need

Example interaction:
```
You: "Where do we handle Twilio webhooks?"

Claude: *Uses semantic-code-search skill*
        docker exec code-search-cli code-search find "Twilio webhook incoming calls"

        Found in api/routes/webhooks.py:45 - handle_incoming_call function
```

## Architecture

```
superpowers/
└── dot-claude/
    └── skills/
        └── semantic-code-search/
            ├── SKILL.md              # Instructions for Claude Code
            ├── README.md             # This file (for humans)
            ├── docker-compose.yml    # Container orchestration
            ├── Dockerfile            # Python app container
            ├── requirements.txt      # Python dependencies
            ├── init.sql             # Database schema
            ├── .env.example         # Environment template
            └── src/
                ├── cli.py           # Command-line interface
                ├── indexer.py       # AST-based code parsing
                ├── embeddings.py    # OpenAI integration
                └── database.py      # PostgreSQL/pgvector ops
```

## Configuration

### Environment Variables

Create `.env` file or export:
```bash
OPENAI_API_KEY=sk-...
DATABASE_URL=postgresql://codesearch:codesearch@postgres:5432/codesearch
```

### Docker Compose

- **Postgres Port**: 5433 (host) → 5432 (container)
- **Project Mount**: `../../..:/workspace:ro` (read-only)
- **Container Names**: `code-search-cli`, `code-search-db`
- **Volume**: `code-search-postgres-data` (persists embeddings)

## Performance

- **Search Speed**: <1 second
- **Index Speed**: ~5 files/second
- **Memory**: ~100MB for 1000 functions
- **Storage**: ~1KB per function

## Maintenance

### View Logs
```bash
cd .claude/skills/semantic-code-search
docker-compose logs -f
```

### Restart Services
```bash
cd .claude/skills/semantic-code-search
docker-compose restart
```

### Stop Services
```bash
cd .claude/skills/semantic-code-search
docker-compose down
```

### Full Reset (deletes all indexed data)
```bash
cd .claude/skills/semantic-code-search
docker-compose down -v
docker-compose up -d --build
docker exec code-search-cli code-search index /workspace --clear
```

## Troubleshooting

### Container Not Running
```bash
# Check status
docker ps -a | grep code-search

# Start containers
cd .claude/skills/semantic-code-search
docker-compose up -d
```

### No Search Results
```bash
# Verify index exists
docker exec code-search-cli code-search stats

# Re-index if needed
docker exec code-search-cli code-search index /workspace --clear
```

### OpenAI API Errors
```bash
# Check if key is set
docker exec code-search-cli env | grep OPENAI_API_KEY

# Set key in .env file
echo "OPENAI_API_KEY=sk-..." > .claude/skills/semantic-code-search/.env

# Restart containers
cd .claude/skills/semantic-code-search
docker-compose restart
```

### Port Conflicts (5433)
If port 5433 is already in use, edit `docker-compose.yml`:
```yaml
ports:
  - "5434:5432"  # Use different port
```

## Limitations

- Currently only indexes Python files
- Requires OpenAI API key (costs ~$0.01 per 1000 functions indexed)
- Read-only mount prevents indexing changes to source from container

## Future Enhancements

- [ ] Multi-language support (JavaScript, TypeScript, Go, Rust)
- [ ] Local embedding models (no OpenAI dependency)
- [ ] Incremental indexing (only new/changed files)
- [ ] Code similarity recommendations
- [ ] Integration with IDE extensions

## License

MIT

## Credits

Part of the Superpowers collection for Claude Code.
