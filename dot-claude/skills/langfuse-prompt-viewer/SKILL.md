---
name: langfuse-prompt-viewer
description: Fetch and view Langfuse prompts and traces. Use when debugging KeyError/schema errors, understanding prompt schemas, viewing traces, or when user requests to view a prompt.
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Langfuse Prompt & Trace Viewer

Comprehensive skill for working with Langfuse prompts and traces. Includes scripts for fetching prompts, viewing traces, and caching prompt content.

## When to Use

**Always use when:**
- Tests fail with `KeyError` or schema validation errors
- Need to understand what schema a prompt returns
- Code references a prompt and you need to see its logic
- User asks to view a specific prompt
- Investigating why prompt response doesn't match expectations
- Debugging Langfuse traces
- Analyzing AI model behavior in production

**Example:** `KeyError: 'therapist_response'` → Fetch `voice_message_enricher` to see actual schema

## Available Scripts

### 1. refresh_prompt_cache.py - Download Prompts Locally

Downloads Langfuse prompts to `docs/cached_prompts/` for offline viewing.

**Usage:**
```bash
# Fetch specific prompt (from project root or api directory)
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/refresh_prompt_cache.py PROMPT_NAME

# Fetch all prompts
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/refresh_prompt_cache.py

# Fetch multiple prompts
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/refresh_prompt_cache.py prompt1 prompt2 prompt3

# Or use justfile command (if available)
cd api && just refresh-prompts PROMPT_NAME
```

**Cached Location:**
- `docs/cached_prompts/{prompt_name}_production.txt` - Prompt content + version
- `docs/cached_prompts/{prompt_name}_production_config.json` - Configuration

### 2. check_prompts.py - List Available Prompts

Lists all prompts available in Langfuse without downloading them.

**Usage:**
```bash
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/check_prompts.py
```

**Output:**
- Lists all prompt names in Langfuse
- Shows which prompts are available
- Useful for discovering prompt names before fetching

### 3. fetch_trace.py - View Langfuse Traces

Fetch and display Langfuse traces for debugging AI model behavior.

**Usage:**
```bash
# Fetch specific trace by ID
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/fetch_trace.py db29520b-9acb-4af9-a7a0-1aa005eb7b24

# Fetch trace from Langfuse URL
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/fetch_trace.py "https://langfuse.prod.cncorp.io/project/.../traces?peek=db29520b..."

# List recent traces
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/fetch_trace.py --list --limit 5

# View help
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/fetch_trace.py --help
```

**What it shows:**
- Trace ID and metadata
- All observations (LLM calls, tool uses, etc.)
- Input/output for each step
- Timing information
- Useful for debugging AI workflows

## Key Prompts Reference

### Core Processing
- `message_enricher` - 🔥 Most critical - analyzes affect, conflict_state, intervention_needed
- `voice_message_enricher` - Voice enrichment with key_quote, segment_conflict_health
- `1on1` - One-on-one coaching conversations
- `fact_extractor` - Extracts facts for LTMM

### Intervention Logic
- `group_message_intervention_conditions_yaml` - SQL conditions triggering interventions
- `group_msg_intervention_needed_sender/recipient` - Intervention responses
- `group_msg_needs_soft_startup` - Soft startup intervention
- `group_msg_needs_timeout_sender/recipient` - Timeout suggestions
- `group_msg_positive_reinforcement_sender/recipient` - Positive reinforcement

### Onboarding
- `onboarding_v3_1on1` - V3 individual flow
- `onboarding_v3_group` - V3 group flow
- `onboarding_group_conversation` - Group onboarding

### Voice Features
- `voice_active_mediation` - Active mediation during calls
- `voice_conflict_intro` - Voice conflict intro
- `voice_guidance_delivery` - Voice guidance delivery

## Understanding Prompt Configs

### Prompt Text File
- Instructions: What AI should do
- Output format: JSON schema, required fields
- Variables: `{{sender_name}}`, `{{current_message}}`, etc.
- Allowed values: Enumerated options for fields
- Version: Header shows version

### Config JSON File
```json
{
  "model_config": {
    "model": "gpt-4.1",
    "temperature": 0.7,
    "response_format": {
      "type": "json_schema",  // or "json_object"
      "json_schema": { ... }
    }
  }
}
```

**response_format types:**
- `json_object` - Unstructured (model decides fields)
- `json_schema` - Strict validation (fields enforced)

## Debugging Workflows

### KeyError in Tests
1. Fetch the prompt using `refresh_prompt_cache.py`
2. Check if field is optional/conditional in prompt text
3. Check config: `json_object` vs `json_schema`
4. Fix test to handle optional field OR update prompt

### Intervention Not Triggering
1. Fetch `message_enricher` to see `intervention_needed` values
2. Fetch `group_message_intervention_conditions_yaml` for SQL conditions
3. Verify enrichment result matches conditions
4. Check trace with `fetch_trace.py` to see actual flow

### Schema Validation Fails
1. Fetch the prompt using `refresh_prompt_cache.py`
2. Read config's `json_schema` section
3. Check `required` array
4. Verify code provides all required parameters

### Understanding AI Behavior
1. Get trace ID from logs or Langfuse UI
2. Use `fetch_trace.py` to view full trace
3. Examine inputs, outputs, and intermediate steps
4. Check for unexpected model responses

## Environment Requirements

**Required environment variables:**
- `LANGFUSE_PUBLIC_KEY` - Langfuse API public key
- `LANGFUSE_SECRET_KEY` - Langfuse API secret key
- `LANGFUSE_HOST` - Langfuse instance URL (optional, defaults to cloud)

**How to set:**
```bash
# Load from .env file
cd api && set -a; source .env; set +a
```

## Quick Reference

```bash
# List all available prompts
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/check_prompts.py

# Fetch specific prompt
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/refresh_prompt_cache.py PROMPT_NAME

# View cached prompt
cat docs/cached_prompts/PROMPT_NAME_production.txt
cat docs/cached_prompts/PROMPT_NAME_production_config.json

# List recent traces
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/fetch_trace.py --list --limit 5

# Fetch specific trace
cd api && set -a; source .env; set +a; PYTHONPATH=src uv run python .claude/skills/langfuse-prompt-viewer/fetch_trace.py TRACE_ID
```

## Important Notes

**READ-ONLY Operations:**
- These scripts are for viewing and debugging only
- DO NOT use to modify or delete prompts in Langfuse
- DO NOT push changes to Langfuse
- Always verify you're looking at the correct environment

**Project Structure:**
- Scripts expect to run from project `api/` directory
- Scripts use project's `common.langfuse_client` and `logger` modules
- Cached prompts saved to `docs/cached_prompts/` relative to project root
