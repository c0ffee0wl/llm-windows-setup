# LLM Tools Installation Script for Windows

**GitHub Repository**: https://github.com/c0ffee0wl/llm-windows-setup

Automated installation script for [Simon Willison's llm CLI tool](https://github.com/simonw/llm) and related AI/LLM command-line utilities for Windows environments.

Based on the [llm-linux-setup](https://github.com/c0ffee0wl/llm-linux-setup) project.

## Features

- ✅ **One-command installation** - Run once to install everything
- ✅ **Auto-update check** - Script automatically checks for updates on every run
- ✅ **Smart admin handling** - Only requires admin for Chocolatey installation
- ✅ **Multi-PowerShell support** - Works with both PowerShell 5.1 and PowerShell 7+
- ✅ **Azure OpenAI integration** - Configured for Azure Foundry
- ✅ **AI command completion** - Press Ctrl+N for intelligent command suggestions

## What Gets Installed

### Core Tools
- **llm** - Simon Willison's LLM CLI tool
- **uv** - Modern Python package installer
- **Python 3** - Via Chocolatey
- **Node.js 22.x** - Via Chocolatey (latest in 22 branch)
- **Git** - Via Chocolatey (if not already installed)
- **jq** - JSON processor

### LLM Plugins
- llm-gemini
- llm-openrouter
- llm-anthropic
- llm-cmd
- llm-cmd-comp
- llm-tools-sqlite
- llm-fragments-site-text
- llm-fragments-pdf
- llm-fragments-github
- llm-jq
- llm-templates-fabric (Damon McMinn's fork)

### LLM Templates
- **assistant.yaml** - Custom assistant template with security/IT expertise configuration

### Additional Tools
- **repomix** - Repository packager for AI consumption
- **gitingest** - Convert Git repositories to LLM-friendly text
- **files-to-prompt** - File content formatter for LLM prompts
- **Claude Code** - Anthropic's agentic coding CLI
- **OpenCode** - AI coding agent for terminal

### PowerShell Integration
- AI-powered command completion (Ctrl+N)
- Custom llm wrapper with default assistant template
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
5. Update repomix, gitingest, files-to-prompt, Claude Code, and OpenCode
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

### Additional Tools

```powershell
# Package repository for AI analysis
repomix

# Convert Git repositories to LLM-friendly text
gitingest https://github.com/user/repo
gitingest C:\path\to\local\repo

# Convert files to LLM-friendly format
files-to-prompt src\*.py

# Use Claude Code
code

# Use OpenCode
opencode
```

### Clipboard Aliases (macOS Compatibility)

```powershell
# Copy to clipboard (like macOS pbcopy)
"Hello World" | pbcopy

# Paste from clipboard (like macOS pbpaste)
pbpaste
```

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

## Directory Structure

```
llm-windows-setup/
├── Install-LlmTools.ps1          # Main installation script
├── integration/
│   └── llm-integration.ps1       # PowerShell integration (PS5 & PS7)
├── llm-template/
│   └── assistant.yaml            # Custom assistant template
├── README.md                      # This file
├── LICENSE                        # License file
└── .gitignore                     # Git ignore patterns
```

## Documentation

- [LLM Documentation](https://llm.datasette.io/)
- [LLM Plugins Directory](https://llm.datasette.io/en/stable/plugins/directory.html)
- [Pedantic Journal - LLM Guide](https://pedanticjournal.com/llm/)
- [Repomix Documentation](https://github.com/yamadashy/repomix)
- [Gitingest Documentation](https://github.com/coderamp-labs/gitingest)
- [Files-to-Prompt](https://github.com/danmackinlay/files-to-prompt)
- [Claude Code Documentation](https://docs.anthropic.com/claude/docs/claude-code)
- [OpenCode Documentation](https://opencode.ai/docs)

## Differences from Linux Version

This Windows version differs from the [Linux version](https://github.com/c0ffee0wl/llm-linux-setup) in the following ways:

### Excluded Features
- ❌ **Cargo/Rust installation** - Not included
- ❌ **Asciinema** - Terminal recording not included
- ❌ **Auto-logging** - No automatic session logging
- ❌ **Context tool** - Terminal history integration not included
- ❌ **Claude Code Router** - Not included

### Windows-Specific Features
- ✅ **Chocolatey** - Package manager for Windows
- ✅ **Smart admin handling** - Only requires admin for Chocolatey installation
- ✅ **Unified PowerShell integration** - Single file works with PS5 and PS7
- ✅ **Windows clipboard aliases** - `pbcopy`/`pbpaste` for macOS compatibility
- ✅ **Auto-update on script run** - Checks git repository and pulls updates automatically (Phase 0)

## License

This installation script is provided as-is under the MIT License. Individual tools have their own licenses:
- llm: Apache 2.0
- Repomix: MIT
- See individual tool repositories for details

## Contributing

To modify or extend this installation:

1. Fork the repository
2. Make your changes
3. Test on Windows 10/11
4. Submit a pull request

## Credits

- [Simon Willison](https://github.com/simonw) - llm CLI tool
- [Repomix Team](https://github.com/yamadashy/repomix) - Repository packaging
- [Dan Mackinlay](https://github.com/danmackinlay) - files-to-prompt fork
- [Damon McMinn](https://github.com/damonmcminn) - llm-templates-fabric fork
- [c0ffee0wl](https://github.com/c0ffee0wl) - Original llm-linux-setup project

## Support

For issues, questions, or suggestions:
- Open an issue: https://github.com/c0ffee0wl/llm-windows-setup/issues
- Linux version: https://github.com/c0ffee0wl/llm-linux-setup

## Related Projects

- [llm-linux-setup](https://github.com/c0ffee0wl/llm-linux-setup) - Linux/Debian version
- [llm](https://github.com/simonw/llm) - The core llm CLI tool
