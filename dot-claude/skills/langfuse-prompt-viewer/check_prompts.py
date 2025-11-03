#!/usr/bin/env python3
"""
CLI script to check status of all prompts in Langfuse.

INSTRUCTIONS FOR CLAUDE/AI AGENTS:
- This script is READ-ONLY - it only verifies prompt existence in Langfuse
- DO NOT use this script to modify or push changes to Langfuse prompts
- DO NOT create or update prompts
- This is strictly a verification tool for local development

This script lists all prompts from Langfuse and shows their status
in the current environment with colored indicators.
"""

import os
import sys

from dotenv import load_dotenv
from langfuse.api.resources.commons.errors.not_found_error import NotFoundError

load_dotenv()

from common.langfuse_client import get_langfuse
from common.prompt_discovery import get_all_prompts
from logger import get_logger

logger = get_logger()
langfuse = get_langfuse()


# Color codes for terminal output
class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    WHITE = "\033[97m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


def check_prompt_exists(prompt_type: str) -> tuple[bool, str]:
    """
    Check if a prompt exists in Langfuse for the current environment only.

    Args:
        prompt_type: The prompt type to check

    Returns:
        Tuple of (exists, environment) where environment is the label where it was found
    """
    # Check environment label only
    env = os.environ["ENVIRONMENT"].lower()

    try:
        langfuse.get_prompt(prompt_type, label=env, cache_ttl_seconds=0)
        return True, env
    except NotFoundError:
        return False, "none"


def print_prompt_status(prompt_type: str, exists: bool, environment: str = "") -> None:
    """Print the status of a prompt with colored indicators."""
    if exists:
        indicator = f"{Colors.GREEN}✓{Colors.RESET}"
        env_info = f" ({environment})" if environment else ""
        print(f"{indicator} {Colors.WHITE}{prompt_type}{Colors.RESET}{env_info}")
    else:
        indicator = f"{Colors.RED}✗{Colors.RESET}"
        print(f"{indicator} {Colors.WHITE}{prompt_type}{Colors.RESET} - {Colors.RED}NOT FOUND{Colors.RESET}")


def main() -> None:
    """Main function to check all prompts."""
    print(f"{Colors.BOLD}Checking All Langfuse Prompts{Colors.RESET}")
    env = os.environ["ENVIRONMENT"]
    print(f"Environment: {Colors.WHITE}{env}{Colors.RESET}")
    print("=" * 50)

    # Get all prompts from Langfuse
    try:
        all_prompts = get_all_prompts()
        logger.info(f"Found {len(all_prompts)} total prompts in Langfuse")
    except (NotFoundError, AttributeError, KeyError) as e:
        print(f"{Colors.RED}Failed to fetch prompts from Langfuse: {e}{Colors.RESET}")
        sys.exit(1)

    # Track statistics
    total_prompts = len(all_prompts)
    found_prompts = 0

    # Check each prompt's availability in current environment
    print(f"\n{Colors.BOLD}All Prompts in Langfuse ({total_prompts} total):{Colors.RESET}")
    for prompt_name in sorted(all_prompts):
        exists, environment = check_prompt_exists(prompt_name)
        print_prompt_status(prompt_name, exists, environment)
        if exists:
            found_prompts += 1

    # Print summary
    print("\n" + "=" * 50)
    print(f"{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"Total prompts in Langfuse: {Colors.WHITE}{total_prompts}{Colors.RESET}")
    print(f"Available in {env}: {Colors.GREEN}{found_prompts}{Colors.RESET}")
    print(f"Missing from {env}: {Colors.RED}{total_prompts - found_prompts}{Colors.RESET}")

    if found_prompts == total_prompts:
        print(f"\n{Colors.GREEN}✓ All prompts available in {env}!{Colors.RESET}")
        sys.exit(0)
    else:
        print(f"\n{Colors.RED}✗ {total_prompts - found_prompts} prompts missing from {env}{Colors.RESET}")
        sys.exit(1)


if __name__ == "__main__":
    main()
