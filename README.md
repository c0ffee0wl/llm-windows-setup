# LLM Tools Installation Script for Windows

**GitHub Repository**: https://github.com/c0ffee0wl/llm-windows-setup

Automated installation script for [Simon Willison's llm CLI tool](https://github.com/simonw/llm) and related AI/LLM command-line utilities for Windows environments.

Based on the [llm-linux-setup](https://github.com/c0ffee0wl/llm-linux-setup) project.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Features](#features)
- [What Gets Installed](#what-gets-installed)
  - [Core Tools](#core-tools)
  - [LLM Plugins](#llm-plugins)
  - [LLM Templates](#llm-templates)
  - [Additional Tools](#additional-tools)
  - [PowerShell Integration](#powershell-integration)
- [System Requirements](#system-requirements)
- [Installation](#installation)
  - [Quick Start](#quick-start)
  - [Execution Policy](#execution-policy)
- [Updating](#updating)
- [Usage](#usage)
  - [Basic LLM Usage](#basic-llm-usage)
  - [AI Command Completion](#ai-command-completion)
  - [Azure OpenAI Models](#azure-openai-models)
  - [Clipboard Aliases (macOS Compatibility)](#clipboard-aliases-macos-compatibility)
  - [Additional Tools](#additional-tools-1)
  - [Context System (PowerShell History for AI)](#context-system-powershell-history-for-ai)
- [Configuration](#configuration)
  - [Configuration Files](#configuration-files)
  - [PowerShell Integration Files](#powershell-integration-files)
  - [PowerShell Profile Locations](#powershell-profile-locations)
  - [Changing Default Model](#changing-default-model)
  - [Managing API Keys](#managing-api-keys)
- [Troubleshooting](#troubleshooting)
  - [Command completion not working](#command-completion-not-working)
  - [Azure API errors](#azure-api-errors)
  - ["llm" command not found](#llm-command-not-found)
  - [Chocolatey installation fails](#chocolatey-installation-fails)
  - [npm permissions errors](#npm-permissions-errors)
- [Supported PowerShell Versions](#supported-powershell-versions)
- [Documentation](#documentation)
- [Differences from Linux Version](#differences-from-linux-version)
  - [Windows-Specific Features](#windows-specific-features)
  - [Excluded Features](#excluded-features)
- [License](#license)
- [Contributing](#contributing)
- [Credits](#credits)
- [Support](#support)
- [Related Projects](#related-projects)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Features

- ✅ **One-command installation** - Run once to install everything
- ✅ **Self-updating** - Re-run to update all tools automatically
- ✅ **Safe git updates** - Pulls latest script version before execution
- ✅ **Multi-PowerShell support** - Works with both PowerShell 5.1 and PowerShell 7+
- ✅ **Azure OpenAI integration** - Configured for Azure Foundry
- ✅ **AI command completion** - Press Ctrl+N for intelligent command suggestions
- ✅ **Automatic session recording** - Terminal history captured for AI context
- ✅ **AI-powered context retrieval** - Query your command history with `context` or `llm --tool context`
- ✅ **Smart admin handling** - Only requires admin for Chocolatey installation

## What Gets Installed

### Core Tools
- **llm** - Simon Willison's LLM CLI tool
- **uv** - Modern Python package installer
- **Python 3** - Via Chocolatey
- **Node.js 22.x** - Via Chocolatey (latest in 22 branch)
- **Git** - Via Chocolatey (if not already installed)
- **jq** - JSON processor
- **Claude Code** - Anthropic's agentic coding CLI
- **OpenCode** - AI coding agent for terminal

### LLM Plugins
- **llm-gemini** - Google Gemini models integration
- **llm-openrouter** - OpenRouter API integration
- **llm-anthropic** - Anthropic Claude models integration
- **llm-cmd** - Command execution and management
- **llm-cmd-comp** - AI-powered command completion (powers Ctrl+N)
- **llm-tools-sqlite** - SQLite database tool
- **llm-tools-context** - Terminal history integration (exposes `context` tool to AI)
- **llm-fragments-site-text** - Web page content extraction
- **llm-fragments-pdf** - PDF content extraction
- **llm-fragments-github** - GitHub repository integration
- **llm-jq** - JSON processing tool
- **llm-templates-fabric** - Fabric prompt templates

### LLM Templates
- **assistant.yaml** - Custom assistant template with security/IT expertise configuration
- **code.yaml** - Code-only generation template (outputs clean, executable code without markdown)

### Additional Tools
- **gitingest** - Convert Git repositories to LLM-friendly text
- **files-to-prompt** - File content formatter for LLM prompts
- **context** - PowerShell history extraction for AI context retrieval

### PowerShell Integration
- AI-powered command completion (Ctrl+N)
- Custom llm wrapper with default assistant template
- Automatic PowerShell transcript logging for AI context
- Clipboard aliases (`pbcopy`, `pbpaste`) for macOS compatibility
- PATH configuration for all installed tools

## System Requirements

- **OS**: Windows 10, Windows 11, or Windows Server 2016+
- **PowerShell**: 5.1 or higher (PowerShell 7+ supported)
- **Internet**: Required for installation and API access
- **Disk Space**: ~1GB for all tools and dependencies
- **Admin Rights**: Only required for initial Chocolatey installation

## Installation

### Quick Start

1. **Clone the repository**:
   ```powershell
   git clone https://github.com/c0ffee0wl/llm-windows-setup.git
   cd llm-windows-setup
   ```

2. **Run the installation script**:

   - **If Chocolatey is NOT installed** (first-time installation):
     ```powershell
     # Run as Administrator (required for Chocolatey installation)
     .\Install-LlmTools.ps1
     ```

   - **If Chocolatey IS already installed**:
     ```powershell
     # Can run as regular user
     .\Install-LlmTools.ps1
     ```

3. **Follow the prompts**:
   - You'll be asked if you want to configure Azure OpenAI (optional)
   - If yes, provide your Azure API key and resource URL

### Execution Policy

If you get an execution policy error, run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Updating

Simply re-run the installation script:

```powershell
cd llm-windows-setup
.\Install-LlmTools.ps1
```

The script will automatically:
1. Check for script updates from the git repository
2. Pull latest changes and re-execute if updates are found
3. Update llm and all plugins
4. Update custom templates (assistant.yaml)
5. Update gitingest, files-to-prompt, Claude Code, and OpenCode
6. Refresh PowerShell integration files

**Note**: Updates do not require Administrator privileges (unless you need to update Chocolatey packages). The git pull happens automatically during Phase 0.

## Usage

### Basic LLM Usage

```powershell
# Ask a question (uses assistant template by default)
llm "What is the capital of France?"

# Start an interactive chat session
llm chat "Let's discuss PowerShell"

# Use a specific model
llm -m azure/gpt-5 "Explain quantum computing"

# List available models
llm models list

# View installed plugins
llm plugins
```

### AI Command Completion

Type a partial command or describe what you want in natural language, then press **Ctrl+N**:

```powershell
# Type: list all json files recursively
# Press Ctrl+N
# Result: Get-ChildItem -Recurse -Filter *.json
```

The AI will suggest and insert the command automatically.

### Azure OpenAI Models

The following models are configured (if you set up Azure OpenAI):
- `azure/gpt-5` - GPT-5
- `azure/gpt-5-mini` - GPT-5 Mini (default)
- `azure/gpt-5-nano` - GPT-5 Nano
- `azure/o4-mini` - O4 Mini
- `azure/gpt-4.1` - GPT-4.1

### Clipboard Aliases (macOS Compatibility)

```powershell
# Copy to clipboard (like macOS pbcopy)
"Hello World" | pbcopy

# Paste from clipboard (like macOS pbpaste)
pbpaste
```

### Additional Tools

```powershell
# Convert Git repositories to LLM-friendly text
gitingest https://github.com/user/repo
gitingest C:\path\to\local\repo

# Convert files to LLM-friendly format
files-to-prompt src\*.py

# Use OpenCode
opencode

# Use Claude Code
claude
```

### Context System (PowerShell History for AI)

PowerShell sessions are automatically logged via transcript recording. The AI can retrieve your terminal history for better context:

```powershell
# Show last command
context

# Show last 5 commands
context 5

# Show entire session history
context all

# Check transcript file location
$env:TRANSCRIPT_LOG_FILE

# Check transcript directory
$env:TRANSCRIPT_LOG_DIR
```

**How it works:**
- Each PowerShell session automatically starts transcript logging
- Transcripts are stored in `$env:TRANSCRIPT_LOG_DIR` (configurable during installation)
- The `context` command parses transcripts and extracts command history
- The `llm-tools-context` plugin exposes this to AI models for contextual assistance
- AI can call `context(N)` to retrieve last N commands when helping with your tasks

**Storage options:**
- **Temporary** (default): `%TEMP%\PowerShell_Transcripts` - cleared on logout/reboot
- **Permanent**: `%USERPROFILE%\PowerShell_Transcripts` - survives reboots

## Configuration

### Configuration Files

- `%APPDATA%\io.datasette.llm\` - LLM configuration directory
  - `extra-openai-models.yaml` - Azure OpenAI model definitions
  - `templates\assistant.yaml` - Custom assistant template (auto-installed)
  - API keys stored securely via llm's key management

### PowerShell Integration Files

Located in the `integration\` subdirectory:
- `integration\llm-integration.ps1` - Unified integration for PS5 & PS7

This file is automatically sourced from your PowerShell profile.

### PowerShell Profile Locations

The installation script adds integration to:
- **PowerShell 5**: `%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`
- **PowerShell 7**: `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

### Changing Default Model

```powershell
llm models default azure/gpt-5
```

### Managing API Keys

```powershell
# Set Azure key
llm keys set azure

# View key storage path
llm keys path

# List all configured keys
llm keys
```

## Troubleshooting

### Command completion not working

1. Restart your PowerShell session or reload your profile:
   ```powershell
   . $PROFILE
   ```

2. Verify llm is in PATH:
   ```powershell
   Get-Command llm
   ```

3. Test llm command completion manually:
   ```powershell
   llm cmdcomp "list files"
   ```

4. Check if PSReadLine is loaded:
   ```powershell
   Get-Module PSReadLine
   ```

### Azure API errors

1. Verify API key is set:
   ```powershell
   llm keys get azure
   ```

2. Check model configuration:
   ```powershell
   Get-Content $env:APPDATA\io.datasette.llm\extra-openai-models.yaml
   ```

3. Update the API base URL in the YAML file if needed

### "llm" command not found

1. Check if the installation completed successfully
2. Verify PATH includes: `%USERPROFILE%\.local\bin`
3. Restart PowerShell
4. Re-run the installation script

### Chocolatey installation fails

1. Ensure you're running PowerShell as Administrator
2. Check your internet connection
3. Verify your execution policy allows scripts:
   ```powershell
   Get-ExecutionPolicy
   ```
4. Install Chocolatey manually: https://chocolatey.org/install

### npm permissions errors

The script configures npm to use user-level global installs. If you still get permission errors:

```powershell
npm config set prefix "$env:USERPROFILE\.npm-global"
```

Then add `%USERPROFILE%\.npm-global` to your PATH.

## Supported PowerShell Versions

- PowerShell 5.1 (Windows PowerShell - included with Windows 10/11)
- PowerShell 7.x (PowerShell Core - cross-platform)

## Documentation

- [LLM Documentation](https://llm.datasette.io/)
- [LLM Plugins Directory](https://llm.datasette.io/en/stable/plugins/directory.html)
- [Pedantic Journal - LLM Guide](https://pedanticjournal.com/llm/)
- [Gitingest Documentation](https://github.com/coderamp-labs/gitingest)
- [Files-to-Prompt](https://github.com/danmackinlay/files-to-prompt)
- [Claude Code Documentation](https://docs.anthropic.com/claude/docs/claude-code)
- [OpenCode Documentation](https://opencode.ai/docs)

## Differences from Linux Version

This Windows version differs from the [Linux version](https://github.com/c0ffee0wl/llm-linux-setup) in the following ways:

### Windows-Specific Features
- ✅ **Chocolatey** - Package manager for Windows
- ✅ **Unified PowerShell integration** - Single file works with PS5 and PS7
- ✅ **Windows clipboard aliases** - `pbcopy`/`pbpaste` for macOS compatibility
- ✅ **PowerShell transcript logging** - Automatic session history capture for AI context
- ✅ **Smart admin handling** - Only requires admin for Chocolatey installation

### Excluded Features
- ❌ **Cargo/Rust installation** - Not included
- ❌ **Asciinema** - Terminal recording not included

## License

This installation script is provided as-is under the MIT License. Individual tools have their own licenses:
- llm: Apache 2.0
- See individual tool repositories for details

## Contributing

To modify or extend this installation:

1. Fork the repository
2. Make your changes
3. Test on Windows 10/11
4. Submit a pull request

## Credits

- [Simon Willison](https://github.com/simonw) - llm CLI tool
- [Dan Mackinlay](https://github.com/danmackinlay) - files-to-prompt fork
- [Damon McMinn](https://github.com/damonmcminn) - llm-templates-fabric fork
- [c0ffee0wl](https://github.com/c0ffee0wl) - Original llm-linux-setup project

## Support

For issues, questions, or suggestions:
- Open an issue: https://github.com/c0ffee0wl/llm-windows-setup/issues

## Related Projects

- [llm-linux-setup](https://github.com/c0ffee0wl/llm-linux-setup) - Linux/Debian version
