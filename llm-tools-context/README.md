# llm-tools-context

LLM plugin for extracting PowerShell command history from transcripts.

## Overview

This plugin provides the `context` tool to LLM, allowing AI to retrieve recent PowerShell commands and their outputs from session transcripts.

## Installation

Automatically installed by `Install-LlmTools.ps1`.

Manual installation:
```powershell
llm install /path/to/llm-tools-context
```

## Requirements

- PowerShell transcription enabled (automatically enabled by llm-integration.ps1)
- Python 3.8+
- context.py script in PATH

## Usage

The AI can call the `context` tool to retrieve command history:

```python
# Get last command
context("")

# Get last 5 commands
context("5")

# Get all commands
context("all")
```

## How it Works

1. PowerShell transcripts are automatically recorded to `$env:TRANSCRIPT_LOG_DIR`
2. The `context.py` script parses transcript files
3. This plugin exposes the context command as an LLM tool
4. AI can retrieve and analyze your command history

## See Also

- [context.py](../context/context.py) - Transcript parser
- [llm-integration.ps1](../integration/llm-integration.ps1) - Automatic transcription
- [CLAUDE.md](../CLAUDE.md) - Full documentation
