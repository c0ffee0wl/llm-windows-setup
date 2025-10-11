# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Windows PowerShell-based installation script for Simon Willison's `llm` CLI tool and related AI/LLM utilities. It's the Windows equivalent of [llm-linux-setup](https://github.com/c0ffee0wl/llm-linux-setup), designed for Windows 10/11/Server with PowerShell 5.1+ and PowerShell 7+ support.

## Architecture

### Three-Component Design

1. **Install-LlmTools.ps1** - Main installer with 10 phases (including Phase 2.5 for ZIP-to-Git conversion)
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

The script executes in 11 sequential phases:

0. **Self-Update** - Check git repository for updates, auto-pull and re-execute if needed. If not a git repo (ZIP download), sets flag for Phase 2.5
1. **Admin Check & Chocolatey** - Install Chocolatey if missing (admin required)
2. **Prerequisites** - Install Python 3, Node.js 22.x, Git, jq via Chocolatey using `Install-ChocoPackage`
2.5. **ZIP-to-Git Conversion** (Optional) - If downloaded as ZIP, offers to convert directory to git repository for auto-updates
3. **Python Tools** - Install pipx, uv (user-scoped via `--user`)
4. **LLM Core** - Install `llm` via `Install-UvTool` helper function
5. **Azure OpenAI Config** - Interactive setup (optional, first-run detection)
6. **LLM Templates** - Copy assistant.yaml with smart update detection
7. **PowerShell Integration** - Add sourcing to PS5 and PS7 profiles
8. **Additional Tools** - Install repomix, gitingest, files-to-prompt, Claude Code, OpenCode using helper functions

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

## Helper Functions (Refactored Architecture)

The script uses 5 reusable helper functions to eliminate code duplication and follow the KISS principle:

1. **`Add-ToPath`** (line 101) - Centralized PATH management
   - Checks if path exists in `$env:Path`
   - Adds to front of PATH if missing
   - Used throughout script instead of inline conditionals

2. **`Install-ChocoPackage`** (line 115) - Unified Chocolatey installation
   - Checks if command/package already exists
   - Handles admin privilege requirements with clear messaging
   - Supports optional skip for non-critical packages
   - Auto-refreshes PATH after installation

3. **`Install-UvTool`** (line 176) - Unified uv tool installation/upgrade
   - Checks if tool is installed via `uv tool list`
   - Upgrades if exists, installs if new
   - Supports git-based packages with availability check
   - Consistent error handling without `$ErrorActionPreference` toggling

4. **`Install-NpmPackage`** (line 221) - Unified npm global installation
   - Installs via `npm install -g`
   - Consistent error handling
   - Returns success/failure for validation

### Usage Examples

```powershell
# Chocolatey package with admin checks
Install-ChocoPackage -PackageName "git" -CommandName "git" -ManualUrl "https://git-scm.com" -AllowSkip $true

# UV tool installation
Install-UvTool -ToolName "llm"
Install-UvTool -ToolName "git+https://github.com/user/repo" -IsGitPackage $true

# npm package installation
Install-NpmPackage -PackageName "repomix"

# PATH management
Add-ToPath "$env:USERPROFILE\.local\bin"
```

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

Add to the appropriate array in Phase 6 (around line 652):

```powershell
# For regular plugins
$plugins = @(
    "llm-gemini",
    # ... existing plugins ...
    "your-new-plugin"  # Add here
)

# For git-based plugins
$gitPlugins = @(
    "git+https://github.com/c0ffee0wl/llm-cmd",
    # ... existing plugins ...
    "git+https://github.com/your/plugin"  # Add here
)
```

### Modifying PowerShell Integration

When editing `integration/llm-integration.ps1`:
- Test on both PS5 and PS7
- Avoid version-specific syntax
- Use `$PSVersionTable.PSVersion` if version detection needed
- Test keybindings: `Set-PSReadLineKeyHandler -Key Ctrl+n`

### Self-Update Mechanism

The core design uses a **self-updating script pattern** with safe execution:

1. **Phase 0 (Self-Update)**: The script checks if it's running in a git repo, fetches updates, compares local vs remote HEAD
   - **If git repo exists**: Uses `git rev-list HEAD..@{u}` to count how many commits **behind** the remote we are
     - If behind > 0: pulls updates and re-executes with same parameters to replace the current process
     - If equal or ahead: continues normally without pulling
   - **If NOT a git repo (ZIP download)**: Sets `$needsGitInit = $true` flag for Phase 2.5
2. **Phase 2.5 (ZIP-to-Git Conversion)**: After git is installed in Phase 2, if `$needsGitInit` is true:
   - Prompts user to convert directory to git repository (default: Yes)
   - Performs: `git init`, `git remote add origin`, `git fetch origin`
   - Auto-detects default branch (tries `main` first, fallback to `master`)
   - Checks out branch and sets up tracking: `git checkout -b <branch> origin/<branch>`
   - Future runs will use normal git pull auto-update mechanism
3. This prevents the script from executing with partially-updated code mid-run and avoids infinite loops when local commits exist

**ZIP Download Workflow**: Users can download the repository as a ZIP file, extract it, and run the script without needing git preinstalled. The script will:
1. Install git as a prerequisite
2. Offer to convert the directory to a proper git repository
3. Enable auto-updates for all future runs

**When modifying `Install-LlmTools.ps1`**: The self-update logic in Phase 0 must ALWAYS run before any other operations. Never move or remove this section.

### Windows-Specific Considerations

- **Execution Policy**: May need `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
- **Path separators**: Use `\` for Windows paths in documentation
- **Line endings**: Scripts should use CRLF for Windows compatibility
- **Admin elevation**: Chocolatey packages require admin, everything else is user-scoped
- **npm call**: Don't start npm with `&` operator - it's a Batch/cmd file that causes error messages on Windows
- **ASCII encoding**: When writing configuration files for Python tools (like extra-openai-models.yaml), use ASCII encoding. UTF-8 in PowerShell 5 creates a BOM that can trip up Python parsers
- **Helper functions**: Use the 5 provided helper functions (`Install-ChocoPackage`, `Install-UvTool`, `Install-NpmPackage`, `Add-ToPath`) instead of inline installation logic to maintain consistency and reduce duplication

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

## Troubleshooting Installation Script

### Issue: Infinite loop on script start ("Updates found! Pulling latest changes...")

This happens when you have local commits that haven't been pushed to origin:

```powershell
# Check if you're ahead of origin
git status

# If "Your branch is ahead of 'origin/main' by N commits":
# Option 1: Push your changes
git push

# Option 2: Reset to origin (WARNING: loses local commits)
git reset --hard origin/main

# The script only pulls when BEHIND remote, not when ahead or equal
```

### Issue: Script won't self-update even though updates exist

```powershell
# Manually check for updates
cd C:\Path\To\llm-windows-setup
git fetch origin
git status

# If behind, manually pull and re-run
git pull
.\Install-LlmTools.ps1

# Check if git is working correctly
git rev-parse --git-dir  # Should show .git directory
git rev-parse '@{u}'     # Should show upstream branch commit
```

### Issue: Downloaded as ZIP and declined git initialization - want to enable later

If you initially downloaded as ZIP and declined the git repository conversion, you can manually convert it later:

```powershell
# Navigate to the installation directory
cd C:\Path\To\llm-windows-setup

# Initialize git repository
git init

# Add remote
git remote add origin https://github.com/c0ffee0wl/llm-windows-setup.git

# Fetch from remote
git fetch origin

# Checkout main branch (or master if main doesn't exist)
git checkout -b main origin/main

# Set up tracking
git branch --set-upstream-to=origin/main main

# Verify it's working
git status
```

Alternatively, you can:
1. Delete the ZIP-extracted directory
2. Clone the repository properly: `git clone https://github.com/c0ffee0wl/llm-windows-setup.git`
3. Run the installation script from the cloned directory

### Issue: Git initialization failed during Phase 2.5

Common causes and solutions:

```powershell
# Issue: Network connectivity problems during git fetch
# Solution: Check your internet connection and try again
.\Install-LlmTools.ps1

# Issue: Proxy or firewall blocking git
# Solution: Configure git to use your proxy
git config --global http.proxy http://proxy.example.com:8080

# Issue: .git directory exists but is corrupted
# Solution: Remove .git directory and run script again
Remove-Item -Recurse -Force .git
.\Install-LlmTools.ps1
```

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

