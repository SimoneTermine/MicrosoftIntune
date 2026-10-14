<#
.SYNOPSIS
    Exports Windows Intune managed-device records that have not synced recently.

.DESCRIPTION
    Read-only Microsoft Graph report. It does not retire, wipe, delete, or update devices.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateRange(1, 3650)]
    [int]$DaysSinceLastSync = 90,

    [Parameter()]
    [string]$OutputPath = (Join-Path -Path (Get-Location) -ChildPath ("Intune-StaleDevices-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),

    [Parameter()]
    [switch]$IncludeNeverSynced
)

$ErrorActionPreference = 'Stop'
$requiredModule = 'Microsoft.Graph.DeviceManagement'
$scope = 'DeviceManagementManagedDevices.Read.All'
$cutoff = (Get-Date).ToUniversalTime().AddDays(-$DaysSinceLastSync)

try {
    if (-not (Get-Module -ListAvailable -Name $requiredModule)) {
        throw "Required module '$requiredModule' is not installed. Install it with: Install-Module Microsoft.Graph -Scope CurrentUser"
    }

    Import-Module $requiredModule -ErrorAction Stop
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes $scope -NoWelcome -ErrorAction Stop | Out-Null
    }

    $context = Get-MgContext
    if ($null -eq $context -or $context.Scopes -notcontains $scope) {
        throw "The current Graph session does not have the required delegated scope '$scope'. Disconnect and reconnect with that scope."
    }

    $properties = @('id', 'deviceName', 'serialNumber', 'userPrincipalName', 'lastSyncDateTime', 'operatingSystem', 'osVersion', 'managementAgent', 'azureADDeviceId', 'enrolledDateTime', 'complianceState')
    $devices = @(Get-MgDeviceManagementManagedDevice -All -Property $properties -ErrorAction Stop | Where-Object { $_.OperatingSystem -eq 'Windows' })

    $stale = @($devices | Where-Object {
        if ($null -eq $_.LastSyncDateTime) {
            [bool]$IncludeNeverSynced
        }
        else {
            ([datetimeoffset]$_.LastSyncDateTime).UtcDateTime -lt $cutoff
        }
    })

    $report = foreach ($device in $stale) {
        $lastSync = $null
        $daysOld = $null
        if ($device.LastSyncDateTime) {
            $lastSync = ([datetimeoffset]$device.LastSyncDateTime).UtcDateTime
            $daysOld = [math]::Floor(((Get-Date).ToUniversalTime() - $lastSync).TotalDays)
        }

        [pscustomobject]@{
            DeviceName        = $device.DeviceName
            ManagedDeviceId   = $device.Id
            UserPrincipalName = $device.UserPrincipalName
            SerialNumber      = $device.SerialNumber
            OperatingSystem   = $device.OperatingSystem
            OSVersion         = $device.OsVersion
            ComplianceState   = $device.ComplianceState
            ManagementAgent   = $device.ManagementAgent
            LastSyncDateTime  = $lastSync
            DaysSinceLastSync = $daysOld
            EnrolledDateTime  = $device.EnrolledDateTime
            AzureADDeviceId   = $device.AzureADDeviceId
            ReviewNote        = 'Stale check-in candidate: verify ownership and lifecycle before cleanup.'
        }
    }

    $parent = Split-Path -Path $OutputPath -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }

    if (@($report).Count -gt 0) {
        @($report) | Sort-Object DaysSinceLastSync -Descending | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8
    }
    else {
        $headers = 'DeviceName,ManagedDeviceId,UserPrincipalName,SerialNumber,OperatingSystem,OSVersion,ComplianceState,ManagementAgent,LastSyncDateTime,DaysSinceLastSync,EnrolledDateTime,AzureADDeviceId,ReviewNote'
        Set-Content -LiteralPath $OutputPath -Value $headers -Encoding utf8
    }

    Write-Output ("Found {0} stale Windows managed-device record(s) using a {1}-day threshold. Cutoff: {2:u}. Report: {3}" -f @($report).Count, $DaysSinceLastSync, $cutoff.UtcDateTime, (Resolve-Path -LiteralPath $OutputPath).Path)
}
catch {
    Write-Error $_
    exit 1
}
