#Requires -Version 5.1
<#
.SYNOPSIS
    Test script for PowerShell Context System

.DESCRIPTION
    Tests the functionality of the context system including:
    - Transcript environment variables
    - Transcript file creation
    - Context command availability
    - Context retrieval functionality
    - LLM plugin integration

.EXAMPLE
    .\tests\test-context-system.ps1

.NOTES
    Requires: PowerShell 5.1+, Python, llm with context plugin
#>

$ErrorActionPreference = "Stop"

# Test counter
$testsPassed = 0
$testsFailed = 0
$testsTotal = 0

function Write-TestHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Feature {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$SuccessMessage,
        [string]$FailureMessage
    )

    $script:testsTotal++

    Write-Host "[Test $script:testsTotal] $TestName..." -NoNewline

    try {
        $result = & $TestScript
        if ($result) {
            Write-Host " PASS" -ForegroundColor Green
            if ($SuccessMessage) {
                Write-Host "  → $SuccessMessage" -ForegroundColor Gray
            }
            $script:testsPassed++
            return $true
        } else {
            Write-Host " FAIL" -ForegroundColor Red
            if ($FailureMessage) {
                Write-Host "  → $FailureMessage" -ForegroundColor Yellow
            }
            $script:testsFailed++
            return $false
        }
    } catch {
        Write-Host " ERROR" -ForegroundColor Red
        Write-Host "  → Exception: $_" -ForegroundColor Yellow
        $script:testsFailed++
        return $false
    }
}

# ============================================================================
# Start Testing
# ============================================================================

Write-TestHeader "PowerShell Context System Test Suite"

# ============================================================================
# Test 1: Transcript Environment Variables
# ============================================================================

Test-Feature `
    -TestName "Checking TRANSCRIPT_LOG_FILE environment variable" `
    -TestScript {
        -not [string]::IsNullOrWhiteSpace($env:TRANSCRIPT_LOG_FILE)
    } `
    -SuccessMessage "TRANSCRIPT_LOG_FILE = $env:TRANSCRIPT_LOG_FILE" `
    -FailureMessage "TRANSCRIPT_LOG_FILE is not set. Transcript logging may not be enabled."

Test-Feature `
    -TestName "Checking TRANSCRIPT_LOG_DIR environment variable" `
    -TestScript {
        -not [string]::IsNullOrWhiteSpace($env:TRANSCRIPT_LOG_DIR)
    } `
    -SuccessMessage "TRANSCRIPT_LOG_DIR = $env:TRANSCRIPT_LOG_DIR" `
    -FailureMessage "TRANSCRIPT_LOG_DIR is not set. Transcript logging may not be configured."

# ============================================================================
# Test 2: Transcript File Existence
# ============================================================================

Test-Feature `
    -TestName "Verifying transcript file exists" `
    -TestScript {
        if ($env:TRANSCRIPT_LOG_FILE) {
            Test-Path $env:TRANSCRIPT_LOG_FILE
        } else {
            $false
        }
    } `
    -SuccessMessage "Transcript file found at $env:TRANSCRIPT_LOG_FILE" `
    -FailureMessage "Transcript file not found. Transcription may not be running."

Test-Feature `
    -TestName "Verifying transcript directory exists" `
    -TestScript {
        if ($env:TRANSCRIPT_LOG_DIR) {
            Test-Path $env:TRANSCRIPT_LOG_DIR
        } else {
            $false
        }
    } `
    -SuccessMessage "Transcript directory found at $env:TRANSCRIPT_LOG_DIR" `
    -FailureMessage "Transcript directory not found."

# ============================================================================
# Test 3: Context Command Availability
# ============================================================================

Test-Feature `
    -TestName "Checking if context command is available" `
    -TestScript {
        $null -ne (Get-Command context -ErrorAction SilentlyContinue)
    } `
    -SuccessMessage "Context command is available in PATH" `
    -FailureMessage "Context command not found. Run Install-LlmTools.ps1 to install."

Test-Feature `
    -TestName "Checking if context.py exists" `
    -TestScript {
        Test-Path (Join-Path $env:USERPROFILE ".local\bin\context.py")
    } `
    -SuccessMessage "context.py found" `
    -FailureMessage "context.py not found in .local\bin"

Test-Feature `
    -TestName "Checking if context.bat wrapper exists" `
    -TestScript {
        Test-Path (Join-Path $env:USERPROFILE ".local\bin\context.bat")
    } `
    -SuccessMessage "context.bat wrapper found" `
    -FailureMessage "context.bat wrapper not found in .local\bin"

# ============================================================================
# Test 4: Context Retrieval Functionality
# ============================================================================

# Create a test marker command
$testMarker = "CONTEXT_TEST_MARKER_$(Get-Random -Minimum 10000 -Maximum 99999)"
Write-Host ""
Write-Host "Creating test marker: $testMarker" -ForegroundColor Gray
Write-Output $testMarker | Out-Null

# Wait a moment for transcript to flush
Start-Sleep -Milliseconds 500

Test-Feature `
    -TestName "Testing context retrieval (last 1 command)" `
    -TestScript {
        if (Get-Command context -ErrorAction SilentlyContinue) {
            $contextOutput = & context 1 2>&1 | Out-String
            $contextOutput -like "*$testMarker*"
        } else {
            $false
        }
    } `
    -SuccessMessage "Context successfully retrieved test marker" `
    -FailureMessage "Context did not retrieve test marker. Transcript parsing may not be working."

Test-Feature `
    -TestName "Testing context retrieval (last 5 commands)" `
    -TestScript {
        if (Get-Command context -ErrorAction SilentlyContinue) {
            $contextOutput = & context 5 2>&1 | Out-String
            $contextOutput.Length -gt 0
        } else {
            $false
        }
    } `
    -SuccessMessage "Context retrieved last 5 commands" `
    -FailureMessage "Context did not return any data"

# ============================================================================
# Test 5: LLM Plugin Integration
# ============================================================================

Test-Feature `
    -TestName "Checking if llm command is available" `
    -TestScript {
        $null -ne (Get-Command llm -ErrorAction SilentlyContinue)
    } `
    -SuccessMessage "llm command is available" `
    -FailureMessage "llm command not found. Install llm first."

if (Get-Command llm -ErrorAction SilentlyContinue) {
    Test-Feature `
        -TestName "Checking if llm-tools-context plugin is installed" `
        -TestScript {
            $plugins = & llm plugins list 2>&1 | Out-String
            $plugins -like "*llm-tools-context*"
        } `
        -SuccessMessage "llm-tools-context plugin is installed" `
        -FailureMessage "llm-tools-context plugin not found. Run Install-LlmTools.ps1 to install."
}

# ============================================================================
# Test Summary
# ============================================================================

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " Test Summary" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests:  $testsTotal" -ForegroundColor White
Write-Host "Passed:       $testsPassed" -ForegroundColor Green
Write-Host "Failed:       $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "All tests passed! Context system is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed. Please review the output above for details." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Yellow
    Write-Host "  1. Reload PowerShell profile: . `$PROFILE" -ForegroundColor Gray
    Write-Host "  2. Reinstall context system: .\Install-LlmTools.ps1" -ForegroundColor Gray
    Write-Host "  3. Check if Python is installed: python --version" -ForegroundColor Gray
    exit 1
}
