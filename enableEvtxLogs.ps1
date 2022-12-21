<#
Author: DCO-DEV 1702
Date: 19 Dec 2022
Purpose: A simple PS script to enable [default]/disable DNS-Client & ScheduleTasks EventLogs

Usage: 
------
DISABLE EVTXLOG: powershell.exe -Command "./Enable-EvtLogs.ps1" \
-WinEventLogs Microsoft-Windows-DNS-Client/Operational,Microsoft-Windows-TaskScheduler/Operational -Disable

ENABLE EVTXLOG: powershell.exe -Command "./Enable-EvtLogs.ps1" \
-WinEventLogs Microsoft-Windows-DNS-Client/Operational,Microsoft-Windows-TaskScheduler/Operational

#>

#Requires -RunAsAdministrator

Param (
    [Parameter(Mandatory = $true)]  
    [String[]] $WinEventLogs,
    
    [Parameter(Mandatory = $false)] 
    [Switch] $Disable = $false
)

[bool]$EnableLog = $false
#$WinEventLogs = @( 
#    Microsoft-Windows-DNS-Client/Operational,
#    Microsoft-Windows-TaskScheduler/Operational
#)


if (-not $Disable) {
    $EnableLog = $true
} else {
    $EnableLog = $false
}

$WinEvtxLogs = @()
$WinEvtxLogs = $WinEventLogs.Split(',') -replace '"', ""

$WinEvtxLogs | ForEach-Object {
    
    Write-Host "LogName: $_ -> set to [$EnableLog]" -ForegroundColor Yellow
    $log = New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration $_

    if ($log.IsEnabled -and $EnableLog) {
        Write-Output "$_ is already enabled!"
    } elseif ($log.IsEnabled -eq $False -and $EnableLog) {
        Write-Output "[Enabling]::$_"
        $log.IsEnabled=$EnableLog
        $log.SaveChanges()
    } elseif ($log.IsEnabled -and $EnableLog -eq $False) {
        Write-Output "[Disabling]::$_"
        $log.IsEnabled=$EnableLog
        $log.SaveChanges()
    }
}
