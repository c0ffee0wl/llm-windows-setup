#!/usr/bin/env python3
"""
Context - Extract PowerShell command history from transcript files

Extracts prompt blocks (prompt + command + output) from PowerShell transcript files.
Uses language-agnostic parsing based on universal transcript structure elements.

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
from typing import List, Optional


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
    Parse PowerShell transcript using universal structure elements.

    PowerShell transcripts have this structure (in all languages):
    - **********************
    - [localized header/footer text]
    - **********************
    - PS <path>> command
    - output
    - **********************

    We use only the universal elements:
    1. **** separators (never localized)
    2. PS <path>> prompt pattern (never localized)

    Returns list of command blocks (prompt + command + output).
    """

    # Normalize line endings and strip BOM if present
    text = text.replace('\r\n', '\n').replace('\r', '\n')

    # Remove UTF-16 BOM if present (shows as \ufeff)
    if text.startswith('\ufeff'):
        text = text[1:]

    # Also remove other potential BOM artifacts
    text = text.lstrip('\x00\ufeff')

    # Filter out lines from previous context command outputs
    # This prevents nested #c# prefixes when context is invoked multiple times
    lines = text.split('\n')
    lines = [line for line in lines if not line.lstrip().startswith('#c#')]
    text = '\n'.join(lines)

    # Split on lines that are ONLY asterisks (20+)
    # Using MULTILINE flag to match at start/end of lines
    separator_pattern = r'^\*{20,}$'
    blocks = re.split(separator_pattern, text, flags=re.MULTILINE)

    # Universal PowerShell prompt pattern (works in all languages)
    # Matches: PS C:\path> or PS /path> (PowerShell Core on Linux)
    prompt_pattern = re.compile(r'^PS\s+[A-Za-z]:[^\n]*>\s*', re.MULTILINE)

    command_blocks = []

    for block in blocks:
        block = block.strip()

        # Skip empty blocks
        if not block:
            continue

        # Skip header blocks (contain transcript start/end text)
        # These never have PS prompts in them
        if not prompt_pattern.search(block):
            continue

        # Skip error-only blocks (e.g., Ctrl+C interruptions)
        # These blocks look like:
        # PS C:\path> TerminatingError(): "Die Pipeline wurde beendet."
        # >> TerminatingError(): "Die Pipeline wurde beendet."
        # Extract the content after the PS prompt
        prompt_match = prompt_pattern.search(block)
        if prompt_match:
            content_after_prompt = block[prompt_match.end():].strip()
            # Check if this is just an error message, not a real command
            if content_after_prompt.startswith('TerminatingError('):
                continue

        # This is a command block - keep it
        command_blocks.append(block)

    return command_blocks


def filter_self_referential(blocks: List[str]) -> List[str]:
    """
    Remove the last block if it's just the current context command with no output.
    """
    if not blocks:
        return blocks

    last_block = blocks[-1]
    lines = [l.strip() for l in last_block.split('\n') if l.strip()]

    # If last block is very short, it might just be the current prompt
    if len(lines) <= 2:
        # Check if it contains 'context' command
        block_text = '\n'.join(lines).lower()
        if 'context' in block_text:
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
    parser.add_argument(
        '--debug',
        action='store_true',
        help='Show debug information'
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
            # Convert negative to positive with a note
            if count < 0:
                count = abs(count)
                print(f"#c# context usage note: Using {count} (converted from negative value)", file=sys.stderr)
            # Still validate that it's not zero
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

    # Read transcript with proper encoding detection
    # Try multiple encodings in order of likelihood
    encodings_to_try = [
        'utf-8',           # Most common on modern systems
        'utf-16-le',       # PowerShell default on Windows
        'utf-16-be',       # Alternate byte order
        'cp1252',          # Windows ANSI (Western European)
        'latin-1',         # Fallback (never fails but may give garbage)
    ]

    text = None
    encoding_used = None

    for encoding in encodings_to_try:
        try:
            with open(transcript_file, 'r', encoding=encoding) as f:
                text = f.read()

            # Verify the text makes sense (contains expected patterns)
            # If it's the wrong encoding, we'll get garbage
            if '****' in text or re.search(r'PS\s+[A-Za-z]:', text):
                encoding_used = encoding
                break
            else:
                # Text decoded but doesn't look like a PowerShell transcript
                # Try next encoding
                text = None
                continue

        except (UnicodeDecodeError, UnicodeError):
            # This encoding didn't work, try next
            continue
        except Exception as e:
            # Other error (file not found, permission denied, etc.)
            print(f"Error reading transcript: {e}", file=sys.stderr)
            sys.exit(1)

    if text is None:
        print(f"Error: Could not decode transcript with any known encoding", file=sys.stderr)
        print(f"Tried: {', '.join(encodings_to_try)}", file=sys.stderr)
        sys.exit(1)

    # Debug mode: show raw transcript info
    if args.debug:
        print(f"# Transcript file: {transcript_file}", file=sys.stderr)
        print(f"# Encoding used: {encoding_used}", file=sys.stderr)
        print(f"# File size: {len(text)} characters", file=sys.stderr)
        print(f"# Contains **** separators: {'****' in text}", file=sys.stderr)
        # Extract pattern to avoid f-string backslash restriction
        ps_prompt_pattern = r'PS\s+[A-Za-z]:'
        print(f"# Contains PS prompts: {bool(re.search(ps_prompt_pattern, text))}", file=sys.stderr)

        # Show first few characters (to debug encoding issues)
        first_chars = repr(text[:100])
        print(f"# First 100 chars: {first_chars}", file=sys.stderr)

        # Count separator lines
        separator_count = len(re.findall(r'^\*{20,}$', text, re.MULTILINE))
        print(f"# Separator lines found: {separator_count}", file=sys.stderr)
        print("", file=sys.stderr)

    # Extract blocks
    blocks = parse_transcript(text)

    if args.debug:
        print(f"# Found {len(blocks)} command blocks", file=sys.stderr)

        # Show first few characters of each block
        for i, block in enumerate(blocks[:5]):  # Show first 5 blocks
            preview = block[:80].replace('\n', '\\n')
            print(f"# Block {i+1}: {repr(preview)}...", file=sys.stderr)

        print("", file=sys.stderr)

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
