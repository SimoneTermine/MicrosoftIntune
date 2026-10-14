<#
.SYNOPSIS
    Exports possible duplicate Windows Intune managed-device records by serial number.

.DESCRIPTION
    Read-only Microsoft Graph report. It does not retire, wipe, delete, or update
    devices. Review every candidate in Intune and Entra before taking action.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = (Join-Path -Path (Get-Location) -ChildPath ("Intune-DuplicateDevices-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

$ErrorActionPreference = 'Stop'
$requiredModule = 'Microsoft.Graph.DeviceManagement'
$scope = 'DeviceManagementManagedDevices.Read.All'

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

    $properties = @(
        'id', 'deviceName', 'serialNumber', 'userPrincipalName', 'lastSyncDateTime',
        'operatingSystem', 'osVersion', 'managementAgent', 'azureADDeviceId',
        'enrolledDateTime', 'complianceState'
    )

    Write-Verbose 'Retrieving managed devices from Microsoft Graph...'
    $managedDevices = @(
        Get-MgDeviceManagementManagedDevice -All -Property $properties -ErrorAction Stop |
            Where-Object { $_.OperatingSystem -eq 'Windows' -and -not [string]::IsNullOrWhiteSpace($_.SerialNumber) }
    )

    $duplicateGroups = @(
        $managedDevices |
            Group-Object -Property { $_.SerialNumber.Trim().ToUpperInvariant() } |
            Where-Object { $_.Count -gt 1 }
    )

    $report = [System.Collections.Generic.List[object]]::new()
    foreach ($group in $duplicateGroups) {
        $orderedGroup = @($group.Group | Sort-Object -Property LastSyncDateTime -Descending)
        $mostRecentlySyncedId = $null
        if ($orderedGroup.Count -gt 0) { $mostRecentlySyncedId = $orderedGroup[0].Id }

        foreach ($device in $orderedGroup) {
            $report.Add([pscustomobject]@{
                SerialNumber             = $device.SerialNumber
                DeviceName               = $device.DeviceName
                ManagedDeviceId          = $device.Id
                UserPrincipalName        = $device.UserPrincipalName
                OperatingSystem          = $device.OperatingSystem
                OSVersion                = $device.OsVersion
                ComplianceState          = $device.ComplianceState
                ManagementAgent          = $device.ManagementAgent
                LastSyncDateTime         = $device.LastSyncDateTime
                EnrolledDateTime         = $device.EnrolledDateTime
                AzureADDeviceId          = $device.AzureADDeviceId
                MostRecentlySyncedRecord = ($device.Id -eq $mostRecentlySyncedId)
                ReviewNote               = 'Possible duplicate: verify in Intune and Entra before any cleanup.'
            })
        }
    }

    $parent = Split-Path -Path $OutputPath -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    if ($report.Count -gt 0) {
        $report | Sort-Object SerialNumber, DeviceName | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8
    }
    else {
        $headers = 'SerialNumber,DeviceName,ManagedDeviceId,UserPrincipalName,OperatingSystem,OSVersion,ComplianceState,ManagementAgent,LastSyncDateTime,EnrolledDateTime,AzureADDeviceId,MostRecentlySyncedRecord,ReviewNote'
        Set-Content -LiteralPath $OutputPath -Value $headers -Encoding utf8
    }

    Write-Output ("Found {0} duplicate serial number group(s), covering {1} device record(s). Report: {2}" -f $duplicateGroups.Count, $report.Count, (Resolve-Path -LiteralPath $OutputPath).Path)
}
catch {
    Write-Error $_
    exit 1
}
