# Windows CLI Bootstrap / Update Runbook

This runbook collects the non-Adobe commands from the setup conversation into a reusable format you can adapt into a boot-up script, first-run workstation setup script, or periodic maintenance task.

It covers:

- Azure CLI
- Azure CLI extensions for Kusto and Log Analytics
- GitHub CLI (`gh`)
- Git for Windows
- 7-Zip
- PowerShell 7
- Node.js LTS
- Basic Azure subscription / Log Analytics Workspace query helpers
- Optional WSL Microsoft Defender for Endpoint plug-in health check

Adobe Acrobat is intentionally excluded because the CLI update attempt did not work reliably in your environment.

---

## Why this is useful

A bootstrap/update script is useful because it makes a Windows workstation setup repeatable.

Instead of manually checking each tool, downloading installers, and remembering which extensions are required, the script can:

- Install required tools when they are missing.
- Upgrade existing tools when newer versions are available through `winget`.
- Keep CLI tooling consistent across rebuilds, VMs, lab machines, and security workstations.
- Prepare Azure CLI extensions needed for KQL, Log Analytics, and Azure Data Explorer work.
- Verify that key tools are available after installation.
- Reduce drift between your default lab subscription and security subscription workflows.

The script below is designed to be safe to re-run. It does not uninstall anything, and it uses `winget upgrade` when a package is already present.

---

## Recommended usage

Open **PowerShell as Administrator** and run the commands.

You can use Windows PowerShell 5.1 for the first run, but after PowerShell 7 is installed, use `pwsh` for future runs.

Save the script section below as something like:

```powershell
C:\Scripts\bootstrap-dev-security-tools.ps1
```

Then run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
C:\Scripts\bootstrap-dev-security-tools.ps1
```

After major CLI installs or upgrades, close and reopen Windows Terminal or PowerShell so PATH changes are picked up.

---

## Full bootstrap / update script

```powershell
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

    It is designed to be re-runnable. Existing packages are upgraded.
    Missing packages are installed.

.NOTES
    Run PowerShell as Administrator.
    Reopen your terminal after installation to refresh PATH.
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

    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Ensure-WingetAvailable {
    Write-Section "Checking winget"

    if (-not (Test-CommandExists "winget")) {
        throw "winget was not found. Install or update App Installer from the Microsoft Store, then re-run this script."
    }

    winget --version
}

function Ensure-WingetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    Write-Section "Processing $DisplayName [$Id]"

    $installedOutput = winget list --id $Id -e 2>$null
    $isInstalled = ($LASTEXITCODE -eq 0 -and $installedOutput -match [regex]::Escape($Id))

    if ($isInstalled) {
        Write-Host "$DisplayName appears to be installed. Attempting upgrade..."
        winget upgrade --id $Id -e --source winget `
            --accept-source-agreements `
            --accept-package-agreements
    }
    else {
        Write-Host "$DisplayName does not appear to be installed. Installing..."
        winget install --id $Id -e --source winget `
            --accept-source-agreements `
            --accept-package-agreements
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
        throw "Azure CLI is not available on PATH. Reopen PowerShell after installing Azure CLI, then re-run this script."
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

Ensure-WingetPackage -Id "Microsoft.AzureCLI"      -DisplayName "Azure CLI"
Ensure-WingetPackage -Id "GitHub.cli"              -DisplayName "GitHub CLI"
Ensure-WingetPackage -Id "Git.Git"                 -DisplayName "Git for Windows"
Ensure-WingetPackage -Id "7zip.7zip"               -DisplayName "7-Zip"
Ensure-WingetPackage -Id "Microsoft.PowerShell"    -DisplayName "PowerShell 7"
Ensure-WingetPackage -Id "OpenJS.NodeJS.LTS"       -DisplayName "Node.js LTS"

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
        Write-Warning "[MISSING] $cmd was not found on PATH. You may need to reopen your terminal."
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
```

---

## Package command reference

### Azure CLI

**Purpose:** Required for managing Azure resources, subscriptions, Log Analytics workspaces, and Azure CLI extensions.

Install or upgrade:

```powershell
winget install --exact --id Microsoft.AzureCLI --source winget
winget upgrade --id Microsoft.AzureCLI -e --source winget
```

Verify:

```powershell
az version
az login
az account show -o table
```

Why it matters:

- Gives you the `az` command.
- Required for Azure resource automation.
- Required before installing Azure CLI extensions such as `kusto` and `log-analytics`.

---

### Azure CLI extension: Kusto

**Purpose:** Adds `az kusto` commands for Azure Data Explorer / Kusto cluster management.

Install or upgrade:

```powershell
az extension add --name kusto --upgrade
```

Verify:

```powershell
az extension show --name kusto -o table
az kusto --help
```

Why it matters:

- Useful for Azure Data Explorer / Kusto cluster administration.
- Different from Log Analytics querying. Use this for Azure Data Explorer resources.

---

### Azure CLI extension: Log Analytics preview

**Purpose:** Adds or updates Log Analytics CLI support, including KQL query support against Log Analytics workspaces.

Install or upgrade:

```powershell
az extension add --name log-analytics --upgrade --allow-preview true
```

Verify:

```powershell
az extension show --name log-analytics -o table
az monitor log-analytics query --help
```

Why it matters:

- Lets you run KQL against a Log Analytics Workspace from the CLI.
- Useful for Microsoft Sentinel, Defender, Azure Monitor, and security operations workflows.

---

### GitHub CLI

**Purpose:** Provides the `gh` command for GitHub authentication, repository operations, issues, pull requests, workflows, and more.

Install or upgrade:

```powershell
winget install --id GitHub.cli --source winget
winget upgrade --id GitHub.cli -e --source winget
```

Authenticate:

```powershell
gh auth login
gh auth status
```

Verify:

```powershell
gh --version
```

Why it matters:

- Allows GitHub automation from PowerShell.
- Useful for cloning repositories, managing PRs, checking workflow runs, and authenticating to GitHub from CLI tools.

Important distinction:

- `gh` is the GitHub CLI.
- `git` is still needed for normal source control commands like `git clone`, `git status`, `git commit`, and `git push`.

---

### Git for Windows

**Purpose:** Provides the `git` command-line client for source control.

Install or upgrade:

```powershell
winget install --id Git.Git -e --source winget
winget upgrade --id Git.Git -e --source winget
```

Verify:

```powershell
git --version
where.exe git
```

Why it matters:

- Required for standard Git workflows.
- Complements `gh`, but is not replaced by `gh`.

---

### 7-Zip

**Purpose:** Provides archive extraction and compression from the GUI and CLI.

Install or upgrade:

```powershell
winget install --id 7zip.7zip -e --source winget
winget upgrade --id 7zip.7zip -e --source winget
```

Verify:

```powershell
winget list --id 7zip.7zip
& "$env:ProgramFiles\7-Zip\7z.exe" i
```

Optional: add 7-Zip to the system PATH:

```powershell
[Environment]::SetEnvironmentVariable(
  "Path",
  [Environment]::GetEnvironmentVariable("Path", "Machine") + ";$env:ProgramFiles\7-Zip",
  "Machine"
)
```

Then open a new terminal and test:

```powershell
7z i
```

Why it matters:

- Useful for scripted extraction of `.zip`, `.7z`, `.tar`, and other archive formats.
- Helpful in setup scripts that download and unpack tools.

---

### PowerShell 7

**Purpose:** Installs the modern cross-platform PowerShell runtime, available as `pwsh`.

Install or upgrade:

```powershell
winget install --id Microsoft.PowerShell -e --source winget
winget upgrade --id Microsoft.PowerShell -e --source winget
```

Verify:

```powershell
pwsh --version
$PSHOME
```

Why it matters:

- PowerShell 7 is newer than Windows PowerShell 5.1.
- Better for modern automation and cross-platform scripting.
- Installs side-by-side with Windows PowerShell.

---

### Node.js LTS

**Purpose:** Installs Node.js and npm for JavaScript/TypeScript tooling.

Recommended LTS install or upgrade:

```powershell
winget install --id OpenJS.NodeJS.LTS -e --source winget
winget upgrade --id OpenJS.NodeJS.LTS -e --source winget
```

Verify:

```powershell
node -v
npm -v
where.exe node
where.exe npm
```

Why it matters:

- Required for many developer tools, static site generators, package managers, CLIs, and build systems.
- LTS is recommended for stability.

Optional: install current non-LTS Node.js instead:

```powershell
winget install --id OpenJS.NodeJS -e --source winget
winget upgrade --id OpenJS.NodeJS -e --source winget
```

Use Current only if you specifically need the newest Node.js runtime features.

---

## Azure subscription helpers

You mentioned access to a default `zolab` subscription and a separate `security` subscription.

List subscriptions:

```powershell
az account list --query "[].{Name:name, Id:id, Default:isDefault}" -o table
```

Switch to the security subscription:

```powershell
az account set --subscription "security"
az account show --query "{Name:name, Id:id, Tenant:tenantId}" -o table
```

Or use a subscription ID:

```powershell
az account set --subscription "<security-subscription-id>"
```

Why it matters:

- Azure CLI commands use the active subscription unless you pass `--subscription`.
- If your Log Analytics Workspace is in the `security` subscription, switch to that subscription before locating or querying the workspace.

---

## Log Analytics Workspace / KQL helpers

List Log Analytics workspaces in the active subscription:

```powershell
az monitor log-analytics workspace list `
  --query "[].{Name:name, ResourceGroup:resourceGroup, WorkspaceId:customerId, Location:location}" `
  -o table
```

Get a workspace GUID / customer ID:

```powershell
$rg = "<law-resource-group>"
$workspaceName = "<log-analytics-workspace-name>"

$workspaceId = az monitor log-analytics workspace show `
  --resource-group $rg `
  --workspace-name $workspaceName `
  --query customerId `
  -o tsv

$workspaceId
```

Run a basic KQL query:

```powershell
az monitor log-analytics query `
  --workspace $workspaceId `
  --analytics-query "Heartbeat | take 10" `
  --timespan P1D `
  -o table
```

Use a PowerShell here-string for longer KQL:

```powershell
$kql = @"
Heartbeat
| summarize Count=count() by Computer
| order by Count desc
"@

az monitor log-analytics query `
  --workspace $workspaceId `
  --analytics-query $kql `
  --timespan P1D `
  -o table
```

Query with an explicit subscription:

```powershell
$securitySub = "security"
$rg = "<law-resource-group>"
$workspaceName = "<log-analytics-workspace-name>"

$workspaceId = az monitor log-analytics workspace show `
  --subscription $securitySub `
  --resource-group $rg `
  --workspace-name $workspaceName `
  --query customerId `
  -o tsv

az monitor log-analytics query `
  --subscription $securitySub `
  --workspace $workspaceId `
  --analytics-query "AzureActivity | take 10" `
  --timespan P1D `
  -o table
```

Important:

- `--workspace` expects the Log Analytics Workspace GUID / `customerId`.
- It does not expect the workspace name or Azure resource ID.

Why it matters:

- This lets you query Microsoft Sentinel / Azure Monitor data from the CLI.
- It is useful for repeatable investigations, automation, and validation after deployments.

---

## Optional: WSL Microsoft Defender for Endpoint plug-in health check

This does not install or update the plug-in, but it checks the currently installed version and health status if the plug-in is present.

```powershell
cd "$env:ProgramFiles\Microsoft Defender for Endpoint plug-in for WSL\tools"
.\healthcheck.exe
```

Why it matters:

- Useful for validating whether the WSL 2 Microsoft Defender for Endpoint plug-in is installed and healthy.
- Helpful after security baseline changes or workstation rebuilds.

---

## Post-run checklist

After running the bootstrap script:

```powershell
az version
az extension list -o table
gh --version
gh auth status
git --version
pwsh --version
node -v
npm -v
& "$env:ProgramFiles\7-Zip\7z.exe" i
```

Then authenticate where needed:

```powershell
az login
gh auth login
```

Set the right Azure subscription for security work:

```powershell
az account set --subscription "security"
az account show -o table
```

---

## Suggested maintenance cadence

Run the bootstrap/update script:

- After rebuilding a workstation.
- After creating a new lab VM.
- Before starting a major Azure / security lab.
- Monthly as a light update routine.
- Any time `az`, `gh`, `git`, `node`, or `pwsh` behave unexpectedly.

The script is not a full patch-management replacement, but it is a practical CLI tooling baseline.
