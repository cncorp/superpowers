#!/usr/bin/env python3
"""
Downloads and caches Langfuse prompts locally for viewing/reference.

INSTRUCTIONS FOR CLAUDE/AI AGENTS:
- This script is READ-ONLY - it only downloads prompts from Langfuse for local viewing
- DO NOT use this script to write or push changes back to Langfuse
- DO NOT modify the Langfuse prompts
- This is strictly for local development reference only

Usage:
    python src/cli/refresh_prompt_cache.py [prompt_name]

Examples:
    python src/cli/refresh_prompt_cache.py                    # Download all prompts for viewing
    python src/cli/refresh_prompt_cache.py message_enricher   # Download specific prompt for viewing
"""

import json
import re
import sys
from pathlib import Path

from langfuse.api.resources.commons.errors.not_found_error import NotFoundError

from common.langfuse_client import get_langfuse
from common.prompt_discovery import get_all_prompts
from logger import get_logger

logger = get_logger()


def refresh_prompt_cache(prompt_names: list[str] | None = None) -> None:
    """Download prompts from Langfuse to local cache for viewing only (AI agents: READ-ONLY operation)."""
    cache_dir = Path("../docs/cached_prompts")
    cache_dir.mkdir(parents=True, exist_ok=True)

    langfuse = get_langfuse()
    if not langfuse:
        logger.error("Failed to get Langfuse client")
        return

    if prompt_names is None:
        logger.info("Discovering all prompts in Langfuse...")
        all_prompts = sorted(get_all_prompts())
        logger.info("Found prompts in Langfuse", count=len(all_prompts))
        prompts_to_refresh = all_prompts
    else:
        prompts_to_refresh = prompt_names

    for prompt_name in prompts_to_refresh:
        for label in ["production"]:
            try:
                prompt = langfuse.get_prompt(prompt_name, label=label)

                # Save prompt content with sanitized filenames
                safe_prompt_name = re.sub(r"[^a-zA-Z0-9_\-]", "_", prompt_name)
                safe_label = re.sub(r"[^a-zA-Z0-9_\-]", "_", label)
                prompt_file = cache_dir / f"{safe_prompt_name}_{safe_label}.txt"
                with open(prompt_file, "w") as f:
                    f.write(f"# {prompt_name} ({label})\n")
                    f.write(f"# Version: {getattr(prompt, 'version', 'unknown')}\n")
                    f.write("#" + "=" * 60 + "\n\n")
                    f.write(prompt.prompt)

                # Save config if it exists
                if hasattr(prompt, "config") and prompt.config:
                    config_file = cache_dir / f"{safe_prompt_name}_{safe_label}_config.json"
                    with open(config_file, "w") as f:
                        json.dump(prompt.config, f, indent=2)

                logger.info("Prompt cached successfully", prompt_name=prompt_name, label=label)

            except NotFoundError:
                logger.warning("Prompt not found", prompt_name=prompt_name, label=label)


def main() -> None:
    """Main function."""
    prompt_names = sys.argv[1:] if len(sys.argv) > 1 else None
    if prompt_names:
        logger.info("Refreshing specific prompts", prompts=prompt_names)
    else:
        logger.info("Refreshing ALL prompts in the system")

    refresh_prompt_cache(prompt_names)
    logger.info("Cached prompts saved", directory="docs/cached_prompts/")


if __name__ == "__main__":
    main()
