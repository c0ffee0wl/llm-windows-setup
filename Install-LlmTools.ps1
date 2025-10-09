#Requires -Version 5.1
<#
.SYNOPSIS
    LLM Tools Installation Script for Windows (10/11/Server)

.DESCRIPTION
    Installs Simon Willison's llm CLI tool and related AI/LLM command-line utilities
    for Windows environments. Supports both PowerShell 5.1 and PowerShell 7+.

.PARAMETER Force
    Force reinstallation of all components

.EXAMPLE
    .\Install-LlmTools.ps1
    Run the installation script

.EXAMPLE
    .\Install-LlmTools.ps1 -Force
    Force reinstall all components

.NOTES
    Author: Based on llm-linux-setup by c0ffee0wl
    Version: 1.0
    Requires: Windows 10/11/Server, PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [switch]$Force
)

# ============================================================================
# Script Configuration
# ============================================================================

$ErrorActionPreference = "Stop"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-ErrorLog {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-WarningLog {
    param([string]$Message)
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-CommandExists {
    param([string]$Command)
    [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-PythonAvailable {
    <#
    .SYNOPSIS
        Tests if Python is actually available and working
    .DESCRIPTION
        On Windows 11, 'python' command may exist as an App Execution Alias that opens
        the Microsoft Store instead of running Python. This function verifies Python
        is actually installed and working by checking version output.
    #>
    try {
        $version = python --version 2>&1
        return ($version -match "Python \d+\.\d+")
    } catch {
        return $false
    }
}

function Refresh-EnvironmentPath {
    <#
    .SYNOPSIS
        Refreshes the PATH environment variable from Machine and User scopes
    .DESCRIPTION
        Combines Machine and User PATH variables to update the current session's PATH.
        Useful after installing new tools via Chocolatey or other installers.
    #>
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

# ============================================================================
# Phase 0: Self-Update (Git Pull)
# ============================================================================

Write-Log "LLM Tools Installation Script for Windows"
Write-Log "=========================================="
Write-Host ""

Write-Log "Checking for script updates..."

# Temporarily disable strict error handling for git operations
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"

# Check if we're in a git repository
$gitDir = & git -C $PSScriptRoot rev-parse --git-dir 2>&1
$isGitRepo = ($LASTEXITCODE -eq 0)

if ($isGitRepo) {
    Write-Log "Git repository detected, checking for updates..."

    # Fetch latest changes
    $fetchOutput = & git -C $PSScriptRoot fetch origin 2>&1
    $fetchSuccess = ($LASTEXITCODE -eq 0)

    if ($fetchSuccess) {
        # Get local and remote commit hashes
        $localCommit = & git -C $PSScriptRoot rev-parse HEAD 2>&1
        $remoteCommit = & git -C $PSScriptRoot rev-parse '@{u}' 2>&1
        $hasUpstream = ($LASTEXITCODE -eq 0)

        if (-not $hasUpstream) {
            # No upstream configured, skip update check
            Write-Log "No upstream branch configured, skipping update check"
            $remoteCommit = $localCommit
        }

        if ($localCommit -ne $remoteCommit) {
            Write-Log "Updates found! Pulling latest changes..."
            $pullOutput = & git -C $PSScriptRoot pull 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Log "Updates applied successfully. Re-executing script..."
                Write-Host ""

                # Restore error handling before re-execution
                $ErrorActionPreference = $previousErrorAction

                & $MyInvocation.MyCommand.Path @PSBoundParameters
                exit $LASTEXITCODE
            } else {
                Write-WarningLog "Failed to pull updates: git pull returned exit code $LASTEXITCODE"
                Write-WarningLog "Continuing with current version"
            }
        } else {
            Write-Log "Script is up to date"
        }
    } else {
        Write-WarningLog "Failed to fetch updates from remote repository"
        Write-WarningLog "Continuing with current version"
    }
} else {
    Write-WarningLog "Not running from a git repository. Self-update disabled."
}

# Restore strict error handling
$ErrorActionPreference = $previousErrorAction

Write-Host ""

# ============================================================================
# Phase 1: Admin Check and Chocolatey Installation
# ============================================================================

# Check if Chocolatey is installed
$chocoInstalled = Test-CommandExists "choco"

if (-not $chocoInstalled) {
    Write-Log "Chocolatey is not installed."
    Write-Host ""

    if (-not (Test-Administrator)) {
        Write-ErrorLog "Chocolatey installation requires Administrator privileges."
        Write-Host ""
        Write-Host "Please run this script as Administrator to install Chocolatey, or install Chocolatey manually:"
        Write-Host "https://chocolatey.org/install"
        Write-Host ""
        Write-Host "After installing Chocolatey, you can re-run this script without Administrator privileges."
        exit 1
    }

    Write-Log "Installing Chocolatey..."
    Write-Host ""

    try {
        # Install Chocolatey
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        # Refresh environment variables
        Refresh-EnvironmentPath

        Write-Log "Chocolatey installed successfully"
    } catch {
        Write-ErrorLog "Failed to install Chocolatey: $_"
        exit 1
    }
} else {
    Write-Log "Chocolatey is already installed"
}

# From here on, we don't need admin rights for most operations
if (Test-Administrator) {
    Write-WarningLog "Running as Administrator. Installations will be system-wide where possible."
} else {
    Write-Log "Running as regular user. Installations will be user-scoped where possible."
}

Write-Host ""

# ============================================================================
# Phase 1: Install Prerequisites via Chocolatey
# ============================================================================

Write-Log "Installing prerequisites via Chocolatey..."
Write-Host ""

# Install Git
if (-not (Test-CommandExists "git")) {
    Write-Log "Installing Git..."
    try {
        if (Test-Administrator) {
            & choco install git -y
        } else {
            Write-WarningLog "Git installation may require Administrator privileges."
            Write-Host "Please install Git manually from: https://git-scm.com/download/win"
            Write-Host "Or run this script as Administrator."
            $continue = Read-Host "Continue without Git? (y/N)"
            if ($continue -ne 'y' -and $continue -ne 'Y') {
                exit 1
            }
        }
    } catch {
        Write-WarningLog "Git installation skipped: $_"
    }
} else {
    Write-Log "Git is already installed"
}

# Install Python 3.13
if (-not (Test-PythonAvailable)) {
    Write-Log "Installing Python 3.13..."
    try {
        if (Test-Administrator) {
            & choco install python313 -y
        } else {
            Write-WarningLog "Python 3.13 installation requires Administrator privileges."
            Write-Host "Please install Python manually from: https://www.python.org/downloads/"
            Write-Host "Or run this script as Administrator."
            exit 1
        }
    } catch {
        Write-ErrorLog "Failed to install Python: $_"
        exit 1
    }

    # Refresh PATH
    Refresh-EnvironmentPath
} else {
    $pythonVersion = & python --version 2>&1
    Write-Log "Python is already installed ($pythonVersion)"
}

# Install Node.js 22.x
if (-not (Test-CommandExists "node")) {
    Write-Log "Installing Node.js 22..."
    try {
        if (Test-Administrator) {
            & choco install nodejs-lts --version-all -y
        } else {
            Write-WarningLog "Node.js installation requires Administrator privileges."
            Write-Host "Please install Node.js manually from: https://nodejs.org/"
            Write-Host "Or run this script as Administrator."
            exit 1
        }
    } catch {
        Write-ErrorLog "Failed to install Node.js: $_"
        exit 1
    }

    # Refresh PATH
    Refresh-EnvironmentPath
} else {
    $nodeVersion = & node --version
    Write-Log "Node.js is already installed ($nodeVersion)"
}

# Install jq
if (-not (Test-CommandExists "jq")) {
    Write-Log "Installing jq..."
    try {
        if (Test-Administrator) {
            & choco install jq -y
        } else {
            Write-WarningLog "jq installation skipped (requires Administrator privileges)"
        }
    } catch {
        Write-WarningLog "jq installation skipped: $_"
    }
} else {
    Write-Log "jq is already installed"
}

# Refresh PATH to pick up newly installed tools
Refresh-EnvironmentPath

Write-Host ""

# ============================================================================
# Phase 2: Install Python Tools (User Scope)
# ============================================================================

Write-Log "Installing Python tools..."
Write-Host ""

# Ensure pip is up to date
Write-Log "Upgrading pip..."
try {
    & python -m pip install --upgrade pip --user --quiet
} catch {
    Write-WarningLog "Failed to upgrade pip: $_"
}

# Install pipx
Write-Log "Installing/upgrading pipx..."
try {
    & python -m pip install --upgrade pipx --user --quiet

    # Ensure pipx paths are set up (adds to persistent PATH)
    & python -m pipx ensurepath --force

    # Refresh PATH in current session to include Python Scripts directory
    Refresh-EnvironmentPath

    # Also ensure .local\bin is in current session PATH
    $pipxBinPath = Join-Path $env:USERPROFILE ".local\bin"
    if ($env:Path -notlike "*$pipxBinPath*") {
        $env:Path = "$pipxBinPath;$env:Path"
    }
} catch {
    Write-ErrorLog "Failed to install pipx: $_"
    exit 1
}

# Install uv
Write-Log "Installing/upgrading uv..."
try {
    if (Test-CommandExists "uv") {
        & pipx upgrade uv
    } else {
        & pipx install uv
    }
} catch {
    Write-ErrorLog "Failed to install uv: $_"
    exit 1
}

# Refresh PATH
$pipxBinPath = Join-Path $env:USERPROFILE ".local\bin"
if ($env:Path -notlike "*$pipxBinPath*") {
    $env:Path = "$pipxBinPath;$env:Path"
}

Write-Host ""

# ============================================================================
# Phase 3: Install LLM Core
# ============================================================================

Write-Log "Installing/updating llm..."
Write-Host ""

$ErrorActionPreference = "Continue"

# Check if llm is already installed
$llmInstalled = & uv tool list 2>&1 | Select-String "llm"

if ($llmInstalled) {
    Write-Log "llm is already installed, upgrading..."
    & uv tool upgrade llm
} else {
    Write-Log "Installing llm..."
    & uv tool install llm
}

if ($LASTEXITCODE -ne 0) {
    $ErrorActionPreference = "Stop"
    Write-ErrorLog "Failed to install/upgrade llm"
    exit 1
}

$ErrorActionPreference = "Stop"

# Ensure llm is in PATH
$uvToolsPath = Join-Path $env:USERPROFILE ".local\bin"
if ($env:Path -notlike "*$uvToolsPath*") {
    $env:Path = "$uvToolsPath;$env:Path"
}

Write-Host ""

# ============================================================================
# Phase 4: Configure Azure OpenAI (Optional)
# ============================================================================

# Detect if this is first run
$llmConfigDir = Join-Path $env:APPDATA "io.datasette.llm"
$extraModelsFile = Join-Path $llmConfigDir "extra-openai-models.yaml"
$isFirstRun = -not (Test-Path $extraModelsFile)

$azureConfigured = $false
$azureApiBase = ""

if ($isFirstRun) {
    Write-Log "Azure OpenAI Configuration"
    Write-Host ""
    $configAzure = Read-Host "Do you want to configure Azure OpenAI? (Y/n)"

    if ([string]::IsNullOrEmpty($configAzure) -or $configAzure -eq 'Y' -or $configAzure -eq 'y') {
        Write-Log "Configuring Azure OpenAI API..."
        Write-Host ""

        $azureApiBase = Read-Host "Enter your Azure Foundry resource URL (e.g., https://YOUR-RESOURCE.openai.azure.com/openai/v1/)"

        # Set Azure API key
        & llm keys set azure

        $azureConfigured = $true
    } else {
        Write-Log "Skipping Azure OpenAI configuration"
    }
} elseif (Test-Path $extraModelsFile) {
    Write-Log "Azure OpenAI was previously configured, preserving existing configuration"

    # Extract existing API base
    $yamlContent = Get-Content $extraModelsFile -Raw
    if ($yamlContent -match 'api_base:\s*(.+)') {
        $azureApiBase = $matches[1].Trim()
        Write-Log "Using existing API base: $azureApiBase"
    } else {
        $azureApiBase = "https://REPLACE-ME.openai.azure.com/openai/v1/"
        Write-WarningLog "Could not read existing API base, using placeholder"
    }

    $azureConfigured = $true
} else {
    Write-Log "Azure OpenAI not configured (skipped during initial setup)"
}

# Create extra-openai-models.yaml if Azure was configured
if ($azureConfigured) {
    Write-Log "Creating Azure OpenAI models configuration..."

    $yamlContent = @"
- model_id: azure/gpt-5
  model_name: gpt-5
  api_base: $azureApiBase
  api_key_name: azure
  supports_tools: true
  supports_schema: true
  vision: true

- model_id: azure/gpt-5-mini
  model_name: gpt-5-mini
  api_base: $azureApiBase
  api_key_name: azure
  supports_tools: true
  supports_schema: true
  vision: true

- model_id: azure/gpt-5-nano
  model_name: gpt-5-nano
  api_base: $azureApiBase
  api_key_name: azure
  supports_tools: true
  supports_schema: true
  vision: true

- model_id: azure/o4-mini
  model_name: o4-mini
  api_base: $azureApiBase
  api_key_name: azure
  supports_tools: true
  supports_schema: true
  vision: true

- model_id: azure/gpt-4.1
  model_name: gpt-4.1
  api_base: $azureApiBase
  api_key_name: azure
  supports_tools: true
  supports_schema: true
  vision: true
"@

    New-Item -ItemType Directory -Path $llmConfigDir -Force | Out-Null
    Set-Content -Path $extraModelsFile -Value $yamlContent -Encoding UTF8

    # Set default model if not already set
    $defaultModelFile = Join-Path $llmConfigDir "default_model.txt"
    if (-not (Test-Path $defaultModelFile)) {
        Write-Log "Setting default model to azure/gpt-5-mini..."
        & llm models default azure/gpt-5-mini
    } else {
        Write-Log "Default model already configured, skipping..."
    }
}

Write-Host ""

# ============================================================================
# Phase 5: Install LLM Plugins
# ============================================================================

Write-Log "Installing/updating llm plugins..."
Write-Host ""

$plugins = @(
    "llm-gemini",
    "llm-openrouter",
    "llm-anthropic",
    "llm-cmd",
    "llm-cmd-comp",
    "llm-tools-sqlite",
    "llm-fragments-site-text",
    "llm-fragments-pdf",
    "llm-fragments-github",
    "llm-jq"
)

# Git-based plugins (may require git to be properly configured)
$gitPlugins = @(
    "git+https://github.com/damonmcminn/llm-templates-fabric"
)

# Install regular plugins
foreach ($plugin in $plugins) {
    Write-Log "Installing/updating $plugin..."
    try {
        # Try upgrade first, if it fails, try install
        & llm install $plugin --upgrade
        if ($LASTEXITCODE -ne 0) {
            & llm install $plugin
        }
    } catch {
        Write-WarningLog "Failed to install $plugin : $_"
    }
}

# Install git-based plugins (with better error handling)
foreach ($plugin in $gitPlugins) {
    Write-Log "Installing/updating $plugin..."
    try {
        # Verify git is available before attempting
        if (-not (Test-CommandExists "git")) {
            Write-WarningLog "Git is not available. Skipping $plugin"
            continue
        }

        & llm install $plugin --upgrade
        if ($LASTEXITCODE -ne 0) {
            Write-WarningLog "Failed to install $plugin"
            Write-WarningLog "This is optional and can be installed manually later with: llm install $plugin"
        }
    } catch {
        Write-WarningLog "Failed to install $plugin : $_"
        Write-WarningLog "This is optional and can be installed manually later"
    }
}

Write-Host ""

# ============================================================================
# Phase 6: Install LLM Templates
# ============================================================================

Write-Log "Installing/updating llm templates..."
Write-Host ""

# Get templates directory
$templatesDir = & llm logs path | Split-Path | Join-Path -ChildPath "templates"

# Create templates directory if it doesn't exist
New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null

# Copy assistant.yaml template from repository
$sourceTemplate = Join-Path $PSScriptRoot "llm-template\assistant.yaml"
$destTemplate = Join-Path $templatesDir "assistant.yaml"

if (Test-Path $sourceTemplate) {
    if (Test-Path $destTemplate) {
        # Both files exist - compare them
        $sourceHash = (Get-FileHash $sourceTemplate).Hash
        $destHash = (Get-FileHash $destTemplate).Hash

        if ($sourceHash -ne $destHash) {
            Write-Log "Template has changed in repository"
            Write-Host ""
            $updateTemplate = Read-Host "The assistant.yaml template in the repository differs from your installed version. Update it? (y/N)"

            if ($updateTemplate -eq 'y' -or $updateTemplate -eq 'Y') {
                Copy-Item $sourceTemplate $destTemplate -Force
                Write-Log "Template updated to $destTemplate"
            } else {
                Write-Log "Keeping existing template"
            }
        } else {
            Write-Log "Template is up to date"
        }
    } else {
        # Only repo version exists - install it
        Write-Log "Installing assistant.yaml template..."
        Copy-Item $sourceTemplate $destTemplate
        Write-Log "Template installed to $destTemplate"
    }
} else {
    Write-WarningLog "Template not found at $sourceTemplate"
}

Write-Host ""

# ============================================================================
# Phase 7: Install Additional Tools
# ============================================================================

Write-Log "Installing/updating additional tools..."
Write-Host ""

# Verify npm is available
if (-not (Test-CommandExists "npm")) {
    Write-ErrorLog "npm is not available. Cannot install npm-based tools."
    Write-ErrorLog "Please ensure Node.js and npm are properly installed and in PATH."
    exit 1
}

# Configure npm for user-level global installs (if not admin)
if (-not (Test-Administrator)) {
    Write-Log "Configuring npm for user-level global installs..."
    $npmGlobalPrefix = Join-Path $env:USERPROFILE ".npm-global"

    try {
        & npm config set prefix $npmGlobalPrefix

        # Add to PATH for current session
        if ($env:Path -notlike "*$npmGlobalPrefix*") {
            $env:Path = "$npmGlobalPrefix;$env:Path"
        }

        Write-Log "npm configured to use: $npmGlobalPrefix"
    } catch {
        Write-WarningLog "Failed to configure npm prefix: $_"
    }
}

# Refresh PATH to ensure npm and node are accessible
Refresh-EnvironmentPath

# Install repomix
Write-Log "Installing/updating repomix..."
try {
    & npm install -g repomix
    if ($LASTEXITCODE -ne 0) {
        Write-WarningLog "Failed to install repomix"
    }
} catch {
    Write-WarningLog "Failed to install repomix: $_"
}

# Install gitingest
Write-Log "Installing/updating gitingest..."

$ErrorActionPreference = "Continue"

$gitingestInstalled = & uv tool list 2>&1 | Select-String "gitingest"
if ($gitingestInstalled) {
    & uv tool upgrade gitingest
    if ($LASTEXITCODE -ne 0) {
        Write-WarningLog "Failed to upgrade gitingest"
    }
} else {
    & uv tool install gitingest
    if ($LASTEXITCODE -ne 0) {
        Write-WarningLog "Failed to install gitingest"
    }
}

$ErrorActionPreference = "Stop"

# Install files-to-prompt
Write-Log "Installing/updating files-to-prompt..."

$ErrorActionPreference = "Continue"

$filesPromptInstalled = & uv tool list 2>&1 | Select-String "files-to-prompt"
if ($filesPromptInstalled) {
    & uv tool upgrade files-to-prompt
    if ($LASTEXITCODE -ne 0) {
        Write-WarningLog "Failed to upgrade files-to-prompt"
    }
} else {
    & uv tool install "git+https://github.com/danmackinlay/files-to-prompt"
    if ($LASTEXITCODE -ne 0) {
        Write-WarningLog "Failed to install files-to-prompt"
    }
}

$ErrorActionPreference = "Stop"

Write-Host ""

# ============================================================================
# Phase 8: Install Claude Code & OpenCode
# ============================================================================

Write-Log "Installing/updating Claude Code and OpenCode..."
Write-Host ""

# Install Claude Code
Write-Log "Installing/updating Claude Code..."
try {
    & npm install -g "@anthropic-ai/claude-code"
    if ($LASTEXITCODE -ne 0) {
        Write-WarningLog "Failed to install Claude Code"
    }
} catch {
    Write-WarningLog "Failed to install Claude Code: $_"
}

# Install OpenCode
Write-Log "Installing/updating OpenCode..."
try {
    & npm install -g "opencode-ai@latest"
    if ($LASTEXITCODE -ne 0) {
        Write-WarningLog "Failed to install OpenCode"
    }
} catch {
    Write-WarningLog "Failed to install OpenCode: $_"
}

Write-Host ""

# ============================================================================
# Phase 9: PowerShell Profile Integration
# ============================================================================

Write-Log "Setting up PowerShell profile integration..."
Write-Host ""

# Define integration source
$integrationFile = Join-Path $PSScriptRoot "integration\llm-integration.ps1"

# PowerShell 5 profile path
$ps5ProfilePath = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

# PowerShell 7 profile path
$ps7ProfilePath = Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"

# Integration snippet to add
$integrationSnippet = @"

# LLM Tools Integration
if (Test-Path "$integrationFile") {
    . "$integrationFile"
}
"@

# Function to add integration to profile
function Add-IntegrationToProfile {
    param(
        [string]$ProfilePath,
        [string]$ProfileName
    )

    # Create profile directory if it doesn't exist
    $profileDir = Split-Path $ProfilePath
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Create profile file if it doesn't exist
    if (-not (Test-Path $ProfilePath)) {
        New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
    }

    # Check if integration is already present
    $profileContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($profileContent) -or ($profileContent -notmatch "llm-integration\.ps1")) {
        Write-Log "Adding llm integration to $ProfileName profile..."
        Add-Content -Path $ProfilePath -Value $integrationSnippet
    } else {
        Write-Log "llm integration already present in $ProfileName profile"
    }
}

# Add to PowerShell 5 profile
Add-IntegrationToProfile -ProfilePath $ps5ProfilePath -ProfileName "PowerShell 5"

# Add to PowerShell 7 profile (if PowerShell 7 is installed)
if (Test-CommandExists "pwsh") {
    Add-IntegrationToProfile -ProfilePath $ps7ProfilePath -ProfileName "PowerShell 7"
}

Write-Host ""

# ============================================================================
# COMPLETE
# ============================================================================

Write-Host ""
Write-Log "============================================="
Write-Log "Installation/Update Complete!"
Write-Log "============================================="
Write-Host ""
Write-Log "Installed tools:"
Write-Log "  - llm (Simon Willison's CLI tool)"
Write-Log "  - llm plugins (gemini, anthropic, tools, fragments, jq, fabric templates)"
Write-Log "  - repomix (repository packager)"
Write-Log "  - gitingest (Git repository to LLM-friendly text)"
Write-Log "  - files-to-prompt (file content formatter)"
Write-Log "  - Claude Code (Anthropic's agentic coding CLI)"
Write-Log "  - OpenCode (AI coding agent for terminal)"
Write-Host ""
Write-Log "PowerShell integration files:"
Write-Log "  - $integrationFile"
Write-Host ""
Write-Log "Next steps:"
Write-Log "  1. Restart your PowerShell session or run: . `$PROFILE"
Write-Log "  2. Test llm: llm 'Hello, how are you?'"
Write-Log "  3. Use Ctrl+N in PowerShell for AI command completion"
Write-Log "  4. Test and configure OpenCode: opencode"
Write-Log "     Configuration: https://opencode.ai/docs/providers"
Write-Host ""
Write-Log "To update all tools in the future, simply re-run this script:"
Write-Log "  .\Install-LlmTools.ps1"
Write-Host ""
