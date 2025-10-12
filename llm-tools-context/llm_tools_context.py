import llm
import subprocess
import sys


def context(input: str) -> str:
    """
    Execute the context command to get PowerShell command history including outputs.

    Args:
        input: empty for last entry, number of recent entries to show, or "all" for entire history

    Returns:
        Session history from PowerShell transcripts, including commands and outputs.
        Each line of the history is prefixed with #c#
    """
    args = ["context"]

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
        # On Windows, context.py should be in PATH or .local\bin
        result = subprocess.run(args, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error running context command: {e.stderr}"
    except FileNotFoundError:
        return "Error: 'context' command not found in PATH. Ensure context.py is installed."


@llm.hookimpl
def register_tools(register):
    register(context)
