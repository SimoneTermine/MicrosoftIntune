<#
.SYNOPSIS
    Renames the Windows Update download cache so Windows can recreate it.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Manual Windows support script for a targeted Windows Update download-cache
    repair. It stops BITS and Windows Update, renames only the Download folder
    under SoftwareDistribution, then restores services that were running before
    the operation. The old cache is retained as a timestamped backup.

    Use -WhatIf to preview the operation. Run from an elevated 64-bit PowerShell
    session during a maintenance window when no update is installing.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param()

$ErrorActionPreference = 'Stop'

$principal = New-Object System.Security.Principal.WindowsPrincipal(
    [System.Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell session.'
}

$cachePath = Join-Path $env:windir 'SoftwareDistribution\Download'
if (-not (Test-Path -LiteralPath $cachePath -PathType Container)) {
    throw "Windows Update download cache was not found: $cachePath"
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path (Split-Path -Parent $cachePath) ("Download.backup.{0}" -f $timestamp)
if (Test-Path -LiteralPath $backupPath) {
    throw "The backup path already exists: $backupPath"
}

$serviceNames = @('BITS', 'wuauserv')
$services = @{}
foreach ($serviceName in $serviceNames) {
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    $services[$serviceName] = [PSCustomObject]@{
        WasRunning = ($service.Status -eq 'Running')
    }
}

$action = 'Stop BITS and Windows Update, rename the download cache, and restore previously running services'
if ($PSCmdlet.ShouldProcess($cachePath, $action)) {
    $renamed = $false
    $restoredServices = [System.Collections.Generic.List[string]]::new()
    try {
        foreach ($serviceName in $serviceNames) {
            $service = Get-Service -Name $serviceName -ErrorAction Stop
            if ($service.Status -ne 'Stopped') {
                Stop-Service -Name $serviceName -Force -ErrorAction Stop
                (Get-Service -Name $serviceName).WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
            }
        }

        Rename-Item -LiteralPath $cachePath -NewName (Split-Path -Leaf $backupPath) -ErrorAction Stop
        $renamed = $true
        New-Item -Path $cachePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    catch {
        if ($renamed -and -not (Test-Path -LiteralPath $cachePath) -and (Test-Path -LiteralPath $backupPath)) {
            Rename-Item -LiteralPath $backupPath -NewName (Split-Path -Leaf $cachePath) -ErrorAction SilentlyContinue
        }
        throw
    }
    finally {
        foreach ($serviceName in $serviceNames) {
            if ($services[$serviceName].WasRunning) {
                try {
                    Start-Service -Name $serviceName -ErrorAction Stop
                    (Get-Service -Name $serviceName).WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
                    $restoredServices.Add($serviceName)
                }
                catch {
                    Write-Warning ("Could not restore service {0} to Running: {1}" -f $serviceName, $_.Exception.Message)
                }
            }
        }
    }

    [PSCustomObject]@{
        Result           = 'CacheRenamed'
        CachePath        = $cachePath
        BackupPath       = $backupPath
        ServicesRestored = ($restoredServices -join ', ')
        CompletedAt      = (Get-Date).ToString('o')
    } | Format-List
}
