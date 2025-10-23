#Requires -Version 5.1
<#
.SYNOPSIS
    LLM Tools Installation Script for Windows (10/11/Server)

.DESCRIPTION
    Installs Simon Willison's llm CLI tool and related AI/LLM command-line utilities
    for Windows environments. Supports both PowerShell 5.1 and PowerShell 7+.

.PARAMETER Azure
    Force Azure OpenAI configuration (even if previously configured or skipped)

.EXAMPLE
    .\Install-LlmTools.ps1
    Run the installation script

.EXAMPLE
    .\Install-LlmTools.ps1 -Azure
    Run installation and force Azure OpenAI configuration

.NOTES
    Author: Based on llm-linux-setup by c0ffee0wl
    Version: 1.0
    Requires: Windows 10/11/Server, PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [switch]$Azure
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

function Add-ToPath {
    <#
    .SYNOPSIS
        Adds a directory to the current session's PATH if not already present
    .PARAMETER Path
        The directory path to add to PATH
    #>
    param([string]$Path)

    if ($env:Path -notlike "*$Path*") {
        $env:Path = "$Path;$env:Path"
    }
}

function Install-ChocoPackage {
    <#
    .SYNOPSIS
        Installs a package via Chocolatey with admin checks
    .PARAMETER PackageName
        The Chocolatey package name to install
    .PARAMETER CommandName
        The command name to check for (defaults to PackageName)
    .PARAMETER ManualUrl
        URL for manual installation instructions
    .PARAMETER AllowSkip
        If true, allows user to skip installation
    .PARAMETER SkipCheck
        If true, don't check if command already installed
	#>
    param(
        [string]$PackageName,
        [string]$CommandName = $PackageName,
        [string]$ManualUrl = "",
        [bool]$AllowSkip = $false,
		[bool]$SkipCheck = $false
    )

    if ((-not $SkipCheck) -and (Test-CommandExists $CommandName)) {
        Write-Log "$CommandName is already installed"
		return $true
    }

    Write-Log "Installing $PackageName..."

    if (Test-Administrator) {
        try {
            & choco install $PackageName -y
            Refresh-EnvironmentPath
            return $true
        } catch {
            Write-WarningLog "Failed to install $PackageName : $_"
            return $false
        }
    } else {
        Write-WarningLog "$PackageName installation requires Administrator privileges."
        if ($ManualUrl) {
            Write-Host "Please install $PackageName manually from: $ManualUrl"
        }
        Write-Host "Or run this script as Administrator."

        if ($AllowSkip) {
            $continue = Read-Host "Continue without $PackageName? (y/N)"
            if ($continue -eq 'y' -or $continue -eq 'Y') {
                return $false
            }
        }
        exit 1
    }
}

function Install-UvTool {
    <#
    .SYNOPSIS
        Installs or upgrades a tool via uv
    .PARAMETER ToolName
        The tool name or git URL to install
    .PARAMETER IsGitPackage
        If true, verifies git is available before installing
    #>
    param(
        [string]$ToolName,
        [bool]$IsGitPackage = $false
    )

    if ($IsGitPackage -and -not (Test-CommandExists "git")) {
        Write-WarningLog "Git is not available. Skipping $ToolName"
        return $false
    }

    Write-Log "Installing/updating $ToolName..."

    # Temporarily disable strict error handling for uv operations
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    # Extract tool name from git URL if needed (e.g., "git+https://github.com/user/repo" -> "repo")
    $toolNameToCheck = $ToolName -replace 'git\+https://.+/(.+?)(?:\.git)?$', '$1'

    # Check if tool is already installed
    $toolInstalled = & uv tool list 2>&1 | Select-String $toolNameToCheck

    if ($toolInstalled) {
        & uv tool upgrade $toolNameToCheck
    } else {
        & uv tool install $ToolName
    }

    if ($LASTEXITCODE -ne 0) {
        $ErrorActionPreference = $previousErrorAction
        Write-WarningLog "Failed to install/upgrade $ToolName"
        return $false
    }

    # Restore previous error handling
    $ErrorActionPreference = $previousErrorAction
    return $true
}

function Install-NpmPackage {
    <#
    .SYNOPSIS
        Installs a package globally via npm
    .PARAMETER PackageName
        The npm package name to install
    #>
    param([string]$PackageName)

    Write-Log "Installing/updating $PackageName..."

    try {
        npm install -g $PackageName
        if ($LASTEXITCODE -ne 0) {
            Write-WarningLog "Failed to install $PackageName"
            return $false
        }
        return $true
    } catch {
        Write-WarningLog "Failed to install $PackageName : $_"
        return $false
    }
}

function Install-LlmTemplate {
    <#
    .SYNOPSIS
        Installs or updates an llm template file with smart update detection
    .DESCRIPTION
        Uses three-way comparison to detect user modifications:
        - Tracks hash of last installed version in metadata file
        - Auto-updates silently if user hasn't modified the template
        - Prompts only if user has local modifications
    .PARAMETER TemplateName
        The template name without .yaml extension (e.g., "assistant", "code")
    .PARAMETER TemplatesDir
        The llm templates directory path
    #>
    param(
        [string]$TemplateName,
        [string]$TemplatesDir
    )

    $sourceTemplate = Join-Path $PSScriptRoot "llm-template\$TemplateName.yaml"
    $destTemplate = Join-Path $TemplatesDir "$TemplateName.yaml"
    $llmConfigDir = Join-Path $env:APPDATA "io.datasette.llm"
    $metadataFile = Join-Path $llmConfigDir ".template-hashes.json"

    if (-not (Test-Path $sourceTemplate)) {
        Write-WarningLog "Template '$TemplateName' not found at $sourceTemplate"
        return $false
    }

    # Load metadata (PS5 compatible)
    $metadata = @{}
    if (Test-Path $metadataFile) {
        try {
            $jsonContent = Get-Content $metadataFile -Raw | ConvertFrom-Json
            # Convert PSCustomObject to hashtable for PS5 compatibility
            $jsonContent.PSObject.Properties | ForEach-Object {
                $metadata[$_.Name] = $_.Value
            }
        } catch {
            Write-WarningLog "Failed to read template metadata: $_"
        }
    }

    if (Test-Path $destTemplate) {
        # Both files exist - perform three-way comparison
        $sourceHash = (Get-FileHash $sourceTemplate).Hash
        $destHash = (Get-FileHash $destTemplate).Hash

        # Check if files are identical
        if ($sourceHash -eq $destHash) {
            Write-Log "Template '$TemplateName' is up to date"
            # Update metadata to reflect current state
            $metadata[$TemplateName] = $sourceHash
        } else {
            # Files differ - check if user has modified it
            $lastInstalledHash = $metadata[$TemplateName]
            $userModified = $lastInstalledHash -and ($destHash -ne $lastInstalledHash)

            if ($userModified) {
                # User has local modifications - prompt before overwriting
                Write-Log "Template '$TemplateName' has local modifications"
                Write-Host ""
                Write-Host "Your installed version differs from the last installed version." -ForegroundColor Yellow
                Write-Host "A new version is available in the repository." -ForegroundColor Yellow
                Write-Host ""
                $updateTemplate = Read-Host "Overwrite your local changes? (y/N)"
                Write-Host ""

                if ($updateTemplate -ne 'y' -and $updateTemplate -ne 'Y') {
                    Write-Log "Keeping existing '$TemplateName' template"
                    return $false
                }
            } else {
                # No user modifications detected - auto-update silently
                Write-Log "Updating '$TemplateName' template (no local modifications detected)..."
            }

            # Update template
            Copy-Item $sourceTemplate $destTemplate -Force
            Write-Log "Template '$TemplateName' updated to $destTemplate"

            # Update metadata with new hash
            $metadata[$TemplateName] = $sourceHash
        }
    } else {
        # Only repo version exists - install it
        Write-Log "Installing $TemplateName.yaml template..."
        Copy-Item $sourceTemplate $destTemplate
        Write-Log "Template '$TemplateName' installed to $destTemplate"

        # Store hash in metadata
        $sourceHash = (Get-FileHash $sourceTemplate).Hash
        $metadata[$TemplateName] = $sourceHash
    }

    # Save metadata (PS5 compatible)
    try {
        # Convert hashtable to PSCustomObject for JSON serialization
        $jsonObject = New-Object PSObject
        $metadata.GetEnumerator() | ForEach-Object {
            $jsonObject | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value
        }

        # Ensure directory exists
        New-Item -ItemType Directory -Path $llmConfigDir -Force | Out-Null

        # Save as JSON with ASCII encoding
        $jsonObject | ConvertTo-Json | Set-Content -Path $metadataFile -Encoding Ascii
    } catch {
        Write-WarningLog "Failed to save template metadata: $_"
    }

    return $true
}

# ============================================================================
# Phase 0: Self-Update (Git Pull)
# ============================================================================

Write-Log "LLM Tools Installation Script for Windows"
Write-Log "=========================================="
Write-Host ""

Write-Log "Checking for script updates..."

# Flag to track if we need to initialize git repository (ZIP download scenario)
$needsGitInit = $false

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
        # Check if we have an upstream branch configured
        $remoteCommit = & git -C $PSScriptRoot rev-parse '@{u}' 2>&1
        $hasUpstream = ($LASTEXITCODE -eq 0)

        if (-not $hasUpstream) {
            # No upstream configured, skip update check
            Write-Log "No upstream branch configured, skipping update check"
        } else {
            # Count commits we don't have that remote has (only pull if behind, not ahead or diverged)
            $behindOutput = & git -C $PSScriptRoot rev-list 'HEAD..@{u}' 2>&1
            $behind = if ($LASTEXITCODE -eq 0 -and $behindOutput) {
                ($behindOutput | Measure-Object).Count
            } else {
                0
            }

            if ($behind -gt 0) {
                Write-Log "Updates found! Pulling latest changes..."

                # Check for local modifications before attempting pull
                $statusOutput = & git -C $PSScriptRoot status --porcelain 2>&1
                if ($statusOutput) {
                    Write-WarningLog "Cannot auto-update: local modifications detected"
                    Write-Host ""
                    Write-Host "Modified files:" -ForegroundColor Yellow
                    Write-Host $statusOutput -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "To enable auto-update, choose one option:" -ForegroundColor Cyan
                    Write-Host "  1. Commit changes:  git add . && git commit -m 'local changes'" -ForegroundColor Cyan
                    Write-Host "  2. Stash changes:   git stash" -ForegroundColor Cyan
                    Write-Host "  3. Discard changes: git reset --hard @{u}" -ForegroundColor Cyan
                    Write-Host ""
                    Write-WarningLog "Continuing with current version"
                } else {
                    # Working directory is clean, safe to pull
                    $pullOutput = & git -C $PSScriptRoot pull --ff-only 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Updates applied successfully. Re-executing script..."
                        Write-Host ""

                        # Restore error handling before re-execution
                        $ErrorActionPreference = $previousErrorAction

                        & $MyInvocation.MyCommand.Path @PSBoundParameters
                        exit $LASTEXITCODE
                    } else {
                        Write-WarningLog "Failed to pull updates: git pull returned exit code $LASTEXITCODE"
                        Write-Host ""
                        Write-Host "Git output:" -ForegroundColor Yellow
                        Write-Host $pullOutput -ForegroundColor Yellow
                        Write-Host ""
                        Write-WarningLog "Continuing with current version"
                    }
                }
            } else {
                Write-Log "Script is up to date"
            }
        }
    } else {
        Write-WarningLog "Failed to fetch updates from remote repository"
        Write-WarningLog "Continuing with current version"
    }
} else {
    Write-WarningLog "Not running from a git repository (downloaded as ZIP file)"
    Write-Log "Git will be installed and the repository will be initialized for future auto-updates"
    $needsGitInit = $true
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
# Phase 2: Install Prerequisites via Chocolatey
# ============================================================================

Write-Log "Installing prerequisites via Chocolatey..."
Write-Host ""

# Install Git
Install-ChocoPackage -PackageName "git" -CommandName "git" -ManualUrl "https://git-scm.com/download/win" -AllowSkip $true

# Install Python 3.13 (special handling for Windows Store alias)
if (-not (Test-PythonAvailable)) {
    Install-ChocoPackage -PackageName "python313" -CommandName "python" -ManualUrl "https://www.python.org/downloads/" -AllowSkip $false -SkipCheck $true
} else {
    $pythonVersion = & python --version 2>&1
    Write-Log "Python is already installed ($pythonVersion)"
}

# Install Node.js
Install-ChocoPackage -PackageName "nodejs-lts" -CommandName "node" -ManualUrl "https://nodejs.org/" -AllowSkip $false

# Install jq (optional)
Install-ChocoPackage -PackageName "jq" -CommandName "jq" -ManualUrl "" -AllowSkip $true

# Refresh PATH to pick up newly installed tools
Refresh-EnvironmentPath

Write-Host ""

# ============================================================================
# Phase 2.5: Convert ZIP Installation to Git Repository (Optional)
# ============================================================================

# If this was a ZIP download and git is now available, offer to initialize repository
if ($needsGitInit -and (Test-CommandExists "git")) {
    Write-Log "Initializing git repository for automatic updates..."
    Write-Host ""

    Write-Host "This directory was downloaded as a ZIP file. Would you like to convert it to a git repository?"
    Write-Host "This will enable automatic updates via 'git pull' on future runs."
    Write-Host ""
    Write-Host "WARNING: This will reset any local file modifications to match the repository." -ForegroundColor Yellow
    Write-Host ""
	
    $convertToGit = Read-Host "Convert to git repository? (Y/n)"
	
    if ([string]::IsNullOrEmpty($convertToGit) -or $convertToGit -eq 'Y' -or $convertToGit -eq 'y') {
		Write-Log "Converting directory to git repository..."

        # Repository configuration
        $repoUrl = "https://github.com/c0ffee0wl/llm-windows-setup.git"

        # Temporarily disable strict error handling for git operations
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        try {
            # Initialize git repository
            Write-Log "Initializing git repository..."
            & git -C $PSScriptRoot init 2>&1 | Out-Null

            if ($LASTEXITCODE -ne 0) {
                Write-ErrorLog "Failed to initialize git repository"
                throw "git init failed"
            }

            # Add or update remote (handle case where remote already exists from previous attempt)
            Write-Log "Configuring remote origin: $repoUrl"
            $existingRemote = & git -C $PSScriptRoot remote get-url origin 2>&1

            if ($LASTEXITCODE -ne 0) {
                # Remote doesn't exist, add it
                & git -C $PSScriptRoot remote add origin $repoUrl 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-ErrorLog "Failed to add remote origin"
                    throw "git remote add failed"
                }
            } else {
                # Remote exists, update it to ensure correct URL
                Write-Log "Remote origin already exists, updating URL..."
                & git -C $PSScriptRoot remote set-url origin $repoUrl 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-ErrorLog "Failed to update remote origin"
                    throw "git remote set-url failed"
                }
            }

            # Fetch from remote
            Write-Log "Fetching from remote repository..."
            & git -C $PSScriptRoot fetch origin 2>&1 | Out-Null

            if ($LASTEXITCODE -ne 0) {
                Write-ErrorLog "Failed to fetch from remote repository"
                Write-ErrorLog "Please check your internet connection and try again later"
                throw "git fetch failed"
            }

            # Detect default branch (try main first, fallback to master)
            Write-Log "Detecting default branch..."
            $defaultBranch = $null

            # Check if 'main' branch exists by checking output content
            $mainBranchCheck = & git -C $PSScriptRoot ls-remote --heads origin main 2>&1
            if ($mainBranchCheck -match "refs/heads/main") {
                $defaultBranch = "main"
            } else {
                # Try 'master' branch
                $masterBranchCheck = & git -C $PSScriptRoot ls-remote --heads origin master 2>&1
                if ($masterBranchCheck -match "refs/heads/master") {
                    $defaultBranch = "master"
                }
            }

            if (-not $defaultBranch) {
                Write-ErrorLog "Could not detect default branch (tried 'main' and 'master')"
                throw "Branch detection failed"
            }

            Write-Log "Using branch: $defaultBranch"

            # Checkout branch (force to overwrite ZIP-extracted files)
            Write-Log "Checking out branch $defaultBranch..."
            # Use -f to force overwrite existing files, -B to create or reset branch
            & git -C $PSScriptRoot checkout -f -B $defaultBranch "origin/$defaultBranch" 2>&1 | Out-Null

            if ($LASTEXITCODE -ne 0) {
                Write-ErrorLog "Failed to checkout branch"
                throw "git checkout failed"
            }

            # Set up branch tracking
            Write-Log "Setting up branch tracking..."
            & git -C $PSScriptRoot branch --set-upstream-to=origin/$defaultBranch $defaultBranch 2>&1 | Out-Null

            if ($LASTEXITCODE -ne 0) {
                Write-WarningLog "Failed to set up branch tracking (non-critical)"
            }

            Write-Host ""
            Write-Log "Git repository initialized successfully!"
            Write-Log "Future runs of this script will automatically check for and apply updates via git pull"

        } catch {
            Write-ErrorLog "Failed to convert to git repository: $_"
            Write-Host ""
            Write-Host "You can manually initialize the repository later by running:" -ForegroundColor Yellow
            Write-Host "  cd $PSScriptRoot" -ForegroundColor Yellow
            Write-Host "  git init" -ForegroundColor Yellow
            Write-Host "  git remote add origin $repoUrl" -ForegroundColor Yellow
            Write-Host "  git fetch origin" -ForegroundColor Yellow
            Write-Host "  git checkout -b main origin/main" -ForegroundColor Yellow
        } finally {
            # Restore strict error handling
            $ErrorActionPreference = $previousErrorAction
        }
    } else {
        Write-Log "Skipping git repository initialization"
        Write-Host ""
        Write-Host "To enable auto-updates later, you can:" -ForegroundColor Yellow
        Write-Host "  1. Delete this directory" -ForegroundColor Yellow
        Write-Host "  2. Clone the repository: git clone $repoUrl" -ForegroundColor Yellow
    }

    Write-Host ""
}

# ============================================================================
# Phase 3: Install Python Tools (User Scope)
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
    Add-ToPath $pipxBinPath
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
Add-ToPath $pipxBinPath

Write-Host ""

# ============================================================================
# Phase 4: Install LLM Core
# ============================================================================

# Install llm via uv
if (-not (Install-UvTool -ToolName "llm")) {
    Write-ErrorLog "Failed to install/upgrade llm"
    exit 1
}

# Ensure llm is in PATH
$uvToolsPath = Join-Path $env:USERPROFILE ".local\bin"
Add-ToPath $uvToolsPath

# Resolve llm.exe path to avoid conflicts with PowerShell function wrapper
# When profile is loaded, 'llm' refers to the function, not the executable
# Using the full path ensures we call the actual llm.exe binary throughout the script
try {
    $llmExe = (Get-Command -Name llm -CommandType Application -ErrorAction Stop).Source
} catch {
    Write-ErrorLog "Could not find llm executable after installation"
    exit 1
}

Write-Host ""

# ============================================================================
# Phase 5: Configure Azure OpenAI (Optional)
# ============================================================================

# Detect if this is first run (no config file exists yet)
$llmConfigDir = Join-Path $env:APPDATA "io.datasette.llm"
$extraModelsFile = Join-Path $llmConfigDir "extra-openai-models.yaml"
$isFirstRun = -not (Test-Path $extraModelsFile)

$azureConfigured = $false
$azureApiBase = ""
$shouldPromptForConfig = $false

# Check if we should prompt for Azure configuration
if ($Azure) {
    # -Azure parameter forces configuration
    $shouldPromptForConfig = $true
    Write-Log "Azure OpenAI Configuration (forced by -Azure parameter)"
} elseif ($isFirstRun) {
    # First run - ask user if they want to configure
    $shouldPromptForConfig = $true
    Write-Log "Azure OpenAI Configuration (first-time setup)"
} elseif (Test-Path $extraModelsFile) {
    # Configuration file exists - check if it was previously skipped or configured
    $yamlContent = Get-Content $extraModelsFile -Raw

    if ($yamlContent -match '# Configuration skipped by user') {
        # User previously skipped - don't ask again unless -Azure is used
        Write-Log "Azure OpenAI configuration was previously skipped"
    } else {
        # Previously configured - preserve it
        Write-Log "Azure OpenAI was previously configured, preserving existing configuration"

        # Extract existing API base
        if ($yamlContent -match 'api_base:\s*(.+)') {
            $azureApiBase = $matches[1].Trim()
            Write-Log "Using existing API base: $azureApiBase"
        } else {
            $azureApiBase = "https://REPLACE-ME.openai.azure.com/openai/v1/"
            Write-WarningLog "Could not read existing API base, using placeholder"
        }

        $azureConfigured = $true
    }
}

# Prompt for Azure configuration if needed
if ($shouldPromptForConfig) {
    Write-Host ""
    $configAzure = Read-Host "Do you want to configure Azure OpenAI? (Y/n)"

    if ([string]::IsNullOrEmpty($configAzure) -or $configAzure -eq 'Y' -or $configAzure -eq 'y') {
        Write-Log "Configuring Azure OpenAI API..."
        Write-Host ""

        $azureApiBase = Read-Host "Enter your Azure Foundry resource URL (e.g. https://YOUR-RESOURCE.openai.azure.com/openai/v1/)"

        # Set Azure API key
        & $llmExe keys set azure

        $azureConfigured = $true
    } else {
        Write-Log "Skipping Azure OpenAI configuration"
        # Create marker file to remember user declined
        $skipMarkerLines = @(
            "# Configuration skipped by user",
            "# To configure Azure OpenAI, run: .\Install-LlmTools.ps1 -Azure",
            "# Or manually edit this file following the format at:",
            "# https://llm.datasette.io/en/stable/openai-models.html"
        )
        $skipMarkerContent = $skipMarkerLines -join "`n"
        New-Item -ItemType Directory -Path $llmConfigDir -Force | Out-Null
        Set-Content -Path $extraModelsFile -Value $skipMarkerContent -Encoding Ascii
    }
}

# Create extra-openai-models.yaml if Azure was configured
if ($azureConfigured) {
    Write-Log "Creating Azure OpenAI models configuration..."

    $yamlContent = @"
- model_id: azure/gpt-4.1
  model_name: gpt-4.1
  api_base: $azureApiBase
  api_key_name: azure
  supports_tools: true
  supports_schema: true
  vision: true

- model_id: azure/gpt-4.1-mini
  model_name: gpt-4.1-mini
  api_base: $azureApiBase
  api_key_name: azure
  supports_tools: true
  supports_schema: true
  vision: true

- model_id: azure/gpt-4.1-nano
  model_name: gpt-4.1-nano
  api_base: $azureApiBase
  api_key_name: azure
  supports_tools: true
  supports_schema: true
  vision: true

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
"@

    New-Item -ItemType Directory -Path $llmConfigDir -Force | Out-Null
    Set-Content -Path $extraModelsFile -Value $yamlContent -Encoding Ascii

    # Set default model if not already set
    $defaultModelFile = Join-Path $llmConfigDir "default_model.txt"
    if (-not (Test-Path $defaultModelFile)) {
        Write-Log "Setting default model to azure/gpt-4.1-mini..."
        & $llmExe models default azure/gpt-4.1-mini
    } else {
        # Check if current default is any gpt-5 variant and migrate to gpt-4.1-mini
        $currentDefault = Get-Content $defaultModelFile -Raw -ErrorAction SilentlyContinue
        if ($currentDefault -and $currentDefault.Trim() -like "azure/gpt-5*") {
            Write-Log "Migrating default model from $($currentDefault.Trim()) to azure/gpt-4.1-mini..."
            Write-Host "  Note: gpt-4.1-mini is recommended for most tasks. For complex tasks, use: llm models default azure/gpt-4.1" -ForegroundColor Yellow
            & $llmExe models default azure/gpt-4.1-mini
        } else {
            Write-Log "Default model already configured, skipping..."
        }
    }
}

Write-Host ""

# ============================================================================
# Phase 6: Install LLM Plugins
# ============================================================================

Write-Log "Installing/updating llm plugins..."
Write-Host ""

# Note: $llmExe variable is already resolved in Phase 4 after llm installation
# This ensures we always call the actual llm.exe binary, not the PowerShell function wrapper

# Regular plugins
$plugins = @(
    "llm-gemini",
    "llm-vertex",
    "llm-openrouter",
    "llm-anthropic",
    "llm-tools-sqlite",
    "llm-fragments-site-text",
    "llm-fragments-pdf",
    "llm-fragments-github",
    "llm-jq"
)

# Git-based plugins (may require git to be properly configured)
$gitPlugins = @(
    "git+https://github.com/c0ffee0wl/llm-cmd",
    "git+https://github.com/c0ffee0wl/llm-cmd-comp",
    "git+https://github.com/c0ffee0wl/llm-templates-fabric"
)

# Install regular plugins
foreach ($plugin in $plugins) {
    Write-Log "Installing/updating $plugin..."
    try {
        # Try upgrade first, if it fails, try install
        & $llmExe install $plugin --upgrade
        if ($LASTEXITCODE -ne 0) {
            & $llmExe install $plugin
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

        & $llmExe install $plugin --upgrade
        if ($LASTEXITCODE -ne 0) {
            & $llmExe install $plugin
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
# Phase 7: Install LLM Templates
# ============================================================================

Write-Log "Installing/updating llm templates..."
Write-Host ""

# Get templates directory
$templatesDir = & $llmExe logs path | Split-Path | Join-Path -ChildPath "templates"

# Create templates directory if it doesn't exist
New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null

# Install templates using helper function
Install-LlmTemplate -TemplateName "assistant" -TemplatesDir $templatesDir
Install-LlmTemplate -TemplateName "code" -TemplatesDir $templatesDir

Write-Host ""

# ============================================================================
# Phase 8: PowerShell Profile Integration
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
# Phase 7.5: Context System Setup
# ============================================================================

Write-Log "Setting up PowerShell context system..."
Write-Host ""

# Check if Python is available (required for context command)
if (-not (Test-PythonAvailable)) {
    Write-WarningLog "Python is not available. Context system requires Python."
    Write-WarningLog "Skipping context system setup. You can install Python and re-run this script later."
    Write-Host ""
} else {
    # Prompt for transcript storage location (first-run only)
    $transcriptConfigMarker = Join-Path $llmConfigDir ".transcript-configured"

    if (-not (Test-Path $transcriptConfigMarker)) {
        Write-Log "Configuring PowerShell session history storage..."
        Write-Host ""
        Write-Host "PowerShell sessions are logged for AI context retrieval." -ForegroundColor Cyan
        Write-Host "Choose storage location:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1) Temporary - Store in `$env:TEMP\PowerShell_Transcripts (cleared on logout/reboot)" -ForegroundColor Yellow
        Write-Host "  2) Permanent - Store in `$env:USERPROFILE\PowerShell_Transcripts (survives reboots)" -ForegroundColor Yellow
        Write-Host ""
        $storageChoice = Read-Host "Choice (1/2) [default: 1]"
        Write-Host ""

        if ($storageChoice -eq '2') {
            $transcriptLogDir = Join-Path $env:USERPROFILE "PowerShell_Transcripts"
        } else {
            $transcriptLogDir = Join-Path $env:TEMP "PowerShell_Transcripts"
        }

        # Create directory
        New-Item -ItemType Directory -Path $transcriptLogDir -Force | Out-Null

        # Save configuration marker
        New-Item -ItemType Directory -Path $llmConfigDir -Force | Out-Null
        Set-Content -Path $transcriptConfigMarker -Value $transcriptLogDir -Encoding Ascii

        Write-Log "Transcript storage configured: $transcriptLogDir"
    } else {
        $transcriptLogDir = Get-Content $transcriptConfigMarker -Raw
        $transcriptLogDir = $transcriptLogDir.Trim()
        Write-Log "Using existing transcript storage: $transcriptLogDir"
    }

    # Install context.py script
    Write-Log "Installing context command..."
    $contextSource = Join-Path $PSScriptRoot "context\context.py"
    $contextDest = Join-Path $env:USERPROFILE ".local\bin\context.py"

    if (Test-Path $contextSource) {
        # Create .local\bin if it doesn't exist
        $localBinDir = Join-Path $env:USERPROFILE ".local\bin"
        New-Item -ItemType Directory -Path $localBinDir -Force | Out-Null

        # Copy context.py
        Copy-Item $contextSource $contextDest -Force

        # Create wrapper batch file for easier invocation
        $contextBat = Join-Path $localBinDir "context.bat"
        $contextBatContent = "@echo off`r`npython `"$contextDest`" %*"
        Set-Content -Path $contextBat -Value $contextBatContent -Encoding Ascii

        Write-Log "Context command installed to $localBinDir"
    } else {
        Write-WarningLog "Context script not found at $contextSource"
    }

    # Install llm-tools-context plugin
    Write-Log "Installing llm-tools-context plugin..."
    $contextPluginPath = Join-Path $PSScriptRoot "llm-tools-context"

    if (Test-Path $contextPluginPath) {
        try {
            & $llmExe install $contextPluginPath --upgrade --no-cache-dir
            if ($LASTEXITCODE -ne 0) {
                & $llmExe install $contextPluginPath --no-cache-dir
            }
            Write-Log "llm-tools-context plugin installed successfully"
        } catch {
            Write-WarningLog "Failed to install llm-tools-context plugin: $_"
        }
    } else {
        Write-WarningLog "llm-tools-context plugin not found at $contextPluginPath"
    }

    # Update PowerShell profiles to include transcript configuration
    Write-Log "Updating PowerShell profiles with transcript configuration..."

    # Read transcript configuration
    $transcriptEnvConfig = @"

# PowerShell Transcript Configuration
`$env:TRANSCRIPT_LOG_DIR = "$transcriptLogDir"
"@

    # Add transcript config to profiles if not already present
    foreach ($profilePath in @($ps5ProfilePath, $ps7ProfilePath)) {
        if (Test-Path $profilePath) {
            $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

            if ($profileContent -notmatch "TRANSCRIPT_LOG_DIR") {
                # Find the line that sources llm-integration.ps1
                $lines = Get-Content $profilePath
                $insertIndex = -1

                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match "# LLM Tools Integration") {
                        $insertIndex = $i
                        break
                    }
                }

                if ($insertIndex -ge 0) {
                    # Insert transcript config before LLM Tools Integration comment
                    $newContent = ($lines[0..($insertIndex-1)] + $transcriptEnvConfig + $lines[$insertIndex..($lines.Count-1)]) -join "`n"
                    Set-Content -Path $profilePath -Value $newContent -Encoding UTF8
                    Write-Log "Added transcript configuration to $(Split-Path $profilePath -Leaf)"
                }
            }
        }
    }
}

Write-Host ""

# ============================================================================
# Phase 9: Install Additional Tools
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
        npm config set prefix $npmGlobalPrefix

        # Add to PATH for current session
        Add-ToPath $npmGlobalPrefix

        Write-Log "npm configured to use: $npmGlobalPrefix"
    } catch {
        Write-WarningLog "Failed to configure npm prefix: $_"
    }
}

# Refresh PATH to ensure npm and node are accessible
Refresh-EnvironmentPath

# Install uv tools
Install-UvTool -ToolName "gitingest"
Install-UvTool -ToolName "git+https://github.com/c0ffee0wl/files-to-prompt" -IsGitPackage $true

Write-Host ""

# Install Claude Code & OpenCode
Write-Log "Installing/updating Claude Code and OpenCode..."
Write-Host ""

Install-NpmPackage -PackageName "@anthropic-ai/claude-code"
Install-NpmPackage -PackageName "opencode-ai@latest"

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
Write-Log "  - llm plugins (gemini, vertex, anthropic, tools, fragments, jq, fabric templates, context)"
Write-Log "  - gitingest (Git repository to LLM-friendly text)"
Write-Log "  - files-to-prompt (file content formatter)"
Write-Log "  - context (PowerShell history extraction for AI)"
Write-Log "  - Claude Code (Anthropic's agentic coding CLI)"
Write-Log "  - OpenCode (AI coding agent for terminal)"
Write-Host ""
Write-Log "PowerShell integration files:"
Write-Log "  - $integrationFile"
Write-Host ""
Write-Log "Features:"
Write-Log "  - Automatic PowerShell transcript logging for AI context retrieval"
Write-Log "  - AI command completion with Ctrl+N"
Write-Log "  - Custom assistant template with German responses and security focus"
Write-Host ""
Write-Log "Next steps:"
Write-Log "  1. Restart your PowerShell session or run: . `$PROFILE"
Write-Log "  2. Test llm: llm 'Hello, how are you?'"
Write-Log "  3. Use Ctrl+N in PowerShell for AI command completion"
Write-Log "  4. Test context: context (shows last command)"
Write-Log "  5. Test and configure OpenCode: opencode"
Write-Log "     Configuration: https://opencode.ai/docs/providers"
Write-Host ""
Write-Log "To update all tools in the future, simply re-run this script:"
Write-Log "  .\Install-LlmTools.ps1"
Write-Host ""
Write-Log "To reconfigure Azure OpenAI (e.g. update endpoint or if initially skipped):"
Write-Log "  .\Install-LlmTools.ps1 -Azure"
Write-Host ""
