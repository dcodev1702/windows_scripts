<#
Author: DCO-DEV 1702
Date: 20 Dec 2022
Name: audit_process_creation.ps1

Purpose: Simply enable/disable audit process creation in the registry

Usage:
ENABLE CMD:
  -- local: powershell.exe -Command .\audit_process_creation.ps1

DISABLE CMD:
  -- local: powershell.exe -Command .\audit_process_creation.ps1 -DisableAudit

#>
#Requires -RunAsAdministrator

Param (    
    [Parameter(Mandatory = $false)] 
    [Switch] $DisableAudit = $false
)

[String]$debug_dir = 'C:\Temp'
[String]$debug_file = 'AuditProcessCreationLog.txt'
if (-not (Test-Path -Path $debug_dir)) {
    New-Item -Path $debug_dir -ItemType Directory
}

[String]$file = "$debug_dir\$debug_file"
Write-Output "$(Get-Date -Format G) :: This script enables Audit Process Creation unless the -DisableAudit flag is issued." | Out-File $file -Append

$path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
$key  = 'ProcessCreationIncludeCmdLine_Enabled'
$value = 1  # set to 'enable' by default

# if $DisableAudit -eq True, set $key value to 0 (disable auditing)
if ($DisableAudit) { $value = 0 }

[int]$getValue = (Get-ItemProperty -Path $path).ProcessCreationIncludeCmdLine_Enabled
if ($getValue -eq 1 -and $DisableAudit -eq $false) {
    Write-Output "$(Get-Date -Format G) :: Audit Process Creation is already enabled..." | Out-File $file -Append
    break
}

if ($getValue -eq 0 -and $DisableAudit) {
    Write-Output "$(Get-Date -Format G) :: Audit Process Creation is already disabled..." | Out-File $file -Append
    break
}

# The value's are unique and require modification IOT comply
New-ItemProperty -Path $path -Name $key -Value $value -PropertyType DWORD -Force | Out-Null

$keyValue = (Get-ItemProperty -Path $path).ProcessCreationIncludeCmdLine_Enabled
Write-Output "$(Get-Date -Format G) :: SUCCESS :: Audit Process Creation set value to [$keyValue]" | Out-File $file -Append
