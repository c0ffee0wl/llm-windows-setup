# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Windows PowerShell-based installation script for Simon Willison's `llm` CLI tool and related AI/LLM utilities. It's the Windows equivalent of [llm-linux-setup](https://github.com/c0ffee0wl/llm-linux-setup), designed for Windows 10/11/Server with PowerShell 5.1+ and PowerShell 7+ support.

## Architecture

### Three-Component Design

1. **Install-LlmTools.ps1** - Main installer with 10 phases (including Phase 2.5 for ZIP-to-Git conversion)
2. **integration/llm-integration.ps1** - Unified PowerShell integration (PS5 & PS7)
3. **llm-template/** - Custom LLM templates
   - **assistant.yaml** - German-language assistant with security/IT expertise
   - **code.yaml** - Code-only output template for piping to files

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
6. **LLM Plugins** - Install llm plugins (regular and git-based)
7. **LLM Templates** - Copy assistant.yaml and code.yaml with smart update detection
8. **PowerShell Integration** - Add sourcing to PS5 and PS7 profiles
7.5. **Context System Setup** - Install context command and llm-tools-context plugin, configure transcript storage
9. **Additional Tools** - Install gitingest, files-to-prompt, Claude Code, OpenCode using helper functions
10. **Configure Git Hooks** - Set `core.hooksPath` to use tracked hooks/ directory for automatic README TOC updates

### PowerShell Integration Architecture

**Single-file approach**: `llm-integration.ps1` works for both PS5 and PS7 by:
- Using PSReadLine (available in both versions)
- Conditionally detecting PowerShell version when needed
- Setting up PATH for all tools (Python Scripts, .local\bin, npm global)

**Key features**:
- **llm wrapper function** - Automatically applies `-t assistant` template to prompts while excluding management commands (models, keys, plugins, etc.)
  - **chat subcommand**: `llm chat "topic"` → `llm chat -t assistant "topic"`
  - **code subcommand**: `llm code "prompt"` → `llm -t code "prompt"` (outputs raw code without markdown)
- **Ctrl+N keybinding** - AI command completion via `llm cmdcomp` using PSReadLine
  - **Critical implementation detail**: Uses `[Console]::WriteLine()` to write to console (NOT `[Microsoft.PowerShell.PSConsoleReadLine]::Insert()` which writes to buffer)
  - Clears buffer with `RevertLine()` BEFORE calling `llm cmdcomp` to allow interactive TTY session
  - `llm cmdcomp` runs interactively via `prompt_toolkit`, showing UI on TTY and returning final command via stdout
  - On success: inserts result and auto-executes with `AcceptLine()`
- **Clipboard aliases** - `pbcopy`/`pbpaste` functions for macOS compatibility

### Command Completion Architecture (`llm cmdcomp`)

The `llm cmdcomp` plugin is a Python-based interactive program that:

1. **Runs as an interactive TTY application** using `prompt_toolkit`
2. **Workflow**:
   - Takes user's partial command/natural language as input
   - Detects environment (shell, OS, package managers) via `/opt/llm-cmd-comp/llm_cmd_comp/__init__.py`
   - Calls LLM with system prompt containing environment context
   - Shows suggested command: `$ <command>`
   - Prompts for revisions: `> ` (loops until user presses Enter on empty input)
   - **Only the final accepted command goes to stdout** via `print(command)`
3. **Key characteristics**:
   - Interactive UI appears on TTY (not captured in buffer)
   - Return value via stdout is the final command string
   - Exit code 0 = success, non-zero = failure/cancellation
4. **Integration requirements**:
   - Shell must not interfere with TTY while `llm cmdcomp` is running
   - Shell captures stdout to get final command
   - Shell inserts and executes the returned command

**Reference implementations**:
- Zsh: `/opt/llm-linux-setup/integration/llm-integration.zsh`
- PowerShell: `/opt/llm-windows-setup/integration/llm-integration.ps1` (lines 138-171)

### Template Context System

The `assistant.yaml` template is Windows-specific with:
- **OS Context**: Windows 10/11/Server (Linux available via WSL2)
- **Shell**: PowerShell 5.1/7 in Windows Terminal
- **Language**: German responses, English code
- **Security Focus**: IT security, ethical hacking, forensics expertise
- **context tool available** - PowerShell session history integration via transcript logging

### PowerShell Context System Architecture

**Windows-native session logging and AI context integration**:

1. **Automatic Transcription** (`integration/llm-integration.ps1`): Interactive PowerShell sessions automatically start transcript recording
   - Uses native `Start-Transcript` cmdlet (no external dependencies)
   - One transcript per session (unique filename: `PowerShell_<timestamp>_<PID>.txt`)
   - Stores transcripts in configurable directory via `$env:TRANSCRIPT_LOG_DIR`
   - Sets `$env:TRANSCRIPT_LOG_FILE` to point to current session transcript
   - Gracefully handles nested shells (skips if already transcribing)

2. **Context Extraction** (`context/context.py`): Python script that parses PowerShell transcripts
   - Reads transcript files (UTF-16-LE or UTF-8)
   - Detects commands using transcript structure (indentation-based parsing)
   - Extracts "blocks" containing prompt + command + output
   - Supports pagination: `context` (last 1), `context 5` (last 5), `context all` (entire history)
   - Environment export: `context -e` outputs variable assignment command

3. **LLM Integration** (`llm-tools-context/`): Python plugin exposes context as an llm tool
   - Registers `context(input)` function for AI to call
   - Returns formatted command history with `#c#` prefix per line
   - Example: AI can retrieve last 10 commands with `context(10)`

**Architecture Flow**: PowerShell starts → `Start-Transcript` records → `$env:TRANSCRIPT_LOG_FILE` points to transcript → `context.py` parses it → `llm-tools-context` exposes to AI

**Storage Options**:
  - **Temporary**: Stores in `%TEMP%\PowerShell_Transcripts` (cleared on logout/reboot, default)
  - **Permanent**: Stores in `%USERPROFILE%\PowerShell_Transcripts` (survives reboots)

**Multi-Session Handling**:
- Each PowerShell window/tab has its own transcript
- `$env:TRANSCRIPT_LOG_FILE` tracks current session
- To query a different session: `$env:TRANSCRIPT_LOG_FILE = 'C:\path\to\transcript.txt'`

## Helper Functions (Refactored Architecture)

The script uses helper functions to eliminate code duplication and follow the KISS principle:

1. **`Add-ToPath`** (around line 101) - Centralized PATH management
   - Checks if path exists in `$env:Path`
   - Adds to front of PATH if missing
   - Used throughout script instead of inline conditionals
   - Note: This only affects current session; permanent PATH changes are handled by tool installers

2. **`Refresh-EnvironmentPath`** (around line 89) - Reloads PATH from registry
   - Combines Machine and User scope PATH variables
   - Used after Chocolatey installations to pick up new tools
   - Required because Chocolatey modifies registry but doesn't update current session

3. **`Install-ChocoPackage`** (around line 115) - Unified Chocolatey installation
   - Checks if command/package already exists
   - Handles admin privilege requirements with clear messaging
   - Supports optional skip for non-critical packages
   - Auto-refreshes PATH after installation
   - Parameters: `PackageName`, `CommandName`, `ManualUrl`, `AllowSkip`, `SkipCheck`

4. **`Install-UvTool`** (around line 171) - Unified uv tool installation/upgrade
   - Checks if tool is installed via `uv tool list`
   - Upgrades if exists, installs if new
   - Supports git-based packages with availability check
   - Consistent error handling without `$ErrorActionPreference` toggling
   - Parameters: `ToolName`, `IsGitPackage`

5. **`Install-NpmPackage`** (around line 219) - Unified npm global installation
   - Installs via `npm install -g`
   - Consistent error handling
   - Returns success/failure for validation
   - Parameters: `PackageName`

6. **`Install-LlmTemplate`** (around line 243) - Unified llm template installation with three-way comparison
   - Uses metadata tracking to detect user modifications vs upstream changes
   - Tracks hash of last installed version in `.template-hashes.json`
   - Auto-updates silently if template changed upstream but user hasn't modified it
   - Prompts only if user has made local modifications
   - PS5 compatible JSON handling for metadata persistence
   - Parameters: `TemplateName`, `TemplatesDir`

Additional helper functions:
- **`Test-Administrator`** - Checks if running with admin privileges
- **`Test-CommandExists`** - Verifies if a command is available
- **`Test-PythonAvailable`** - Checks if Python is actually working (not just Windows Store alias)

### Usage Examples

```powershell
# Chocolatey package with admin checks
Install-ChocoPackage -PackageName "git" -CommandName "git" -ManualUrl "https://git-scm.com" -AllowSkip $true

# UV tool installation
Install-UvTool -ToolName "llm"
Install-UvTool -ToolName "git+https://github.com/user/repo" -IsGitPackage $true

# PATH management
Add-ToPath "$env:USERPROFILE\.local\bin"

# Template installation (Phase 7)
Install-LlmTemplate -TemplateName "assistant" -TemplatesDir $templatesDir
Install-LlmTemplate -TemplateName "code" -TemplatesDir $templatesDir
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
   - Code generation: `llm code "prompt"` → `llm -t code "prompt"`

### Template Smart Update Logic

The `Install-LlmTemplate` function uses **three-way comparison** to distinguish between user modifications and upstream updates:

**Metadata tracking**:
- Stores hash of last installed version in `%APPDATA%\io.datasette.llm\.template-hashes.json`
- JSON format: `{"assistant": "abc123...", "code": "def456..."}`
- Persists across script runs

**Update decision logic**:

1. **If installed hash == last installed hash** (user hasn't modified):
   - Auto-updates silently when template changes in git
   - Message: `"Updating 'assistant' template (no local modifications detected)..."`
   - No user prompt required

2. **If installed hash != last installed hash** (user has modified):
   - Prompts before overwriting: `"Overwrite your local changes? (y/N)"`
   - Shows warning about local modifications
   - User must explicitly confirm to update

3. **If no metadata exists** (first install or unknown state):
   - Installs template without prompting
   - Creates metadata for future comparisons

**Benefits**:
- Eliminates unnecessary prompts for routine updates
- Protects user customizations from accidental overwrites
- Works seamlessly with git-based auto-updates (Phase 0)
- PowerShell 5 & 7 compatible

**Example scenarios**:

```powershell
# Scenario 1: Template updated in git, user hasn't touched it
# Result: Auto-updates silently ✓

# Scenario 2: User modified template, new version available
# Result: Prompts "Overwrite your local changes? (y/N)" ✓

# Scenario 3: User modified template, no new version
# Result: Keeps existing template, updates metadata ✓
```

### PATH Management Strategy

Integration file dynamically adds to PATH in this order:
1. Python user scripts (`%APPDATA%\Python\Python*\Scripts`)
2. User local bin (`%USERPROFILE%\.local\bin`)
3. npm global (`%APPDATA%\npm` or `%USERPROFILE%\.npm-global`)

This ensures uv tools, pipx tools, and npm global packages are accessible.

## Common Commands

### Running the Installation Script

```powershell
# Initial installation (requires admin for Chocolatey)
.\Install-LlmTools.ps1

# Update all tools (can run as regular user if Chocolatey already installed)
.\Install-LlmTools.ps1

# Force Azure OpenAI configuration
.\Install-LlmTools.ps1 -Azure
```

### Testing Individual Components

```powershell
# Test llm installation
Get-Command llm
llm "test query"

# Test code generation
llm code "python hello world"
llm code "powershell function to list files" > list.ps1

# Test command completion manually
llm cmdcomp "list files"

# Test context system
Get-Command context
context          # Show last command
context 5        # Show last 5 commands
context all      # Show entire session
$env:TRANSCRIPT_LOG_FILE  # Check transcript file path
$env:TRANSCRIPT_LOG_DIR   # Check transcript directory

# Test PowerShell integration (after loading profile)
. $PROFILE

# Verify PATH includes required directories
$env:PATH -split ';' | Select-String "\.local\\bin"
$env:PATH -split ';' | Select-String "npm"

# Check installed llm plugins
llm plugins
llm plugins list | Select-String "context"

# Verify Azure configuration
Get-Content $env:APPDATA\io.datasette.llm\extra-openai-models.yaml
llm keys get azure

# Test PSReadLine module
Get-Module PSReadLine
```

### Reloading Integration After Changes

```powershell
# Reload current PowerShell profile
. $PROFILE

# Or restart PowerShell session
exit  # Then reopen PowerShell
```

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

### Adding New LLM Templates

Add to Phase 7 (around line 913) using the `Install-LlmTemplate` helper:

```powershell
# Install templates using helper function
Install-LlmTemplate -TemplateName "assistant" -TemplatesDir $templatesDir
Install-LlmTemplate -TemplateName "code" -TemplatesDir $templatesDir
Install-LlmTemplate -TemplateName "your-new-template" -TemplatesDir $templatesDir  # Add here
```

Then create `llm-template/your-new-template.yaml` in the repository.

### Adding New LLM Plugins

Add to the appropriate array in Phase 6 (around line 843):

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

**Critical rules for PSReadLine keybindings with external interactive programs**:
- **NEVER** use `[Microsoft.PowerShell.PSConsoleReadLine]::Insert()` to write output messages - this modifies the command buffer
- **DO** use `[Console]::WriteLine()` or `Write-Host` for console output
- **DO** clear buffer with `RevertLine()` before running external interactive programs like `llm cmdcomp`
- External programs using `prompt_toolkit` (like `llm cmdcomp`) need direct TTY access - buffer must be clean
- Only use `Insert()` to add the final result to the command buffer
- Use `AcceptLine()` to auto-execute the inserted command

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
   - Checks out branch and sets up tracking: `git checkout -f -B <branch> origin/<branch>`
   - Future runs will use normal git pull auto-update mechanism
3. This prevents the script from executing with partially-updated code mid-run and avoids infinite loops when local commits exist

**ZIP Download Workflow**: Users can download the repository as a ZIP file, extract it, and run the script without needing git preinstalled. The script will:
1. Install git as a prerequisite
2. Offer to convert the directory to a proper git repository
3. Enable auto-updates for all future runs

**When modifying `Install-LlmTools.ps1`**: The self-update logic in Phase 0 must ALWAYS run before any other operations. Never move or remove this section.

### README Table of Contents (TOC) System

The README.md file uses automatically generated Table of Contents via [doctoc](https://github.com/thlorenz/doctoc) and git hooks.

**Architecture**:
1. **TOC Markers** in README.md:
   ```markdown
   <!-- START doctoc generated TOC please keep comment here to allow auto update -->
   <!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

   <!-- END doctoc generated TOC please keep comment here to allow auto update -->
   ```

2. **Git Pre-commit Hook** (`hooks/pre-commit`):
   - Bash script that runs automatically when committing README.md
   - Detects if README.md is being committed
   - Runs `doctoc README.md --github` to regenerate TOC
   - Re-adds updated README.md to the commit
   - Requires Git Bash (installed with Git for Windows)

3. **Git Hooks Configuration** (Phase 10):
   - Script runs: `git config core.hooksPath hooks`
   - Points git to use `hooks/` directory (tracked in version control)
   - All developers automatically get the hook when they clone/pull

**Important Notes**:
- **doctoc is NOT installed on Windows** - the git hook runs via Git Bash (comes with Git for Windows)
- The hook is a bash script and relies on Git Bash's bash environment
- This ensures TOC stays in sync automatically on every commit
- Matches the Linux repository's implementation

**When editing README.md**:
- Just edit the content normally
- TOC will auto-update when you commit
- Don't manually edit the TOC section (between the comment markers)

**Manual TOC update** (if needed):
```bash
# If you have doctoc installed separately (Linux/macOS/WSL):
doctoc README.md --github

# Or let the git hook handle it on commit:
git add README.md
git commit -m "Updated README"  # TOC updates automatically
```

### Windows-Specific Considerations

- **Execution Policy**: May need `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
- **Path separators**: Use `\` for Windows paths in documentation
- **Line endings**: Scripts should use CRLF for Windows compatibility
- **Admin elevation**: Chocolatey packages require admin, everything else is user-scoped
- **npm call**: Don't start npm with `&` operator - it's a Batch/cmd file that causes error messages on Windows
- **ASCII encoding**: When writing configuration files for Python tools (like extra-openai-models.yaml), use ASCII encoding. UTF-8 in PowerShell 5 creates a BOM that can trip up Python parsers
- **Helper functions**: Use the 6 provided helper functions (`Install-ChocoPackage`, `Install-UvTool`, `Install-NpmPackage`, `Install-LlmTemplate`, `Add-ToPath`, `Refresh-EnvironmentPath`) instead of inline installation logic to maintain consistency and reduce duplication

## File Locations

### Installation Script Creates

- `%APPDATA%\io.datasette.llm\extra-openai-models.yaml` - Azure OpenAI model config
- `%APPDATA%\io.datasette.llm\templates\assistant.yaml` - LLM assistant template
- `%APPDATA%\io.datasette.llm\templates\code.yaml` - LLM code-only template
- `%APPDATA%\io.datasette.llm\.template-hashes.json` - Template installation metadata for smart update detection
- `%APPDATA%\io.datasette.llm\.transcript-configured` - Transcript storage configuration marker
- `%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` - PS5 profile
- `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` - PS7 profile

### Tool Installation Paths

- **uv tools** (llm, gitingest, files-to-prompt): `%USERPROFILE%\.local\bin`
- **npm global**: `%APPDATA%\npm` (admin) or `%USERPROFILE%\.npm-global` (user)
- **pipx**: `%USERPROFILE%\.local\bin`
- **context command**: `%USERPROFILE%\.local\bin\context.py` and `%USERPROFILE%\.local\bin\context.bat`

### Transcript Storage

- `%TEMP%\PowerShell_Transcripts\*.txt` - Temporary transcript storage (default)
- `%USERPROFILE%\PowerShell_Transcripts\*.txt` - Permanent transcript storage (optional)

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

### Issue: llm-tools-context installation fails with permission error

**Symptoms**:
- Installation succeeds when run with admin rights
- Subsequent non-admin runs fail during llm-tools-context installation
- Error: `Permission denied: 'c:\users\...\appdata\local\pip\cache\wheels\...'`
- Context command and AI context retrieval stop working

**Cause**: The pip cache directory at `%LOCALAPPDATA%\pip\cache` was created with admin permissions during the first run. Non-admin runs cannot write to this cache directory when building the llm-tools-context wheel.

**Solution**: This issue is fixed in the latest version of the installation script. Update via:

```powershell
git pull
.\Install-LlmTools.ps1
```

**Manual workarounds** (if you can't update the script):

Option 1: Clear the pip cache directory
```powershell
Remove-Item -Recurse -Force $env:LOCALAPPDATA\pip\cache
.\Install-LlmTools.ps1
```

Option 2: Fix cache permissions
```powershell
icacls "$env:LOCALAPPDATA\pip\cache" /grant "${env:USERNAME}:(OI)(CI)F" /T
.\Install-LlmTools.ps1
```

**Prevention**: The updated installation script uses the `--no-cache-dir` flag to bypass pip cache entirely for local package installations, preventing permission conflicts between admin and non-admin runs.

## Troubleshooting

### Issue: Ctrl+N command completion not working or behaving incorrectly

**Symptoms**:
- Pressing Ctrl+N does nothing
- Ctrl+N corrupts the command line
- Interactive UI doesn't appear
- Command doesn't auto-execute

**Solutions**:

1. **Reload PowerShell profile**:
   ```powershell
   . $PROFILE
   ```

2. **Verify PSReadLine is loaded**:
   ```powershell
   Get-Module PSReadLine
   # If not loaded, import it:
   Import-Module PSReadLine
   ```

3. **Test llm cmdcomp manually**:
   ```powershell
   llm cmdcomp "list files"
   # Should show interactive UI with `$` prompt and `>` for revisions
   ```

4. **Check keybinding is registered**:
   ```powershell
   # View all PSReadLine keybindings
   Get-PSReadLineKeyHandler | Select-String "Ctrl\+n"
   ```

5. **Verify integration file exists**:
   ```powershell
   Test-Path "$PSScriptRoot\integration\llm-integration.ps1"
   ```

6. **Common implementation bugs** (for developers):
   - Using `[Microsoft.PowerShell.PSConsoleReadLine]::Insert()` for console output (WRONG - corrupts buffer)
   - Not clearing buffer with `RevertLine()` before calling `llm cmdcomp` (WRONG - interferes with TTY)
   - Not checking `$LASTEXITCODE` after running `llm cmdcomp` (WRONG - doesn't detect failures)
   - Using `2>$null` to hide errors (WRONG - makes debugging impossible)

### Issue: Context command not found

**Symptoms**:
- Running `context` in PowerShell returns "command not found"
- AI cannot retrieve terminal history

**Solutions**:

1. **Verify context.py is installed**:
   ```powershell
   Test-Path $env:USERPROFILE\.local\bin\context.py
   Test-Path $env:USERPROFILE\.local\bin\context.bat
   ```

2. **Check PATH includes .local\bin**:
   ```powershell
   $env:PATH -split ';' | Select-String "\.local\\bin"
   ```

3. **Verify Python is available**:
   ```powershell
   python --version
   ```

4. **Manually test context script**:
   ```powershell
   python $env:USERPROFILE\.local\bin\context.py
   ```

5. **Reinstall context system**:
   ```powershell
   .\Install-LlmTools.ps1
   ```

### Issue: Context returns "No commands found"

**Symptoms**:
- `context` command runs but returns no results
- Transcripts not being created

**Solutions**:

1. **Check if transcription started**:
   ```powershell
   $env:TRANSCRIPT_LOG_FILE
   # Should show path to current transcript
   ```

2. **Verify transcript directory exists**:
   ```powershell
   $env:TRANSCRIPT_LOG_DIR
   Test-Path $env:TRANSCRIPT_LOG_DIR
   ```

3. **Check transcript file exists**:
   ```powershell
   Test-Path $env:TRANSCRIPT_LOG_FILE
   ```

4. **Reload PowerShell profile**:
   ```powershell
   . $PROFILE
   ```

5. **Start a new PowerShell session** (transcription starts automatically)

### Issue: Transcript encoding errors

**Symptoms**:
- Context command shows garbled text
- Unicode characters not displayed correctly

**Cause**: PowerShell uses UTF-16-LE encoding by default, but some systems may vary.

**Solution**: The context parser auto-detects encoding (UTF-16-LE, then UTF-8 fallback). If issues persist, check transcript file encoding:

```powershell
# View raw transcript
Get-Content $env:TRANSCRIPT_LOG_FILE -Encoding Unicode
```

### Issue: Native command output not captured in transcripts

**Symptoms**:
- Commands like `ping`, `ipconfig`, `tracert`, or `git` execute successfully
- Output appears in console but is missing from transcript file
- `context` command shows the command was run but returns no output
- May see `TerminatingError(): "Die Pipeline wurde beendet."` when pressing Ctrl+C

**Cause**: This is a **known PowerShell limitation**, not a bug in our code. PowerShell's `Start-Transcript` cmdlet does not capture output from native console applications (executables) that write directly to the console buffer. PowerShell doesn't redirect their output handles, so the transcription framework cannot capture them.

**Official Microsoft documentation**:
- [Workaround for Start-Transcript on native processes](https://devblogs.microsoft.com/powershell/workaround-for-start-transcript-on-native-processes/)
- [GitHub Issue #10994: Start/Stop-Transcript does not capture everything](https://github.com/PowerShell/PowerShell/issues/10994)

**Workaround**: Pipe native commands through `Out-Default` to force PowerShell to intercept their output:

```powershell
# Without workaround - output NOT captured
ping heise.de

# With workaround - output IS captured
ping heise.de | Out-Default

# Other examples
ipconfig /all | Out-Default
tracert google.com | Out-Default
git status | Out-Default
```

**Note about TerminatingError**: When you press Ctrl+C to interrupt a command, PowerShell writes a `TerminatingError(): "Die Pipeline wurde beendet."` message to the transcript. This is normal PowerShell behavior and is automatically filtered out by the `context` parser.

## Troubleshooting Command Reference

```powershell
# Verify llm installation
Get-Command llm

# Test command completion manually
llm cmdcomp "list files"

# Test context command
context
context 5

# Check transcript environment variables
$env:TRANSCRIPT_LOG_FILE
$env:TRANSCRIPT_LOG_DIR

# Verify context command exists
Get-Command context

# Check Azure configuration
Get-Content $env:APPDATA\io.datasette.llm\extra-openai-models.yaml

# Verify API key
llm keys get azure

# Reload PowerShell profile
. $PROFILE

# Check PSReadLine module
Get-Module PSReadLine

# View PSReadLine keybindings
Get-PSReadLineKeyHandler
```

