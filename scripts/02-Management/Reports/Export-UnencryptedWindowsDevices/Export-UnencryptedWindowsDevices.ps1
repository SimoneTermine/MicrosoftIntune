<#
.SYNOPSIS
    Exports Windows Intune managed devices reported as not encrypted.

.DESCRIPTION
    Read-only Microsoft Graph report using the managedDevice isEncrypted
    property. By default, exports records where the property is false. Use
    -IncludeUnknown to include records where Graph returned no encryption value.
    This report does not read BitLocker state locally or change device settings.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path -Path (Get-Location).Path -ChildPath ("Intune-Unencrypted-Windows-Devices-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [switch]$IncludeUnknown
)

$ErrorActionPreference = 'Stop'
$scope = 'DeviceManagementManagedDevices.Read.All'

try {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement)) {
        throw 'Microsoft.Graph.DeviceManagement is not installed. Install it with: Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser'
    }

    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop

    $graphContext = Get-MgContext
    if (-not $graphContext -or $graphContext.AuthType -ne 'Delegated' -or $graphContext.Scopes -notcontains $scope) {
        Connect-MgGraph -Scopes $scope -NoWelcome
    }

    $devices = Get-MgDeviceManagementManagedDevice -All -Property @(
        'id', 'deviceName', 'operatingSystem', 'osVersion', 'azureADDeviceId',
        'isEncrypted', 'managedDeviceOwnerType', 'managementAgent',
        'complianceState', 'lastSyncDateTime', 'serialNumber', 'manufacturer', 'model'
    )

    $results = @(
        $devices |
            Where-Object {
                $_.OperatingSystem -eq 'Windows' -and (
                    ($null -ne $_.IsEncrypted -and -not [bool]$_.IsEncrypted) -or
                    ($IncludeUnknown -and $null -eq $_.IsEncrypted)
                )
            } |
            ForEach-Object {
                $encryptionStatus = if ($null -eq $_.IsEncrypted) { 'Unknown' } elseif ([bool]$_.IsEncrypted) { 'Encrypted' } else { 'NotEncrypted' }
                [PSCustomObject]@{
                    DeviceName            = $_.DeviceName
                    OperatingSystem       = $_.OperatingSystem
                    OSVersion             = $_.OsVersion
                    EncryptionStatus      = $encryptionStatus
                    IsEncrypted           = $_.IsEncrypted
                    SerialNumber          = $_.SerialNumber
                    Manufacturer          = $_.Manufacturer
                    Model                 = $_.Model
                    ManagedDeviceOwner    = $_.ManagedDeviceOwnerType
                    ManagementAgent       = $_.ManagementAgent
                    ComplianceState       = $_.ComplianceState
                    LastSyncDateTime      = $_.LastSyncDateTime
                    IntuneManagedDeviceId = $_.Id
                    EntraDeviceId         = $_.AzureADDeviceId
                }
            }
    )

    $parent = Split-Path -Path $OutputPath -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    if ($results.Count -gt 0) {
        $results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
    }
    else {
        'DeviceName,OperatingSystem,OSVersion,EncryptionStatus,IsEncrypted,SerialNumber,Manufacturer,Model,ManagedDeviceOwner,ManagementAgent,ComplianceState,LastSyncDateTime,IntuneManagedDeviceId,EntraDeviceId' |
            Set-Content -LiteralPath $OutputPath -Encoding UTF8
    }
    Write-Output ("Exported {0} Windows device record(s) to {1}" -f $results.Count, (Resolve-Path -LiteralPath $OutputPath).Path)
}
catch {
    Write-Error -Message $_.Exception.Message
    exit 1
}
