<#
.SYNOPSIS
    Install or update common Windows CLI tooling for Azure, GitHub, KQL, PowerShell, Node.js, and utilities.

.DESCRIPTION
    This script installs or updates:
      - Azure CLI
      - GitHub CLI
      - Git for Windows
      - 7-Zip
      - PowerShell 7
      - Node.js LTS
      - Azure CLI extensions: kusto, log-analytics

    It is designed to be re-runnable:
      - Existing winget packages are upgraded.
      - Missing winget packages are installed.
      - Azure CLI extensions are added or upgraded.

    Adobe Acrobat is intentionally excluded.

.NOTES
    Run PowerShell as Administrator.
    Reopen your terminal after installation to refresh PATH.

    If an installer fails with exit code 1625, that usually means Windows Installer is blocked
    by device or organization policy. The fix is usually policy/IT approval, not a syntax change.
#>

$ErrorActionPreference = "Stop"

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

function Test-CommandExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Ensure-WingetAvailable {
    Write-Section "Checking winget"

    if (-not (Test-CommandExists "winget")) {
        throw "winget was not found. Install or update App Installer from the Microsoft Store, then re-run this script."
    }

    winget --version
}

function Invoke-WingetInstallOrUpgrade {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("install", "upgrade")]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    Write-Host "Running: winget $Action --id $Id"

    & winget $Action --id $Id -e --source winget `
        --accept-source-agreements `
        --accept-package-agreements

    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "[OK] $DisplayName $Action completed."
        return
    }

    if ($exitCode -eq 1625) {
        Write-Warning "$DisplayName failed with MSI exit code 1625."
        Write-Warning "That means installation is forbidden by system policy. Contact your device/admin team or use an approved software deployment channel."
        return
    }

    Write-Warning "$DisplayName winget $Action exited with code $exitCode."
}

function Ensure-WingetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    Write-Section "Processing $DisplayName [$Id]"

    $installedOutput = & winget list --id $Id -e 2>$null
    $listExitCode = $LASTEXITCODE
    $isInstalled = ($listExitCode -eq 0 -and $installedOutput -match [regex]::Escape($Id))

    if ($isInstalled) {
        Write-Host "$DisplayName appears to be installed. Attempting upgrade..."
        Invoke-WingetInstallOrUpgrade -Action "upgrade" -Id $Id -DisplayName $DisplayName
    }
    else {
        Write-Host "$DisplayName does not appear to be installed. Installing..."
        Invoke-WingetInstallOrUpgrade -Action "install" -Id $Id -DisplayName $DisplayName
    }
}

function Ensure-AzExtension {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [switch]$AllowPreview
    )

    Write-Section "Installing/upgrading Azure CLI extension: $Name"

    if (-not (Test-CommandExists "az")) {
        Write-Warning "Azure CLI is not available on PATH. Reopen PowerShell after installing Azure CLI, then re-run this script."
        return
    }

    if ($AllowPreview) {
        az extension add --name $Name --upgrade --allow-preview true
    }
    else {
        az extension add --name $Name --upgrade
    }
}

Ensure-WingetAvailable

Write-Section "Installing or updating core packages"

Ensure-WingetPackage -Id "Microsoft.AzureCLI"   -DisplayName "Azure CLI"
Ensure-WingetPackage -Id "GitHub.cli"           -DisplayName "GitHub CLI"
Ensure-WingetPackage -Id "Git.Git"              -DisplayName "Git for Windows"
Ensure-WingetPackage -Id "7zip.7zip"            -DisplayName "7-Zip"
Ensure-WingetPackage -Id "Microsoft.PowerShell" -DisplayName "PowerShell 7"

# Use Node.js LTS by default for stability. Current Node.js can be installed separately with OpenJS.NodeJS.
Ensure-WingetPackage -Id "OpenJS.NodeJS.LTS"    -DisplayName "Node.js LTS"

Write-Section "Installing or updating Azure CLI extensions"

Ensure-AzExtension -Name "kusto"
Ensure-AzExtension -Name "log-analytics" -AllowPreview

Write-Section "Verification"

$commandsToCheck = @(
    "az",
    "gh",
    "git",
    "pwsh",
    "node",
    "npm"
)

foreach ($cmd in $commandsToCheck) {
    if (Test-CommandExists $cmd) {
        Write-Host "[OK] $cmd found at: $((Get-Command $cmd).Source)"
    }
    else {
        Write-Warning "[MISSING] $cmd was not found on PATH. You may need to reopen your terminal or the install may have been blocked."
    }
}

Write-Section "Version checks"

if (Test-CommandExists "az")   { az version }
if (Test-CommandExists "gh")   { gh --version }
if (Test-CommandExists "git")  { git --version }
if (Test-CommandExists "pwsh") { pwsh --version }
if (Test-CommandExists "node") { node -v }
if (Test-CommandExists "npm")  { npm -v }

$sevenZipPath = "$env:ProgramFiles\7-Zip\7z.exe"
if (Test-Path $sevenZipPath) {
    & $sevenZipPath i
}
else {
    Write-Warning "7z.exe was not found at $sevenZipPath"
}

Write-Section "Next manual steps"

Write-Host "1. Reopen PowerShell or Windows Terminal."
Write-Host "2. Run: az login"
Write-Host "3. Run: gh auth login"
Write-Host "4. If needed, set your Azure subscription with: az account set --subscription '<subscription-name-or-id>'"
Write-Host "5. If Node.js failed with 1625, use your organization's approved software deployment path."
