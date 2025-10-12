#!/usr/bin/env python3
"""
Context - Extract PowerShell command history from transcript files

Extracts prompt blocks (prompt + command + output) from PowerShell transcript files.
Each block contains everything from one prompt to the next, preserving exact formatting.

Usage:
    context          # Show last prompt block (default)
    context 5        # Show last 5 prompt blocks
    context all      # Show entire session
    context -a       # Show entire session
    context -e       # Output TRANSCRIPT_LOG_FILE environment variable
"""

import os
import sys
import re
import argparse
from pathlib import Path
from typing import List, Tuple, Optional


def find_transcript_file() -> Optional[str]:
    """Find the current session's transcript file"""
    # First, check environment variable
    if "TRANSCRIPT_LOG_FILE" in os.environ:
        transcript_file = os.environ["TRANSCRIPT_LOG_FILE"]
        if os.path.exists(transcript_file):
            return transcript_file

    # Fall back to finding most recent transcript in log directory
    log_dir = os.environ.get("TRANSCRIPT_LOG_DIR")
    if not log_dir:
        # Default locations
        temp_dir = os.environ.get("TEMP", "C:\\Windows\\Temp")
        log_dir = os.path.join(temp_dir, "PowerShell_Transcripts")

    if not os.path.exists(log_dir):
        return None

    # Find all .txt files
    transcript_files = list(Path(log_dir).glob("PowerShell_*.txt"))

    if not transcript_files:
        return None

    # Return most recently modified file
    return str(max(transcript_files, key=lambda p: p.stat().st_mtime))


def parse_transcript(text: str) -> List[str]:
    """
    Parse PowerShell transcript and extract command blocks.

    PowerShell transcripts have this structure:
    - Transcript header (starts with "**********************")
    - Each command is preceded by "PS <path>>" prompt
    - Command output follows
    - Commands at column 0, continuation lines indented

    Returns list of blocks (prompt + command + output).
    """
    lines = text.split('\n')
    blocks = []
    current_block = []
    in_command_block = False

    # Skip transcript header (lines starting with ****)
    start_idx = 0
    for i, line in enumerate(lines):
        if not line.startswith('****'):
            start_idx = i
            break

    # PowerShell prompt pattern: PS <path>>
    # Also match custom prompts that end with > or $
    prompt_pattern = re.compile(r'^PS\s+[A-Za-z]:\\.*?>\s*$|^PS\s+[A-Za-z]:\\.*?>\s+\S')

    for line in lines[start_idx:]:
        # Skip transcript footer
        if line.startswith('****'):
            if current_block:
                blocks.append('\n'.join(current_block))
                current_block = []
            continue

        # Detect prompt line using transcript structure
        # In transcripts, prompts are at column 0 and match PS pattern
        if prompt_pattern.match(line):
            # Save previous block
            if current_block:
                blocks.append('\n'.join(current_block))
                current_block = []

            current_block.append(line)
            in_command_block = True
        elif in_command_block:
            # Everything after prompt is part of the block (command + output)
            current_block.append(line)

    # Add final block
    if current_block:
        blocks.append('\n'.join(current_block))

    return blocks


def filter_self_referential(blocks: List[str]) -> List[str]:
    """
    Remove the last block if it's just the current context command with no output.
    """
    if not blocks:
        return blocks

    last_block = blocks[-1]
    lines = [l for l in last_block.split('\n') if l.strip()]

    # Check if last block is just a prompt with 'context' command
    if len(lines) <= 1:
        # Single line, probably just empty prompt
        return blocks[:-1]
    elif len(lines) == 2:
        # Check if second line is 'context' command
        if re.search(r'\bcontext\b', lines[1]):
            return blocks[:-1]

    return blocks


def format_output(blocks: List[str]) -> str:
    """Format prompt blocks for display"""
    if not blocks:
        return "#c# No commands found in transcript."

    result = []
    for block in blocks:
        # Prefix each line of the block
        for line in block.split('\n'):
            result.append(f"#c# {line}")
        result.append("#c# ")  # Blank line separator

    return '\n'.join(result)


def main():
    # Parse arguments
    parser = argparse.ArgumentParser(
        description='Extract command blocks from PowerShell transcript'
    )
    parser.add_argument(
        'count',
        nargs='?',
        default=1,
        help='Number of recent blocks to show or "all" for entire history (default: 1)'
    )
    parser.add_argument(
        '-e', '--environment',
        action='store_true',
        help='Output TRANSCRIPT_LOG_FILE environment variable'
    )
    parser.add_argument(
        '-a', '--all',
        action='store_true',
        help='Show entire history'
    )

    args = parser.parse_args()

    # Find transcript file
    transcript_file = find_transcript_file()

    # Handle -e/--environment flag
    if args.environment:
        if transcript_file:
            # PowerShell environment variable syntax
            env_cmd = f"$env:TRANSCRIPT_LOG_FILE = '{transcript_file}'"
            print(env_cmd)

            # Try to copy to clipboard (Windows)
            try:
                import subprocess
                subprocess.run(
                    ['clip'],
                    input=env_cmd.encode('utf-16le'),
                    check=True,
                    capture_output=True
                )
                print("# Command copied to clipboard", file=sys.stderr)
            except (subprocess.CalledProcessError, FileNotFoundError):
                # clip not available - silently continue
                pass
        else:
            print("# No PowerShell transcript found", file=sys.stderr)
            sys.exit(1)
        return

    # Determine if we want all history
    show_all = args.all or args.count == 'all'

    if show_all:
        count = None
    else:
        try:
            count = int(args.count)
            if count < 1:
                raise ValueError()
        except (ValueError, TypeError):
            print("Error: Please provide a positive number or 'all'", file=sys.stderr)
            parser.print_help(sys.stderr)
            sys.exit(1)

    if not transcript_file:
        print("Error: No PowerShell transcript found.", file=sys.stderr)
        print("Make sure transcription is enabled in your PowerShell profile.", file=sys.stderr)
        sys.exit(1)

    # Read and parse transcript
    try:
        with open(transcript_file, 'r', encoding='utf-16-le', errors='replace') as f:
            text = f.read()
    except UnicodeDecodeError:
        # Try UTF-8 as fallback
        try:
            with open(transcript_file, 'r', encoding='utf-8', errors='replace') as f:
                text = f.read()
        except Exception as e:
            print(f"Error reading transcript: {e}", file=sys.stderr)
            sys.exit(1)

    # Extract blocks
    blocks = parse_transcript(text)

    # Filter self-referential context commands
    blocks = filter_self_referential(blocks)

    # Get requested number of blocks
    if count is None:
        selected_blocks = blocks
    else:
        selected_blocks = blocks[-count:] if blocks else []

    # Display results
    print(format_output(selected_blocks))


if __name__ == "__main__":
    main()
