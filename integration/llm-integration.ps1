#
# LLM Tools Integration for PowerShell
# Compatible with both PowerShell 5.1 (Windows) and PowerShell 7+ (Core)
#
# This file is sourced from both PowerShell 5 and PowerShell 7 profiles
#

# ============================================================================
# Helper Functions
# ============================================================================

function Add-ToPathIfExists {
    <#
    .SYNOPSIS
        Adds a directory to PATH if it exists and isn't already in PATH
    #>
    param([string]$Path)

    if ((Test-Path $Path) -and ($env:PATH -notlike "*$Path*")) {
        $env:PATH = "$Path;$env:PATH"
    }
}

# ============================================================================
# PATH Configuration
# ============================================================================

# Ensure Python user scripts are in PATH
$pythonUserScripts = Join-Path $env:APPDATA "Python\Python*\Scripts"
if (Test-Path $pythonUserScripts) {
    $pythonScriptsPath = (Get-Item $pythonUserScripts | Select-Object -First 1).FullName
    Add-ToPathIfExists $pythonScriptsPath
}

# Ensure user local bin is in PATH
Add-ToPathIfExists (Join-Path $env:USERPROFILE ".local\bin")

# Ensure npm global is in PATH
Add-ToPathIfExists (Join-Path $env:APPDATA "npm")

# Alternative npm global location (if configured)
Add-ToPathIfExists (Join-Path $env:USERPROFILE ".npm-global")

# ============================================================================
# Resolve llm.exe Path (before function definition)
# ============================================================================

# Store the full path to llm.exe to avoid command resolution issues inside the llm wrapper function
$script:LlmExecutable = (Get-Command -Name llm -CommandType Application -ErrorAction Stop).Source

# ============================================================================
# Custom llm Wrapper Function
# ============================================================================

function llm {
    <#
    .SYNOPSIS
        Wrapper for the llm CLI tool that auto-applies the 'assistant' template

    .DESCRIPTION
        This function wraps the llm command and automatically adds the '-t assistant'
        template parameter for prompt commands, while passing through management
        commands (models, keys, plugins, etc.) unchanged.

    .EXAMPLE
        llm "What is PowerShell?"
        # Automatically uses: llm -t assistant "What is PowerShell?"

    .EXAMPLE
        llm models list
        # Passes through unchanged: llm models list

    .EXAMPLE
        llm -c abc123 "Continue this conversation"
        # Skips template (continuing conversation): llm -c abc123 "Continue this conversation"
    #>

    # List of subcommands that should NOT get the -t template parameter
    # These are management/configuration commands, not prompt commands
    $excludeCommands = @(
        "models", "keys", "plugins", "templates", "tools", "schemas", "fragments",
        "collections", "embed", "embed-models", "embed-multi", "similar",
        "aliases", "logs", "install", "uninstall",
        "openai", "gemini", "openrouter",
        "cmd", "cmdcomp", "jq"
    )

    # Check for help/version flags - pass through directly
    if ($args -contains "-h" -or $args -contains "--help" -or $args -contains "--version") {
        & $script:LlmExecutable @args
        return
    }

    # Check if first argument is an excluded subcommand
    if ($args.Count -gt 0 -and $excludeCommands -contains $args[0]) {
        & $script:LlmExecutable @args
        return
    }

    # Check if we should skip template (user specified their own context/template/system)
    $skipTemplate = $false
    foreach ($arg in $args) {
        if ($arg -match '^(-c|--continue|--cid|--conversation)$' -or
            $arg -match '^(-s|--system)' -or
            $arg -match '^(-t|--template)' -or
            $arg -eq '--sf') {
            $skipTemplate = $true
            break
        }
    }

    if ($skipTemplate) {
        & $script:LlmExecutable @args
        return
    }

    # Handle 'chat' subcommand specially
    if ($args.Count -gt 0 -and $args[0] -eq "chat") {
        if ($args.Count -eq 1) {
            # No arguments after 'chat' - avoid problematic array slicing
            & $script:LlmExecutable chat -t assistant
        } else {
            # Arguments after 'chat' - safe to slice array
            $chatArgs = $args[1..($args.Count - 1)]
            & $script:LlmExecutable chat -t assistant @chatArgs
        }
        return
    }

    # Default: add assistant template
    & $script:LlmExecutable -t assistant @args
}

# ============================================================================
# Clipboard Aliases (macOS compatibility)
# ============================================================================

# Provide macOS-style clipboard commands for cross-platform scripts
Set-Alias pbcopy Set-Clipboard
Set-Alias pbpaste Get-Clipboard

# ============================================================================
# PSReadLine Key Bindings
# ============================================================================

# Check if PSReadLine is available (should be in both PS5 and PS7)
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue

    # Capture llm executable path in local variable for ScriptBlock closure
    # (ScriptBlock can't access $script: scope variables directly)
    $llmExePath = $script:LlmExecutable

    # Bind Ctrl+N to LLM command completion
    Set-PSReadLineKeyHandler -Key Ctrl+n -ScriptBlock {
        # Get the current command line
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        # Only proceed if there's something to complete
        if ([string]::IsNullOrWhiteSpace($line)) {
            return
        }

        # Clear the current line from the buffer before running llm cmdcomp
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()

        # Write a newline to the console (not the buffer) for cleaner output
        [Console]::WriteLine()

        try {
            # Call llm cmdcomp - interactive UI appears on stderr (console)
            # Only capture stdout (the final command), let stderr go to console
            # This matches the Zsh implementation behavior
            $result = & $llmExePath "cmdcomp" "$line"
            $exitCode = $LASTEXITCODE

            # Check for success and non-empty result
            if ($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($result)) {
                # Success - insert command and execute
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
                [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            } elseif ($exitCode -ne 0) {
                # Command failed
                [Console]::WriteLine("Command completion failed (exit code: $exitCode)")
            }
            # If empty result (user cancelled), do nothing
        } catch {
            # Exception during execution
            [Console]::WriteLine("Command completion error: $_")
        }
    }
}

# ============================================================================
# Automatic PowerShell Transcript Logging
# ============================================================================

# Only start transcript if this is an interactive session and not already transcribing
if ($Host.Name -eq "ConsoleHost" -and -not $Host.PrivateData.PSObject.Properties['TranscriptPath']) {
    try {
        # Configure transcript directory (user can override via environment variable)
        if (-not $env:TRANSCRIPT_LOG_DIR) {
            $env:TRANSCRIPT_LOG_DIR = Join-Path $env:TEMP "PowerShell_Transcripts"
        }

        # Create transcript directory if it doesn't exist
        if (-not (Test-Path $env:TRANSCRIPT_LOG_DIR)) {
            New-Item -ItemType Directory -Path $env:TRANSCRIPT_LOG_DIR -Force | Out-Null
        }

        # Generate unique transcript filename (timestamp + PID)
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $transcriptFile = Join-Path $env:TRANSCRIPT_LOG_DIR "PowerShell_${timestamp}_$PID.txt"

        # Store in environment variable for context command
        $env:TRANSCRIPT_LOG_FILE = $transcriptFile

        # Start transcript (suppress output message)
        Start-Transcript -Path $transcriptFile -IncludeInvocationHeader | Out-Null

        # Show session log info (unless TRANSCRIPT_LOG_SILENT is set)
        if ($env:TRANSCRIPT_LOG_SILENT -ne "true" -and $env:TRANSCRIPT_LOG_SILENT -ne "1") {
            Write-Host "Session logged for 'context' command. To query this session from another terminal:" -ForegroundColor Cyan
            Write-Host "`$env:TRANSCRIPT_LOG_FILE = '$transcriptFile'" -ForegroundColor Gray
            Write-Host ""
        }
    }
    catch {
        # Silently fail if transcript cannot be started (non-critical feature)
        # User can still use PowerShell without context logging
    }
}

# ============================================================================
# Informational Message (optional - can be removed if unwanted)
# ============================================================================

# Uncomment to show a message when the integration is loaded
# Write-Host "LLM Tools Integration loaded. Press Ctrl+N for AI command completion." -ForegroundColor Cyan
