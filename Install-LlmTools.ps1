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
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

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

function Write-Warning {
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
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# ============================================================================
# Phase 0: Admin Check and Chocolatey Installation
# ============================================================================

Write-Log "LLM Tools Installation Script for Windows"
Write-Log "=========================================="
Write-Host ""

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
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

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
    Write-Warning "Running as Administrator. Installations will be system-wide where possible."
} else {
    Write-Log "Running as regular user. Installations will be user-scoped where possible."
}

Write-Host ""

# ============================================================================
# Phase 1: Install Prerequisites via Chocolatey
# ============================================================================

Write-Log "Installing prerequisites via Chocolatey..."
Write-Host ""

# Determine if we need to use sudo (if running as non-admin after choco install)
$chocoCmd = if (Test-Administrator) { "choco" } else { "choco" }

# Install Git
if (-not (Test-CommandExists "git")) {
    Write-Log "Installing Git..."
    try {
        if (Test-Administrator) {
            & choco install git -y
        } else {
            Write-Warning "Git installation may require Administrator privileges."
            Write-Host "Please install Git manually from: https://git-scm.com/download/win"
            Write-Host "Or run this script as Administrator."
            $continue = Read-Host "Continue without Git? (y/N)"
            if ($continue -ne 'y' -and $continue -ne 'Y') {
                exit 1
            }
        }
    } catch {
        Write-Warning "Git installation skipped: $_"
    }
} else {
    Write-Log "Git is already installed"
}

# Install Python 3.13
if (-not (Test-CommandExists "python")) {
    Write-Log "Installing Python 3.13..."
    try {
        if (Test-Administrator) {
            & choco install python313 -y
        } else {
            Write-Warning "Python 3.13 installation requires Administrator privileges."
            Write-Host "Please install Python manually from: https://www.python.org/downloads/"
            Write-Host "Or run this script as Administrator."
            exit 1
        }
    } catch {
        Write-ErrorLog "Failed to install Python: $_"
        exit 1
    }

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
} else {
    Write-Log "Python is already installed"
}

# Install Node.js 22.x
if (-not (Test-CommandExists "node")) {
    Write-Log "Installing Node.js 22..."
    try {
        if (Test-Administrator) {
            & choco install nodejs-lts --version-all -y
        } else {
            Write-Warning "Node.js installation requires Administrator privileges."
            Write-Host "Please install Node.js manually from: https://nodejs.org/"
            Write-Host "Or run this script as Administrator."
            exit 1
        }
    } catch {
        Write-ErrorLog "Failed to install Node.js: $_"
        exit 1
    }

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
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
            Write-Warning "jq installation skipped (requires Administrator privileges)"
        }
    } catch {
        Write-Warning "jq installation skipped: $_"
    }
} else {
    Write-Log "jq is already installed"
}

# Refresh PATH to pick up newly installed tools
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

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
    Write-Warning "Failed to upgrade pip: $_"
}

# Install pipx
Write-Log "Installing/upgrading pipx..."
try {
    & python -m pip install --upgrade pipx --user --quiet

    # Ensure pipx path is in PATH
    $pipxBinPath = "$env:USERPROFILE\.local\bin"
    if ($env:Path -notlike "*$pipxBinPath*") {
        $env:Path = "$pipxBinPath;$env:Path"
    }

    # Ensure pipx paths are set up
    & python -m pipx ensurepath --force
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
$pipxBinPath = "$env:USERPROFILE\.local\bin"
if ($env:Path -notlike "*$pipxBinPath*") {
    $env:Path = "$pipxBinPath;$env:Path"
}

Write-Host ""

# ============================================================================
# Phase 3: Install LLM Core
# ============================================================================

Write-Log "Installing/updating llm..."
Write-Host ""

try {
    # Check if llm is already installed
    $llmInstalled = & uv tool list 2>$null | Select-String "llm"

    if ($llmInstalled) {
        Write-Log "llm is already installed, upgrading..."
        & uv tool upgrade llm
    } else {
        Write-Log "Installing llm..."
        & uv tool install llm
    }
} catch {
    Write-ErrorLog "Failed to install llm: $_"
    exit 1
}

# Ensure llm is in PATH
$uvToolsPath = "$env:USERPROFILE\.local\bin"
if ($env:Path -notlike "*$uvToolsPath*") {
    $env:Path = "$uvToolsPath;$env:Path"
}

Write-Host ""

# ============================================================================
# Phase 4: Configure Azure OpenAI (Optional)
# ============================================================================

# Detect if this is first run
$llmConfigDir = "$env:APPDATA\io.datasette.llm"
$extraModelsFile = "$llmConfigDir\extra-openai-models.yaml"
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
        Write-Warning "Could not read existing API base, using placeholder"
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
    $defaultModelFile = "$llmConfigDir\default_model.txt"
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
    "llm-tools-quickjs",
    "llm-tools-sqlite",
    "llm-fragments-site-text",
    "llm-fragments-pdf",
    "llm-fragments-github",
    "llm-jq",
    "git+https://github.com/damonmcminn/llm-templates-fabric"
)

foreach ($plugin in $plugins) {
    Write-Log "Installing/updating $plugin..."
    try {
        # Try upgrade first, if it fails, try install
        $upgradeResult = & llm install $plugin --upgrade 2>&1
        if ($LASTEXITCODE -ne 0) {
            & llm install $plugin
        }
    } catch {
        Write-Warning "Failed to install $plugin : $_"
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
$sourceTemplate = Join-Path $ScriptDir "llm-template\assistant.yaml"
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
    Write-Warning "Template not found at $sourceTemplate"
}

Write-Host ""

# ============================================================================
# Phase 7: Install Additional Tools
# ============================================================================

Write-Log "Installing/updating additional tools..."
Write-Host ""

# Configure npm for user-level global installs (if not admin)
if (-not (Test-Administrator)) {
    Write-Log "Configuring npm for user-level global installs..."
    $npmGlobalPrefix = "$env:USERPROFILE\.npm-global"
    & npm config set prefix $npmGlobalPrefix

    # Add to PATH
    if ($env:Path -notlike "*$npmGlobalPrefix*") {
        $env:Path = "$npmGlobalPrefix;$env:Path"
    }
}

# Install repomix
Write-Log "Installing/updating repomix..."
try {
    & npm install -g repomix
} catch {
    Write-Warning "Failed to install repomix: $_"
}

# Install gitingest
Write-Log "Installing/updating gitingest..."
try {
    $gitingestInstalled = & uv tool list 2>$null | Select-String "gitingest"
    if ($gitingestInstalled) {
        & uv tool upgrade gitingest
    } else {
        & uv tool install gitingest
    }
} catch {
    Write-Warning "Failed to install gitingest: $_"
}

# Install files-to-prompt
Write-Log "Installing/updating files-to-prompt..."
try {
    $filesPromptInstalled = & uv tool list 2>$null | Select-String "files-to-prompt"
    if ($filesPromptInstalled) {
        & uv tool upgrade files-to-prompt
    } else {
        & uv tool install "git+https://github.com/danmackinlay/files-to-prompt"
    }
} catch {
    Write-Warning "Failed to install files-to-prompt: $_"
}

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
} catch {
    Write-Warning "Failed to install Claude Code: $_"
}

# Install OpenCode
Write-Log "Installing/updating OpenCode..."
try {
    & npm install -g "opencode-ai@latest"
} catch {
    Write-Warning "Failed to install OpenCode: $_"
}

Write-Host ""

# ============================================================================
# Phase 9: PowerShell Profile Integration
# ============================================================================

Write-Log "Setting up PowerShell profile integration..."
Write-Host ""

# Define integration source
$integrationFile = Join-Path $ScriptDir "integration\llm-integration.ps1"

# PowerShell 5 profile path
$ps5ProfilePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

# PowerShell 7 profile path
$ps7ProfilePath = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"

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

    if ($profileContent -notmatch "llm-integration\.ps1") {
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
