import llm
import subprocess
import sys
import os
from pathlib import Path


def context(input: str) -> str:
    """
    Execute the context command to get PowerShell command history including outputs.

    Args:
        input: empty for last entry, number of recent entries to show, or "all" for entire history

    Returns:
        Session history from PowerShell transcripts, including commands and outputs.
        Each line of the history is prefixed with #c#
    """
    # Find context.py in standard location
    # On Windows, subprocess.run(["context"]) fails because it can't find .bat files
    # So we call Python directly with the full path to context.py
    user_home = os.path.expanduser("~")
    context_script = Path(user_home) / ".local" / "bin" / "context.py"

    if not context_script.exists():
        return f"Error: context.py not found at {context_script}"

    # Call Python directly with context.py (bypasses .bat wrapper issue on Windows)
    args = [sys.executable, str(context_script)]

    # Validate and sanitize input to prevent shell injection
    if input and input.strip():
        input_clean = input.strip()

        # Only allow "all", "-a", "--all", or positive integers
        if input_clean.lower() in ["all", "-a", "--all"]:
            args.append(input_clean.lower())
        elif input_clean.isdigit() and int(input_clean) > 0:
            args.append(input_clean)
        else:
            return f"Error: Invalid input '{input_clean}'. Must be 'all', '-a', '--all', or a positive integer."

    try:
        result = subprocess.run(args, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error running context command: {e.stderr}"
    except Exception as e:
        return f"Error: {str(e)}"


@llm.hookimpl
def register_tools(register):
    register(context)
