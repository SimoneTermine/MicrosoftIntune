<#
.SYNOPSIS
    Collects local Intune Management Extension logs and selected enrollment diagnostics.

.DESCRIPTION
    Creates a ZIP file locally. It does not upload or transmit the collected data.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputDirectory = (Join-Path $env:ProgramData 'IntuneSupportBundles'),

    [Parameter()]
    [switch]$IncludeDeviceManagementEventLog
)

$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "IntuneClientLogs-$env:COMPUTERNAME-$timestamp"
$stagingPath = Join-Path $env:TEMP $bundleName
$zipPath = Join-Path $OutputDirectory "$bundleName.zip"
$imeLogPath = Join-Path $env:ProgramData 'Microsoft\IntuneManagementExtension\Logs'

try {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    New-Item -Path $stagingPath -ItemType Directory -Force | Out-Null

    $copiedLogCount = 0
    if (Test-Path -LiteralPath $imeLogPath) {
        $destinationLogs = Join-Path $stagingPath 'IME-Logs'
        New-Item -Path $destinationLogs -ItemType Directory -Force | Out-Null
        $imeLogs = @(Get-ChildItem -LiteralPath $imeLogPath -File -ErrorAction Stop)
        foreach ($log in $imeLogs) {
            Copy-Item -LiteralPath $log.FullName -Destination $destinationLogs -Force
            $copiedLogCount++
        }
    }
    else {
        'IME log folder was not found.' | Set-Content -LiteralPath (Join-Path $stagingPath 'IME-Logs-not-found.txt') -Encoding UTF8
    }

    $dsregCmd = Join-Path $env:windir 'System32\dsregcmd.exe'
    if (Test-Path -LiteralPath $dsregCmd) {
        & $dsregCmd /status 2>&1 | Out-File -LiteralPath (Join-Path $stagingPath 'dsregcmd-status.txt') -Encoding utf8
    }

    if ($IncludeDeviceManagementEventLog) {
        $eventLogFile = Join-Path $stagingPath 'DeviceManagement-Enterprise-Diagnostics-Provider-Admin.evtx'
        & (Join-Path $env:windir 'System32\wevtutil.exe') epl 'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin' $eventLogFile '/ow:true'
        if ($LASTEXITCODE -ne 0) {
            "Event log export failed with exit code $LASTEXITCODE." | Set-Content -LiteralPath (Join-Path $stagingPath 'event-log-export-error.txt') -Encoding UTF8
        }
    }

    $metadata = @(
        "ComputerName=$env:COMPUTERNAME"
        "CollectedAt=$(Get-Date -Format o)"
        "PowerShellVersion=$($PSVersionTable.PSVersion)"
        "ImeLogFilesCopied=$copiedLogCount"
        "DeviceManagementEventLogIncluded=$([bool]$IncludeDeviceManagementEventLog)"
    )
    $metadata | Set-Content -LiteralPath (Join-Path $stagingPath 'collection-info.txt') -Encoding UTF8

    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -Path (Join-Path $stagingPath '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force
    Write-Output "Support bundle created: $zipPath"
}
catch {
    Write-Error "Could not create the support bundle: $($_.Exception.Message)"
    exit 1
}
finally {
    if (Test-Path -LiteralPath $stagingPath) {
        Remove-Item -LiteralPath $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
