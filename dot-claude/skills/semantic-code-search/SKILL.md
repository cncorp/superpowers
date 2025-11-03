---
name: semantic-code-search
description: Semantic code search using vector embeddings. Find functions/classes by meaning, not exact text. Use when exploring codebases or when grep doesn't find what you need.
allowed-tools:
  - Bash
  - Read
  - Grep
---

# Semantic Code Search

Semantic code search tool that uses vector embeddings to find functions, classes, and variables by **meaning** rather than exact text matching. Provides 10x faster code discovery compared to traditional text-based searching.

## When to Use

Use proactively when:
- User asks "how do I..." or "where is the code that..."
- Looking for functions by purpose (e.g., "authentication", "database queries", "webhook handling")
- Traditional grep fails to find relevant code
- Exploring unfamiliar codebases
- Need to find similar patterns or implementations
- User wants to discover reusable code

## Prerequisites

The skill requires:
1. Docker and Docker Compose installed
2. OpenAI API key (for generating embeddings)
3. Codebase indexed (done during install.sh or manually)

**Check if installed:**
```bash
docker ps | grep semantic-code-search
```

**If not running:**
```bash
cd .claude/skills/semantic-code-search && docker-compose up -d
```

## Primary Commands

### Search Semantically
```bash
# Find authentication code
docker exec code-search-cli code-search find "user authentication login verification"

# Find webhook handlers
docker exec code-search-cli code-search find "handle incoming webhook messages"

# Find database operations
docker exec code-search-cli code-search find "save data to PostgreSQL database"

# Find API endpoints
docker exec code-search-cli code-search find "HTTP request routing webhooks"

# More results (default is 5)
docker exec code-search-cli code-search find "async processing" --limit 10
```

### View Statistics
```bash
docker exec code-search-cli code-search stats
```

### Re-index After Code Changes
```bash
# Re-index entire codebase (clears old index)
docker exec code-search-cli code-search index /workspace --clear

# Index without clearing
docker exec code-search-cli code-search index /workspace
```

## How It Works

1. **AST Parsing**: Extracts all Python functions and classes with signatures and docstrings
2. **OpenAI Embeddings**: Generates 1536-dimensional vectors using text-embedding-3-small model
3. **pgvector**: Stores vectors in PostgreSQL with vector similarity extension
4. **Cosine Similarity**: Finds semantically similar code using IVFFlat index (<1s response time)

## Architecture

- **Database**: PostgreSQL 16 with pgvector extension on port 5433
- **CLI**: Python 3.11 with AST parsing for accurate code extraction
- **Container**: code-search-cli with mounted project root at /workspace
- **Storage**: Persistent postgres-data volume for embeddings

## Example Workflows

### Finding Authentication Code
```bash
docker exec code-search-cli code-search find "user authentication login verification" --limit 10
```

Expected output:
```
Found 3 results:
1. authenticate_user (score: 0.91)
   File: api/auth/handlers.py
   Type: function
   Signature: def authenticate_user(username: str, password: str) -> bool
   Docstring: Verify user credentials against database

2. verify_token (score: 0.85)
   File: api/auth/jwt.py
   Type: function
   Signature: def verify_token(token: str) -> dict
```

### Finding Similar Functions
```bash
# User wants to implement something similar to an existing function
docker exec code-search-cli code-search find "process webhook payload validate signature"
```

### After Major Code Changes
```bash
# Re-index to include new code
docker exec code-search-cli code-search index /workspace --clear

# Verify index updated
docker exec code-search-cli code-search stats
```

## Integration with Claude Code

When a user asks questions like:
- "Where do we handle webhooks?"
- "How do we authenticate users?"
- "Is there code for sending emails?"

**Workflow:**
1. Use semantic-code-search to search semantically
2. Read the relevant files found
3. Provide the user with file paths and line numbers

```bash
# User: "Where do we handle Twilio webhooks?"
docker exec code-search-cli code-search find "Twilio webhook incoming calls"

# Claude reads the top result
Read api/routes/webhooks.py

# Claude responds with context
"Twilio webhooks are handled in api/routes/webhooks.py:45 by the handle_incoming_call function..."
```

## Performance

- **Search Speed**: <1 second for most queries
- **Index Speed**: ~5 files per second
- **Memory Usage**: ~100MB for 1000 functions indexed
- **Storage**: ~1KB per indexed function

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Container not running | `cd .claude/skills/semantic-code-search && docker-compose up -d` |
| No results found | Re-index: `docker exec code-search-cli code-search index /workspace --clear` |
| OpenAI API error | Verify OPENAI_API_KEY environment variable |
| Database connection error | Check postgres health: `cd .claude/skills/semantic-code-search && docker-compose ps` |
| Port conflict (5433) | Edit docker-compose.yml to use different port |
| Stale results | Re-index after code changes |
| Container missing | Check if skill was installed: `ls .claude/skills/semantic-code-search` |

## Common Issues

### Container Not Found
```bash
# Check if containers exist
docker ps -a | grep semantic-code-search

# Start containers
cd .claude/skills/semantic-code-search && docker-compose up -d
```

### Empty Index
```bash
# Verify index exists
docker exec code-search-cli code-search stats

# If total_elements is 0, re-index
docker exec code-search-cli code-search index /workspace --clear
```

### OpenAI API Key Missing
```bash
# Check if key is set in container
docker exec code-search-cli env | grep OPENAI_API_KEY

# If missing, set in .claude/skills/semantic-code-search/.env and restart
cd .claude/skills/semantic-code-search
echo "OPENAI_API_KEY=your-key-here" > .env
docker-compose down && docker-compose up -d
```

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

### Full Reset
```bash
cd .claude/skills/semantic-code-search
docker-compose down -v  # Warning: deletes all indexed data
docker-compose up -d
docker exec code-search-cli code-search index /workspace --clear
```

## Tips for Effective Searching

1. **Use descriptive queries**: "handle user authentication with JWT tokens" is better than "auth"
2. **Include context**: "save conversation to database with embeddings" vs "save database"
3. **Try variations**: If no results, rephrase the query
4. **Check stats first**: Verify index is populated before searching
5. **Re-index often**: After pulling new code or major changes

## Quick Reference

```bash
# 🔥 Search for code
docker exec code-search-cli code-search find "your semantic query here"

# 🔥 View index statistics
docker exec code-search-cli code-search stats

# 🔥 Re-index codebase
docker exec code-search-cli code-search index /workspace --clear

# 🔥 Check if running
docker ps | grep semantic-code-search

# 🔥 Start containers
cd .claude/skills/semantic-code-search && docker-compose up -d

# 🔥 View logs
cd .claude/skills/semantic-code-search && docker-compose logs -f
```

## Notes

- Default project mount: `/workspace` (3 levels up from skill directory)
- Database port: 5433 (avoids conflicts with other PostgreSQL instances)
- Container names: `code-search-cli`, `semantic-code-search-db`
- Embeddings model: OpenAI text-embedding-3-small (1536 dimensions)
- Only Python files are currently indexed (future: multi-language support)
- Index persists across container restarts via Docker volume
