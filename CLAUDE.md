# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Windows PowerShell-based installation script for Simon Willison's `llm` CLI tool and related AI/LLM utilities. It's the Windows equivalent of [llm-linux-setup](https://github.com/c0ffee0wl/llm-linux-setup), designed for Windows 10/11/Server with PowerShell 5.1+ and PowerShell 7+ support.

## Architecture

### Three-Component Design

1. **Install-LlmTools.ps1** - Main installer with 9 phases
2. **integration/llm-integration.ps1** - Unified PowerShell integration (PS5 & PS7)
3. **llm-template/assistant.yaml** - Custom LLM template for security/IT context

### Smart Admin Privilege Handling

The installation script uses a two-tier privilege model:

- **Phase 0**: Admin check - only required for initial Chocolatey installation
- **Phases 1-9**: User-scoped installations (pipx, uv, llm, npm global with user prefix)

This allows users to:
- Run first-time install as admin (for Chocolatey)
- Run all subsequent updates as regular user
- Use `git pull` without elevation

### Installation Phases

The script executes in 10 sequential phases:

0. **Self-Update** - Check git repository for updates, auto-pull and re-execute if needed
1. **Admin Check & Chocolatey** - Install Chocolatey if missing (admin required)
2. **Prerequisites** - Install Python 3, Node.js 22.x, Git, jq via Chocolatey
3. **Python Tools** - Install pipx, uv (user-scoped via `--user`)
4. **LLM Core** - Install `llm` via `uv tool install`
5. **Azure OpenAI Config** - Interactive setup (optional, first-run detection)
6. **LLM Plugins** - Install plugins including llm-cmd, llm-anthropic, llm-jq, llm-tools-sqlite
7. **LLM Templates** - Copy assistant.yaml with smart update detection
8. **PowerShell Integration** - Add sourcing to PS5 and PS7 profiles
9. **Additional Tools** - Install repomix, gitingest, files-to-prompt, Claude Code, OpenCode

### PowerShell Integration Architecture

**Single-file approach**: `llm-integration.ps1` works for both PS5 and PS7 by:
- Using PSReadLine (available in both versions)
- Conditionally detecting PowerShell version when needed
- Setting up PATH for all tools (Python Scripts, .local\bin, npm global)

**Key features**:
- **llm wrapper function** - Automatically applies `-t assistant` template to prompts while excluding management commands (models, keys, plugins, etc.)
- **Ctrl+N keybinding** - AI command completion via `llm cmdcomp` using PSReadLine
- **Clipboard aliases** - `pbcopy`/`pbpaste` functions for macOS compatibility

### Template Context System

The `assistant.yaml` template is Windows-specific with:
- **OS Context**: Windows 10/11/Server (Linux available via WSL2)
- **Shell**: PowerShell 5.1/7 in Windows Terminal
- **Language**: German responses, English code
- **Security Focus**: IT security, ethical hacking, forensics expertise
- **NO context tool** - Unlike Linux version, terminal history integration not included

## Key Design Patterns

### First-Run Detection

Used in multiple components to avoid re-prompting:

```powershell
# Azure OpenAI config
$isFirstRun = -not (Test-Path $extraModelsFile)

# Template updates
if (Test-Path $sourceTemplate -and Test-Path $destTemplate) {
    # Compare file hashes, prompt only if different
}

# PowerShell profile integration
if ($profileContent -notmatch "llm-integration\.ps1") {
    # Add integration snippet
}
```

### Template Auto-Application Logic

The llm wrapper function intelligently decides when to apply the assistant template:

1. **Skip template if**:
   - Management command (models, keys, plugins, etc.)
   - User specified `-c` (continue conversation)
   - User specified `-t` (custom template)
   - User specified `-s` (custom system prompt)

2. **Apply template for**:
   - Direct prompts: `llm "question"`
   - Chat sessions: `llm chat "topic"` → `llm chat -t assistant "topic"`

### PATH Management Strategy

Integration file dynamically adds to PATH in this order:
1. Python user scripts (`%APPDATA%\Python\Python*\Scripts`)
2. User local bin (`%USERPROFILE%\.local\bin`)
3. npm global (`%APPDATA%\npm` or `%USERPROFILE%\.npm-global`)

This ensures uv tools, pipx tools, and npm global packages are accessible.

## Development Workflows

### Testing the Installation Script

```powershell
# Test in fresh Windows VM
.\Install-LlmTools.ps1

# Test update scenario (re-run after install)
.\Install-LlmTools.ps1

# Test with existing Chocolatey (non-admin)
# Run as regular user after Chocolatey is installed
```

### Adding New LLM Plugins

Add to the `$plugins` array in Phase 5 (lines 429-442):

```powershell
$plugins = @(
    "llm-gemini",
    # ... existing plugins ...
    "your-new-plugin"  # Add here
)
```

### Modifying PowerShell Integration

When editing `integration/llm-integration.ps1`:
- Test on both PS5 and PS7
- Avoid version-specific syntax
- Use `$PSVersionTable.PSVersion` if version detection needed
- Test keybindings: `Set-PSReadLineKeyHandler -Key Ctrl+n`

## Important Constraints

### Excluded Features (vs Linux version)

- **NO Cargo/Rust** - Not installed
- **NO asciinema** - No terminal recording
- **NO auto-logging** - No session logging
- **NO context tool** - No terminal history integration
- **NO Claude Code Router** - Not included

### Self-Update Mechanism

- **Phase 0: Self-Update** - Checks for script updates from git repository on every run
- Auto-detects if running from a git repository
- Compares local commit with remote tracking branch
- Auto-pulls updates and re-executes script if changes detected
- Falls back gracefully if not in a git repository or if update fails

### Windows-Specific Considerations

- **Execution Policy**: May need `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
- **Path separators**: Use `\` for Windows paths in documentation
- **Line endings**: Scripts should use CRLF for Windows compatibility
- **Admin elevation**: Chocolatey packages require admin, everything else is user-scoped
- Remember to not start npm with & because this is a Batch / cmd file that causes an error message when running on windows.

## File Locations

### Installation Script Creates

- `%APPDATA%\io.datasette.llm\extra-openai-models.yaml` - Azure OpenAI model config
- `%APPDATA%\io.datasette.llm\templates\assistant.yaml` - LLM template
- `%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` - PS5 profile
- `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` - PS7 profile

### Tool Installation Paths

- **uv tools** (llm, gitingest, files-to-prompt): `%USERPROFILE%\.local\bin`
- **npm global**: `%APPDATA%\npm` (admin) or `%USERPROFILE%\.npm-global` (user)
- **pipx**: `%USERPROFILE%\.local\bin`

## Azure OpenAI Model Configuration

Models are configured in YAML with this structure:

```yaml
- model_id: azure/gpt-5-mini
  model_name: gpt-5-mini
  api_base: https://YOUR-RESOURCE.openai.azure.com/openai/v1/
  api_key_name: azure
  supports_tools: true
  supports_schema: true
  vision: true
```

Default model is set to `azure/gpt-5-mini` on first run.

## Troubleshooting Command Reference

```powershell
# Verify llm installation
Get-Command llm

# Test command completion manually
llm cmdcomp "list files"

# Check Azure configuration
Get-Content $env:APPDATA\io.datasette.llm\extra-openai-models.yaml

# Verify API key
llm keys get azure

# Reload PowerShell profile
. $PROFILE

# Check PSReadLine module
Get-Module PSReadLine
```

