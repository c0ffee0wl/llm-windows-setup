#
# LLM Tools Integration for PowerShell
# Compatible with both PowerShell 5.1 (Windows) and PowerShell 7+ (Core)
#
# This file is sourced from both PowerShell 5 and PowerShell 7 profiles
#

# ============================================================================
# PATH Configuration
# ============================================================================

# Ensure Python user scripts are in PATH
$pythonUserScripts = "$env:APPDATA\Python\Python*\Scripts"
if (Test-Path $pythonUserScripts) {
    $pythonScriptsPath = (Get-Item $pythonUserScripts | Select-Object -First 1).FullName
    if ($env:PATH -notlike "*$pythonScriptsPath*") {
        $env:PATH = "$pythonScriptsPath;$env:PATH"
    }
}

# Ensure user local bin is in PATH
$userLocalBin = "$env:USERPROFILE\.local\bin"
if (Test-Path $userLocalBin) {
    if ($env:PATH -notlike "*$userLocalBin*") {
        $env:PATH = "$userLocalBin;$env:PATH"
    }
}

# Ensure npm global is in PATH
$npmGlobal = "$env:APPDATA\npm"
if (Test-Path $npmGlobal) {
    if ($env:PATH -notlike "*$npmGlobal*") {
        $env:PATH = "$npmGlobal;$env:PATH"
    }
}

# Alternative npm global location (if configured)
$npmGlobalAlt = "$env:USERPROFILE\.npm-global"
if (Test-Path $npmGlobalAlt) {
    if ($env:PATH -notlike "*$npmGlobalAlt*") {
        $env:PATH = "$npmGlobalAlt;$env:PATH"
    }
}

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
        & (Get-Command -Name llm -CommandType Application) @args
        return
    }

    # Check if first argument is an excluded subcommand
    if ($args.Count -gt 0 -and $excludeCommands -contains $args[0]) {
        & (Get-Command -Name llm -CommandType Application) @args
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
        & (Get-Command -Name llm -CommandType Application) @args
        return
    }

    # Handle 'chat' subcommand specially
    if ($args.Count -gt 0 -and $args[0] -eq "chat") {
        $chatArgs = $args[1..($args.Count - 1)]
        & (Get-Command -Name llm -CommandType Application) chat -t assistant @chatArgs
        return
    }

    # Default: add assistant template
    & (Get-Command -Name llm -CommandType Application) -t assistant @args
}

# ============================================================================
# Clipboard Aliases (macOS compatibility)
# ============================================================================

function pbcopy {
    <#
    .SYNOPSIS
        Copy input to clipboard (macOS pbcopy equivalent)

    .EXAMPLE
        "Hello" | pbcopy
    #>
    $input | Set-Clipboard
}

function pbpaste {
    <#
    .SYNOPSIS
        Output clipboard contents (macOS pbpaste equivalent)

    .EXAMPLE
        pbpaste
    #>
    Get-Clipboard
}

# ============================================================================
# PSReadLine Key Bindings
# ============================================================================

# Check if PSReadLine is available (should be in both PS5 and PS7)
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue

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

        # Show a newline for cleaner output
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("`n")

        try {
            # Call llm cmdcomp to get the completion
            $completion = & (Get-Command -Name llm -CommandType Application) cmdcomp $line 2>$null

            if ($completion -and $completion -ne $line) {
                # Replace the current line with the completion
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($completion)
            } else {
                # Restore original line if completion failed or returned same
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($line)
            }
        } catch {
            # On error, restore original line
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($line)
            Write-Host "Command completion failed: $_" -ForegroundColor Red
        }
    }
}

# ============================================================================
# Informational Message (optional - can be removed if unwanted)
# ============================================================================

# Uncomment to show a message when the integration is loaded
# Write-Host "LLM Tools Integration loaded. Press Ctrl+N for AI command completion." -ForegroundColor Green
